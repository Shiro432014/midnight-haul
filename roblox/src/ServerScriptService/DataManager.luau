-- DataManager: загрузка/сохранение данных игрока через DataStore.
-- UpdateAsync + retry, автосейв каждые 60 сек, сохранение при выходе и BindToClose.
-- Все остальные серверные модули меняют данные только через этот модуль
-- и вызывают DataManager.Sync(player), чтобы клиент получил свежий снимок.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Util = require(Modules.Util)
local UpgradeConfig = require(Modules.UpgradeConfig)
local MonetizationConfig = require(Modules.MonetizationConfig)

local DataManager = {}

local STORE_NAME = "MidnightHaul_v1"
local AUTOSAVE_INTERVAL = 60
local MAX_RETRIES = 4
local MAX_RECEIPTS = 60

local store: DataStore? = nil
local profiles: { [Player]: any } = {}
local loadedCallbacks: { (Player, any) -> () } = {}
local syncQueued: { [Player]: boolean } = {}
local warnedStudio = false

local function defaultData()
	return {
		Version = 1,
		Cash = 0,
		XP = 0,
		Upgrades = { Lockpick = 1, Scanner = 1, Engine = 0, Garage = 1 },
		Parked = {}, -- { {ModelId, Rarity, ColorIndex} }
		SecondChances = 0,
		BoostUntil = 0, -- os.time()
		Daily = { Streak = 0, LastClaim = 0 },
		Cosmetics = { Owned = {}, Underglow = "None" },
		Stats = { Thefts = 0, Fails = 0, Sold = 0, Earned = 0, BestSale = 0, Passive = 0, ByRarity = {} },
		Receipts = {}, -- PurchaseId -> true
		ReceiptOrder = {},
	}
end

-- Добавляет недостающие поля (миграция после обновлений схемы).
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local function withRetries(label: string, fn: () -> any): (boolean, any)
	local lastError
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		if string.find(tostring(result), "StudioAccessToApisNotAllowed") or string.find(tostring(result), "403") then
			break -- в Studio без доступа к API нет смысла повторять
		end
		task.wait(2 ^ (attempt - 1))
	end
	warn(string.format("[DataManager] %s failed: %s", label, tostring(lastError)))
	return false, lastError
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	elseif not warnedStudio then
		warnedStudio = true
		warn("[DataManager] DataStore недоступен (в Studio включите Game Settings → Security → Enable Studio Access to API Services). Прогресс не сохраняется.")
	end
	return store
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = folder
	local rep = Instance.new("IntValue")
	rep.Name = "Реп."
	rep.Value = 1
	rep.Parent = folder
	folder.Parent = player
end

function DataManager.GetRepLevel(xp: number): (number, number)
	-- уровень репутации и прогресс до следующего (0..1)
	local level = math.floor(math.sqrt(xp / 60)) + 1
	local current = (level - 1) ^ 2 * 60
	local nextXp = level ^ 2 * 60
	return level, (xp - current) / (nextXp - current)
end

local function loadProfile(player: Player)
	local profile = { Data = defaultData(), Loaded = false, CanSave = false, Passes = {} }
	profiles[player] = profile
	setupLeaderstats(player)

	local ds = getStore()
	if ds then
		local ok, stored = withRetries("Load " .. player.Name, function()
			return ds:GetAsync(keyFor(player))
		end)
		if ok then
			if type(stored) == "table" then
				profile.Data = reconcile(stored, defaultData())
			end
			profile.CanSave = true
		elseif not RunService:IsStudio() then
			-- Не перезаписываем сохранение пустыми данными, если загрузка не удалась.
			task.defer(function()
				Util.Remote("Notify"):FireClient(player, "Не удалось загрузить сохранение. Прогресс этой сессии не сохранится.", "Error")
			end)
		end
	end

	if player.Parent ~= Players then
		profiles[player] = nil
		return
	end
	profile.Loaded = true
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
	DataManager.Sync(player)
end

function DataManager.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.Loaded or not profile.CanSave then
		return false
	end
	local ds = getStore()
	if not ds then
		return false
	end
	local data = profile.Data
	local ok = withRetries("Save " .. player.Name, function()
		return ds:UpdateAsync(keyFor(player), function(_old)
			return data
		end)
	end)
	return ok
end

-- Публичный API -------------------------------------------------------------------

function DataManager.OnLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		if profile.Loaded then
			task.spawn(callback, player, profile)
		end
	end
end

