-- UpgradeConfig: ветки улучшений, стоимости и эффекты.
-- Стоимость растёт экспоненциально (~ base * 1.6^level), кроме Lockpick —
-- у него цены зафиксированы таблицей из дизайн-документа.
-- Уровень гаража открывает доступ к более высоким тирам остальных улучшений.

local RarityConfig = require(script.Parent.RarityConfig)

local UpgradeConfig = {}

local GROWTH = 1.6

local function roundNice(value: number): number
	if value >= 10000 then
		return math.floor(value / 500 + 0.5) * 500
	end
	return math.floor(value / 50 + 0.5) * 50
end

local function exponential(base: number)
	return function(level: number): number
		return roundNice(base * GROWTH ^ level)
	end
end

-- Мини-игра --------------------------------------------------------------------
UpgradeConfig.BaseAttempts = 3
-- В документе: +2% за уровень и «Mythical на максимуме = 20% вместо 10%».
-- Чтобы оба условия сходились на 4 платных уровнях (2..5), бонус = 2.5% за уровень.
UpgradeConfig.ZoneBonusPerLevel = 0.025
UpgradeConfig.ExtraAttemptLevel = 4 -- с этого уровня Lockpick даёт +1 попытку
UpgradeConfig.EngineBonusPerLevel = 0.05

UpgradeConfig.Branches = {
	Lockpick = {
		Id = "Lockpick",
		DisplayName = "Инструменты взлома",
		Description = "Шире зелёная зона в мини-игре. На 4 уровне +1 попытка.",
		Icon = "🔓",
		MinLevel = 1,
		MaxLevel = 5,
		Costs = { [2] = 1500, [3] = 4000, [4] = 9000, [5] = 18000 },
		RequiredGarage = { [2] = 1, [3] = 2, [4] = 3, [5] = 5 },
	},
	Scanner = {
		Id = "Scanner",
		DisplayName = "Сканер",
		Description = "Показывает машины на карте. Каждый уровень открывает следующую редкость.",
		Icon = "📡",
		MinLevel = 1,
		MaxLevel = 5,
		Cost = exponential(700),
		RequiredGarage = { [2] = 1, [3] = 2, [4] = 4, [5] = 6 },
	},
	Engine = {
		Id = "Engine",
		DisplayName = "Двигатель",
		Description = "+5% к максимальной скорости угнанной машины за уровень.",
		Icon = "⚙️",
		MinLevel = 0,
		MaxLevel = 5,
		Cost = exponential(1100),
		RequiredGarage = { [1] = 1, [2] = 2, [3] = 3, [4] = 5, [5] = 7 },
	},
	Garage = {
		Id = "Garage",
		DisplayName = "Уровень гаража",
		Description = "+1 пад для пассивного дохода и доступ к новым тирам улучшений.",
		Icon = "🏠",
		MinLevel = 1,
		MaxLevel = 10,
		Cost = exponential(940),
		RequiredGarage = {},
	},
}

UpgradeConfig.Order = { "Lockpick", "Scanner", "Engine", "Garage" }

function UpgradeConfig.Get(id: string)
	return UpgradeConfig.Branches[id]
end

-- Стоимость перехода НА уровень `level`. nil, если уровня нет.
function UpgradeConfig.GetCost(id: string, level: number): number?
	local branch = UpgradeConfig.Branches[id]
	if not branch or level <= branch.MinLevel or level > branch.MaxLevel then
		return nil
	end
	if branch.Costs then
		return branch.Costs[level]
	end
	return branch.Cost(level)
end

function UpgradeConfig.GetRequiredGarage(id: string, level: number): number
	local branch = UpgradeConfig.Branches[id]
	if not branch then
		return math.huge
	end
	return branch.RequiredGarage[level] or 1
end

-- Эффекты ----------------------------------------------------------------------
function UpgradeConfig.GetZoneBonus(lockpickLevel: number): number
	return math.max(0, lockpickLevel - 1) * UpgradeConfig.ZoneBonusPerLevel
end

function UpgradeConfig.GetAttempts(lockpickLevel: number): number
	local attempts = UpgradeConfig.BaseAttempts
	if lockpickLevel >= UpgradeConfig.ExtraAttemptLevel then
		attempts += 1
	end
	return attempts
end

function UpgradeConfig.GetSpeedMultiplier(engineLevel: number): number
	return 1 + engineLevel * UpgradeConfig.EngineBonusPerLevel
end

function UpgradeConfig.GetPadCount(garageLevel: number, hasExtraSlotPass: boolean): number
	return garageLevel + (if hasExtraSlotPass then 1 else 0)
end

-- Какие редкости видит сканер. fastScanner (Game Pass) = все редкости, но без таймера.
function UpgradeConfig.CanScan(scannerLevel: number, rarityName: string, fastScanner: boolean): boolean
	if fastScanner then
		return true
	end
	local rarity = RarityConfig.Get(rarityName)
	return rarity ~= nil and scannerLevel >= rarity.ScannerLevel
end

function UpgradeConfig.ScannerShowsTimer(scannerLevel: number): boolean
	return scannerLevel >= 5
end

-- Человекочитаемый эффект уровня (для карточек в меню гаража).
function UpgradeConfig.DescribeLevel(id: string, level: number): string
	if id == "Lockpick" then
		local bonus = UpgradeConfig.GetZoneBonus(level) * 100
		return string.format("Зона +%.1f%%, попыток: %d", bonus, UpgradeConfig.GetAttempts(level))
	elseif id == "Scanner" then
		local names = {}
		for _, rarity in RarityConfig.List do
			if level >= rarity.ScannerLevel then
				table.insert(names, rarity.DisplayName)
			end
		end
		local text = table.concat(names, ", ")
		if UpgradeConfig.ScannerShowsTimer(level) then
			text ..= " + таймер"
		end
		return text
	elseif id == "Engine" then
		return string.format("Скорость +%d%%", level * 5)
	elseif id == "Garage" then
		return string.format("Падов: %d", level)
	end
	return ""
end

return UpgradeConfig
