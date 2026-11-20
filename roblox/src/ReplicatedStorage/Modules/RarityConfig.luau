-- RarityConfig: единственный источник правды по редкостям.
-- Веса, цвета, множители цены, сложность мини-игры и пассивный доход.
-- Никакой другой скрипт не должен хардкодить эти значения.

export type Rarity = {
	Name: string,
	DisplayName: string,
	Weight: number,
	Color: Color3,
	Multiplier: number, -- множитель цены у скупщика
	ZoneWidth: number, -- ширина зелёной зоны (доля полосы 0..1) до улучшений
	BarSpeed: number, -- скорость бегунка (длин полосы в секунду)
	PassiveIncome: number, -- Cash за тик пассивного дохода (каждые 10 секунд) на паде гаража
	ScannerLevel: number, -- минимальный уровень сканера, который видит эту редкость
	Order: number,
}

local RarityConfig = {}

-- Порядок важен только для отображения. Ролл не зависит от порядка
-- (кумулятивный weighted random по сумме весов).
local LIST: { Rarity } = {
	{
		Name = "Common",
		DisplayName = "Обычная",
		Weight = 600,
		Color = Color3.fromRGB(160, 164, 178),
		Multiplier = 1.0,
		ZoneWidth = 0.22,
		BarSpeed = 1.2,
		PassiveIncome = 6,
		ScannerLevel = 1,
		Order = 1,
	},
	{
		Name = "Uncommon",
		DisplayName = "Необычная",
		Weight = 300,
		Color = Color3.fromRGB(64, 230, 120),
		Multiplier = 1.6,
		ZoneWidth = 0.20,
		BarSpeed = 1.35,
		PassiveIncome = 10,
		ScannerLevel = 1,
		Order = 2,
	},
	{
		Name = "Rare",
		DisplayName = "Редкая",
		Weight = 200,
		Color = Color3.fromRGB(56, 140, 255),
		Multiplier = 2.8,
		ZoneWidth = 0.17,
		BarSpeed = 1.5,
		PassiveIncome = 18,
		ScannerLevel = 2,
		Order = 3,
	},
	{
		Name = "Epic",
		DisplayName = "Эпическая",
		Weight = 100,
		Color = Color3.fromRGB(170, 80, 255),
		Multiplier = 5.0,
		ZoneWidth = 0.14,
		BarSpeed = 1.65,
		PassiveIncome = 32,
		ScannerLevel = 3,
		Order = 4,
	},
	{
		Name = "Legendary",
		DisplayName = "Легендарная",
		Weight = 50,
		Color = Color3.fromRGB(255, 196, 40),
		Multiplier = 9.0,
		ZoneWidth = 0.12,
		BarSpeed = 1.8,
		PassiveIncome = 60,
		ScannerLevel = 4,
		Order = 5,
	},
	{
		Name = "Mythical",
		DisplayName = "Мифическая",
		Weight = 10,
		Color = Color3.fromRGB(255, 40, 80),
		Multiplier = 18.0,
		ZoneWidth = 0.10,
		BarSpeed = 2.0,
		PassiveIncome = 120,
		ScannerLevel = 5,
		Order = 6,
	},
}

local BY_NAME: { [string]: Rarity } = {}
local TOTAL_WEIGHT = 0
for _, rarity in LIST do
	BY_NAME[rarity.Name] = rarity
	TOTAL_WEIGHT += rarity.Weight
end

RarityConfig.List = LIST
RarityConfig.TotalWeight = TOTAL_WEIGHT

function RarityConfig.Get(name: string): Rarity?
	return BY_NAME[name]
end

-- Weighted random (кумулятивный подход):
-- 1) кидаем число 1..totalWeight
-- 2) идём по списку и вычитаем вес, пока число не попадёт в текущий интервал.
function RarityConfig.Roll(rng: Random?): Rarity
	local roll = if rng then rng:NextInteger(1, TOTAL_WEIGHT) else math.random(1, TOTAL_WEIGHT)
	for _, rarity in LIST do
		if roll <= rarity.Weight then
			return rarity
		end
		roll -= rarity.Weight
	end
	return LIST[1] -- недостижимо при корректных весах
end

-- Шанс выпадения в процентах (для UI/статистики).
function RarityConfig.GetChance(name: string): number
	local rarity = BY_NAME[name]
	if not rarity then
		return 0
	end
	return rarity.Weight / TOTAL_WEIGHT * 100
end

return RarityConfig
