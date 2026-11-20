-- HUD: Cash, уровень гаража, репутация, буст, подсказка цели, спидометр
-- и кнопки «Гараж», «Сканер», «Магазин», «Награды».
-- Прячется во время мини-игры взлома.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIKit = require(Modules.UIKit)
local Util = require(Modules.Util)
local ClientState = require(Modules.ClientState)

local player = Players.LocalPlayer
local gui = script.Parent :: ScreenGui
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 5
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local C = UIKit.Colors
local new = UIKit.new

local root = new("Frame", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = gui,
})

-- Левый верхний блок: деньги и уровни ----------------------------------------------------
local statsPanel = new("Frame", {
	Name = "Stats",
	Size = UDim2.fromScale(0.22, 0.15),
	Position = UDim2.fromScale(0.012, 0.075),
	BackgroundColor3 = C.Panel,
	BackgroundTransparency = 0.08,
	Parent = root,
}, {
	UIKit.corner(0.16),
	UIKit.stroke(C.Cyan, 1.2, 0.55),
	UIKit.aspect(2.6),
	UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 200)),
})
UIKit.shadow(statsPanel)

local cashLabel = UIKit.label({
	Name = "Cash",
	Text = "$0",
	Size = UDim2.fromScale(0.86, 0.42),
	Position = UDim2.fromScale(0.07, 0.1),
	Font = UIKit.Fonts.Black,
	TextColor3 = C.Success,
	MaxText = 40,
	Parent = statsPanel,
})
local levelLabel = UIKit.label({
	Name = "Levels",
	Text = "Гараж ур. 1 · Реп. 1",
	Size = UDim2.fromScale(0.86, 0.2),
	Position = UDim2.fromScale(0.07, 0.55),
	Font = UIKit.Fonts.Bold,
	TextColor3 = C.Muted,
	MaxText = 18,
	Parent = statsPanel,
})
local repTrack = new("Frame", {
	Name = "RepTrack",
	Size = UDim2.fromScale(0.86, 0.06),
	Position = UDim2.fromScale(0.07, 0.82),
	BackgroundColor3 = C.PanelDark,
	Parent = statsPanel,
}, { UIKit.corner(1) })
local repFill = new("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = C.Magenta,
	Parent = repTrack,
}, { UIKit.corner(1), UIKit.gradient(C.Magenta, C.Cyan, 0) })

local boostLabel = UIKit.label({
	Name = "Boost",
	Text = "",
	Size = UDim2.fromScale(0.22, 0.035),
	Position = UDim2.fromScale(0.014, 0.235),
	TextColor3 = C.Gold,
	Font = UIKit.Fonts.Bold,
	MaxText = 18,
	Visible = false,
	Parent = root,
})

local popup = UIKit.label({
	Name = "IncomePopup",
	Text = "",
	Size = UDim2.fromScale(0.12, 0.035),
	Position = UDim2.fromScale(0.235, 0.09),
	TextColor3 = C.Success,
	Font = UIKit.Fonts.Black,
	MaxText = 22,
	TextTransparency = 1,
	Parent = root,
})

-- Подсказка цели сверху по центру ----------------------------------------------------------
local objective = new("Frame", {
	Name = "Objective",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromScale(0.36, 0.055),
	Position = UDim2.fromScale(0.5, 0.02),
	BackgroundColor3 = C.Panel,
	BackgroundTransparency = 0.15,
	Parent = root,
}, {
	UIKit.corner(0.5),
	UIKit.stroke(C.Magenta, 1.2, 0.5),
	UIKit.aspect(9),
})
local objectiveText = UIKit.label({
	Text = "",
	Size = UDim2.fromScale(0.92, 0.6),
	Position = UDim2.fromScale(0.04, 0.2),
	TextXAlignment = Enum.TextXAlignment.Center,
	Font = UIKit.Fonts.Bold,
	MaxText = 20,
	Parent = objective,
})

-- Спидометр --------------------------------------------------------------------------------
local speedo = UIKit.label({
	Name = "Speed",
	Text = "",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromScale(0.16, 0.07),
	Position = UDim2.fromScale(0.5, 0.97),
	TextXAlignment = Enum.TextXAlignment.Center,
	Font = UIKit.Fonts.Black,
	TextColor3 = C.Cyan,
	MaxText = 40,
	Visible = false,
	Parent = root,
})

-- Кнопки справа снизу -----------------------------------------------------------------------
local buttonBar = new("Frame", {
	Name = "Buttons",
	AnchorPoint = Vector2.new(1, 1),
	Size = UDim2.fromScale(0.36, 0.13),
	Position = UDim2.fromScale(0.985, 0.97),
	BackgroundTransparency = 1,
	Parent = root,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0.025, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	UIKit.aspect(4.4),
})

