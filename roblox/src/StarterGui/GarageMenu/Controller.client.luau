-- GarageMenu: меню гаража с вкладками Улучшения / Слоты / Статистика / Тюнинг.
-- Клиент только показывает цены и шлёт запросы (BuyUpgrade, GarageAction);
-- списание Cash, требования и эффекты проверяет сервер (UpgradeHandler).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIKit = require(Modules.UIKit)
local Util = require(Modules.Util)
local ClientState = require(Modules.ClientState)
local UpgradeConfig = require(Modules.UpgradeConfig)
local RarityConfig = require(Modules.RarityConfig)
local CarConfig = require(Modules.CarConfig)
local GameConfig = require(Modules.GameConfig)
local MonetizationConfig = require(Modules.MonetizationConfig)

local gui = script.Parent :: ScreenGui
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local C = UIKit.Colors
local new = UIKit.new

local remoteBuy = Util.Remote("BuyUpgrade")
local remoteGarage = Util.Remote("GarageAction")

local MAX_PADS = UpgradeConfig.Branches.Garage.MaxLevel + 1 -- 10 уровней + пасс «+1 слот»

local modal = UIKit.modal(gui, {
	Title = "ГАРАЖ",
	Subtitle = "",
	Accent = C.Cyan,
	Size = UDim2.fromScale(0.76, 0.8),
	Aspect = 1.6,
	OnClose = function()
		ClientState.CloseMenu("GarageMenu")
	end,
})
local body = modal.Body

local content = new("Frame", {
	Name = "Content",
	Size = UDim2.fromScale(1, 0.86),
	Position = UDim2.fromScale(0, 0.13),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = body,
})

local pages: { [string]: Frame } = {}
local function page(name: string): Frame
	local frame = new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
		Parent = content,
	})
	pages[name] = frame
	return frame
end

local currentTab = "Upgrades"
local tabs = UIKit.tabs(body, {
	{ Key = "Upgrades", Text = "Улучшения" },
	{ Key = "Slots", Text = "Слоты" },
	{ Key = "Stats", Text = "Статистика" },
	{ Key = "Tuning", Text = "Тюнинг" },
}, function(key)
	currentTab = key
	for name, frame in pages do
		frame.Visible = name == key
	end
end)

local function setButtonEnabled(button: TextButton, enabled: boolean, color: Color3?)
	button.BackgroundColor3 = if enabled then (color or C.Cyan) else C.PanelLight
	button.TextColor3 = if enabled then C.Background else C.Muted
end

-- Улучшения ------------------------------------------------------------------------------
local upgradesPage = page("Upgrades")
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0.018, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = upgradesPage,
})

