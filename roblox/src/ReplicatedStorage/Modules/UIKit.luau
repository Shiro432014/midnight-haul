-- UIKit: тема и конструкторы UI в неоновом тёмном стиле.
-- Всё позиционирование — через Scale. Текст — TextScaled + UITextSizeConstraint.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local RarityConfig = require(script.Parent.RarityConfig)
local GameConfig = require(script.Parent.GameConfig)

local UIKit = {}

UIKit.Colors = {
	Background = Color3.fromHex("#0D0D12"),
	Panel = Color3.fromHex("#1A1A24"),
	PanelLight = Color3.fromHex("#242433"),
	PanelDark = Color3.fromHex("#13131B"),
	Cyan = Color3.fromHex("#00E5FF"),
	Magenta = Color3.fromHex("#FF2E9A"),
	Text = Color3.fromRGB(240, 242, 255),
	Muted = Color3.fromRGB(140, 144, 170),
	Success = Color3.fromRGB(60, 235, 140),
	Danger = Color3.fromRGB(255, 70, 100),
	Gold = Color3.fromRGB(255, 200, 60),
	Black = Color3.new(0, 0, 0),
}

UIKit.Fonts = {
	Black = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Medium = Enum.Font.GothamMedium,
	Regular = Enum.Font.Gotham,
}

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = UIKit.new

function UIKit.corner(scale: number?): UICorner
	return new("UICorner", { CornerRadius = UDim.new(scale or 0.12, 0) })
end

function UIKit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color or UIKit.Colors.Cyan,
		Thickness = thickness or 1,
		Transparency = transparency or 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function UIKit.padding(scale: number): UIPadding
	local u = UDim.new(scale, 0)
	return new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UIKit.aspect(ratio: number): UIAspectRatioConstraint
	return new("UIAspectRatioConstraint", { AspectRatio = ratio })
end

function UIKit.textSize(maxSize: number, minSize: number?): UITextSizeConstraint
	return new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = minSize or 8 })
end

