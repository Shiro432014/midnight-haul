-- Util: мелкие общие функции (форматирование, детерминированный бегунок,
-- доступ к RemoteEvent'ам, кулдауны для валидации на сервере).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = {}

function Util.FormatCash(amount: number): string
	local negative = amount < 0
	local digits = tostring(math.floor(math.abs(amount) + 0.5))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	formatted = formatted:gsub("^ ", "")
	return (if negative then "-$" else "$") .. formatted
end

function Util.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Позиция бегунка 0..1 (треугольная волна). Одна и та же формула на клиенте и сервере,
-- поэтому сервер сам вычисляет, где остановился бегунок, по прошедшему времени.
function Util.RunnerPosition(elapsed: number, speed: number): number
	local travel = (elapsed * speed) % 2
	if travel <= 1 then
		return travel
	end
	return 2 - travel
end

-- RemoteEvent'ы лежат в ReplicatedStorage.Remotes. На сервере недостающие создаются.
local REMOTE_NAMES = {
	-- из дизайн-документа
	"StartLockpick", -- S→C: начать мини-игру
	"SubmitLockpickResult", -- C→S: остановка бегунка; S→C: результат попытки
	"SellCar", -- C→S: подтвердить сдачу
	"BuyUpgrade", -- C→S: купить улучшение
	"ClaimDaily", -- C→S: забрать ежедневную награду
	-- служебные
	"DataSync", -- C→S: запросить данные; S→C: снимок данных игрока
	"Notify", -- S→C: тост
	"OpenScrapyard", -- S→C: открыть меню сдачи с расчётом цены
	"GarageAction", -- C→S: действия с падами и косметикой
	"Effect", -- S→C: визуальные эффекты (партиклы/звуки)
}
Util.RemoteNames = REMOTE_NAMES

local cachedFolder: Folder? = nil
local function getRemotesFolder(): Folder
	if cachedFolder then
		return cachedFolder
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if RunService:IsServer() then
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in REMOTE_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	cachedFolder = folder
	return folder
end

function Util.Remote(name: string): RemoteEvent
	local folder = getRemotesFolder()
	if RunService:IsServer() then
		return folder:FindFirstChild(name) :: RemoteEvent
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Кулдаун на игрока: local check = Util.Cooldown(3); if not check(player) then return end
function Util.Cooldown(seconds: number)
	local last: { [Player]: number } = {}
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
	return function(player: Player): boolean
		local now = os.clock()
		local previous = last[player]
		if previous and now - previous < seconds then
			return false
		end
		last[player] = now
		return true
	end
end

-- Проверка, что вызвавший remote игрок реально в игре.
function Util.IsValidPlayer(player: any): boolean
	return typeof(player) == "Instance"
		and player:IsA("Player")
		and player.Parent == game:GetService("Players")
end

function Util.Shuffle(list: { any }, rng: Random)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Util