local upgradeCards = {}
for order, id in UpgradeConfig.Order do
	local branch = UpgradeConfig.Get(id)
	local card = UIKit.card({
		Name = id,
		Size = UDim2.fromScale(0.235, 1),
		LayoutOrder = order,
		Aspect = 0.56,
		Parent = upgradesPage,
	})
	UIKit.label({ Text = branch.Icon, Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.04), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 44, Parent = card })
	UIKit.label({ Text = branch.DisplayName, Size = UDim2.fromScale(0.9, 0.08), Position = UDim2.fromScale(0.05, 0.2), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Black, MaxText = 22, Parent = card })
	local levelLabel = UIKit.label({ Text = "", Size = UDim2.fromScale(0.9, 0.055), Position = UDim2.fromScale(0.05, 0.29), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Cyan, MaxText = 18, Parent = card })
	local pips = new("Frame", {
		Name = "Pips",
		Size = UDim2.fromScale(0.84, 0.025),
		Position = UDim2.fromScale(0.08, 0.36),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local pipCount = branch.MaxLevel - branch.MinLevel
	local pipFrames = {}
	for i = 1, pipCount do
		pipFrames[i] = new("Frame", {
			Size = UDim2.fromScale((1 - 0.02 * (pipCount - 1)) / pipCount, 1),
			BackgroundColor3 = C.PanelDark,
			Parent = pips,
		}, { UIKit.corner(1) })
	end
	UIKit.label({ Text = branch.Description, Size = UDim2.fromScale(0.88, 0.16), Position = UDim2.fromScale(0.06, 0.42), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Muted, Font = UIKit.Fonts.Medium, MaxText = 15, Parent = card })
	local nowLabel = UIKit.label({ Text = "", Size = UDim2.fromScale(0.88, 0.075), Position = UDim2.fromScale(0.06, 0.6), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Medium, MaxText = 15, Parent = card })
	local nextLabel = UIKit.label({ Text = "", Size = UDim2.fromScale(0.88, 0.075), Position = UDim2.fromScale(0.06, 0.69), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Cyan, Font = UIKit.Fonts.Bold, MaxText = 15, Parent = card })
	local reqLabel = UIKit.label({ Text = "", Size = UDim2.fromScale(0.88, 0.05), Position = UDim2.fromScale(0.06, 0.78), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Danger, Font = UIKit.Fonts.Bold, MaxText = 14, Parent = card })

	local state = { CanBuy = false, Reason = "" }
	local button = UIKit.button({
		Name = "Buy",
		Text = "",
		Size = UDim2.fromScale(0.86, 0.1),
		Position = UDim2.fromScale(0.07, 0.86),
		MaxText = 18,
		Parent = card,
		OnClick = function()
			if state.CanBuy then
				remoteBuy:FireServer(id)
			elseif state.Reason ~= "" then
				ClientState.Toast(state.Reason, "Info")
			end
		end,
	})
	upgradeCards[id] = { Level = levelLabel, Pips = pipFrames, Now = nowLabel, Next = nextLabel, Req = reqLabel, Button = button, State = state }
end

local function renderUpgrades(data)
	for id, card in upgradeCards do
		local branch = UpgradeConfig.Get(id)
		local level = data.Upgrades[id] or branch.MinLevel
		card.Level.Text = string.format("Ур. %d / %d", level, branch.MaxLevel)
		for i, pip in card.Pips do
			local filled = branch.MinLevel + i <= level
			pip.BackgroundColor3 = if filled then C.Cyan else C.PanelDark
		end
		card.Now.Text = "Сейчас: " .. (if level > 0 then UpgradeConfig.DescribeLevel(id, level) else "стоковый")

		local nextLevel = level + 1
		local cost = UpgradeConfig.GetCost(id, nextLevel)
		if not cost then
			card.Next.Text = "Максимальный уровень"
			card.Req.Text = ""
			card.Button.Text = "МАКС"
			card.State.CanBuy = false
			card.State.Reason = branch.DisplayName .. ": уже максимум."
			setButtonEnabled(card.Button, false)
		else
			card.Next.Text = "Далее: " .. UpgradeConfig.DescribeLevel(id, nextLevel)
			local required = UpgradeConfig.GetRequiredGarage(id, nextLevel)
			local garageOk = data.Upgrades.Garage >= required
			local cashOk = data.Cash >= cost
			card.Req.Text = if garageOk then "" else string.format("Нужен гараж ур. %d", required)
			card.Button.Text = Util.FormatCash(cost)
			card.State.CanBuy = garageOk and cashOk
			card.State.Reason = if not garageOk
				then string.format("Сначала прокачай гараж до %d уровня.", required)
				elseif not cashOk then "Не хватает " .. Util.FormatCash(cost - data.Cash)
				else ""
			setButtonEnabled(card.Button, card.State.CanBuy, if id == "Garage" then C.Magenta else C.Cyan)
			if not cashOk and garageOk then
				card.Button.TextColor3 = C.Danger
			end
		end
	end
end

-- Слоты (пады пассивного дохода) ---------------------------------------------------------
local slotsPage = page("Slots")
local slotsHeader = UIKit.card({
	Name = "Header",
	Size = UDim2.fromScale(1, 0.12),
	Color = C.PanelDark,
	Parent = slotsPage,
})
local slotsInfo = UIKit.label({
	Text = "",
	Size = UDim2.fromScale(0.62, 0.56),
	Position = UDim2.fromScale(0.02, 0.22),
	Font = UIKit.Fonts.Bold,
	MaxText = 20,
	Parent = slotsHeader,
})
UIKit.button({
	Name = "Park",
	Text = "🅿️ Поставить угнанную",
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromScale(0.32, 0.72),
	Position = UDim2.fromScale(0.985, 0.5),
	Color = C.Cyan,
	MaxText = 18,
	Parent = slotsHeader,
	OnClick = function()
		if not ClientState.GetStolenCarId() then
			ClientState.Toast("Сначала угони машину и пригони её в зону парковки у гаража.", "Info")
			return
		end
		remoteGarage:FireServer("Park")
	end,
})

local slotsGrid = new("Frame", {
	Name = "Grid",
	Size = UDim2.fromScale(1, 0.85),
	Position = UDim2.fromScale(0, 0.15),
	BackgroundTransparency = 1,
	Parent = slotsPage,
})
local gridLayout = new("UIGridLayout", {
	CellSize = UDim2.fromScale(0.184, 0.3),
	CellPadding = UDim2.fromScale(0.02, 0.035),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Parent = slotsGrid,
})
UIKit.aspect(1.45).Parent = gridLayout

local slotCards = {}
for index = 1, MAX_PADS do
	local card = UIKit.card({ Name = "Slot" .. index, LayoutOrder = index, Parent = slotsGrid })
	local number = UIKit.label({ Text = "#" .. index, Size = UDim2.fromScale(0.3, 0.16), Position = UDim2.fromScale(0.06, 0.06), TextColor3 = C.Muted, Font = UIKit.Fonts.Black, MaxText = 16, Parent = card })
	local title = UIKit.label({ Text = "", Size = UDim2.fromScale(0.88, 0.18), Position = UDim2.fromScale(0.06, 0.24), Font = UIKit.Fonts.Black, MaxText = 18, Parent = card })
	local subtitle = UIKit.label({ Text = "", Size = UDim2.fromScale(0.88, 0.13), Position = UDim2.fromScale(0.06, 0.43), Font = UIKit.Fonts.Bold, MaxText = 15, Parent = card })
	local income = UIKit.label({ Text = "", Size = UDim2.fromScale(0.88, 0.13), Position = UDim2.fromScale(0.06, 0.57), TextColor3 = C.Success, Font = UIKit.Fonts.Bold, MaxText = 15, Parent = card })
	local sell = UIKit.button({
		Name = "Sell",
		Text = "",
		Size = UDim2.fromScale(0.88, 0.2),
		Position = UDim2.fromScale(0.06, 0.74),
		Color = C.Magenta,
		TextColor = C.Text,
		MaxText = 15,
		Parent = card,
		OnClick = function()
			local data = ClientState.Data
			if data and data.Parked[index] then
				remoteGarage:FireServer("SellSlot", index)
			end
		end,
	})
	slotCards[index] = { Card = card, Number = number, Title = title, Subtitle = subtitle, Income = income, Sell = sell }
end

local function renderSlots(data)
	local pads = data.PadCount
	local hasExtra = data.Passes and data.Passes.ExtraSlot == true
	local totalIncome = 0
	for index, entry in data.Parked do
		local rarity = RarityConfig.Get(entry.Rarity)
		if rarity and index <= pads then
			totalIncome += rarity.PassiveIncome
		end
	end
	local boost = data.BoostRemaining > 0
	if boost then
		totalIncome *= MonetizationConfig.BoostMultiplier
	end
	slotsInfo.Text = string.format(
		"Падов: %d/%d · Доход: %s / %d сек%s",
		#data.Parked,
		pads,
		Util.FormatCash(totalIncome),
		GameConfig.PassiveTick,
		if boost then "  ⚡x2" else ""
	)

	for index, slot in slotCards do
		local entry = data.Parked[index]
		local stroke = slot.Card:FindFirstChildOfClass("UIStroke")
		slot.Card.Visible = index <= pads or index <= UpgradeConfig.Branches.Garage.MaxLevel or hasExtra
		if entry then
			local def = CarConfig.Get(entry.ModelId)
			local rarity = RarityConfig.Get(entry.Rarity)
			local color = if rarity then rarity.Color else C.Muted
			slot.Title.Text = if def then def.DisplayName else entry.ModelId
			slot.Title.TextColor3 = C.Text
			slot.Subtitle.Text = if rarity then rarity.DisplayName else entry.Rarity
			slot.Subtitle.TextColor3 = color
			slot.Income.Text = if rarity then string.format("+%s / %d сек", Util.FormatCash(rarity.PassiveIncome), GameConfig.PassiveTick) else ""
			local payout = if def and rarity then math.floor(def.BasePrice * rarity.Multiplier * GameConfig.SlotSellRatio) else 0
			slot.Sell.Visible = true
			slot.Sell.Text = "Продать " .. Util.FormatCash(payout)
			slot.Card.BackgroundColor3 = C.PanelLight
			if stroke then
				stroke.Color = color
				stroke.Transparency = 0.3
			end
		elseif index <= pads then
			slot.Title.Text = "Свободно"
			slot.Title.TextColor3 = C.Muted
			slot.Subtitle.Text = "Пригони машину"
			slot.Subtitle.TextColor3 = C.Muted
			slot.Income.Text = "в зону 🅿️ у гаража"
			slot.Sell.Visible = false
			slot.Card.BackgroundColor3 = C.PanelLight
			if stroke then
				stroke.Color = C.Cyan
				stroke.Transparency = 0.7
			end
		else
			local needLevel = index - (if hasExtra then 1 else 0)
			slot.Title.Text = "🔒 Закрыто"
			slot.Title.TextColor3 = C.Muted
			slot.Subtitle.Text = if needLevel <= UpgradeConfig.Branches.Garage.MaxLevel then string.format("Гараж ур. %d", needLevel) else "Пасс «+1 слот»"
			slot.Subtitle.TextColor3 = C.Muted
			slot.Income.Text = ""
			slot.Sell.Visible = false
			slot.Card.BackgroundColor3 = C.PanelDark
			if stroke then
				stroke.Color = C.Muted
				stroke.Transparency = 0.85
			end
		end
	end
end

-- Статистика ------------------------------------------------------------------------------
local statsPage = page("Stats")
local statsLeft = UIKit.card({ Name = "Totals", Size = UDim2.fromScale(0.48, 1), Color = C.PanelDark, Parent = statsPage })
local statsRight = UIKit.card({ Name = "ByRarity", Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), Color = C.PanelDark, Accent = C.Magenta, Parent = statsPage })

local function statList(parent: Frame, titleText: string)
	UIKit.label({ Text = titleText, Size = UDim2.fromScale(0.9, 0.09), Position = UDim2.fromScale(0.05, 0.04), Font = UIKit.Fonts.Black, MaxText = 22, Parent = parent })
	local list = new("Frame", {
		Name = "List",
		Size = UDim2.fromScale(0.9, 0.82),
		Position = UDim2.fromScale(0.05, 0.15),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { new("UIListLayout", { Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }) })
	return list
end

local totalsList = statList(statsLeft, "📊 Карьера угонщика")
local rarityList = statList(statsRight, "🎯 Редкости")

local function statRow(list: Frame, order: number, rowHeight: number)
	local frame = new("Frame", { Size = UDim2.fromScale(1, rowHeight), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
	local left = UIKit.label({ Text = "", Size = UDim2.fromScale(0.62, 0.8), Position = UDim2.fromScale(0, 0.1), TextColor3 = C.Muted, Font = UIKit.Fonts.Medium, MaxText = 18, Parent = frame })
	local right = UIKit.label({ Text = "", Size = UDim2.fromScale(0.38, 0.8), Position = UDim2.fromScale(0.62, 0.1), TextXAlignment = Enum.TextXAlignment.Right, Font = UIKit.Fonts.Bold, MaxText = 18, Parent = frame })
	return left, right
end

local TOTAL_ROWS = {
	{ "Репутация", function(d) return string.format("ур. %d (%d XP)", d.RepLevel, d.XP) end },
	{ "Угнано машин", function(d) return tostring(d.Stats.Thefts) end },
	{ "Провалов взлома", function(d) return tostring(d.Stats.Fails) end },
	{ "Успешность", function(d)
		local tries = d.Stats.Thefts + d.Stats.Fails
		return if tries > 0 then string.format("%d%%", math.floor(d.Stats.Thefts / tries * 100 + 0.5)) else "—"
	end },
	{ "Продано", function(d) return tostring(d.Stats.Sold) end },
	{ "Заработано всего", function(d) return Util.FormatCash(d.Stats.Earned) end },
	{ "Лучшая сделка", function(d) return Util.FormatCash(d.Stats.BestSale) end },
	{ "Пассивный доход", function(d) return Util.FormatCash(d.Stats.Passive) end },
	{ "Вторых шансов", function(d) return tostring(d.SecondChances) end },
}
local totalLabels = {}
for order, info in TOTAL_ROWS do
	local left, right = statRow(totalsList, order, 0.098)
	left.Text = info[1]
	totalLabels[order] = right
end

UIKit.label({ Text = "Редкость · шанс · угнано", Size = UDim2.fromScale(1, 0.08), TextColor3 = C.Muted, Font = UIKit.Fonts.Medium, MaxText = 14, LayoutOrder = 0, Parent = rarityList })
local rarityLabels = {}
for order, rarity in RarityConfig.List do
	local left, right = statRow(rarityList, order, 0.13)
	left.Text = string.format("%s · %.1f%%", rarity.DisplayName, RarityConfig.GetChance(rarity.Name))
	left.TextColor3 = rarity.Color
	left.Font = UIKit.Fonts.Bold
	rarityLabels[rarity.Name] = right
end

local function renderStats(data)
	for order, info in TOTAL_ROWS do
		totalLabels[order].Text = info[2](data)
	end
	for name, label in rarityLabels do
		label.Text = tostring(data.Stats.ByRarity[name] or 0)
	end
end

-- Тюнинг (неоновая подсветка днища + рамка номера) -------------------------------------
local tuningPage = page("Tuning")
UIKit.label({
	Text = "Подсветка днища и рамка номера того же цвета. Все цвета — пасс «Кастомизация», «Маджента» и «Золото» — ежедневные награды.",
	Size = UDim2.fromScale(1, 0.12),
	TextWrapped = true,
	TextColor3 = C.Muted,
	Font = UIKit.Fonts.Medium,
	MaxText = 16,
	Parent = tuningPage,
})
local glowRow = new("Frame", {
	Name = "Glows",
	Size = UDim2.fromScale(1, 0.84),
	Position = UDim2.fromScale(0, 0.15),
	BackgroundTransparency = 1,
	Parent = tuningPage,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0.015, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local glowCards = {}
for order, glow in MonetizationConfig.Underglows do
	local card = UIKit.card({ Name = glow.Key, Size = UDim2.fromScale(0.185, 1), LayoutOrder = order, Aspect = 0.7, Accent = glow.Color, Parent = glowRow })
	local swatch = new("Frame", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.5, 0.08),
		BackgroundColor3 = glow.Color,
		Parent = card,
	}, { UIKit.corner(1), UIKit.aspect(1), UIKit.stroke(glow.Color, 3, 0.2) })
	if glow.Key == "None" then
		swatch.BackgroundTransparency = 0.7
	end
	UIKit.label({ Text = glow.Name, Size = UDim2.fromScale(0.9, 0.1), Position = UDim2.fromScale(0.05, 0.58), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Black, MaxText = 18, Parent = card })
	local state = { Owned = false }
	local button = UIKit.button({
		Name = "Select",
		Text = "",
		Size = UDim2.fromScale(0.84, 0.14),
		Position = UDim2.fromScale(0.08, 0.78),
		MaxText = 16,
		Parent = card,
		OnClick = function()
			if state.Owned then
				remoteGarage:FireServer("SetUnderglow", glow.Key)
			else
				ClientState.Toast("Закрыто: купи пасс «Кастомизация» в магазине или забирай ежедневные награды.", "Info")
			end
		end,
	})
	glowCards[glow.Key] = { Button = button, State = state, Card = card }
end

local function renderTuning(data)
	local all = data.Passes and data.Passes.Customization == true
	for key, info in glowCards do
		local owned = key == "None" or all or data.Cosmetics.Owned[key] == true
		local selected = data.Cosmetics.Underglow == key
		info.State.Owned = owned
		if selected then
			info.Button.Text = "✓ Выбрано"
			setButtonEnabled(info.Button, true, C.Success)
		elseif owned then
			info.Button.Text = "Выбрать"
			setButtonEnabled(info.Button, true, C.Cyan)
		else
			info.Button.Text = "🔒 Закрыто"
			setButtonEnabled(info.Button, false)
		end
		info.Card.BackgroundColor3 = if selected then C.Panel else C.PanelLight
	end
end

-- Общее -----------------------------------------------------------------------------------
local function render(data)
	modal.Subtitle.Text = string.format("Ур. %d · %s", data.Upgrades.Garage, Util.FormatCash(data.Cash))
	renderUpgrades(data)
	renderSlots(data)
	renderStats(data)
	renderTuning(data)
end

ClientState.OnData(render)

ClientState.RegisterMenu("GarageMenu", {
	Open = function(tab)
		if type(tab) == "string" and pages[tab] then
			currentTab = tab
		end
		tabs.Select(currentTab)
		if ClientState.Data then
			render(ClientState.Data)
		end
		modal.Show()
	end,
	Close = function()
		modal.Hide()
	end,
})

tabs.Select(currentTab)