function UIKit.tween(inst: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(inst, TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function UIKit.rarityColor(name: string): Color3
	local rarity = RarityConfig.Get(name)
	return if rarity then rarity.Color else UIKit.Colors.Muted
end

function UIKit.rarityName(name: string): string
	local rarity = RarityConfig.Get(name)
	return if rarity then rarity.DisplayName else name
end

local soundCache: { [string]: Sound } = {}
function UIKit.playSound(kind: string, pitch: number?, volume: number?)
	local id = GameConfig.Sounds[kind]
	if not id or id == "" then
		return
	end
	local key = kind .. tostring(pitch)
	local sound = soundCache[key]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.PlaybackSpeed = pitch or 1
		sound.Volume = volume or 0.5
		sound.Parent = SoundService
		soundCache[key] = sound
	end
	SoundService:PlayLocalSound(sound)
end

-- Текст с автоподгоном размера
function UIKit.label(props: { [string]: any }): TextLabel
	local maxSize = props.MaxText or 28
	props.MaxText = nil
	local defaults = {
		BackgroundTransparency = 1,
		TextScaled = true,
		Font = UIKit.Fonts.Bold,
		TextColor3 = UIKit.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = new("TextLabel", defaults)
	UIKit.textSize(maxSize).Parent = label
	return label
end

-- Мягкая тень: ImageLabel с градиентом прозрачности под окном
function UIKit.shadow(target: GuiObject): ImageLabel
	local shadow = new("ImageLabel", {
		Name = target.Name .. "Shadow",
		BackgroundColor3 = UIKit.Colors.Black,
		BackgroundTransparency = 0.35,
		ImageTransparency = 1,
		AnchorPoint = target.AnchorPoint,
		Position = target.Position + UDim2.fromScale(0, 0.012),
		Size = target.Size + UDim2.fromScale(0.02, 0.03),
		ZIndex = target.ZIndex - 1,
		Parent = target.Parent,
	}, {
		UIKit.corner(0.06),
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.85, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	-- если окно отключено, тень тоже
	target:GetPropertyChangedSignal("Visible"):Connect(function()
		shadow.Visible = target.Visible
	end)
	return shadow
end

-- Кнопка с hover/press анимацией
function UIKit.button(props: { [string]: any }): TextButton
	local color = props.Color or UIKit.Colors.Cyan
	local textColor = props.TextColor or UIKit.Colors.Background
	local onClick = props.OnClick
	local maxText = props.MaxText or 24
	local button = new("TextButton", {
		Name = props.Name or "Button",
		Text = props.Text or "",
		Size = props.Size or UDim2.fromScale(0.3, 0.1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		TextColor3 = textColor,
		Font = props.Font or UIKit.Fonts.Black,
		TextScaled = true,
		AutoButtonColor = false,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, {
		UIKit.corner(props.Corner or 0.25),
		UIKit.textSize(maxText),
		new("UIPadding", { PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0), PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
		UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)),
	})
	local scale = new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.15, { Scale = 1.04 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.15, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.08, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1.04 })
	end)
	if onClick then
		button.Activated:Connect(function()
			UIKit.playSound("Click", 1.6, 0.25)
			onClick()
		end)
	end
	return button
end

-- Карточка-панель
function UIKit.card(props: { [string]: any }): Frame
	local accent = props.Accent or UIKit.Colors.Cyan
	local frame = new("Frame", {
		Name = props.Name or "Card",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Color or UIKit.Colors.PanelLight,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, {
		UIKit.corner(props.Corner or 0.08),
		UIKit.stroke(accent, 1.2, props.StrokeTransparency or 0.7),
		UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 190)),
	})
	if props.Aspect then
		UIKit.aspect(props.Aspect).Parent = frame
	end
	return frame
end

-- Модальное окно: затемнённый фон + окно с заголовком, кнопкой закрытия и телом.
-- Возвращает { Gui, Root, Window, Title, Body, Show, Hide }
function UIKit.modal(gui: ScreenGui, opts: { [string]: any })
	local colors = UIKit.Colors
	local root = new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Background,
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = gui,
	})
	local window = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = opts.Size or UDim2.fromScale(0.72, 0.78),
		BackgroundColor3 = colors.Panel,
		ZIndex = 2,
		Parent = root,
	}, {
		UIKit.corner(0.035),
		UIKit.stroke(opts.Accent or colors.Cyan, 1.5, 0.55),
		UIKit.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 220)),
		UIKit.aspect(opts.Aspect or 1.6),
		new("UISizeConstraint", { MaxSize = Vector2.new(1300, 900) }),
	})
	UIKit.shadow(window)

	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.fromScale(1, 0.12),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = window,
	})
	local title = UIKit.label({
		Name = "Title",
		Text = opts.Title or "",
		Size = UDim2.fromScale(0.6, 0.62),
		Position = UDim2.fromScale(0.035, 0.28),
		Font = UIKit.Fonts.Black,
		MaxText = 34,
		ZIndex = 3,
		Parent = header,
	})
	local subtitle = UIKit.label({
		Name = "Subtitle",
		Text = opts.Subtitle or "",
		Size = UDim2.fromScale(0.4, 0.4),
		Position = UDim2.fromScale(0.5, 0.38),
		TextColor3 = opts.Accent or colors.Cyan,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = UIKit.Fonts.Bold,
		MaxText = 20,
		ZIndex = 3,
		Parent = header,
	})
	-- неоновая линия под заголовком
	new("Frame", {
		Name = "Accent",
		Size = UDim2.new(0.93, 0, 0, 2),
		Position = UDim2.fromScale(0.035, 1),
		BackgroundColor3 = opts.Accent or colors.Cyan,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = header,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(0.93, 0.82),
		Position = UDim2.fromScale(0.035, 0.15),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = window,
	})

	local api = { Gui = gui, Root = root, Window = window, Title = title, Subtitle = subtitle, Body = body, Header = header }

	local scale = new("UIScale", { Parent = window })
	function api.Show()
		root.Visible = true
		scale.Scale = 0.92
		window.Position = UDim2.fromScale(0.5, 0.55)
		UIKit.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.tween(window, 0.25, { Position = UDim2.fromScale(0.5, 0.52) })
	end
	function api.Hide()
		root.Visible = false
	end

	local close = UIKit.button({
		Name = "Close",
		Text = "✕",
		Size = UDim2.fromScale(0.055, 0.55),
		Position = UDim2.fromScale(0.97, 0.3),
		AnchorPoint = Vector2.new(1, 0),
		Color = colors.PanelLight,
		TextColor = colors.Text,
		Corner = 0.3,
		ZIndex = 4,
		Parent = header,
		OnClick = function()
			if opts.OnClose then
				opts.OnClose()
			end
		end,
	})
	UIKit.aspect(1).Parent = close
	api.Close = close

	return api
end

-- Ряд вкладок. tabs = { {Key, Text} }, onSelect(key)
function UIKit.tabs(parent: GuiObject, tabs: { { Key: string, Text: string } }, onSelect: (string) -> ())
	local bar = new("Frame", {
		Name = "Tabs",
		Size = UDim2.fromScale(1, 0.1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local buttons = {}
	local function select(key: string)
		for tabKey, button in buttons do
			local active = tabKey == key
			button.BackgroundColor3 = if active then UIKit.Colors.Cyan else UIKit.Colors.PanelLight
			button.TextColor3 = if active then UIKit.Colors.Background else UIKit.Colors.Muted
		end
		onSelect(key)
	end
	for index, tab in tabs do
		buttons[tab.Key] = UIKit.button({
			Name = tab.Key,
			Text = tab.Text,
			Size = UDim2.fromScale(0.2, 1),
			LayoutOrder = index,
			Color = UIKit.Colors.PanelLight,
			TextColor = UIKit.Colors.Muted,
			MaxText = 20,
			ZIndex = 3,
			Parent = bar,
			OnClick = function()
				select(tab.Key)
			end,
		})
	end
	return { Bar = bar, Select = select }
end

function UIKit.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
end

return UIKit
