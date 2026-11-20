-- WorldBuilder: строит прототип карты при старте сервера, если в Workspace
-- ещё нет своих моделей. Можно заменить любую часть своей:
--   Workspace.City        — город (любые детали)
--   Workspace.CarSpawns   — Part'ы/Attachment'ы с именами CarSpawn_01..CarSpawn_30
--   Workspace.Scrapyard   — нужны DropZone (Part), Counter (Part с ProximityPrompt "SellPrompt"),
--                            VipZone (Part с ProximityPrompt "VipPrompt")
--   Workspace.Garage      — нужны ParkZone (Part с ProximityPrompt "ParkPrompt"), Folder Pads (Pad_01..),
--                            UpgradeStand / ToolStand / StatsBoard (Part с ProximityPrompt "OpenPrompt")
-- Если папка/модель с таким именем уже есть — она не перестраивается.

local Lighting = game:GetService("Lighting")

local WorldBuilder = {}

local THEME = {
	Asphalt = Color3.fromRGB(30, 30, 38),
	Sidewalk = Color3.fromRGB(58, 58, 70),
	Building = { Color3.fromRGB(28, 30, 42), Color3.fromRGB(36, 34, 48), Color3.fromRGB(24, 28, 36), Color3.fromRGB(42, 40, 54) },
	Neon = { Color3.fromRGB(0, 229, 255), Color3.fromRGB(255, 46, 154), Color3.fromRGB(255, 170, 60), Color3.fromRGB(140, 90, 255) },
	Cyan = Color3.fromRGB(0, 229, 255),
	Magenta = Color3.fromRGB(255, 46, 154),
	Gold = Color3.fromRGB(255, 196, 40),
	Lamp = Color3.fromRGB(255, 214, 150),
}

-- Сетка города: 3x2 квартала по 150 studs, дороги по 40 studs.
local BLOCK = 150
local ROAD = 40
local COLS = { -190, 0, 190 }
local ROWS = { -95, 95 }
local CITY_HALF_X = 305
local CITY_HALF_Z = 210

local rng = Random.new(1911) -- фиксированный сид: карта одинаковая на каждом сервере

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function block(props: { [string]: any }, parent: Instance): Part
	local defaults = {
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Material = Enum.Material.SmoothPlastic,
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("Part", defaults, parent)
end

local function decal(props, parent)
	-- плоская декоративная полоса без коллизий
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return block(props, parent)
end

local function signText(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = make("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 20,
		LightInfluence = 0,
		Brightness = 2,
	}, part)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = color,
	}, gui)
	return gui
end

local function prompt(parent: Instance, name: string, action: string, objectText: string, distance: number?)
	return make("ProximityPrompt", {
		Name = name,
		ActionText = action,
		ObjectText = objectText,
		HoldDuration = 0.2,
		MaxActivationDistance = distance or 12,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
	}, parent)
end

local function outline(parent: Instance, center: Vector3, sizeX: number, sizeZ: number, color: Color3)
	local t = 0.6
	for _, info in {
		{ Vector3.new(0, 0, sizeZ / 2), Vector3.new(sizeX, 0.1, t) },
		{ Vector3.new(0, 0, -sizeZ / 2), Vector3.new(sizeX, 0.1, t) },
		{ Vector3.new(sizeX / 2, 0, 0), Vector3.new(t, 0.1, sizeZ) },
		{ Vector3.new(-sizeX / 2, 0, 0), Vector3.new(t, 0.1, sizeZ) },
	} do
		decal({ Name = "Outline", Size = info[2], Position = center + info[1], Color = color, Material = Enum.Material.Neon }, parent)
	end
end

local function streetLamp(parent: Instance, position: Vector3)
	local lamp = make("Model", { Name = "StreetLamp" }, parent)
	block({ Name = "Pole", Size = Vector3.new(0.6, 16, 0.6), Position = position + Vector3.new(0, 8, 0), Color = Color3.fromRGB(40, 40, 48), Material = Enum.Material.Metal }, lamp)
	local head = block({ Name = "Head", Size = Vector3.new(2.4, 0.6, 2.4), Position = position + Vector3.new(0, 16.2, 0), Color = THEME.Lamp, Material = Enum.Material.Neon, CanCollide = false }, lamp)
	make("PointLight", { Range = 38, Brightness = 1.4, Color = THEME.Lamp, Shadows = false }, head)
