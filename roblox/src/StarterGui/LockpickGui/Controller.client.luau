-- LockpickGui: мини-игра «останови бегунок в зелёной зоне».
-- Клиент только рисует и отправляет время нажатия. Успех решает сервер (TheftHandler).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIKit = require(Modules.UIKit)
local Util = require(Modules.Util)
local ClientState = require(Modules.ClientState)

local player = Players.LocalPlayer
local gui = script.Parent :: ScreenGui
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local C = UIKit.Colors
local new = UIKit.new

local remoteStart = Util.Remote("StartLockpick")
local remoteSubmit = Util.Remote("SubmitLockpickResult")

-- Вёрстка -------------------------------------------------------------------------------
local overlay = new("Frame", {
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.25,
	Visible = false,
	Parent = gui,
})

local card = new("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.66, 0.5),
	BackgroundColor3 = C.Panel,
	ZIndex = 2,
	Parent = overlay,
}, {
	UIKit.corner(0.06),
	UIKit.aspect(2.3),
	UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 215)),
	new("UISizeConstraint", { MaxSize = Vector2.new(980, 430) }),
})
local cardStroke = UIKit.stroke(C.Cyan, 2, 0.3)
cardStroke.Parent = card
UIKit.shadow(card)
local cardScale = new("UIScale", { Parent = card })

-- таймер сверху карточки
local timerTrack = new("Frame", {
	Name = "TimerTrack",
	Size = UDim2.new(0.92, 0, 0.025, 0),
	Position = UDim2.fromScale(0.04, 0.06),
	BackgroundColor3 = C.PanelDark,
	Parent = card,
}, { UIKit.corner(1) })
local timerFill = new("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Cyan,
	Parent = timerTrack,
}, { UIKit.corner(1), UIKit.gradient(C.Cyan, C.Magenta, 0) })

local title = UIKit.label({
	Name = "CarName",
	Text = "",
	Size = UDim2.fromScale(0.55, 0.13),
	Position = UDim2.fromScale(0.04, 0.12),
	Font = UIKit.Fonts.Black,
	MaxText = 36,
	Parent = card,
})
local rarityBadge = new("Frame", {
	Name = "RarityBadge",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromScale(0.22, 0.11),
	Position = UDim2.fromScale(0.96, 0.13),
	BackgroundColor3 = C.Cyan,
	Parent = card,
}, { UIKit.corner(0.5) })
local rarityText = UIKit.label({
	Text = "",
	Size = UDim2.fromScale(1, 0.7),
	Position = UDim2.fromScale(0, 0.15),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = C.Background,
	Font = UIKit.Fonts.Black,
	MaxText = 22,
	Parent = rarityBadge,
})

local attemptsRow = new("Frame", {
	Name = "Attempts",
	Size = UDim2.fromScale(0.4, 0.07),
	Position = UDim2.fromScale(0.04, 0.29),
	BackgroundTransparency = 1,
	Parent = card,
}, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), VerticalAlignment = Enum.VerticalAlignment.Center }),
})
local chancesLabel = UIKit.label({
	Name = "SecondChances",
	Text = "",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromScale(0.3, 0.07),
	Position = UDim2.fromScale(0.96, 0.29),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = C.Gold,
	Font = UIKit.Fonts.Bold,
	MaxText = 18,
	Parent = card,
})

-- полоса
local track = new("Frame", {
	Name = "Track",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.2),
	Position = UDim2.fromScale(0.5, 0.55),
	BackgroundColor3 = C.PanelDark,
	ClipsDescendants = false,
	Parent = card,
}, { UIKit.corner(0.25), UIKit.stroke(C.Cyan, 1, 0.7) })

local zone = new("Frame", {
	Name = "GreenZone",
	Size = UDim2.fromScale(0.2, 1),
	Position = UDim2.fromScale(0.4, 0),
	BackgroundColor3 = C.Success,
	Parent = track,
}, {
	UIKit.corner(0.2),
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(120, 255, 180), Color3.fromRGB(30, 200, 110)),
		Rotation = 90,
	}),
	UIKit.stroke(C.Success, 2, 0.2),
})

local ghost = new("Frame", {
	Name = "Ghost",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(0.006, 1.3),
	Position = UDim2.fromScale(0, 0.5),
	BackgroundColor3 = C.Danger,
	BackgroundTransparency = 0.3,
	Visible = false,
	Parent = track,
}, { UIKit.corner(1) })

local runner = new("Frame", {
	Name = "Runner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(0.014, 1.55),
	Position = UDim2.fromScale(0, 0.5),
	BackgroundColor3 = C.Text,
	ZIndex = 3,
	Parent = track,
}, { UIKit.corner(1), UIKit.stroke(C.Cyan, 2, 0) })

