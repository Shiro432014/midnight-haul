-- CarSpawner: спавн, деспавн и состояние машин в городе.
-- Держит 5–7 активных машин на 20–30 точках, редкость — только через RarityConfig.
-- Состояния машины: Parked → Lockpicking → (Alarm → Parked) | Stolen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RarityConfig = require(Modules.RarityConfig)
local CarConfig = require(Modules.CarConfig)
local GameConfig = require(Modules.GameConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)
local CarBuilder = require(Modules.CarBuilder)
local Util = require(Modules.Util)

local DataManager = require(script.Parent.DataManager)

local CarSpawner = {}

export type CarRecord = {
	Id: string,
	Model: Model,
	Def: any,
	Rarity: any,
	ColorIndex: number,
	SpawnPoint: string?,
	SpawnedAt: number,
	ExpiresAt: number,
	State: string,
	Owner: Player?,
	LastDriven: number,
}

local rng = Random.new()
local cars: { [string]: CarRecord } = {}
local points: { [string]: { CFrame: CFrame, Occupant: string?, CooldownUntil: number } } = {}
local activeFolder: Folder

-- Колбэк, который подключает TheftHandler (нажатие «Взломать»)
CarSpawner.OnLockpickRequested = nil :: ((Player, CarRecord) -> ())?

local function setState(record: CarRecord, state: string)
	record.State = state
	record.Model:SetAttribute("State", state)
	local promptInst = record.Model:FindFirstChild("LockpickPrompt", true) :: ProximityPrompt?
	if promptInst then
		promptInst.Enabled = state == "Parked"
	end
end
CarSpawner.SetState = setState

local function collectSpawnPoints()
	local folder = workspace:WaitForChild("CarSpawns")
	for _, child in folder:GetDescendants() do
		if string.match(child.Name, "^CarSpawn_%d+$") then
			local cf
			if child:IsA("BasePart") then
				cf = child.CFrame * CFrame.new(0, -child.Size.Y / 2, 0)
			elseif child:IsA("Attachment") then
				cf = child.WorldCFrame
			end
			if cf then
				-- сохраняем только поворот вокруг Y, чтобы машина стояла ровно
				local _, yaw = cf:ToOrientation()
				points[child.Name] = { CFrame = CFrame.new(cf.Position) * CFrame.Angles(0, yaw, 0), Occupant = nil, CooldownUntil = 0 }
			end
		end
	end
	local count = 0
	for _ in points do
		count += 1
	end
	if count == 0 then
		warn("[CarSpawner] В Workspace.CarSpawns нет точек CarSpawn_XX")
	end
end

local function freePoints(): { string }
	local now = os.clock()
	local result = {}
	for name, point in points do
		if not point.Occupant and point.CooldownUntil <= now then
			table.insert(result, name)
		end
	end
	return result
end

local function releasePoint(record: CarRecord, cooldown: number)
	local name = record.SpawnPoint
	if not name then
		return
	end
	local point = points[name]
	if point and point.Occupant == record.Id then
		point.Occupant = nil
		point.CooldownUntil = os.clock() + cooldown
	end
	record.SpawnPoint = nil
end

function CarSpawner.CountParked(): number
	local count = 0
	for _, record in cars do
		if record.State ~= "Stolen" then
			count += 1
		end
	end
	return count
end

