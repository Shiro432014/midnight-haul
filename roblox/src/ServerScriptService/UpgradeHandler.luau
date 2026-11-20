-- UpgradeHandler: покупка улучшений, пады гаража (пассивный доход) и косметика.
-- Все цены, требования и эффекты — из UpgradeConfig; сервер списывает Cash сам.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UpgradeConfig = require(Modules.UpgradeConfig)
local RarityConfig = require(Modules.RarityConfig)
local CarConfig = require(Modules.CarConfig)
local GameConfig = require(Modules.GameConfig)
local MonetizationConfig = require(Modules.MonetizationConfig)
local CarBuilder = require(Modules.CarBuilder)
local Util = require(Modules.Util)

local DataManager = require(script.Parent.DataManager)
local CarSpawner = require(script.Parent.CarSpawner)

local UpgradeHandler = {}

local remotes = {
	Buy = Util.Remote("BuyUpgrade"),
	Garage = Util.Remote("GarageAction"),
	Notify = Util.Remote("Notify"),
	Effect = Util.Remote("Effect"),
}

local buyCooldown = Util.Cooldown(0.35)
local garageCooldown = Util.Cooldown(0.5)
local parkCooldown = Util.Cooldown(1)

local function notify(player: Player, text: string, kind: string)
	remotes.Notify:FireClient(player, text, kind)
end

local function onBuy(player: Player, upgradeId: any)
	if not Util.IsValidPlayer(player) or type(upgradeId) ~= "string" or not buyCooldown(player) then
		return
	end
	local branch = UpgradeConfig.Get(upgradeId)
	local data = DataManager.Get(player)
	if not branch or not data then
		return
	end
	local current = data.Upgrades[upgradeId] or branch.MinLevel
	local nextLevel = current + 1
	if nextLevel > branch.MaxLevel then
		notify(player, branch.DisplayName .. ": уже максимум.", "Info")
		return
	end
	local required = UpgradeConfig.GetRequiredGarage(upgradeId, nextLevel)
	if data.Upgrades.Garage < required then
		notify(player, string.format("Нужен гараж %d уровня.", required), "Error")
		return
	end
	local cost = UpgradeConfig.GetCost(upgradeId, nextLevel)
	if not cost then
		return
	end
	if not DataManager.SpendCash(player, cost) then
		notify(player, "Не хватает Cash: нужно " .. Util.FormatCash(cost), "Error")
		return
	end
	data.Upgrades[upgradeId] = nextLevel
	DataManager.Sync(player)
	remotes.Effect:FireClient(player, "Upgrade", nil, upgradeId)
	notify(player, string.format("%s → ур. %d", branch.DisplayName, nextLevel), "Success")

	-- двигатель действует и на уже угнанную машину
	if upgradeId == "Engine" then
		local record = CarSpawner.GetStolenCar(player)
		if record then
			record.Model:SetAttribute("MaxSpeed", record.Def.MaxSpeed * UpgradeConfig.GetSpeedMultiplier(nextLevel))
		end
	end
end