end

-- Освещение: ночь, туман, неоновый блум ---------------------------------------------
local function buildLighting()
	Lighting.ClockTime = 0.2
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(34, 34, 52)
	Lighting.OutdoorAmbient = Color3.fromRGB(58, 58, 92)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.FogColor = Color3.fromRGB(13, 13, 18)
	Lighting.FogStart = 250
	Lighting.FogEnd = 1100
	Lighting.GlobalShadows = true

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		make("Atmosphere", {
			Density = 0.32,
			Offset = 0.1,
			Color = Color3.fromRGB(28, 26, 48),
			Decay = Color3.fromRGB(60, 30, 80),
			Glare = 0,
			Haze = 1.4,
		}, Lighting)
	end
	if not Lighting:FindFirstChild("NeonBloom") then
		make("BloomEffect", { Name = "NeonBloom", Intensity = 0.9, Size = 28, Threshold = 0.85 }, Lighting)
	end
	if not Lighting:FindFirstChild("NightGrade") then
		make("ColorCorrectionEffect", {
			Name = "NightGrade",
			Contrast = 0.12,
			Saturation = 0.15,
			TintColor = Color3.fromRGB(225, 228, 255),
		}, Lighting)
	end
end

-- Город ---------------------------------------------------------------------------------
local PARKING_BLOCKS = { ["0,-95"] = true, ["190,95"] = true }

