-- CarConfig: модели машин, базовые цены, скорость и параметры внешнего вида.
-- Итоговая цена = BasePrice * RarityConfig.Multiplier (+ бонусы VIP и т.д. на сервере).
-- Форма кузова описывается параметрами, а CarBuilder собирает модель из Part'ов.

local CarConfig = {}

CarConfig.Models = {
	{
		Id = "VestaHatch",
		DisplayName = "Vesta Hatch",
		BasePrice = 420,
		MaxSpeed = 62, -- studs/s
		TurnRate = 2.4, -- рад/с на полной скорости
		Style = { Length = 10.5, Width = 5.6, BodyHeight = 1.5, CabinLength = 6.2, CabinHeight = 1.5, CabinOffset = 0.8, Spoiler = false, Bed = false },
		Colors = { Color3.fromRGB(196, 60, 60), Color3.fromRGB(60, 120, 196), Color3.fromRGB(220, 220, 225), Color3.fromRGB(70, 70, 80) },
	},
	{
		Id = "KestrelSedan",
		DisplayName = "Kestrel Sedan",
		BasePrice = 540,
		MaxSpeed = 66,
		TurnRate = 2.2,
		Style = { Length = 12.5, Width = 6, BodyHeight = 1.5, CabinLength = 6, CabinHeight = 1.4, CabinOffset = 0.3, Spoiler = false, Bed = false },
		Colors = { Color3.fromRGB(30, 30, 36), Color3.fromRGB(150, 150, 160), Color3.fromRGB(40, 70, 120), Color3.fromRGB(110, 20, 30) },
	},
	{
		Id = "AtlasPickup",
		DisplayName = "Atlas Pickup",
		BasePrice = 610,
		MaxSpeed = 60,
		TurnRate = 2.0,
		Style = { Length = 13.5, Width = 6.4, BodyHeight = 1.9, CabinLength = 4.8, CabinHeight = 1.7, CabinOffset = -2.2, Spoiler = false, Bed = true },
		Colors = { Color3.fromRGB(90, 110, 70), Color3.fromRGB(180, 120, 50), Color3.fromRGB(230, 230, 230), Color3.fromRGB(40, 40, 46) },
	},
	{
		Id = "RoninCoupe",
		DisplayName = "Ronin Coupe",
		BasePrice = 720,
		MaxSpeed = 72,
		TurnRate = 2.5,
		Style = { Length = 11.5, Width = 5.8, BodyHeight = 1.3, CabinLength = 5, CabinHeight = 1.2, CabinOffset = 0.9, Spoiler = true, Bed = false },
		Colors = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(20, 20, 24), Color3.fromRGB(230, 230, 240), Color3.fromRGB(0, 150, 140) },
	},
	{
		Id = "ViperGT",
		DisplayName = "Viper GT",
		BasePrice = 900,
		MaxSpeed = 80,
		TurnRate = 2.6,
		Style = { Length = 12, Width = 6.2, BodyHeight = 1.1, CabinLength = 4.4, CabinHeight = 1.05, CabinOffset = 1.2, Spoiler = true, Bed = false },
		Colors = { Color3.fromRGB(230, 20, 40), Color3.fromRGB(250, 210, 0), Color3.fromRGB(15, 15, 18), Color3.fromRGB(0, 200, 255) },
	},
}

local BY_ID = {}
for _, model in CarConfig.Models do
	BY_ID[model.Id] = model
end

function CarConfig.Get(id: string)
	return BY_ID[id]
end

function CarConfig.RandomModel(rng: Random)
	return CarConfig.Models[rng:NextInteger(1, #CarConfig.Models)]
end

return CarConfig
