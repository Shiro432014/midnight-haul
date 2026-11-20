-- MonetizationConfig: Game Passes, Developer Products, ежедневные награды и косметика.
-- ВАЖНО: перед публикацией создайте пассы/продукты в Creator Hub
-- (Monetization → Passes / Developer Products) и впишите их ID в поле Id.
-- Пока Id = 0, кнопка «Купить» показывает подсказку вместо окна покупки.

local MonetizationConfig = {}

MonetizationConfig.VipCashBonus = 0.25 -- +25% Cash со сдачи
MonetizationConfig.BoostMultiplier = 2 -- x2 пассивный доход во время буста

MonetizationConfig.GamePasses = {
	VIP = {
		Key = "VIP",
		Id = 0,
		Name = "VIP",
		Description = "+25% Cash со сдачи, золотой ник, VIP-приёмка у скупщика",
		Price = 199,
		Icon = "👑",
	},
	FastScanner = {
		Key = "FastScanner",
		Id = 0,
		Name = "Быстрый сканер",
		Description = "Сканер сразу видит все редкости (без таймера)",
		Price = 149,
		Icon = "📡",
	},
	ExtraSlot = {
		Key = "ExtraSlot",
		Id = 0,
		Name = "+1 слот гаража",
		Description = "Дополнительный пад сверх уровня гаража",
		Price = 99,
		Icon = "🅿️",
	},
	Customization = {
		Key = "Customization",
		Id = 0,
		Name = "Кастомизация",
		Description = "Все неоновые подсветки днища и рамки номеров",
		Price = 79,
		Icon = "🎨",
	},
}
MonetizationConfig.GamePassOrder = { "VIP", "FastScanner", "ExtraSlot", "Customization" }

MonetizationConfig.Products = {
	Cash5k = {
		Key = "Cash5k",
		Id = 0,
		Name = "5 000 Cash",
		Description = "Мгновенно на счёт",
		Price = 49,
		Icon = "💵",
		Category = "Cash",
		Grant = { Cash = 5000 },
	},
	Cash25k = {
		Key = "Cash25k",
		Id = 0,
		Name = "25 000 Cash",
		Description = "Мгновенно на счёт",
		Price = 199,
		Icon = "💰",
		Category = "Cash",
		Grant = { Cash = 25000 },
	},
	SecondChance = {
		Key = "SecondChance",
		Id = 0,
		Name = "Второй шанс",
		Description = "+1 попытка, если в мини-игре закончились попытки",
		Price = 25,
		Icon = "🎲",
		Category = "Boosts",
		Grant = { SecondChances = 1 },
	},
	GarageBoost = {
		Key = "GarageBoost",
		Id = 0,
		Name = "Ускоритель гаража",
		Description = "x2 пассивный доход на 30 минут",
		Price = 75,
		Icon = "⚡",
		Category = "Boosts",
		Grant = { BoostMinutes = 30 },
	},
}
MonetizationConfig.ProductOrder = { "Cash5k", "Cash25k", "SecondChance", "GarageBoost" }

function MonetizationConfig.FindProductById(productId: number)
	for _, product in MonetizationConfig.Products do
		if product.Id ~= 0 and product.Id == productId then
			return product
		end
	end
	return nil
end

-- Косметика: неоновая подсветка днища + рамка номера того же цвета.
MonetizationConfig.Underglows = {
	{ Key = "None", Name = "Без подсветки", Color = Color3.fromRGB(60, 60, 70) },
	{ Key = "Cyan", Name = "Неон-циан", Color = Color3.fromRGB(0, 229, 255) },
	{ Key = "Magenta", Name = "Маджента", Color = Color3.fromRGB(255, 46, 154) },
	{ Key = "Gold", Name = "Золото", Color = Color3.fromRGB(255, 196, 40) },
	{ Key = "Toxic", Name = "Токсик", Color = Color3.fromRGB(120, 255, 60) },
}

function MonetizationConfig.GetUnderglow(key: string)
	for _, glow in MonetizationConfig.Underglows do
		if glow.Key == key then
			return glow
		end
	end
	return nil
end

-- Ежедневные награды: 7 дней подряд, затем цикл сначала.
-- Пропуск дня (>48 ч с последнего получения) сбрасывает серию.
MonetizationConfig.Daily = {
	{ Label = "$500", Cash = 500 },
	{ Label = "$1 000", Cash = 1000 },
	{ Label = "Буст x2 · 10 мин", BoostMinutes = 10 },
	{ Label = "$2 500", Cash = 2500 },
	{ Label = "Подсветка «Маджента»", Cosmetic = "Magenta", Cash = 1000 },
	{ Label = "$5 000 + шанс", Cash = 5000, SecondChances = 1 },
	{ Label = "$8 000 + «Золото» + буст", Cash = 8000, Cosmetic = "Gold", BoostMinutes = 30 },
}
MonetizationConfig.DailyCooldown = 20 * 3600 -- можно забирать раз в 20 часов
MonetizationConfig.DailyStreakReset = 48 * 3600

return MonetizationConfig
