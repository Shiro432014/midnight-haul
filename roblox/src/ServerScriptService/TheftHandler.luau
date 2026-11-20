-- TheftHandler: мини-игра взлома на стороне сервера.
-- Сервер выбирает зону и скорость, хранит сессию и сам вычисляет, где остановился
-- бегунок (по прошедшему времени и той же формуле, что у клиента — Util.RunnerPosition).
-- Клиент присылает только «я нажал через t секунд после старта попытки».
-- Проверки: сессия существует, id совпадает, время не истекло, попытки не кончились,
-- игрок рядом с машиной, нет спама, заявленное время правдоподобно с учётом пинга.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)
local Util = require(Modules.Util)

local DataManager = require(script.Parent.DataManager)
local CarSpawner = require(script.Parent.CarSpawner)

local TheftHandler = {}

local RESUME_DELAY = 0.6 -- пауза перед стартом каждой попытки (клиент показывает отсчёт/фидбек)
local SECOND_CHANCE_BONUS_TIME = 3

local rng = Random.new()
local sessions: { [Player]: any } = {}
local startCooldown = Util.Cooldown(1)

local remotes = {
	Start = Util.Remote("StartLockpick"),
	Submit = Util.Remote("SubmitLockpickResult"),
	Notify = Util.Remote("Notify"),
	Effect = Util.Remote("Effect"),
}

local function randomZoneStart(width: number): number
	return rng:NextNumber(0.04, 0.96 - width)
end

local function distanceToCar(player: Player, record): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local chassis = CarSpawner.GetChassis(record)
	if not root or not chassis then
		return math.huge
	end
	return (root.Position - chassis.Position).Magnitude
end

-- Сигнализация: мигание фар красным и звук, машина «остывает».
local function triggerAlarm(record)
	local model = record.Model
	CarSpawner.SetState(record, "Alarm")
	local chassis = model.PrimaryPart
	if chassis then
		local sound = Instance.new("Sound")
		sound.Name = "Alarm"
		sound.SoundId = GameConfig.Sounds.Alarm
		sound.Looped = true
		sound.PlaybackSpeed = 0.7
		sound.Volume = 0.8
		sound.RollOffMaxDistance = 140
		sound.Parent = chassis
		sound:Play()
		task.delay(GameConfig.AlarmDuration, function()
			sound:Destroy()
		end)
	end
	local lights = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and (part.Name == "Headlight" or part.Name == "Taillight") then
			table.insert(lights, { Part = part, Color = part.Color })
		end
	end
	task.spawn(function()
		local started = os.clock()
		local on = false
		while os.clock() - started < GameConfig.AlarmDuration and model.Parent do
			on = not on
			for _, light in lights do
				light.Part.Color = if on then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(255, 160, 40)
			end
			task.wait(0.25)
		end
		for _, light in lights do
			if light.Part.Parent then
				light.Part.Color = light.Color
			end
		end
	end)
	task.delay(GameConfig.AlarmLockout, function()
		if record.State == "Alarm" and CarSpawner.Get(record.Id) then
			CarSpawner.SetState(record, "Parked")
		end
	end)
end

