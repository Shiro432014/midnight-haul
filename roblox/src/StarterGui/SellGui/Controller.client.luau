-- SellGui: меню сдачи машины скупщику.
-- Сервер присылает расчёт (OpenScrapyard), клиент показывает его и шлёт SellCar(carId).
-- Цену и право на сдачу сервер проверяет заново при получении SellCar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIKit = require(Modules.UIKit)
local Util = require(Modules.Util)
local ClientState = require(Modules.ClientState)
local RarityConfig = require(Modules.RarityConfig)

local player = Players.LocalPlayer
local gui = script.Parent :: ScreenGui
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local C = UIKit.Colors
local new = UIKit.new

local remoteOpen = Util.Remote("OpenScrapyard")
local remoteSell = Util.Remote("SellCar")

local currentQuote = nil

local modal = UIKit.modal(gui, {
	Title = "СКУПЩИК",
	Subtitle = "Наличными, без вопросов",
	Accent = C.Magenta,
	Size = UDim2.fromScale(0.46, 0.62),
	Aspect = 1.25,
	OnClose = function()
		ClientState.CloseMenu("SellGui")
	end,
})
local body = modal.Body

-- Шапка машины ---------------------------------------------------------------------------
local carCard = UIKit.card({
	Name = "Car",
	Size = UDim2.fromScale(1, 0.24),
	Accent = C.Magenta,
	Parent = body,
})
local carIcon = UIKit.label({
	Text = "🚗",
	Size = UDim2.fromScale(0.16, 0.7),
	Position = UDim2.fromScale(0.03, 0.15),
	TextXAlignment = Enum.TextXAlignment.Center,
	MaxText = 48,
	Parent = carCard,
})
local carName = UIKit.label({
	Name = "CarName",
	Text = "",
	Size = UDim2.fromScale(0.5, 0.42),
	Position = UDim2.fromScale(0.21, 0.14),
	Font = UIKit.Fonts.Black,
	MaxText = 30,
	Parent = carCard,
})
local rarityLabel = UIKit.label({
	Name = "Rarity",
	Text = "",
	Size = UDim2.fromScale(0.5, 0.28),
	Position = UDim2.fromScale(0.21, 0.58),
	Font = UIKit.Fonts.Bold,
	MaxText = 20,
	Parent = carCard,
})
local chanceLabel = UIKit.label({
	Name = "Chance",
	Text = "",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromScale(0.26, 0.28),
	Position = UDim2.fromScale(0.96, 0.36),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = C.Muted,
	Font = UIKit.Fonts.Medium,
	MaxText = 16,
	Parent = carCard,
})

-- Расчёт цены --------------------------------------------------------------------------------
local rows = new("Frame", {
	Name = "Rows",
	Size = UDim2.fromScale(1, 0.4),
	Position = UDim2.fromScale(0, 0.28),
	BackgroundTransparency = 1,
	Parent = body,
}, {
	new("UIListLayout", { Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function row(order: number, labelText: string, color: Color3?)
	local frame = new("Frame", {
		Name = "Row" .. order,
		Size = UDim2.fromScale(1, 0.22),
		BackgroundColor3 = C.PanelDark,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = rows,
	}, { UIKit.corner(0.3) })
	UIKit.label({
		Text = labelText,
		Size = UDim2.fromScale(0.6, 0.6),
		Position = UDim2.fromScale(0.04, 0.2),
		TextColor3 = C.Muted,
		Font = UIKit.Fonts.Medium,
		MaxText = 20,
		Parent = frame,
	})
	local value = UIKit.label({
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromScale(0.4, 0.6),
		Position = UDim2.fromScale(0.96, 0.2),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = color or C.Text,
		Font = UIKit.Fonts.Bold,
		MaxText = 20,
		Parent = frame,
	})
	return frame, value
end

local _, baseValue = row(1, "Базовая цена модели")
local _, multValue = row(2, "Множитель редкости")
local vipRow, vipValue = row(3, "👑 VIP-бонус +25%", C.Gold)

local totalCard = UIKit.card({
	Name = "Total",
	Size = UDim2.fromScale(1, 0.14),
	Position = UDim2.fromScale(0, 0.68),
	Color = C.PanelDark,
	Accent = C.Success,
	StrokeTransparency = 0.4,
	Parent = body,
})
UIKit.label({
	Text = "ИТОГО",
	Size = UDim2.fromScale(0.4, 0.5),
	Position = UDim2.fromScale(0.04, 0.25),
	Font = UIKit.Fonts.Black,
	TextColor3 = C.Muted,
	MaxText = 22,
	Parent = totalCard,
})
local totalValue = UIKit.label({
	Text = "",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromScale(0.55, 0.7),
	Position = UDim2.fromScale(0.96, 0.15),
	TextXAlignment = Enum.TextXAlignment.Right,
	Font = UIKit.Fonts.Black,
	TextColor3 = C.Success,
	MaxText = 36,
	Parent = totalCard,
})

-- Кнопки --------------------------------------------------------------------------------------
local sellButton
sellButton = UIKit.button({
	Name = "Sell",
	Text = "СДАТЬ",
	Size = UDim2.fromScale(0.62, 0.12),
	Position = UDim2.fromScale(0, 0.87),
	Color = C.Magenta,
	TextColor = C.Text,
	MaxText = 24,
	Parent = body,
	OnClick = function()
		if not currentQuote then
			return
		end
		remoteSell:FireServer(currentQuote.CarId)
		currentQuote = nil
		ClientState.CloseMenu("SellGui")
	end,
})
UIKit.button({
	Name = "Later",
	Text = "Позже",
	Size = UDim2.fromScale(0.34, 0.12),
	Position = UDim2.fromScale(0.66, 0.87),
	Color = C.PanelLight,
	TextColor = C.Muted,
	MaxText = 20,
	Parent = body,
	OnClick = function()
		ClientState.CloseMenu("SellGui")
	end,
})

local function render(quote)
	local color = UIKit.rarityColor(quote.Rarity)
	carName.Text = quote.CarName
	rarityLabel.Text = UIKit.rarityName(quote.Rarity)
	rarityLabel.TextColor3 = color
	carIcon.TextColor3 = color
	chanceLabel.Text = string.format("шанс %.1f%%", RarityConfig.GetChance(quote.Rarity))
	local stroke = carCard:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	baseValue.Text = Util.FormatCash(quote.BasePrice)
	multValue.Text = string.format("× %.1f", quote.Multiplier)
	multValue.TextColor3 = color
	vipRow.Visible = quote.VipBonus > 0
	vipValue.Text = "+" .. Util.FormatCash(quote.VipBonus)
	totalValue.Text = Util.FormatCash(quote.Total)
	sellButton.Text = "СДАТЬ ЗА " .. Util.FormatCash(quote.Total)
end

ClientState.RegisterMenu("SellGui", {
	Open = function(quote)
		if quote then
			currentQuote = quote
			render(quote)
		end
		modal.Show()
	end,
	Close = function()
		modal.Hide()
	end,
})

remoteOpen.OnClientEvent:Connect(function(quote)
	if type(quote) ~= "table" or type(quote.CarId) ~= "string" then
		return
	end
	ClientState.OpenMenu("SellGui", quote)
end)

-- машина пропала (сдана, эвакуирована) — меню больше не актуально
player:GetAttributeChangedSignal("StolenCarId"):Connect(function()
	if currentQuote and ClientState.GetStolenCarId() ~= currentQuote.CarId then
		currentQuote = nil
		ClientState.CloseMenu("SellGui")
	end
end)
