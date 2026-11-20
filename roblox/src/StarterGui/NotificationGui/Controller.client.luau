-- NotificationGui: тосты справа сверху («Угон успешен! +$2 400»).
-- Источники: remote Notify (сервер) и ClientState.Toast (клиентские подсказки).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIKit = require(Modules.UIKit)
local Util = require(Modules.Util)
local ClientState = require(Modules.ClientState)

local gui = script.Parent :: ScreenGui
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 40 -- поверх меню и мини-игры, но тосты узкие и не перекрывают полосу взлома
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local C = UIKit.Colors
local new = UIKit.new

local MAX_TOASTS = 4
local LIFETIME = 3.6

local KINDS = {
	Info = { Color = C.Cyan, Icon = "ℹ️" },
	Success = { Color = C.Success, Icon = "✅" },
	Error = { Color = C.Danger, Icon = "⚠️" },
	Cash = { Color = C.Gold, Icon = "💵" },
}

local stack = new("Frame", {
	Name = "Stack",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromScale(0.3, 0.5),
	Position = UDim2.fromScale(0.99, 0.09),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0.02, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	new("UISizeConstraint", { MaxSize = Vector2.new(460, 600) }),
})

local counter = 0
local active: { Frame } = {}

local function removeToast(toast: Frame)
	local index = table.find(active, toast)
	if not index then
		return
	end
	table.remove(active, index)
	local scale = toast:FindFirstChildOfClass("UIScale")
	if scale then
		UIKit.tween(scale, 0.2, { Scale = 0.8 })
	end
	UIKit.tween(toast, 0.2, { BackgroundTransparency = 1 })
	for _, child in toast:GetDescendants() do
		if child:IsA("TextLabel") then
			UIKit.tween(child, 0.2, { TextTransparency = 1 })
		elseif child:IsA("UIStroke") then
			UIKit.tween(child, 0.2, { Transparency = 1 })
		end
	end
	task.delay(0.22, function()
		toast:Destroy()
	end)
end

local function showToast(text: any, kind: any)
	if type(text) ~= "string" or text == "" then
		return
	end
	local style = KINDS[kind] or KINDS.Info
	counter += 1

	local toast = new("Frame", {
		Name = "Toast" .. counter,
		Size = UDim2.fromScale(1, 0.15),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		LayoutOrder = counter,
		Parent = stack,
	}, {
		UIKit.corner(0.25),
		UIKit.stroke(style.Color, 1.5, 0.3),
		UIKit.aspect(5.2),
		UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 205)),
	})
	-- цветная полоска слева
	new("Frame", {
		Name = "Accent",
		Size = UDim2.fromScale(0.018, 0.64),
		Position = UDim2.fromScale(0.03, 0.18),
		BackgroundColor3 = style.Color,
		BorderSizePixel = 0,
		Parent = toast,
	}, { UIKit.corner(1) })
	UIKit.label({
		Name = "Icon",
		Text = style.Icon,
		Size = UDim2.fromScale(0.12, 0.6),
		Position = UDim2.fromScale(0.065, 0.2),
		TextXAlignment = Enum.TextXAlignment.Center,
		MaxText = 26,
		Parent = toast,
	})
	UIKit.label({
		Name = "Text",
		Text = text,
		Size = UDim2.fromScale(0.78, 0.7),
		Position = UDim2.fromScale(0.2, 0.15),
		TextWrapped = true,
		Font = UIKit.Fonts.Bold,
		TextColor3 = C.Text,
		MaxText = 18,
		Parent = toast,
	})

	local scale = new("UIScale", { Scale = 0.6, Parent = toast })
	UIKit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

	table.insert(active, toast)
	while #active > MAX_TOASTS do
		removeToast(active[1])
	end
	if kind == "Error" then
		UIKit.playSound("Fail", 0.8, 0.25)
	elseif kind == "Success" then
		UIKit.playSound("Success", 1.4, 0.3)
	end
	task.delay(LIFETIME, function()
		removeToast(toast)
	end)
end

Util.Remote("Notify").OnClientEvent:Connect(showToast)
ClientState.ToastRequested.Event:Connect(showToast)