function DataManager.GetProfile(player: Player)
	local profile = profiles[player]
	if profile and profile.Loaded then
		return profile
	end
	return nil
end

function DataManager.Get(player: Player)
	local profile = DataManager.GetProfile(player)
	return profile and profile.Data
end

function DataManager.CanPersist(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.CanSave
end

function DataManager.HasPass(player: Player, key: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Passes[key] == true
end

function DataManager.SetPass(player: Player, key: string, owned: boolean)
	local profile = profiles[player]
	if profile then
		profile.Passes[key] = owned
		DataManager.Sync(player)
	end
end

function DataManager.AddCash(player: Player, amount: number)
	local data = DataManager.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.Cash += math.floor(amount)
	DataManager.Sync(player)
end

function DataManager.SpendCash(player: Player, amount: number): boolean
	local data = DataManager.Get(player)
	if not data or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= math.floor(amount)
	DataManager.Sync(player)
	return true
end

function DataManager.AddXP(player: Player, amount: number)
	local data = DataManager.Get(player)
	if data and amount > 0 then
		data.XP += math.floor(amount)
		DataManager.Sync(player)
	end
end

function DataManager.GetPadCount(player: Player): number
	local data = DataManager.Get(player)
	if not data then
		return 0
	end
	return UpgradeConfig.GetPadCount(data.Upgrades.Garage, DataManager.HasPass(player, "ExtraSlot"))
end

function DataManager.IsBoostActive(player: Player): boolean
	local data = DataManager.Get(player)
	return data ~= nil and data.BoostUntil > os.time()
end

function DataManager.RecordReceipt(player: Player, purchaseId: string)
	local data = DataManager.Get(player)
	if not data then
		return
	end
	data.Receipts[purchaseId] = true
	table.insert(data.ReceiptOrder, purchaseId)
	while #data.ReceiptOrder > MAX_RECEIPTS do
		local oldest = table.remove(data.ReceiptOrder, 1)
		data.Receipts[oldest] = nil
	end
end

-- Состояние ежедневной награды: какой день сейчас (1..7), можно ли забрать, сколько ждать.
function DataManager.GetDailyState(data)
	local now = os.time()
	local daily = data.Daily
	local streak = daily.Streak
	local sinceLast = now - daily.LastClaim
	if daily.LastClaim > 0 and sinceLast > MonetizationConfig.DailyStreakReset then
		streak = 0
	end
	local canClaim = daily.LastClaim == 0 or sinceLast >= MonetizationConfig.DailyCooldown
	return {
		Day = (streak % #MonetizationConfig.Daily) + 1,
		Streak = streak,
		CanClaim = canClaim,
		NextIn = if canClaim then 0 else MonetizationConfig.DailyCooldown - sinceLast,
	}
end

-- Снимок данных для клиента (только чтение; клиент ничего не решает).
local function buildSnapshot(player: Player, profile)
	local data = profile.Data
	local repLevel, repProgress = DataManager.GetRepLevel(data.XP)
	return {
		Cash = data.Cash,
		XP = data.XP,
		RepLevel = repLevel,
		RepProgress = repProgress,
		Upgrades = data.Upgrades,
		Parked = data.Parked,
		PadCount = DataManager.GetPadCount(player),
		SecondChances = data.SecondChances,
		BoostRemaining = math.max(0, data.BoostUntil - os.time()),
		Daily = DataManager.GetDailyState(data),
		DailyClaimedStreak = data.Daily.Streak,
		Cosmetics = data.Cosmetics,
		Passes = profile.Passes,
		Stats = data.Stats,
		Persisted = profile.CanSave,
	}
end

function DataManager.Sync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		local profile = DataManager.GetProfile(player)
		if not profile or player.Parent ~= Players then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			leaderstats.Cash.Value = profile.Data.Cash
			leaderstats["Реп."].Value = (DataManager.GetRepLevel(profile.Data.XP))
		end
		Util.Remote("DataSync"):FireClient(player, buildSnapshot(player, profile))
	end)
end

function DataManager.Init()
	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			DataManager.Save(player)
			profiles[player] = nil
		end
		syncQueued[player] = nil
	end)

	-- Клиент просит данные при запуске своих скриптов
	local requestCooldown = Util.Cooldown(1)
	Util.Remote("DataSync").OnServerEvent:Connect(function(player)
		if Util.IsValidPlayer(player) and requestCooldown(player) then
			DataManager.Sync(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataManager.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataManager.Save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataManager
