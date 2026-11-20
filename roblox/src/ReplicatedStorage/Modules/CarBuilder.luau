-- CarBuilder: собирает модель машины из Part'ов по описанию из CarConfig.
-- Используется сервером (машины в городе, с физикой) и клиентом
-- (декоративные копии на падах гаража, без физики).
-- Перед машиной — направление -Z (LookVector шасси).

local MonetizationConfig = require(script.Parent.MonetizationConfig)

local CarBuilder = {}

local WHEEL_RADIUS = 1.1
local BODY_BOTTOM = 0.7

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function attach(model: Model, chassis: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = chassis.CFrame * offset
	p.Parent = model
	if p ~= chassis then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = p
		weld.Parent = p
	end
end

-- opts.Physics = true: шасси со столкновениями, VehicleSeat и констрейнты движения.
-- opts.Physics = false: всё заякорено, без сиденья (витрина в гараже).
function CarBuilder.Build(def, rarity, colorIndex: number, opts: { Physics: boolean }?): Model
	local physics = opts == nil or opts.Physics ~= false
	local style = def.Style
	local L, W = style.Length, style.Width
	local bodyColor = def.Colors[((colorIndex - 1) % #def.Colors) + 1]

	local model = Instance.new("Model")
	model.Name = def.Id

	local chassis = part({
		Name = "Chassis",
		Size = Vector3.new(W, 1.2, L),
		Transparency = 1,
		CanCollide = true,
		CanTouch = true,
		Massless = false,
		Anchored = true,
		CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100),
	})
	chassis.CFrame = CFrame.new(0, 0.6, 0)
	chassis.Parent = model
	model.PrimaryPart = chassis
	local base = CFrame.new(0, -0.6, 0) -- точка на земле относительно шасси

	local bodyY = BODY_BOTTOM + style.BodyHeight / 2
	attach(model, chassis, part({
		Name = "Body",
		Size = Vector3.new(W, style.BodyHeight, L),
		Color = bodyColor,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.08,
	}), base * CFrame.new(0, bodyY, 0))

	local cabinY = BODY_BOTTOM + style.BodyHeight + style.CabinHeight / 2
	attach(model, chassis, part({
		Name = "Cabin",
		Size = Vector3.new(W - 0.6, style.CabinHeight, style.CabinLength),
		Color = Color3.fromRGB(18, 22, 34),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
	}), base * CFrame.new(0, cabinY, style.CabinOffset))

	attach(model, chassis, part({
		Name = "Roof",
		Size = Vector3.new(W - 0.7, 0.2, style.CabinLength - 0.8),
		Color = bodyColor,
	}), base * CFrame.new(0, cabinY + style.CabinHeight / 2 + 0.1, style.CabinOffset + 0.2))

	if style.Bed then
		local bedLength = L / 2 - (style.CabinOffset + style.CabinLength / 2) - 0.4
		local bedZ = L / 2 - bedLength / 2 - 0.2
		for _, side in { -1, 1 } do
			attach(model, chassis, part({
				Name = "BedRail",
				Size = Vector3.new(0.3, 0.6, bedLength),
				Color = bodyColor,
			}), base * CFrame.new(side * (W / 2 - 0.15), BODY_BOTTOM + style.BodyHeight + 0.3, bedZ))
		end
	end

	if style.Spoiler then
		local topY = BODY_BOTTOM + style.BodyHeight
		attach(model, chassis, part({
			Name = "Spoiler",
			Size = Vector3.new(W - 0.6, 0.18, 1.1),
			Color = Color3.fromRGB(20, 20, 24),
		}), base * CFrame.new(0, topY + 0.85, L / 2 - 0.7))
		for _, side in { -1, 1 } do
			attach(model, chassis, part({
				Name = "SpoilerPost",
				Size = Vector3.new(0.2, 0.8, 0.3),
				Color = Color3.fromRGB(20, 20, 24),
			}), base * CFrame.new(side * (W / 2 - 1.2), topY + 0.4, L / 2 - 0.7))
		end
	end

	-- Колёса (декоративные)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local wheelCf = base * CFrame.new(sx * (W / 2 - 0.3), WHEEL_RADIUS, sz * (L / 2 - 2.2))
			attach(model, chassis, part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.9, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2),
				Color = Color3.fromRGB(22, 22, 26),
			}), wheelCf)
			attach(model, chassis, part({
				Name = "Hub",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.95, 1.1, 1.1),
				Color = Color3.fromRGB(150, 155, 170),
				Material = Enum.Material.Metal,
			}), wheelCf)
		end
	end

	-- Фары и стопы
	local lightY = BODY_BOTTOM + style.BodyHeight * 0.65
	for _, sx in { -1, 1 } do
		local head = part({
			Name = "Headlight",
			Size = Vector3.new(1.2, 0.35, 0.2),
			Color = Color3.fromRGB(255, 244, 214),
			Material = Enum.Material.Neon,
		})
		attach(model, chassis, head, base * CFrame.new(sx * (W / 2 - 1), lightY, -L / 2 - 0.05))
		attach(model, chassis, part({
			Name = "Taillight",
			Size = Vector3.new(1.2, 0.3, 0.2),
			Color = Color3.fromRGB(255, 30, 50),
			Material = Enum.Material.Neon,
		}), base * CFrame.new(sx * (W / 2 - 1), lightY, L / 2 + 0.05))
	end

	if physics then
		local beam = Instance.new("SpotLight")
		beam.Name = "HeadBeam"
		beam.Face = Enum.NormalId.Front
		beam.Range = 45
		beam.Angle = 70
		beam.Brightness = 3
		beam.Color = Color3.fromRGB(255, 240, 210)
		beam.Enabled = false
		beam.Parent = model:FindFirstChild("Headlight")
	end

	-- Номер + неоновая рамка (косметика)
	attach(model, chassis, part({
		Name = "Plate",
		Size = Vector3.new(1.6, 0.5, 0.1),
		Color = Color3.fromRGB(235, 235, 240),
	}), base * CFrame.new(0, BODY_BOTTOM + 0.45, L / 2 + 0.06))
	attach(model, chassis, part({
		Name = "PlateFrame",
		Size = Vector3.new(1.85, 0.72, 0.06),
		Material = Enum.Material.Neon,
		Transparency = 1,
	}), base * CFrame.new(0, BODY_BOTTOM + 0.45, L / 2 + 0.04))

	-- Полоса редкости по бортам
	if rarity and rarity.Order >= 2 then
		for _, sx in { -1, 1 } do
			attach(model, chassis, part({
				Name = "RarityTrim",
				Size = Vector3.new(0.08, 0.18, L * 0.78),
				Color = rarity.Color,
				Material = Enum.Material.Neon,
			}), base * CFrame.new(sx * (W / 2 + 0.03), BODY_BOTTOM + 0.35, 0))
		end
	end

	-- Подсветка днища (косметика, по умолчанию скрыта)
	local glow = part({
		Name = "Underglow",
		Size = Vector3.new(W - 1.2, 0.08, L - 2.5),
		Material = Enum.Material.Neon,
		Transparency = 1,
	})
	attach(model, chassis, glow, base * CFrame.new(0, 0.3, 0))
	local glowLight = Instance.new("PointLight")
	glowLight.Name = "GlowLight"
	glowLight.Range = 14
	glowLight.Brightness = 3
	glowLight.Enabled = false
	glowLight.Parent = glow

	-- Легендарные и мифические машины светятся цветом редкости даже без косметики
	if rarity and rarity.Order >= 5 then
		local aura = Instance.new("PointLight")
		aura.Name = "RarityAura"
		aura.Color = rarity.Color
		aura.Range = 16
		aura.Brightness = 2
		aura.Parent = chassis
	end

	if physics then
		local seat = Instance.new("VehicleSeat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2, 0.5, 2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Massless = true
		seat.Disabled = true -- открывается только после успешного взлома
		seat.MaxSpeed = 0
		seat.Torque = 0
		seat.TurnSpeed = 0
		seat.HeadsUpDisplay = false
		attach(model, chassis, seat, base * CFrame.new(-W / 4 + 0.2, 1.25, style.CabinOffset + 0.4))

		local root = Instance.new("Attachment")
		root.Name = "DriveAttachment"
		root.Parent = chassis

		local drive = Instance.new("LinearVelocity")
		drive.Name = "Drive"
		drive.Attachment0 = root
		drive.RelativeTo = Enum.ActuatorRelativeTo.World
		drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		drive.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		drive.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		drive.PlaneVelocity = Vector2.zero
		drive.MaxForce = 250000
		drive.Enabled = false
		drive.Parent = chassis

		local steer = Instance.new("AngularVelocity")
		steer.Name = "Steer"
		steer.Attachment0 = root
		steer.RelativeTo = Enum.ActuatorRelativeTo.World
		steer.AngularVelocity = Vector3.zero
		steer.MaxTorque = 2000000
		steer.Enabled = false
		steer.Parent = chassis
	else
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
	end

	return model
end

-- Применить косметику (подсветка днища + рамка номера). key = "None" выключает.
function CarBuilder.ApplyUnderglow(model: Model, key: string)
	local glowDef = MonetizationConfig.GetUnderglow(key)
	local glow = model:FindFirstChild("Underglow", true) :: BasePart?
	local frame = model:FindFirstChild("PlateFrame", true) :: BasePart?
	local enabled = glowDef ~= nil and key ~= "None"
	if glow then
		glow.Transparency = if enabled then 0.15 else 1
		if glowDef then
			glow.Color = glowDef.Color
		end
		local light = glow:FindFirstChild("GlowLight") :: PointLight?
		if light then
			light.Enabled = enabled
			if glowDef then
				light.Color = glowDef.Color
			end
		end
	end
	if frame then
		frame.Transparency = if enabled then 0 else 1
		if glowDef then
			frame.Color = glowDef.Color
		end
	end
end

return CarBuilder