local function endSession(player: Player, result: string, reason: string?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	local record = session.Record
	local data = DataManager.Get(player)

	if result == "Success" then
		if data then
			data.Stats.Thefts += 1
			data.Stats.ByRarity[record.Rarity.Name] = (data.Stats.ByRarity[record.Rarity.Name] or 0) + 1
		end
		CarSpawner.MarkStolen(record, player)
		local chassis = CarSpawner.GetChassis(record)
		remotes.Effect:FireAllClients("Success", chassis and chassis.Position, record.Rarity.Name)
		remotes.Notify:FireClient(player, string.format("Угон успешен! %s · %s — вези к скупщику", record.Def.DisplayName, record.Rarity.DisplayName), "Success")
	else
		if data then
			data.Stats.Fails += 1
		end
		if CarSpawner.Get(record.Id) then
			triggerAlarm(record)
		end
		remotes.Notify:FireClient(player, reason or "Взлом сорвался — сработала сигнализация!", "Error")
	end
	DataManager.Sync(player)
end

local function beginLockpick(player: Player, record)
	if not Util.IsValidPlayer(player) or not startCooldown(player) then
		return
	end
	local data = DataManager.Get(player)
	if not data then
		return
	end
	if sessions[player] then
		return
	end
	if record.State ~= "Parked" then
		remotes.Notify:FireClient(player, "Эту машину сейчас нельзя взломать.", "Error")
		return
	end
	if CarSpawner.GetStolenCar(player) then
		remotes.Notify:FireClient(player, "Сначала сдай или поставь в гараж текущую машину.", "Error")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
		return
	end
	if distanceToCar(player, record) > GameConfig.LockpickMaxDistance then
		return
	end

	local lockLevel = data.Upgrades.Lockpick
	local width = math.clamp(record.Rarity.ZoneWidth + UpgradeConfig.GetZoneBonus(lockLevel), 0.05, 0.6)
	local now = os.clock()
	local session = {
		Id = HttpService:GenerateGUID(false),
		Record = record,
		ZoneWidth = width,
		ZoneStart = randomZoneStart(width),
		Speed = record.Rarity.BarSpeed,
		AttemptsLeft = UpgradeConfig.GetAttempts(lockLevel),
		AttemptStartedAt = now + RESUME_DELAY,
		ExpiresAt = now + RESUME_DELAY + GameConfig.LockpickTimeLimit,
		LastSubmit = 0,
	}
	sessions[player] = session
	CarSpawner.SetState(record, "Lockpicking")

	remotes.Start:FireClient(player, {
		SessionId = session.Id,
		CarName = record.Def.DisplayName,
		Rarity = record.Rarity.Name,
		ZoneStart = session.ZoneStart,
		ZoneWidth = session.ZoneWidth,
		Speed = session.Speed,
		Attempts = session.AttemptsLeft,
		TimeLimit = GameConfig.LockpickTimeLimit,
		ResumeDelay = RESUME_DELAY,
		SecondChances = data.SecondChances,
	})

	-- сторож по времени: если клиент молчит — провал
	local sessionId = session.Id
	local function watchdog()
		local current = sessions[player]
		if not current or current.Id ~= sessionId then
			return
		end
		local remaining = current.ExpiresAt + GameConfig.LockpickGrace - os.clock()
		if remaining > 0 then
			task.delay(remaining + 0.05, watchdog)
			return
		end
		remotes.Submit:FireClient(player, { SessionId = sessionId, Result = "Fail", Reason = "Timeout" })
		endSession(player, "Fail", "Время вышло — сработала сигнализация!")
	end
	task.delay(RESUME_DELAY + GameConfig.LockpickTimeLimit + GameConfig.LockpickGrace + 0.05, watchdog)
end

local function onSubmit(player: Player, sessionId: any, elapsed: any)
	if not Util.IsValidPlayer(player) then
		return
	end
	local session = sessions[player]
	if not session or type(sessionId) ~= "string" or session.Id ~= sessionId then
		return
	end
	local now = os.clock()
	local record = session.Record

	if elapsed == "cancel" then
		remotes.Submit:FireClient(player, { SessionId = session.Id, Result = "Fail", Reason = "Cancelled" })
		endSession(player, "Fail", "Взлом прерван — сработала сигнализация!")
		return
	end
	if type(elapsed) ~= "number" or elapsed ~= elapsed or elapsed < 0 or elapsed > 60 then
		return
	end
	if now - session.LastSubmit < GameConfig.LockpickSubmitCooldown then
		return
	end
	session.LastSubmit = now

	-- машина исчезла / игрок ушёл / время вышло
	if not CarSpawner.Get(record.Id) then
		sessions[player] = nil
		remotes.Submit:FireClient(player, { SessionId = session.Id, Result = "Fail", Reason = "Gone" })
		return
	end
	if now > session.ExpiresAt + GameConfig.LockpickGrace then
		remotes.Submit:FireClient(player, { SessionId = session.Id, Result = "Fail", Reason = "Timeout" })
		endSession(player, "Fail", "Время вышло — сработала сигнализация!")
		return
	end
	if distanceToCar(player, record) > GameConfig.LockpickMaxDistance + 4 then
		remotes.Submit:FireClient(player, { SessionId = session.Id, Result = "Fail", Reason = "TooFar" })
		endSession(player, "Fail", "Ты отошёл от машины — сработала сигнализация!")
		return
	end

	-- правдоподобность времени: клиент не может нажать «раньше старта» на сервере
	-- и не может опоздать больше, чем позволяет пинг
	local serverElapsed = now - session.AttemptStartedAt
	local ping = 0.1
	pcall(function()
		ping = player:GetNetworkPing()
	end)
	local maxLag = math.clamp(ping * 2 + 0.35, 0.35, 1.5)
	local plausible = elapsed <= serverElapsed + 0.08 and serverElapsed - elapsed <= maxLag

	local position = Util.RunnerPosition(elapsed, session.Speed)
	local hit = plausible and position >= session.ZoneStart and position <= session.ZoneStart + session.ZoneWidth

	if hit then
		remotes.Submit:FireClient(player, { SessionId = session.Id, Result = "Success", Position = position })
		endSession(player, "Success")
		return
	end

	session.AttemptsLeft -= 1
	local secondChanceUsed = false
	if session.AttemptsLeft <= 0 then
		local data = DataManager.Get(player)
		if data and data.SecondChances > 0 then
			data.SecondChances -= 1
			session.AttemptsLeft = 1
			session.ExpiresAt += SECOND_CHANCE_BONUS_TIME
			secondChanceUsed = true
			DataManager.Sync(player)
		end
	end

	if session.AttemptsLeft <= 0 then
		remotes.Submit:FireClient(player, { SessionId = session.Id, Result = "Fail", Reason = "NoAttempts", Position = position })
		endSession(player, "Fail")
		return
	end

	session.ZoneStart = randomZoneStart(session.ZoneWidth)
	session.AttemptStartedAt = now + RESUME_DELAY
	local data = DataManager.Get(player)
	remotes.Submit:FireClient(player, {
		SessionId = session.Id,
		Result = "Miss",
		Position = position,
		AttemptsLeft = session.AttemptsLeft,
		ZoneStart = session.ZoneStart,
		SecondChanceUsed = secondChanceUsed,
		SecondChances = if data then data.SecondChances else 0,
		ExtraTime = if secondChanceUsed then SECOND_CHANCE_BONUS_TIME else 0,
	})
end

function TheftHandler.Init()
	CarSpawner.OnLockpickRequested = beginLockpick
	remotes.Submit.OnServerEvent:Connect(onSubmit)

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			sessions[player] = nil
			if CarSpawner.Get(session.Record.Id) and session.Record.State == "Lockpicking" then
				CarSpawner.SetState(session.Record, "Parked")
			end
		end
	end)
end

return TheftHandler
