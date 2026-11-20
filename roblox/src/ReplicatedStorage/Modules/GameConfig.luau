-- GameConfig: общие тайминги и параметры геймплея (кроме редкостей — они в RarityConfig).

local GameConfig = {}

-- Спавн машин (CarSpawner)
GameConfig.MinActiveCars = 5
GameConfig.MaxActiveCars = 7
GameConfig.InitialCars = 6
GameConfig.SpawnCheckMin = 25 -- сек
GameConfig.SpawnCheckMax = 40
GameConfig.CarLifetime = 4 * 60 -- припаркованная машина «уезжает» через 4 минуты
GameConfig.SpawnPointCooldown = 60 -- точка свободна снова через 60 сек после угона
GameConfig.AbandonedStolenTimeout = 3 * 60 -- брошенная угнанная машина исчезает

-- Мини-игра (TheftHandler)
GameConfig.LockpickTimeLimit = 10 -- сек на всю мини-игру
GameConfig.LockpickGrace = 0.75 -- запас на пинг
GameConfig.LockpickMaxDistance = 18 -- игрок должен стоять рядом с машиной
GameConfig.LockpickSubmitCooldown = 0.25
GameConfig.AlarmDuration = 6 -- сигнализация после провала
GameConfig.AlarmLockout = 12 -- машина «остыла»: столько секунд её нельзя взломать

-- Скупщик (ScrapyardHandler)
GameConfig.SellCooldown = 3
GameConfig.SellRadius = 32 -- машина должна быть в зоне скупщика (studs от центра)
GameConfig.XpPerCash = 0.1 -- XP = итоговая сумма * 0.1

-- Гараж
GameConfig.PassiveTick = 10 -- сек между начислениями пассивного дохода
GameConfig.ParkRadius = 24
GameConfig.SlotSellRatio = 0.6 -- продажа машины прямо с пада = 60% цены

-- Звуки. rbxasset:// — встроенные файлы клиента Roblox (всегда доступны).
-- Замените на свои rbxassetid://..., если хотите другие.
GameConfig.Sounds = {
	Success = "rbxasset://sounds/electronicpingshort.wav",
	Fail = "rbxasset://sounds/electronicpingshort.wav", -- проигрывается с пониженным тоном
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Alarm = "rbxasset://sounds/electronicpingshort.wav",
	Cash = "rbxasset://sounds/electronicpingshort.wav",
}

return GameConfig