local status = UIKit.label({
	Name = "Status",
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromScale(0.8, 0.14),
	Position = UDim2.fromScale(0.5, 0.7),
	TextXAlignment = Enum.TextXAlignment.Center,
	Font = UIKit.Fonts.Black,
	MaxText = 40,
	Parent = card,
})
local hint = UIKit.label({
	Name = "Hint",
	Text = "SPACE · КЛИК · ТАП — остановить бегунок",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromScale(0.7, 0.07),
	Position = UDim2.fromScale(0.5, 0.86),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = C.Muted,
	Font = UIKit.Fonts.Medium,
	MaxText = 18,
	Parent = card,
})

local cancelButton = UIKit.button({
	Name = "Cancel",
	Text = "Отмена",
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromScale(0.14, 0.1),
	Position = UDim2.fromScale(0.96, 0.85),
	Color = C.PanelLight,
	TextColor = C.Muted,
	MaxText = 16,
	Parent = card,
})

-- Состояние -----------------------------------------------------------------------------
local session = nil
local phase = "Idle" -- Running | Waiting | Done | Idle
local attemptStart = 0
local deadline = 0
local timeLimit = 10
local renderConn: RBXScriptConnection? = nil
local savedWalkSpeed: number? = nil
local stop: () -> () -- объявлена ниже

local function setAttempts(count: number)
	UIKit.clear(attemptsRow)
	for i = 1, count do
		new("Frame", {
			Name = "Dot" .. i,
			Size = UDim2.fromScale(0.09, 0.9),
			BackgroundColor3 = C.Cyan,
			Parent = attemptsRow,
		}, { UIKit.corner(1), UIKit.aspect(1), UIKit.stroke(C.Cyan, 1, 0.3) })
	end
end

local function setZone(start: number, width: number, animate: boolean)
	local target = UDim2.fromScale(start, 0)
	zone.Size = UDim2.fromScale(width, 1)
	if animate then
		UIKit.tween(zone, 0.35, { Position = target }, Enum.EasingStyle.Back)
	else
		zone.Position = target
	end
end

local function setStatus(text: string, color: Color3)
	status.Text = text
	status.TextColor3 = color
	status.TextTransparency = 0
	local s = status:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = status })
	s.Scale = 1.25
	UIKit.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function shake()
	task.spawn(function()
		for i = 1, 6 do
			card.Position = UDim2.fromScale(0.5 + (if i % 2 == 0 then 0.006 else -0.006), 0.5)
			task.wait(0.03)
		end
		card.Position = UDim2.fromScale(0.5, 0.5)
	end)
end

local function burst(color: Color3)
	-- «партиклы» в UI: разлетающиеся точки от бегунка
	for _ = 1, 18 do
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.012, 0.012),
			Position = UDim2.fromScale(runner.Position.X.Scale * 0.92 + 0.04, 0.55),
			BackgroundColor3 = color,
			ZIndex = 5,
			Parent = card,
		}, { UIKit.corner(1), UIKit.aspect(1) })
		local angle = math.random() * math.pi * 2
		local dist = 0.08 + math.random() * 0.15
		UIKit.tween(dot, 0.6, {
			Position = dot.Position + UDim2.fromScale(math.cos(angle) * dist, math.sin(angle) * dist * 2.3),
			BackgroundTransparency = 1,
		})
		task.delay(0.65, function()
			dot:Destroy()
		end)
	end
end