local function hudButton(order: number, icon: string, text: string, accent: Color3, onClick: () -> ())
	local button = new("TextButton", {
		Name = text,
		Text = "",
		Size = UDim2.fromScale(0.23, 1),
		BackgroundColor3 = C.Panel,
		AutoButtonColor = false,
		LayoutOrder = order,
		Parent = buttonBar,
	}, {
		UIKit.corner(0.22),
		UIKit.aspect(1),
		UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 195)),
	})
	local stroke = UIKit.stroke(accent, 1.5, 0.45)
	stroke.Parent = button
	UIKit.label({ Text = icon, Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.1), TextXAlignment = Enum.TextXAlignment.Center, MaxText = 40, Parent = button })
	UIKit.label({ Text = text, Size = UDim2.fromScale(0.9, 0.22), Position = UDim2.fromScale(0.05, 0.66), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = accent, Font = UIKit.Fonts.Bold, MaxText = 16, Parent = button })
	local dot = new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.18, 0.18),
		Position = UDim2.fromScale(0.88, 0.12),
		BackgroundColor3 = C.Magenta,
		Visible = false,
		Parent = button,
	}, { UIKit.corner(1), UIKit.aspect(1) })
	local scale = new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.15, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.15, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		UIKit.playSound("Click", 1.6, 0.25)
		scale.Scale = 0.92
		UIKit.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		onClick()
	end)
	return button, stroke, dot
end

hudButton(1, "🏠", "Гараж", C.Cyan, function()
	ClientState.ToggleMenu("GarageMenu", "Upgrades")
end)
local scannerButton, scannerStroke = hudButton(2, "📡", "Сканер", C.Cyan, function()
	ClientState.SetScanner(not ClientState.ScannerOn)
end)
hudButton(3, "🛒", "Магазин", C.Magenta, function()
	ClientState.ToggleMenu("ShopGui")
end)
local _, _, dailyDot = hudButton(4, "🎁", "Награды", C.Gold, function()
	ClientState.ToggleMenu("DailyGui")
end)

ClientState.ScannerChanged.Event:Connect(function(on)
	scannerButton.BackgroundColor3 = if on then Color3.fromRGB(0, 70, 90) else C.Panel
	scannerStroke.Transparency = if on then 0 else 0.45
end)

-- Обновление --------------------------------------------------------------------------------
local shownCash = 0
local targetCash = 0
local boostEndsAt = 0

ClientState.OnData(function(data)
	targetCash = data.Cash
	levelLabel.Text = string.format("Гараж ур. %d · Реп. %d", data.Upgrades.Garage, data.RepLevel)
	UIKit.tween(repFill, 0.4, { Size = UDim2.fromScale(math.clamp(data.RepProgress, 0, 1), 1) })
	boostEndsAt = os.clock() + data.BoostRemaining
	dailyDot.Visible = data.Daily.CanClaim
end)

local function updateObjective()
	local text
	if ClientState.GetStolenCarId() then
		text = "🚗 Вези машину к СКУПЩИКУ (восток) или в ГАРАЖ (запад)"
	elseif ClientState.ScannerOn then
		text = "📡 Найди машину по маркеру и взломай её [E]"
	else
		text = "🌃 Включи СКАНЕР, найди машину и взломай её"
	end
	objectiveText.Text = text
end
player:GetAttributeChangedSignal("StolenCarId"):Connect(updateObjective)
ClientState.ScannerChanged.Event:Connect(updateObjective)
updateObjective()

Util.Remote("Effect").OnClientEvent:Connect(function(kind, _position, value)
	if kind == "Passive" or kind == "Cash" then
		popup.Text = "+" .. Util.FormatCash(value)
		popup.TextTransparency = 0
		popup.Position = UDim2.fromScale(0.235, 0.1)
		UIKit.tween(popup, 1.2, { TextTransparency = 1, Position = UDim2.fromScale(0.235, 0.075) }, Enum.EasingStyle.Quad)
		UIKit.playSound("Cash", 1.8, 0.2)
	end
end)

ClientState.LockpickChanged.Event:Connect(function(active)
	root.Visible = not active
end)

RunService.RenderStepped:Connect(function(dt)
	if shownCash ~= targetCash then
		local diff = targetCash - shownCash
		local step = math.max(1, math.abs(diff) * math.min(1, dt * 8))
		if math.abs(diff) <= step then
			shownCash = targetCash
		else
			shownCash += math.sign(diff) * step
		end
		cashLabel.Text = Util.FormatCash(shownCash)
	end
	local boostLeft = boostEndsAt - os.clock()
	boostLabel.Visible = boostLeft > 0
	if boostLeft > 0 then
		boostLabel.Text = "⚡ Буст x2 · " .. Util.FormatTime(boostLeft)
	end
	local speed = ClientState.Speed
	speedo.Visible = speed > 0.5
	if speedo.Visible then
		speedo.Text = string.format("%d км/ч", math.floor(speed * 1.3))
	end
end)
