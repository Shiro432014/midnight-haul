-- ScrapyardHandler: сдача угнанных машин скупщику.
-- Подход → ProximityPrompt (или въезд в зону) → сервер присылает расчёт цены →
-- игрок жмёт «Сдать» → сервер заново всё проверяет и начисляет Cash.
-- Кулдаун сдачи 3 сек. Сдать можно только машину с StolenBy == player.UserId.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules.GameConfig)
local MonetizationConfig = require(Modules.MonetizationConfig)
local Util = require(Modules.Util)

local DataManager = require(script.Parent.DataManager)
local CarSpawner = require(script.Parent.CarSpawner)

local ScrapyardHandler = {}

local remotes = {
	Open = Util.Remote("OpenScrapyard"),
	Sell = Util.Remote("SellCar"),
	Notify = Util.Remote("Notify"),
	Effect = Util.Remote("Effect"),
}

local sellCooldown = Util.Cooldown(GameConfig.SellCooldown)
local promptCooldown = Util.Cooldown(0.5)
local quoteShown: { [string]: boolean } = {} -- CarId → меню уже открывалось при въезде

local dropZone: BasePart
local vipZone: BasePart?

local function inZone(position: Vector3, zone: BasePart?, radius: number): boolean
	if not zone then
		return false
	end
	local flat = Vector3.new(position.X - zone.Position.X, 0, position.Z - zone.Position.Z)
	return flat.Magnitude <= radius
end

local function carInYard(player: Player, record): boolean
	local chassis = CarSpawner.GetChassis(record)
	if not chassis then
		return false
	end
	if inZone(chassis.Position, dropZone, GameConfig.SellRadius) then
		return true
	end
	return DataManager.HasPass(player, "VIP") and inZone(chassis.Position, vipZone, GameConfig.SellRadius)
end

function ScrapyardHandler.Quote(player: Player, record)
	local basePrice = record.Def.BasePrice
	local multiplier = record.Rarity.Multiplier
	local subtotal = basePrice * multiplier
	local isVip = DataManager.HasPass(player, "VIP")
	local vipBonus = if isVip then subtotal * MonetizationConfig.VipCashBonus else 0
	return {
		CarId = record.Id,
		CarName = record.Def.DisplayName,
		Rarity = record.Rarity.Name,
		BasePrice = basePrice,
		Multiplier = multiplier,
		VipBonus = math.floor(vipBonus),
		Total = math.floor(subtotal + vipBonus),
	}
end

local function openQuote(player: Player): boolean
	local record = CarSpawner.GetStolenCar(player)
	if not record then
		remotes.Notify:FireClient(player, "У тебя нет угнанной машины.", "Error")
		return false
	end
	if not carInYard(player, record) then
		remotes.Notify:FireClient(player, "Загони машину в зону сдачи.", "Info")
		return false
	end
	quoteShown[record.Id] = true
	remotes.Open:FireClient(player, ScrapyardHandler.Quote(player, record))
	return true
end

local function onSell(player: Player, carId: any)
	if not Util.IsValidPlayer(player) or type(carId) ~= "string" then
		return
	end
	local data = DataManager.Get(player)
	if not data then
		return
	end
	local record = CarSpawner.Get(carId)
	if not record or record.State ~= "Stolen" or record.Owner ~= player or record.Model:GetAttribute("StolenBy") ~= player.UserId then
		remotes.Notify:FireClient(player, "Скупщик: «Это не твоя тачка».", "Error")
		return
	end
	if not carInYard(player, record) then
		remotes.Notify:FireClient(player, "Машина слишком далеко от скупщика.", "Error")
		return
	end
	if not sellCooldown(player) then
		remotes.Notify:FireClient(player, "Подожди пару секунд.", "Info")
		return
	end

	local quote = ScrapyardHandler.Quote(player, record)
	local chassis = CarSpawner.GetChassis(record)
	local position = chassis and chassis.Position
	CarSpawner.RemoveCar(record, "Sold")
	quoteShown[carId] = nil

	data.Stats.Sold += 1
	data.Stats.Earned += quote.Total
	data.Stats.BestSale = math.max(data.Stats.BestSale, quote.Total)
	DataManager.AddCash(player, quote.Total)
	DataManager.AddXP(player, quote.Total * GameConfig.XpPerCash)

	remotes.Effect:FireClient(player, "Cash", position, quote.Total)
	remotes.Notify:FireClient(player, string.format("Сделка! +%s", Util.FormatCash(quote.Total)), "Cash")
end

function ScrapyardHandler.Init()
	local yard = workspace:WaitForChild("Scrapyard")
	dropZone = yard:WaitForChild("DropZone") :: BasePart
	vipZone = yard:FindFirstChild("VipZone") :: BasePart?

	local counter = yard:WaitForChild("Counter")
	local sellPrompt = counter:WaitForChild("SellPrompt") :: ProximityPrompt
	sellPrompt.Triggered:Connect(function(player)
		if promptCooldown(player) then
			openQuote(player)
		end
	end)

	if vipZone then
		local vipPrompt = vipZone:FindFirstChild("VipPrompt") :: ProximityPrompt?
		if vipPrompt then
			vipPrompt.Triggered:Connect(function(player)
				if not promptCooldown(player) then
					return
				end
				if not DataManager.HasPass(player, "VIP") then
					remotes.Notify:FireClient(player, "VIP-приёмка доступна только с VIP-пассом.", "Info")
					local pass = MonetizationConfig.GamePasses.VIP
					if pass.Id ~= 0 then
						MarketplaceService:PromptGamePassPurchase(player, pass.Id)
					end
					return
				end
				openQuote(player)
			end)
		end
	end

	remotes.Sell.OnServerEvent:Connect(onSell)

	-- Автооткрытие меню при въезде в зону (по одному разу за въезд)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local record = CarSpawner.GetStolenCar(player)
				if record then
					local inside = carInYard(player, record)
					if inside and not quoteShown[record.Id] then
						openQuote(player)
					elseif not inside then
						quoteShown[record.Id] = nil
					end
				end
			end
		end
	end)
end

return ScrapyardHandler