local function bindInput(active: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if active then
		ContextActionService:BindActionAtPriority("LockpickStop", function(_, state)
			if state == Enum.UserInputState.Begin then
				stop()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		if humanoid then
			savedWalkSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = 0
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
	else
		ContextActionService:UnbindAction("LockpickStop")
		if humanoid then
			if savedWalkSpeed then
				humanoid.WalkSpeed = savedWalkSpeed
			end
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		savedWalkSpeed = nil
	end
end

local function close(delaySeconds: number)
	local closingSession = session
	task.delay(delaySeconds, function()
		if session ~= closingSession then
			return
		end
		session = nil
		phase = "Idle"
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
		bindInput(false)
		UIKit.tween(cardScale, 0.15, { Scale = 0.9 })
		task.wait(0.15)
		if session == nil then
			overlay.Visible = false
			ClientState.SetLockpick(false)
		end
	end)
end

stop = function()
	if not session or phase ~= "Running" then
		return
	end
	local elapsed = os.clock() - attemptStart
	if elapsed < 0 then
		return
	end
	phase = "Waiting"
	runner.Position = UDim2.fromScale(Util.RunnerPosition(elapsed, session.Speed), 0.5)
	remoteSubmit:FireServer(session.SessionId, elapsed)
end

local function onRender()
	if not session then
		return
	end
	local now = os.clock()
	local remaining = math.max(0, deadline - now)
	timerFill.Size = UDim2.fromScale(remaining / timeLimit, 1)
	timerFill.BackgroundColor3 = if remaining < 3 then C.Danger else C.Cyan
	if phase == "Running" then
		local elapsed = now - attemptStart
		if elapsed < 0 then
			runner.Position = UDim2.fromScale(0, 0.5)
		else
			runner.Position = UDim2.fromScale(Util.RunnerPosition(elapsed, session.Speed), 0.5)
		end
	end
	-- страховка: если сервер так и не ответил после дедлайна
	if now > deadline + 3 and phase ~= "Done" then
		phase = "Done"
		close(0)
	end
end

remoteStart.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	session = info
	phase = "Running"
	local now = os.clock()
	attemptStart = now + info.ResumeDelay
	timeLimit = info.TimeLimit
	deadline = now + info.ResumeDelay + info.TimeLimit

	local color = UIKit.rarityColor(info.Rarity)
	title.Text = info.CarName
	rarityBadge.BackgroundColor3 = color
	rarityText.Text = string.upper(UIKit.rarityName(info.Rarity))
	cardStroke.Color = color
	setAttempts(info.Attempts)
	setZone(info.ZoneStart, info.ZoneWidth, false)
	chancesLabel.Text = if info.SecondChances > 0 then "🎲 Вторых шансов: " .. info.SecondChances else ""
	ghost.Visible = false
	status.Text = "ГОТОВЬСЯ..."
	status.TextColor3 = C.Muted
	hint.Visible = true

	ClientState.SetLockpick(true)
	overlay.Visible = true
	cardScale.Scale = 0.85
	UIKit.tween(cardScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	bindInput(true)
	if renderConn then
		renderConn:Disconnect()
	end
	renderConn = RunService.RenderStepped:Connect(onRender)
	task.delay(info.ResumeDelay, function()
		if session == info and phase == "Running" then
			status.Text = ""
		end
	end)
end)

remoteSubmit.OnClientEvent:Connect(function(result)
	if not session or type(result) ~= "table" or result.SessionId ~= session.SessionId then
		return
	end
	if result.Position then
		runner.Position = UDim2.fromScale(result.Position, 0.5)
	end

	if result.Result == "Success" then
		phase = "Done"
		setStatus("ВЗЛОМАНО!", C.Success)
		UIKit.playSound("Success", 1.2, 0.6)
		burst(C.Success)
		zone.BackgroundColor3 = Color3.fromRGB(180, 255, 210)
		task.delay(0.3, function()
			zone.BackgroundColor3 = C.Success
		end)
		close(0.9)
	elseif result.Result == "Miss" then
		ghost.Position = UDim2.fromScale(result.Position or 0, 0.5)
		ghost.Visible = true
		setAttempts(result.AttemptsLeft)
		if result.SecondChanceUsed then
			setStatus("ВТОРОЙ ШАНС!", C.Gold)
			deadline += result.ExtraTime or 0
			chancesLabel.Text = if result.SecondChances > 0 then "🎲 Вторых шансов: " .. result.SecondChances else ""
		else
			setStatus("МИМО!", C.Danger)
		end
		UIKit.playSound("Fail", 0.6, 0.5)
		shake()
		local resumeDelay = session.ResumeDelay
		attemptStart = os.clock() + resumeDelay
		setZone(result.ZoneStart, session.ZoneWidth, true)
		phase = "Running"
	else
		phase = "Done"
		local text = "СИГНАЛИЗАЦИЯ!"
		if result.Reason == "Timeout" then
			text = "ВРЕМЯ ВЫШЛО!"
		elseif result.Reason == "Gone" then
			text = "МАШИНА УЕХАЛА"
		end
		if result.Position then
			ghost.Position = UDim2.fromScale(result.Position, 0.5)
			ghost.Visible = true
		end
		setStatus(text, C.Danger)
		UIKit.playSound("Fail", 0.45, 0.6)
		shake()
		close(1.3)
	end
end)

-- клик/тап в любом месте экрана (кроме кнопок) тоже останавливает бегунок
UserInputService.InputBegan:Connect(function(input, processed)
	if not session or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		stop()
	end
end)

cancelButton.Activated:Connect(function()
	if session and phase ~= "Done" then
		phase = "Done"
		remoteSubmit:FireServer(session.SessionId, "cancel")
	end
end)