function CarSpawner.SpawnCar(): CarRecord?
	local free = freePoints()
	if #free == 0 then
		return nil
	end
	local pointName = free[rng:NextInteger(1, #free)]
	local point = points[pointName]

	local rarity = RarityConfig.Roll(rng)
	local def = CarConfig.RandomModel(rng)
	local colorIndex = rng:NextInteger(1, #def.Colors)
	local model = CarBuilder.Build(def, rarity, colorIndex, { Physics = true })

	local id = HttpService:GenerateGUID(false)
	local lifetime = GameConfig.CarLifetime
	model.Name = def.Id .. "_" .. string.sub(id, 1, 6)
	model:SetAttribute("CarId", id)
	model:SetAttribute("ModelId", def.Id)
	model:SetAttribute("DisplayName", def.DisplayName)
	model:SetAttribute("Rarity", rarity.Name)
	model:SetAttribute("ExpiresAt", workspace:GetServerTimeNow() + lifetime)
	model:SetAttribute("StolenBy", 0)
	model:PivotTo(point.CFrame * CFrame.new(0, 0.62, 0))

	local body = model:FindFirstChild("Body") :: BasePart
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.Name = "LockpickPrompt"
	lockPrompt.ActionText = "Взломать"
	lockPrompt.ObjectText = string.format("%s · %s", def.DisplayName, rarity.DisplayName)
	lockPrompt.HoldDuration = 0.35
	lockPrompt.MaxActivationDistance = 11
	lockPrompt.RequiresLineOfSight = false
	lockPrompt.KeyboardKeyCode = Enum.KeyCode.E
	lockPrompt.Parent = body

	local record: CarRecord = {
		Id = id,
		Model = model,
		Def = def,
		Rarity = rarity,
		ColorIndex = colorIndex,
		SpawnPoint = pointName,
		SpawnedAt = os.clock(),
		ExpiresAt = os.clock() + lifetime,
		State = "Parked",
		Owner = nil,
		LastDriven = os.clock(),
	}
	cars[id] = record
	point.Occupant = id
	setState(record, "Parked")

	lockPrompt.Triggered:Connect(function(player)
		if record.State == "Parked" and CarSpawner.OnLockpickRequested then
			CarSpawner.OnLockpickRequested(player, record)
		end
	end)

	model.Parent = activeFolder
	return record
end

function CarSpawner.RemoveCar(record: CarRecord, reason: string?)
	if not cars[record.Id] then
		return
	end
	cars[record.Id] = nil
	releasePoint(record, if reason == "Stolen" then GameConfig.SpawnPointCooldown else 0)
	if record.Owner and record.Owner.Parent == Players and record.Owner:GetAttribute("StolenCarId") == record.Id then
		record.Owner:SetAttribute("StolenCarId", nil)
	end
	record.Model:Destroy()
end

function CarSpawner.Get(id: any): CarRecord?
	if type(id) ~= "string" then
		return nil
	end
	return cars[id]
end

function CarSpawner.GetStolenCar(player: Player): CarRecord?
	local id = player:GetAttribute("StolenCarId")
	local record = if type(id) == "string" then cars[id] else nil
	if record and record.Owner == player and record.State == "Stolen" then
		return record
	end
	return nil
end

function CarSpawner.GetChassis(record: CarRecord): BasePart?
	local chassis = record.Model.PrimaryPart
	if chassis and chassis.Parent then
		return chassis
	end
	return nil
end

-- Успешный взлом: машина становится управляемой и привязывается к игроку.
function CarSpawner.MarkStolen(record: CarRecord, player: Player)
	local data = DataManager.Get(player)
	local model = record.Model
	local chassis = model.PrimaryPart :: BasePart
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat

	record.Owner = player
	record.LastDriven = os.clock()
	model:SetAttribute("StolenBy", player.UserId)
	player:SetAttribute("StolenCarId", record.Id)
	setState(record, "Stolen")
	-- точка освобождается и станет доступна через 60 сек
	releasePoint(record, GameConfig.SpawnPointCooldown)

	local engineLevel = if data then data.Upgrades.Engine else 0
	model:SetAttribute("MaxSpeed", record.Def.MaxSpeed * UpgradeConfig.GetSpeedMultiplier(engineLevel))
	model:SetAttribute("TurnRate", record.Def.TurnRate)

	local cosmetic = if data then data.Cosmetics.Underglow else "None"
	CarBuilder.ApplyUnderglow(model, cosmetic)
	local beam = model:FindFirstChild("HeadBeam", true) :: SpotLight?
	if beam then
		beam.Enabled = true
	end

	chassis.Anchored = false
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity
	local steer = chassis:FindFirstChild("Steer") :: AngularVelocity
	drive.Enabled = true
	steer.Enabled = true
	seat.Disabled = false
	pcall(function()
		chassis:SetNetworkOwner(player)
	end)

	-- в машину может сесть только угонщик
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if not occupant then
			return
		end
		local owner = record.Owner
		if not owner or occupant.Parent ~= owner.Character then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			occupant.Jump = true
		else
			record.LastDriven = os.clock()
			pcall(function()
				chassis:SetNetworkOwner(owner)
			end)
		end
	end)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		seat:Sit(humanoid)
	end
end

local function maintenance()
	local now = os.clock()
	for _, record in table.clone(cars) do
		local chassis = CarSpawner.GetChassis(record)
		if not chassis or not record.Model.Parent then
			CarSpawner.RemoveCar(record, "Destroyed")
		elseif record.State == "Stolen" then
			local seat = record.Model:FindFirstChild("DriverSeat") :: VehicleSeat?
			if seat and seat.Occupant then
				record.LastDriven = now
			end
			local owner = record.Owner
			if not owner or owner.Parent ~= Players then
				CarSpawner.RemoveCar(record, "OwnerLeft")
			elseif now - record.LastDriven > GameConfig.AbandonedStolenTimeout then
				Util.Remote("Notify"):FireClient(owner, "Брошенную машину эвакуировали.", "Error")
				CarSpawner.RemoveCar(record, "Abandoned")
			elseif chassis.Position.Y < -40 then
				CarSpawner.RemoveCar(record, "Fell")
			end
		elseif record.State == "Parked" and now >= record.ExpiresAt then
			-- машина «уехала»
			CarSpawner.RemoveCar(record, "Expired")
		end
	end
end

local function spawnTick()
	local parked = CarSpawner.CountParked()
	while parked < GameConfig.MinActiveCars do
		if not CarSpawner.SpawnCar() then
			break
		end
		parked += 1
	end
	-- иногда добираем до 6–7, чтобы город не выглядел пустым
	if parked < GameConfig.MaxActiveCars and rng:NextNumber() < 0.45 then
		CarSpawner.SpawnCar()
	end
end

function CarSpawner.Init()
	activeFolder = Instance.new("Folder")
	activeFolder.Name = "ActiveCars"
	activeFolder.Parent = workspace

	collectSpawnPoints()
	for _ = 1, GameConfig.InitialCars do
		CarSpawner.SpawnCar()
	end

	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(GameConfig.SpawnCheckMin, GameConfig.SpawnCheckMax))
			spawnTick()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			maintenance()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, record in table.clone(cars) do
			if record.Owner == player then
				CarSpawner.RemoveCar(record, "OwnerLeft")
			end
		end
	end)
end

return CarSpawner