local function parkCar(player: Player)
	local data = DataManager.Get(player)
	if not data or not parkCooldown(player) then
		return
	end
	local record = CarSpawner.GetStolenCar(player)
	if not record then
		notify(player, "Пригони угнанную машину, чтобы поставить её на пад.", "Info")
		return
	end
	local zone = workspace.Garage:FindFirstChild("ParkZone") :: BasePart?
	local chassis = CarSpawner.GetChassis(record)
	if not zone or not chassis then
		return
	end
	local flat = Vector3.new(chassis.Position.X - zone.Position.X, 0, chassis.Position.Z - zone.Position.Z)
	if flat.Magnitude > GameConfig.ParkRadius then
		notify(player, "Заедь в зону парковки у входа в гараж.", "Info")
		return
	end
	local pads = DataManager.GetPadCount(player)
	if #data.Parked >= pads then
		notify(player, string.format("Все пады заняты (%d/%d). Улучши гараж или продай машину с пада.", #data.Parked, pads), "Error")
		return
	end
	table.insert(data.Parked, { ModelId = record.Def.Id, Rarity = record.Rarity.Name, ColorIndex = record.ColorIndex })
	CarSpawner.RemoveCar(record, "Parked")
	DataManager.Sync(player)
	notify(player, string.format("%s на паде! +%s / %d сек", record.Def.DisplayName, Util.FormatCash(record.Rarity.PassiveIncome), GameConfig.PassiveTick), "Success")
end

local function ownsUnderglow(player: Player, data, key: string): boolean
	if key == "None" then
		return true
	end
	return DataManager.HasPass(player, "Customization") or data.Cosmetics.Owned[key] == true
end

local function onGarageAction(player: Player, action: any, arg: any)
	if not Util.IsValidPlayer(player) or type(action) ~= "string" or not garageCooldown(player) then
		return
	end
	local data = DataManager.Get(player)
	if not data then
		return
	end

	if action == "SellSlot" then
		if type(arg) ~= "number" or arg ~= math.floor(arg) then
			return
		end
		local entry = data.Parked[arg]
		if not entry then
			return
		end
		local def = CarConfig.Get(entry.ModelId)
		local rarity = RarityConfig.Get(entry.Rarity)
		if not def or not rarity then
			table.remove(data.Parked, arg)
			DataManager.Sync(player)
			return
		end
		local payout = math.floor(def.BasePrice * rarity.Multiplier * GameConfig.SlotSellRatio)
		table.remove(data.Parked, arg)
		data.Stats.Sold += 1
		data.Stats.Earned += payout
		DataManager.AddCash(player, payout)
		DataManager.Sync(player)
		notify(player, string.format("%s продана с пада: +%s", def.DisplayName, Util.FormatCash(payout)), "Cash")
	elseif action == "SetUnderglow" then
		if type(arg) ~= "string" or not MonetizationConfig.GetUnderglow(arg) then
			return
		end
		if not ownsUnderglow(player, data, arg) then
			notify(player, "Подсветка закрыта: нужен пасс «Кастомизация» или ежедневная награда.", "Error")
			return
		end
		data.Cosmetics.Underglow = arg
		local record = CarSpawner.GetStolenCar(player)
		if record then
			CarBuilder.ApplyUnderglow(record.Model, arg)
		end
		DataManager.Sync(player)
	elseif action == "Park" then
		parkCar(player)
	end
end

-- Пассивный доход: каждые 10 сек за каждую машину на паде
local function passiveTick()
	for _, player in Players:GetPlayers() do
		local data = DataManager.Get(player)
		if data and #data.Parked > 0 then
			local pads = DataManager.GetPadCount(player)
			local income = 0
			for index, entry in data.Parked do
				if index > pads then
					break -- если пасс на доп. слот пропал, лишний пад не приносит доход
				end
				local rarity = RarityConfig.Get(entry.Rarity)
				if rarity then
					income += rarity.PassiveIncome
				end
			end
			if DataManager.IsBoostActive(player) then
				income *= MonetizationConfig.BoostMultiplier
			end
			if income > 0 then
				data.Stats.Passive += income
				DataManager.AddCash(player, income)
				remotes.Effect:FireClient(player, "Passive", nil, income)
			end
		end
	end
end

function UpgradeHandler.Init()
	remotes.Buy.OnServerEvent:Connect(onBuy)
	remotes.Garage.OnServerEvent:Connect(onGarageAction)

	local garage = workspace:WaitForChild("Garage")
	local zone = garage:WaitForChild("ParkZone")
	local parkPrompt = zone:WaitForChild("ParkPrompt") :: ProximityPrompt
	parkPrompt.Triggered:Connect(parkCar)

	task.spawn(function()
		while true do
			task.wait(GameConfig.PassiveTick)
			passiveTick()
		end
	end)
end

return UpgradeHandler
