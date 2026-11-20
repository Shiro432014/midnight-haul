-- Main: точка входа сервера. Порядок инициализации важен:
-- карта → данные → монетизация → спавн машин → взлом → скупщик → улучшения.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Util"))
Util.Remote("Notify") -- создаёт недостающие RemoteEvent'ы до того, как клиенты начнут их ждать

local WorldBuilder = require(script.Parent.WorldBuilder)
local DataManager = require(script.Parent.DataManager)
local MonetizationHandler = require(script.Parent.MonetizationHandler)
local CarSpawner = require(script.Parent.CarSpawner)
local TheftHandler = require(script.Parent.TheftHandler)
local ScrapyardHandler = require(script.Parent.ScrapyardHandler)
local UpgradeHandler = require(script.Parent.UpgradeHandler)

WorldBuilder.Build()
DataManager.Init()
MonetizationHandler.Init()
CarSpawner.Init()
TheftHandler.Init()
ScrapyardHandler.Init()
UpgradeHandler.Init()

print("[Midnight Haul] сервер запущен")
