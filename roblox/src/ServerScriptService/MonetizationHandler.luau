-- VIP-ник. Клиент только открывает окно покупки — выдача идёт строго здесь.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MonetizationConfig = require(Modules.MonetizationConfig)
local Util = require(Modules.Util)

local DataManager = require(script.Parent.DataManager)

local MonetizationHandler = {}

local remotes = {
	ClaimDaily = Util.Remote("ClaimDaily"),
	Notify = Util.Remote("Notify"),
	Effect = Util.Remote("Effect"),
}

local dailyCooldown = Util.Cooldown(1)

-- Выдать набор наград: { Cash, SecondChances, BoostMinutes, Cosmetic }
function MonetizationHandler.Grant(player: Player, grant): boolean
	local data = DataManager.Get(player)
	if not data then
		return false
	end
	if grant.Cash then
		data.Cash += grant.Cash
	end
	if grant.SecondChances then
		data.SecondChances += grant.SecondChances
	end
	if grant.BoostMinutes then
		data.BoostUntil = math.max(data.BoostUntil, os.time()) + grant.BoostMinutes * 60
	end
	if grant.Cosmetic then
		data.Cosmetics.Owned[grant.Cosmetic] = true
	end
	DataManager.Sync(player)
	return true
end

-- VIP: золотой ник над головой
local function applyVipTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild("VipTag") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "VipTag"
	billboard.Size = UDim2.fromScale(6, 1.2)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "👑 " .. player.DisplayName
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 205, 60)
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
	billboard.Parent = head
end

local function refreshPasses(player: Player)
	for key, pass in MonetizationConfig.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				DataManager.SetPass(player, key, true)
			end
		end
	end
	if DataManager.HasPass(player, "VIP") then
		applyVipTag(player)
	end
end

local function findPassKey(passId: number): string?
	for key, pass in MonetizationConfig.GamePasses do
		if pass.Id ~= 0 and pass.Id == passId then
			return key
		end
	end
	return nil
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataManager.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if data.Receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- уже выдано ранее
	end
	local product = MonetizationConfig.FindProductById(receipt.ProductId)
	if not product then
		warn("[Monetization] Неизвестный ProductId: " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MonetizationHandler.Grant(player, product.Grant)
	DataManager.RecordReceipt(player, purchaseId)

	-- подтверждаем покупку только после успешного сохранения (если сохранение вообще доступно)
	if DataManager.CanPersist(player) and not DataManager.Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	remotes.Notify:FireClient(player, "Покупка: " .. product.Name, "Cash")
	remotes.Effect:FireClient(player, "Purchase", nil, product.Key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onClaimDaily(player: Player)
	if not Util.IsValidPlayer(player) or not dailyCooldown(player) then
		return
	end
	local data = DataManager.Get(player)
	if not data then
		return
	end
	local state = DataManager.GetDailyState(data)
	if not state.CanClaim then
		remotes.Notify:FireClient(player, "Следующая награда через " .. Util.FormatTime(state.NextIn), "Info")
		return
	end
	local reward = MonetizationConfig.Daily[state.Day]
	data.Daily.Streak = state.Streak + 1
	data.Daily.LastClaim = os.time()
	MonetizationHandler.Grant(player, reward)
	remotes.Notify:FireClient(player, string.format("День %d: %s", state.Day, reward.Label), "Success")
	remotes.Effect:FireClient(player, "Daily", nil, state.Day)
end

function MonetizationHandler.Init()
	MarketplaceService.ProcessReceipt = processReceipt

	DataManager.OnLoaded(function(player)
		refreshPasses(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = findPassKey(passId)
		if key then
			DataManager.SetPass(player, key, true)
			remotes.Notify:FireClient(player, "Пасс активирован: " .. MonetizationConfig.GamePasses[key].Name, "Success")
			if key == "VIP" then
				applyVipTag(player)
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if DataManager.HasPass(player, "VIP") then
				applyVipTag(player)
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if DataManager.HasPass(player, "VIP") then
				applyVipTag(player)
			end
		end)
	end

	remotes.ClaimDaily.OnServerEvent:Connect(onClaimDaily)
end

return MonetizationHandler