local function buildBuildingBlock(city: Instance, cx: number, cz: number)
	local folder = make("Folder", { Name = string.format("Block_%d_%d", cx, cz) }, city)
	local padSize = (BLOCK - 16) / 2 -- 4 участка, между ними переулки по 16 studs
	for _, ox in { -1, 1 } do
		for _, oz in { -1, 1 } do
			local px = cx + ox * (8 + padSize / 2)
			local pz = cz + oz * (8 + padSize / 2)
			block({ Name = "Sidewalk", Size = Vector3.new(padSize, 0.6, padSize), Position = Vector3.new(px, 0.3, pz), Color = THEME.Sidewalk, Material = Enum.Material.Concrete }, folder)

			local w = rng:NextNumber(padSize - 18, padSize - 8)
			local d = rng:NextNumber(padSize - 18, padSize - 8)
			local h = rng:NextInteger(5, 14) * 10
			local color = THEME.Building[rng:NextInteger(1, #THEME.Building)]
			block({
				Name = "Building",
				Size = Vector3.new(w, h, d),
				Position = Vector3.new(px, 0.6 + h / 2, pz),
				Color = color,
				Material = Enum.Material.Concrete,
			}, folder)

			-- неоновые полосы окон опоясывают здание
			local neon = THEME.Neon[rng:NextInteger(1, #THEME.Neon)]
			local floorStep = 14
			for y = 10, h - 6, floorStep do
				decal({
					Name = "WindowBand",
					Size = Vector3.new(w + 0.3, 1.2, d + 0.3),
					Position = Vector3.new(px, 0.6 + y, pz),
					Color = if rng:NextNumber() < 0.75 then Color3.fromRGB(255, 220, 160) else neon,
					Material = Enum.Material.Neon,
					Transparency = rng:NextNumber(0.35, 0.7),
				}, folder)
			end
			-- крышная обводка
			decal({
				Name = "RoofTrim",
				Size = Vector3.new(w + 0.6, 0.6, d + 0.6),
				Position = Vector3.new(px, 0.6 + h, pz),
				Color = neon,
				Material = Enum.Material.Neon,
			}, folder)

			-- фонарь на внешнем углу участка
			streetLamp(folder, Vector3.new(px + ox * (padSize / 2 - 2), 0.6, pz + oz * (padSize / 2 - 2)))
		end
	end
end

local function buildParkingBlock(city: Instance, cx: number, cz: number)
	local folder = make("Folder", { Name = string.format("Parking_%d_%d", cx, cz) }, city)
	decal({ Name = "LotSurface", Size = Vector3.new(BLOCK, 0.05, BLOCK), Position = Vector3.new(cx, 0.03, cz), Color = Color3.fromRGB(38, 38, 48), Material = Enum.Material.Asphalt }, folder)
	for _, row in { -1, 1 } do
		local rowZ = cz + row * 38
		for i = -2, 3 do
			decal({ Name = "StallLine", Size = Vector3.new(0.4, 0.06, 16), Position = Vector3.new(cx + i * 24 - 12, 0.06, rowZ), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Neon, Transparency = 0.55 }, folder)
		end
	end
	outline(folder, Vector3.new(cx, 0.06, cz), BLOCK - 4, BLOCK - 4, THEME.Magenta)
	for _, ox in { -1, 1 } do
		for _, oz in { -1, 1 } do
			streetLamp(folder, Vector3.new(cx + ox * 62, 0, cz + oz * 62))
		end
	end
	local sign = block({ Name = "LotSign", Size = Vector3.new(14, 6, 0.6), Position = Vector3.new(cx, 9, cz), Color = Color3.fromRGB(16, 16, 22) }, folder)
	block({ Name = "SignPole", Size = Vector3.new(0.6, 6, 0.6), Position = Vector3.new(cx, 3, cz), Color = Color3.fromRGB(40, 40, 48) }, folder)
	signText(sign, Enum.NormalId.Front, "P · ПАРКОВКА", THEME.Cyan)
	signText(sign, Enum.NormalId.Back, "P · ПАРКОВКА", THEME.Cyan)
end

local function buildCity()
	local city = make("Model", { Name = "City" }, workspace)

	block({ Name = "Ground", Size = Vector3.new(1400, 2, 820), Position = Vector3.new(0, -1, 0), Color = THEME.Asphalt, Material = Enum.Material.Asphalt }, city)

	-- невидимые стены по краю карты
	for _, info in {
		{ Vector3.new(0, 40, 410), Vector3.new(1400, 80, 2) },
		{ Vector3.new(0, 40, -410), Vector3.new(1400, 80, 2) },
		{ Vector3.new(700, 40, 0), Vector3.new(2, 80, 820) },
		{ Vector3.new(-700, 40, 0), Vector3.new(2, 80, 820) },
	} do
		block({ Name = "Boundary", Position = info[1], Size = info[2], Transparency = 1, CanQuery = false }, city)
	end

	-- разметка: двойная осевая на каждой дороге
	local markings = make("Folder", { Name = "RoadMarkings" }, city)
	local roadXs = { -285, -95, 95, 285 }
	local roadZs = { -190, 0, 190 }
	for _, x in roadXs do
		for _, off in { -0.5, 0.5 } do
			decal({ Size = Vector3.new(0.35, 0.05, CITY_HALF_Z * 2), Position = Vector3.new(x + off, 0.03, 0), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon, Transparency = 0.5 }, markings)
		end
	end
	for _, z in roadZs do
		for _, off in { -0.5, 0.5 } do
			decal({ Size = Vector3.new(CITY_HALF_X * 2, 0.05, 0.35), Position = Vector3.new(0, 0.03, z + off), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon, Transparency = 0.5 }, markings)
		end
	end
	-- дороги к скупщику и гаражу
	for _, x in { 330, -330 } do
		for _, off in { -0.5, 0.5 } do
			decal({ Size = Vector3.new(50, 0.05, 0.35), Position = Vector3.new(x, 0.03, off), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon, Transparency = 0.5 }, markings)
		end
	end

	for _, cx in COLS do
		for _, cz in ROWS do
			if PARKING_BLOCKS[string.format("%d,%d", cx, cz)] then
				buildParkingBlock(city, cx, cz)
			else
				buildBuildingBlock(city, cx, cz)
			end
		end
	end

	-- Билборды-указатели на перекрёстках выезда
	local signs = make("Folder", { Name = "DirectionSigns" }, city)
	local toYard = block({ Name = "ToScrapyard", Size = Vector3.new(16, 5, 0.6), Position = Vector3.new(312, 12, -24), Color = Color3.fromRGB(16, 16, 22), CanCollide = false }, signs)
	toYard.CFrame = toYard.CFrame * CFrame.Angles(0, math.rad(90), 0)
	signText(toYard, Enum.NormalId.Front, "СКУПКА", THEME.Magenta)
	signText(toYard, Enum.NormalId.Back, "ГОРОД", THEME.Cyan)
	local toGarage = block({ Name = "ToGarage", Size = Vector3.new(16, 5, 0.6), Position = Vector3.new(-312, 12, -24), Color = Color3.fromRGB(16, 16, 22), CanCollide = false }, signs)
	toGarage.CFrame = toGarage.CFrame * CFrame.Angles(0, math.rad(90), 0)
	signText(toGarage, Enum.NormalId.Front, "ГОРОД", THEME.Magenta)
	signText(toGarage, Enum.NormalId.Back, "ГАРАЖ", THEME.Cyan)
end

-- Точки спавна машин -------------------------------------------------------------------
local function buildCarSpawns()
	local folder = make("Folder", { Name = "CarSpawns" }, workspace)
	local points: { CFrame } = {}

	-- парковки: два ряда по 5 мест, машины носом к центру ряда
	for key in PARKING_BLOCKS do
		local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
		local x0, z0 = tonumber(cx) :: number, tonumber(cz) :: number
		for _, row in { -1, 1 } do
			for _, i in { -2, -1, 0, 1, 2 } do
				local yaw = if row < 0 then 0 else math.pi
				table.insert(points, CFrame.new(x0 + i * 12 * 2, 0, z0 + row * 38) * CFrame.Angles(0, yaw, 0))
			end
		end
	end
	-- переулки внутри жилых кварталов
	for _, cx in COLS do
		for _, cz in ROWS do
			if not PARKING_BLOCKS[string.format("%d,%d", cx, cz)] then
				table.insert(points, CFrame.new(cx, 0, cz + 38) * CFrame.Angles(0, 0, 0))
			end
		end
	end
	-- вдоль обочин (параллельная парковка)
	for _, info in {
		{ Vector3.new(-190, 0, -16), math.rad(90) },
		{ Vector3.new(190, 0, 16), math.rad(-90) },
		{ Vector3.new(-95 + 16, 0, 95), 0 },
		{ Vector3.new(95 - 16, 0, -95), math.pi },
		{ Vector3.new(-190, 0, 206 - 20), math.rad(90) },
		{ Vector3.new(190, 0, -206 + 20), math.rad(-90) },
	} do
		table.insert(points, CFrame.new(info[1]) * CFrame.Angles(0, info[2], 0))
	end

	for index, cf in points do
		block({
			Name = string.format("CarSpawn_%02d", index),
			Size = Vector3.new(6, 0.2, 12),
			CFrame = cf * CFrame.new(0, 0.1, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, folder)
	end
end

-- Скупщик --------------------------------------------------------------------------
local function buildScrapyard()
	local yard = make("Model", { Name = "Scrapyard" }, workspace)
	local cx = 430

	-- забор из профлиста (вход с запада)
	local fenceColor = Color3.fromRGB(70, 74, 84)
	block({ Name = "Fence", Size = Vector3.new(150, 12, 1), Position = Vector3.new(cx, 6, 75), Color = fenceColor, Material = Enum.Material.CorrodedMetal }, yard)
	block({ Name = "Fence", Size = Vector3.new(150, 12, 1), Position = Vector3.new(cx, 6, -75), Color = fenceColor, Material = Enum.Material.CorrodedMetal }, yard)
	block({ Name = "Fence", Size = Vector3.new(1, 12, 150), Position = Vector3.new(cx + 75, 6, 0), Color = fenceColor, Material = Enum.Material.CorrodedMetal }, yard)
	block({ Name = "Fence", Size = Vector3.new(1, 12, 45), Position = Vector3.new(cx - 75, 6, 52.5), Color = fenceColor, Material = Enum.Material.CorrodedMetal }, yard)
	block({ Name = "Fence", Size = Vector3.new(1, 12, 45), Position = Vector3.new(cx - 75, 6, -52.5), Color = fenceColor, Material = Enum.Material.CorrodedMetal }, yard)

	-- склад
	block({ Name = "Warehouse", Size = Vector3.new(30, 26, 100), Position = Vector3.new(cx + 58, 13, 0), Color = Color3.fromRGB(34, 34, 44), Material = Enum.Material.Metal }, yard)
	local sign = block({ Name = "Sign", Size = Vector3.new(0.6, 8, 40), Position = Vector3.new(cx + 42.6, 20, 0), Color = Color3.fromRGB(14, 14, 20) }, yard)
	signText(sign, Enum.NormalId.Left, "СКУПКА", THEME.Magenta)

	-- ворота входа
	for _, z in { -30, 30 } do
		block({ Name = "GatePost", Size = Vector3.new(2, 18, 2), Position = Vector3.new(cx - 75, 9, z), Color = Color3.fromRGB(30, 30, 38) }, yard)
	end
	local gate = block({ Name = "GateSign", Size = Vector3.new(1, 5, 62), Position = Vector3.new(cx - 75, 19, 0), Color = Color3.fromRGB(14, 14, 20), CanCollide = false }, yard)
	signText(gate, Enum.NormalId.Left, "MIDNIGHT HAUL · СКУПКА", THEME.Magenta)

	-- зона сдачи
	local zone = block({ Name = "DropZone", Size = Vector3.new(50, 0.1, 50), Position = Vector3.new(cx - 15, 0.05, 0), Color = Color3.fromRGB(40, 16, 34), CanCollide = false, CanTouch = false }, yard)
	outline(yard, Vector3.new(cx - 15, 0.12, 0), 50, 50, THEME.Magenta)
	make("PointLight", { Range = 40, Brightness = 1, Color = THEME.Magenta }, zone)

	-- стойка скупщика + NPC
	local counter = block({ Name = "Counter", Size = Vector3.new(4, 4, 14), Position = Vector3.new(cx + 18, 2, 0), Color = Color3.fromRGB(26, 26, 34), Material = Enum.Material.Metal }, yard)
	prompt(counter, "SellPrompt", "Сдать машину", "Скупщик", 34)
	local npc = make("Model", { Name = "Buyer" }, yard)
	local npcX = cx + 22
	block({ Name = "Legs", Size = Vector3.new(2, 3, 1.2), Position = Vector3.new(npcX, 1.5, 0), Color = Color3.fromRGB(30, 30, 40) }, npc)
	block({ Name = "Torso", Size = Vector3.new(2.4, 2.6, 1.4), Position = Vector3.new(npcX, 4.3, 0), Color = Color3.fromRGB(80, 30, 60) }, npc)
	block({ Name = "Head", Size = Vector3.new(1.4, 1.4, 1.4), Position = Vector3.new(npcX, 6.3, 0), Color = Color3.fromRGB(214, 170, 130) }, npc)
	block({ Name = "Cap", Size = Vector3.new(1.6, 0.4, 1.8), Position = Vector3.new(npcX - 0.1, 7.15, 0), Color = THEME.Magenta, Material = Enum.Material.Neon }, npc)

	-- VIP-приёмка
	local vipZone = block({ Name = "VipZone", Size = Vector3.new(30, 0.1, 30), Position = Vector3.new(cx - 45, 0.05, 50 - 8), Color = Color3.fromRGB(46, 36, 10), CanCollide = false, CanTouch = false }, yard)
	outline(yard, vipZone.Position + Vector3.new(0, 0.07, 0), 30, 30, THEME.Gold)
	local vipPost = block({ Name = "VipPost", Size = Vector3.new(1, 8, 1), Position = vipZone.Position + Vector3.new(14, 4, 14), Color = THEME.Gold, Material = Enum.Material.Neon }, yard)
	prompt(vipZone, "VipPrompt", "VIP-сдача", "VIP-приёмка", 24)
	local vipSign = block({ Name = "VipSign", Size = Vector3.new(10, 3, 0.4), Position = vipPost.Position + Vector3.new(-5, 5, 0), Color = Color3.fromRGB(14, 14, 20), CanCollide = false }, yard)
	signText(vipSign, Enum.NormalId.Front, "VIP", THEME.Gold)
	signText(vipSign, Enum.NormalId.Back, "VIP", THEME.Gold)

	-- кучи металлолома для атмосферы
	for i = 1, 6 do
		local side = if i % 2 == 0 then 1 else -1
		local pos = Vector3.new(cx + rng:NextNumber(20, 40), 0, side * rng:NextNumber(22, 64))
		block({ Name = "Scrap", Size = Vector3.new(rng:NextNumber(4, 8), rng:NextNumber(2, 5), rng:NextNumber(4, 9)), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(80 + i * 6, 60, 50), Material = Enum.Material.CorrodedMetal }, yard)
	end
	streetLamp(yard, Vector3.new(cx - 60, 0, -60))
	streetLamp(yard, Vector3.new(cx - 60, 0, 60))
end

-- Гараж ------------------------------------------------------------------------------
local function buildGarage()
	local garage = make("Model", { Name = "Garage" }, workspace)
	local x0, x1 = -500, -370 -- задняя стена — запад, вход — восток
	local cx = (x0 + x1) / 2
	local wallColor = Color3.fromRGB(26, 26, 36)

	decal({ Name = "Floor", Size = Vector3.new(x1 - x0, 0.05, 120), Position = Vector3.new(cx, 0.03, 0), Color = Color3.fromRGB(20, 20, 28), Material = Enum.Material.Concrete }, garage)
	block({ Name = "BackWall", Size = Vector3.new(2, 30, 120), Position = Vector3.new(x0, 15, 0), Color = wallColor, Material = Enum.Material.Concrete }, garage)
	block({ Name = "SideWall", Size = Vector3.new(x1 - x0, 30, 2), Position = Vector3.new(cx, 15, 60), Color = wallColor, Material = Enum.Material.Concrete }, garage)
	block({ Name = "SideWall", Size = Vector3.new(x1 - x0, 30, 2), Position = Vector3.new(cx, 15, -60), Color = wallColor, Material = Enum.Material.Concrete }, garage)
	block({ Name = "Roof", Size = Vector3.new(x1 - x0, 2, 124), Position = Vector3.new(cx, 31, 0), Color = Color3.fromRGB(18, 18, 24) }, garage)
	-- фасад с проёмом
	for _, z in { -46, 46 } do
		block({ Name = "Facade", Size = Vector3.new(2, 30, 28), Position = Vector3.new(x1, 15, z), Color = wallColor, Material = Enum.Material.Concrete }, garage)
	end
	block({ Name = "Facade", Size = Vector3.new(2, 10, 64), Position = Vector3.new(x1, 25, 0), Color = wallColor, Material = Enum.Material.Concrete }, garage)
	local frameSign = block({ Name = "GarageSign", Size = Vector3.new(0.6, 6, 40), Position = Vector3.new(x1 + 1.3, 25, 0), Color = Color3.fromRGB(12, 12, 18), CanCollide = false }, garage)
	signText(frameSign, Enum.NormalId.Right, "ГАРАЖ", THEME.Cyan)
	decal({ Name = "DoorFrame", Size = Vector3.new(0.4, 0.6, 64), Position = Vector3.new(x1 + 1.1, 20, 0), Color = THEME.Cyan, Material = Enum.Material.Neon }, garage)

	-- свет внутри
	for _, x in { -470, -430, -395 } do
		local lamp = decal({ Name = "CeilingLight", Size = Vector3.new(4, 0.4, 80), Position = Vector3.new(x, 29.6, 0), Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Neon }, garage)
		make("PointLight", { Range = 50, Brightness = 1.2, Color = Color3.fromRGB(200, 230, 255) }, lamp)
	end

	-- пады для пассивного дохода: 2 ряда вдоль стен
	local pads = make("Folder", { Name = "Pads" }, garage)
	local index = 0
	for _, row in { 1, -1 } do
		for i = 0, 5 do
			index += 1
			if index > 11 then
				break
			end
			local pos = Vector3.new(-482 + i * 17, 0.07, row * 44)
			local pad = block({
				Name = string.format("Pad_%02d", index),
				Size = Vector3.new(9, 0.1, 15),
				CFrame = CFrame.new(pos) * CFrame.Angles(0, if row > 0 then 0 else math.pi, 0),
				Color = Color3.fromRGB(30, 30, 44),
				CanCollide = false,
			}, pads)
			outline(pad, pos + Vector3.new(0, 0.06, 0), 9, 15, THEME.Cyan)
			local label = block({ Name = "Number", Size = Vector3.new(4, 0.05, 2), Position = pos + Vector3.new(0, 0.1, -row * 8.5), Transparency = 1, CanCollide = false }, pad)
			local gui = signText(label, Enum.NormalId.Top, tostring(index), THEME.Cyan)
			gui.Name = "NumberGui"
		end
	end

	-- стойки
	local function stand(name: string, position: Vector3, title: string, color: Color3, action: string)
		local base = block({ Name = name, Size = Vector3.new(3, 6, 8), Position = position + Vector3.new(0, 3, 0), Color = Color3.fromRGB(24, 24, 32), Material = Enum.Material.Metal }, garage)
		decal({ Name = name .. "Glow", Size = Vector3.new(3.2, 0.3, 8.2), Position = position + Vector3.new(0, 6.1, 0), Color = color, Material = Enum.Material.Neon }, garage)
		local screen = block({ Name = name .. "Screen", Size = Vector3.new(0.4, 3, 7), Position = position + Vector3.new(1.4, 8, 0), Color = Color3.fromRGB(10, 10, 16), CanCollide = false }, garage)
		signText(screen, Enum.NormalId.Right, title, color)
		prompt(base, "OpenPrompt", action, title, 10)
		return base
	end
	stand("UpgradeStand", Vector3.new(-494, 0, -16), "УЛУЧШЕНИЯ", THEME.Cyan, "Открыть")
	stand("ToolStand", Vector3.new(-494, 0, 16), "ИНСТРУМЕНТЫ", THEME.Magenta, "Открыть")

	-- доска статистики на задней стене (текст обновляет клиент для своего игрока)
	local board = block({ Name = "StatsBoard", Size = Vector3.new(0.6, 14, 24), Position = Vector3.new(x0 + 1.4, 14, 0), Color = Color3.fromRGB(12, 12, 18) }, garage)
	local boardGui = make("SurfaceGui", {
		Name = "BoardGui",
		Face = Enum.NormalId.Right,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 25,
		LightInfluence = 0,
	}, board)
	make("TextLabel", { Name = "Title", Size = UDim2.fromScale(1, 0.2), BackgroundTransparency = 1, Text = "ДОСКА СТАТИСТИКИ", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = THEME.Cyan }, boardGui)
	make("TextLabel", { Name = "Body", Size = UDim2.fromScale(0.9, 0.75), Position = UDim2.fromScale(0.05, 0.22), BackgroundTransparency = 1, Text = "", TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(230, 230, 245) }, boardGui)
	prompt(board, "OpenPrompt", "Подробнее", "Статистика", 14)

	-- зона парковки у входа
	local park = block({ Name = "ParkZone", Size = Vector3.new(30, 0.1, 30), Position = Vector3.new(x1 - 18, 0.07, 0), Color = Color3.fromRGB(10, 34, 42), CanCollide = false, CanTouch = false }, garage)
	outline(garage, park.Position + Vector3.new(0, 0.06, 0), 30, 30, THEME.Cyan)
	prompt(park, "ParkPrompt", "Поставить в гараж", "Пад гаража", 24)

	-- спавн игроков перед гаражом
	make("SpawnLocation", {
		Name = "PlayerSpawn",
		Anchored = true,
		Size = Vector3.new(12, 1, 12),
		Position = Vector3.new(x1 + 26, 0.5, 30),
		Neutral = true,
		Duration = 0,
		Color = Color3.fromRGB(20, 40, 50),
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
	}, garage)
	streetLamp(garage, Vector3.new(x1 + 10, 0, 40))
	streetLamp(garage, Vector3.new(x1 + 10, 0, -40))
end

function WorldBuilder.Build()
	buildLighting()
	if not workspace:FindFirstChild("City") then
		buildCity()
	end
	if not workspace:FindFirstChild("CarSpawns") then
		buildCarSpawns()
	end
	if not workspace:FindFirstChild("Scrapyard") then
		buildScrapyard()
	end
	if not workspace:FindFirstChild("Garage") then
		buildGarage()
	end
	-- стандартная платформа Baseplate мешает городу
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
end

return WorldBuilder
