-- Effets visuels purement côté client : tirs des tours et barres de vie des ennemis.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ProximityLabel = require(Shared.ProximityLabel)
local Remotes = require(Shared.Remotes)
local Towers = require(Shared.Towers)
local SoundManager = require(script.Parent.SoundManager)
local CombatVFX = require(script.Parent.CombatVFX)

local Effects = {}

-- Match classé : son du tir de chaque tour (Sounds.luau ; le mode solo joue les siens dans PlotRenderer).
local RANKED_SHOT_SOUNDS = { Gunner = "ArcherShot", Sniper = "BallistaShot", Mortar = "CatapultLaunch", Freezer = "FrostPulse" }

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "Effects"
effectsFolder.Parent = workspace

local function basePart(): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	return part
end

function Effects.tracer(from: Vector3, to: Vector3, color: Color3, width: number)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local part = basePart()
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Color = color
	part.Parent = effectsFolder
	TweenService:Create(part, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.2)
end

function Effects.burst(position: Vector3, radius: number, color: Color3, duration: number)
	CombatVFX.burst(effectsFolder, position, radius, color, duration)
end

-- Onde circulaire au sol (tours de zone).
function Effects.pulse(position: Vector3, radius: number, color: Color3)
	CombatVFX.pulse(effectsFolder, position, radius, color)
end

-- Cercle bleu simple du Totem de givre (et de la tour de givre du classé), comme à l'origine (CombatVFX.circle).
function Effects.circle(position: Vector3, radius: number, color: Color3)
	CombatVFX.circle(effectsFolder, position, radius, color)
end

local function partsNamed(model: Model?, names: { [string]: boolean }): { BasePart }
	local found = {}
	if not model then
		return found
	end
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and names[child.Name] then
			table.insert(found, child)
		end
	end
	return found
end

local function hideBriefly(model: Model?, names: { [string]: boolean }, duration: number)
	for _, visual in partsNamed(model, names) do
		local transparency = visual.Transparency
		visual.Transparency = 1
		task.delay(duration, function()
			if visual.Parent then
				visual.Transparency = transparency
			end
		end)
	end
end

local animating: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local bowAnimating: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function aimTower(model: Model?, target: Vector3)
	if not model then return end
	local current = model:GetAttribute("AimFrame")
	if typeof(current) ~= "CFrame" then return end -- modèles du mode infini uniquement
	-- Ne pas déplacer une pièce dont un ancien tween conserve la position absolue.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and animating[descendant] then return end
	end
	local flatTarget = Vector3.new(target.X, current.Position.Y, target.Z)
	if (flatTarget - current.Position).Magnitude < 0.1 then return end
	local aimed = CFrame.lookAt(current.Position, flatTarget)
	model:PivotTo(aimed * current:Inverse() * model:GetPivot())
	model:SetAttribute("AimFrame", aimed)
end

-- Deux segments de corde reliés aux extrémités de l'arc : détente puis réarmement.
-- Une boucle courte par arme active, pas de connexion permanente par tour.
local function releaseBow(model: Model)
	if bowAnimating[model] then return end
	bowAnimating[model] = true
	local strings = partsNamed(model, { BowString = true })
	hideBriefly(model, { Arrow = true, ArrowHead = true, ArrowFeather = true,
		Bolt = true, BoltHead = true, BoltFeather = true }, 0.2)
	task.spawn(function()
		local elapsed = 0
		repeat
			elapsed += RunService.RenderStepped:Wait()
			local alpha = if elapsed < 0.06 then elapsed / 0.06 else 1 - math.clamp((elapsed - 0.06) / 0.2, 0, 1)
			local frame = model:GetAttribute("AimFrame")
			if not model.Parent or typeof(frame) ~= "CFrame" then break end
			for _, stringPart in strings do
				if stringPart.Parent then
					local tip = stringPart:GetAttribute("StringTip")
					local nock = stringPart:GetAttribute("StringNock"):Lerp(stringPart:GetAttribute("StringReleased"), alpha)
					stringPart.Size = Vector3.new(stringPart.Size.X, stringPart.Size.Y, (nock - tip).Magnitude)
					stringPart.CFrame = frame * CFrame.lookAt((tip + nock) / 2, nock)
				end
			end
		until elapsed >= 0.26
		bowAnimating[model] = nil
	end)
end

local function recoil(model: Model?, names: { [string]: boolean }, goalOffset: CFrame, outTime: number, returnTime: number)
	for _, visual in partsNamed(model, names) do
		if animating[visual] then
			continue
		end
		animating[visual] = true
		local rest = visual.CFrame
		local outward = TweenService:Create(visual, TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = rest * goalOffset })
		outward:Play()
		outward.Completed:Once(function()
			if not visual.Parent then
				animating[visual] = nil
				return
			end
			local back = TweenService:Create(visual, TweenInfo.new(returnTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = rest })
			back:Play()
			back.Completed:Once(function()
				animating[visual] = nil
			end)
		end)
	end
end

local function projectilePart(color: Color3, size: Vector3, material): Part
	local projectile = basePart()
	projectile.Size = size
	projectile.Color = color
	projectile.Material = material
	projectile.Transparency = 0
	projectile.Parent = effectsFolder
	return projectile
end

-- Flèche ou carreau réellement visible pendant tout le trajet.
-- travel = durée du vol imposée (mode infini : le serveur applique les dégâts à l'arrivée) ;
-- impactRadius > 0 = petite explosion à l'arrivée (carreau de la Baliste) ;
-- follow = projectile qui suit sa cible (mode infini, voir playTowerShot) : à chaque image, il vole vers le
-- point que renvoie follow() au lieu de `to`, et l'explosion a lieu là où il arrive.
local function linearProjectile(from: Vector3, to: Vector3, color: Color3, heavy: boolean, travel: number?, impactRadius: number?, follow: (() -> Vector3)?, flaming: boolean?)
	local delta = to - from
	if delta.Magnitude < 0.1 then
		return
	end
	local projectile = projectilePart(color, if heavy then Vector3.new(0.22, 0.22, 2.8) else Vector3.new(0.12, 0.12, 1.8), Enum.Material.Metal)
	local direction = delta.Unit
	projectile.CFrame = CFrame.lookAt(from, from + direction)
	CombatVFX.decorateArrow(projectile, heavy, flaming == true)
	local duration = travel or math.clamp(delta.Magnitude / (if heavy then 90 else 125), 0.12, 0.55)
	Debris:AddItem(projectile, duration + 0.5) -- garde-fou même si la cible suivie disparaît
	if follow then
		-- Une boucle par projectile, comme la pierre en cloche (arcingProjectile) : aucune table ni fonction créée
		-- image par image.
		task.spawn(function()
			local elapsed, landing = 0, to
			while elapsed < duration and projectile.Parent do
				elapsed += RunService.RenderStepped:Wait()
				landing = follow()
				local heading = landing - from
				if heading.Magnitude > 0.1 then
					direction = heading.Unit
				end
				local position = from:Lerp(landing, math.min(1, elapsed / duration))
				projectile.CFrame = CFrame.lookAt(position, position + direction)
			end
			if projectile.Parent then
				projectile:Destroy()
				if impactRadius and impactRadius > 0 then
					Effects.burst(landing, math.max(1.2, impactRadius), color, 0.2)
				elseif flaming then
					Effects.burst(landing, 0.9, Color3.fromRGB(255, 151, 46), 0.16)
				end
			end
		end)
		return
	end
	TweenService:Create(projectile, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + direction) }):Play()
	Debris:AddItem(projectile, duration + 0.03)
	if impactRadius and impactRadius > 0 then
		task.delay(duration, Effects.burst, to, math.max(1.2, impactRadius), color, 0.2)
	elseif flaming then
		task.delay(duration, Effects.burst, to, 0.9, Color3.fromRGB(255, 151, 46), 0.16)
	end
end

-- Étourdissement du Trébuchet royal (mode infini) : même doré que le disque des ennemis étourdis (PlotRenderer).
local STUN_COLOR = Color3.fromRGB(255, 212, 90)

-- Pierre de siège avec une vraie trajectoire parabolique.
-- travel = durée du vol imposée (mode infini), sinon calculée avec la distance (ranked).
-- size / material / onImpact : grosse pierre du Trébuchet royal (sinon rocher de 0,9 et petite explosion).
-- follow = rocher qui suit sa cible (Catapulte du mode infini, voir playTowerShot) : à chaque image, la cloche
-- (même hauteur) retombe sur le point que renvoie follow() au lieu de `to`, et l'explosion a lieu là.
local function arcingProjectile(from: Vector3, to: Vector3, color: Color3, radius: number, travel: number?, size: number?, material: Enum.Material?, onImpact: ((Vector3) -> ())?, follow: (() -> Vector3)?)
	local projectile = projectilePart(color, Vector3.one * (size or 0.9), material or Enum.Material.Rock)
	projectile.Shape = Enum.PartType.Ball
	CombatVFX.decorateStone(projectile, color)
	local distance = (to - from).Magnitude
	local duration = travel or math.clamp(distance / 55, 0.42, 0.9)
	Debris:AddItem(projectile, duration + 0.5)
	local arc = math.clamp(distance * 0.22, 5, 15)
	task.spawn(function()
		local elapsed, landing = 0, to
		while elapsed < duration and projectile.Parent do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			if follow then
				landing = follow()
			end
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local nextAlpha = math.min(1, alpha + 0.025)
			local position = from:Lerp(landing, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * arc, 0)
			local nextPosition = from:Lerp(landing, nextAlpha) + Vector3.new(0, math.sin(nextAlpha * math.pi) * arc, 0)
			-- À l'impact, nextAlpha == alpha : conserver un cap valide, jamais un lookAt dégénéré.
			local heading = nextPosition - position
			projectile.CFrame = CFrame.lookAt(position, position + (if heading.Magnitude > 0.001 then heading else projectile.CFrame.LookVector))
		end
		if projectile.Parent then
			projectile:Destroy()
			if onImpact then
				onImpact(landing)
			else
				CombatVFX.stoneImpact(effectsFolder, landing, math.max(1.8, radius), color)
			end
		end
	end)
end

-- Impact de la pierre runique du Trébuchet royal : un éclat, puis une onde dorée au sol exactement de la
-- taille de sa zone (radius, envoyé par le serveur) : les ennemis dedans prennent les dégâts et sont étourdis
-- (sauf ceux déjà contrôlés par une autre tour, règle des contrôles de PlotGame).
local function trebuchetImpact(to: Vector3, radius: number, color: Color3)
	CombatVFX.stoneImpact(effectsFolder, to, math.max(2, radius * 0.45), color)
	Effects.pulse(to, math.max(1, radius), STUN_COLOR)
end

-- Carreau perçant de la Baliste lourde (mode infini, appelé par PlotRenderer à l'impact) : une traînée au ras
-- du chemin, de la tour (sous `from`) au point d'impact, aussi large que la zone touchée par le serveur
-- (2 x halfWidth) : tous les ennemis dessous ont pris les dégâts.
function Effects.pierceTrail(from: Vector3, to: Vector3, halfWidth: number, color: Color3)
	local y = to.Y + 0.8
	local a = Vector3.new(from.X, y, from.Z)
	local b = Vector3.new(to.X, y, to.Z)
	local length = (b - a).Magnitude
	if length < 0.1 then
		return
	end
	-- Deux sillages brefs délimitent la largeur touchée, pas un rectangle opaque sur la route.
	local side = (b - a).Unit:Cross(Vector3.yAxis) * halfWidth
	Effects.tracer(a + side, b + side, color, 0.06)
	Effects.tracer(a - side, b - side, color, 0.06)
	Effects.tracer(a, b, color:Lerp(Color3.new(1, 1, 1), 0.5), 0.1)
	Effects.burst(b, 1.4, color, 0.2)
end

local function magicProjectile(from: Vector3, to: Vector3, color: Color3)
	local projectile = projectilePart(color, Vector3.one * 0.58, Enum.Material.Neon)
	projectile.Shape = Enum.PartType.Ball
	projectile.Position = from
	CombatVFX.decorateMagic(projectile, color)
	local duration = math.clamp((to - from).Magnitude / 75, 0.18, 0.55)
	Debris:AddItem(projectile, duration + 0.5)
	TweenService:Create(projectile, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = to, Size = Vector3.one * 0.3 }):Play()
	task.delay(duration, function()
		if projectile.Parent then
			projectile:Destroy()
			Effects.burst(to, 1.4, color, 0.18)
		end
	end)
end

-- Éclair en zigzag (Mage des tempêtes du mode infini) : 7 segments à cœur clair qui s'effacent vite, puis une petite
-- décharge de la taille de sa zone là où la foudre tombe.
local function stormStrike(from: Vector3, to: Vector3, color: Color3, radius: number)
	local segments = 7
	local previous = from
	local delta = to - from
	local side = if delta.Magnitude > 0.1 then delta.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
	if side.Magnitude < 0.1 then
		side = Vector3.xAxis
	end
	for i = 1, segments do
		local point = from + delta * (i / segments)
		if i < segments then
			point += side.Unit * (math.random() - 0.5) * 1.6 + Vector3.new(0, (math.random() - 0.5) * 0.8, 0)
		end
		Effects.tracer(previous, point, color, 0.2)
		Effects.tracer(previous, point, color:Lerp(Color3.new(1, 1, 1), 0.8), 0.055)
		previous = point
	end
	Effects.burst(to + Vector3.new(0, 0.6, 0), math.max(1.2, radius), color, 0.22)
end

local ARROW_TYPES = { Gunner = true, MachineGun = true, Sniper = true, Rocket = true }
local SIEGE_TYPES = { Mortar = true, Bomb = true, Orbital = true }

local MUZZLE_PARTS = {
	Gunner = { "Arrow" },
	MachineGun = { "Arrow" },
	Sniper = { "Bolt" },
	Rocket = { "Bolt", "BoltHead" },
	Mortar = { "Boulder" },
	Bomb = { "Boulder" },
	Orbital = { "RunicStone" },
	Cryo = { "IceCrystal", "Staff" },
	Frost = { "CrystalCore" },
	Tesla = { "StormGem" },
	Laser = { "ArcaneShard2", "RuneFront" },
	Chain = { "Spark", "Conductor" },
}

local function muzzlePosition(model: Model?, towerType: string, fallback: Vector3): Vector3
	local choices = MUZZLE_PARTS[towerType]
	if not model or not choices then
		return fallback
	end
	for _, name in choices do
		local visual = model:FindFirstChild(name, true)
		if visual and visual:IsA("BasePart") then
			return visual.Position
		end
	end
	return fallback
end

-- Animation mécanique locale : elle est légère, immédiate et ne modifie jamais les dégâts serveur.
local function animateTower(model: Model?, towerType: string): number
	if model and model:GetAttribute("WorkingBow") then
		releaseBow(model)
		return 0.035
	elseif towerType == "Sniper" or towerType == "Rocket" then
		recoil(model, { CrossbowArm = true, CrossbowString = true, BowArm = true, String = true }, CFrame.new(0, 0, 0.32), 0.1, 0.12)
		hideBriefly(model, { Bolt = true }, 0.28)
		return 0.09
	elseif towerType == "Gunner" or towerType == "MachineGun" then
		recoil(model, { BowUpper = true, BowLower = true }, CFrame.new(0, 0, 0.18) * CFrame.Angles(0, 0, math.rad(5)), 0.08, 0.14)
		hideBriefly(model, { Arrow = true }, 0.22)
		return 0.07
	elseif towerType == "Mortar" or towerType == "Bomb" then
		recoil(model, { ThrowingArm = true, Spoon = true }, CFrame.Angles(math.rad(52), 0, 0), 0.13, 0.42)
		hideBriefly(model, { Boulder = true }, 0.55)
		return 0.12
	elseif towerType == "Orbital" then
		recoil(model, { TrebuchetArm = true, Sling = true }, CFrame.Angles(math.rad(58), 0, 0), 0.16, 0.55)
		recoil(model, { Counterweight = true }, CFrame.new(0, -0.5, 0), 0.16, 0.55)
		hideBriefly(model, { RunicStone = true }, 0.7)
		return 0.15
	elseif towerType == "Cryo" or towerType == "Tesla" then
		recoil(model, { Staff = true }, CFrame.Angles(0, 0, math.rad(-10)), 0.1, 0.22)
	elseif towerType == "Laser" then
		recoil(model, { ArcaneShard1 = true, ArcaneShard2 = true, ArcaneShard3 = true }, CFrame.new(0, 0.35, 0), 0.1, 0.2)
	elseif towerType == "Chain" then
		recoil(model, { Conductor = true, Prong = true, Spark = true }, CFrame.new(0, 0.28, 0), 0.08, 0.18)
	end
	return 0
end

-- flightTime (mode infini seulement) : secondes réelles avant l'impact, envoyées par le serveur. Le
-- projectile part après l'animation de la tour et arrive pile à ce moment-là (quand les dégâts tombent).
-- Sans flightTime (ranked), les durées de toujours.
-- follow (mode infini seulement : flèche, rocher de la Catapulte, carreau de la Baliste) : fonction qui renvoie,
-- à chaque image, le point où le projectile doit tomber (l'ennemi visé tel qu'il est affiché, ou le point prévu
-- s'il a disparu, voir PlotRenderer) : il arrive là où le serveur fait tomber les dégâts. La tour vise quand
-- même le point prévu au départ. Sans follow, le projectile va tout droit à `to`.
function Effects.playTowerShot(from: Vector3, to: Vector3, towerType: string, radius: number, color: Color3, kind: string, towerModel: Model?, flightTime: number?, follow: (() -> Vector3)?)
	if not CombatVFX.isNear(from) and not CombatVFX.isNear(to) then return end
	aimTower(towerModel, to)
	from = muzzlePosition(towerModel, towerType, from)
	local delay = animateTower(towerModel, towerType)
	local travel = nil
	if flightTime then
		-- L'animation de la tour mange le début du vol : le projectile part un peu après, arrive à l'heure.
		delay = math.min(delay, flightTime * 0.5)
		travel = math.max(0.05, flightTime - delay)
	end
	task.delay(delay, function()
		if kind == "Aura" then
			-- Totem de givre : le cercle bleu simple d'origine (demande du propriétaire, 30/09/2026).
			Effects.circle(to, radius, color)
		elseif towerType == "Orbital" and flightTime then
			-- Trébuchet royal : grosse pierre runique, onde dorée (étourdissement) de la taille de sa zone.
			arcingProjectile(from, to, Color3.fromRGB(96, 92, 86):Lerp(color, 0.3), radius, travel, 1.7, Enum.Material.Slate, function(at)
				trebuchetImpact(at, radius, color)
			end)
		elseif SIEGE_TYPES[towerType] then
			arcingProjectile(from, to, Color3.fromRGB(79, 76, 69):Lerp(color, 0.18), radius, travel, nil, nil, nil, follow)
		elseif ARROW_TYPES[towerType] then
			linearProjectile(
				from,
				to,
				if towerType == "Rocket" then color else Color3.fromRGB(218, 171, 71),
				towerType == "Sniper" or towerType == "Rocket",
				travel,
				if flightTime and towerType == "Rocket" then radius else nil,
				follow,
				flightTime ~= nil and towerType == "MachineGun"
			)
		elseif towerType == "Tesla" and flightTime then
			stormStrike(from, to, color, radius)
		elseif towerType == "Chain" then
			stormStrike(from, to, color, 0.7)
		elseif towerType == "Laser" then
			Effects.tracer(from, to, color, 0.28)
		else
			magicProjectile(from, to, color)
		end
	end)
end

----------------------------------------------------------------------
-- Mode infini : zones de feu et rayon continu (appelés par PlotRenderer)
----------------------------------------------------------------------

-- Fait disparaître une part en douceur, puis la détruit.
function Effects.fadeOut(part: BasePart, duration: number)
	CombatVFX.fadeOut(part, duration)
end

-- Feu au sol : plusieurs foyers, braises, fumée. PlotRenderer garde la durée serveur inchangée.
function Effects.firePatch(position: Vector3, radius: number): BasePart
	return CombatVFX.firePatch(effectsFolder, position, radius)
end

-- Rayon continu du Sorcier des arcanes : deux couches de Beam et des étincelles au contact.
-- Une seule paire d'ancres par tour, déplacée par PlotRenderer (updateBeam), cachée quand le rayon
-- s'éteint (hideBeam) : pas de création ni de destruction à chaque tir, pas de clignotement.
function Effects.createBeam(color: Color3)
	return CombatVFX.createBeam(effectsFolder, color)
end

-- heat : 0 = rayon qui démarre (x1, fin et pâle), 1 = rayon au maximum (épais, presque blanc).
function Effects.updateBeam(handle, from: Vector3, to: Vector3, heat: number, t: number)
	CombatVFX.updateBeam(handle, from, to, heat, t)
end

function Effects.hideBeam(handle)
	CombatVFX.hideBeam(handle)
end

function Effects.destroyBeam(handle)
	CombatVFX.destroyBeam(handle)
end

function Effects.createStatusVisual(root: BasePart, size: number, top: number?): BasePart
	return CombatVFX.statusAnchor(root, size, top)
end

function Effects.setStatusVisual(anchor: BasePart, source: string?, fragile: boolean)
	CombatVFX.setStatus(anchor, source, fragile)
end

local function towerById(towerId: number?): Model?
	if not towerId then
		return nil
	end
	local towers = workspace:FindFirstChild("Towers")
	if not towers then
		return nil
	end
	for _, tower in towers:GetChildren() do
		if tower:IsA("Model") and tower:GetAttribute("TowerId") == towerId then
			return tower
		end
	end
	return nil
end

local function onTowerFired(from: Vector3, to: Vector3, towerType: string, radius: number, towerId: number?)
	local def = Towers.Defs[towerType]
	if not def then
		return
	end
	Effects.playTowerShot(from, to, towerType, radius, def.color, def.kind, towerById(towerId))
	local sound = RANKED_SHOT_SOUNDS[towerType]
	if sound then
		SoundManager.playAt(sound, from)
	end
	if towerType == "Mortar" and SoundManager.isAudible("CatapultImpact", to) then
		-- Même durée que le rocher (animation de la tour, puis arcingProjectile) : le bruit tombe avec lui.
		local travel = 0.12 + math.clamp((to - from).Magnitude / 55, 0.42, 0.9)
		task.delay(travel, SoundManager.playAt, "CatapultImpact", to)
	end
end

local function addHealthBar(enemy: Instance)
	if not enemy:IsA("BasePart") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(40, 6)
	billboard.StudsOffset = Vector3.new(0, enemy.Size.Y / 2 + 1, 0)
	ProximityLabel.register(billboard, Config.LabelDistance.Far)
	billboard.AlwaysOnTop = true

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	background.BorderSizePixel = 0
	background.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = background

	local function update()
		local health = enemy:GetAttribute("Health") or 0
		local maxHealth = enemy:GetAttribute("MaxHealth") or 1
		fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
	end
	update()
	enemy:GetAttributeChangedSignal("Health"):Connect(update)
	billboard.Parent = enemy
end

-- Badge au-dessus de chaque tour : 3 pastilles qui se remplissent avec le niveau
-- (dorées au niveau max). Visible sur tes tours comme sur celles de l'adversaire.
local function addTowerBadge(model: Instance)
	local towerType = model:GetAttribute("TowerType")
	local def = towerType and Towers.Defs[towerType]
	if not def or not model:IsA("Model") then
		return
	end
	local anchor = model:WaitForChild("Base", 5)
	if not anchor then
		return
	end
	local maxLevel = Towers.maxLevel(towerType)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LevelBadge"
	billboard.Size = UDim2.fromOffset(78, 26)
	billboard.AlwaysOnTop = true
	ProximityLabel.register(billboard, Config.LabelDistance.Medium)
	billboard.Adornee = anchor

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	background.BackgroundTransparency = 0.25
	background.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = background
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = background

	local pips = {}
	for index = 1, maxLevel do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(14, 14)
		pip.LayoutOrder = index
		pip.Parent = background
		local pipCorner = Instance.new("UICorner")
		pipCorner.CornerRadius = UDim.new(1, 0)
		pipCorner.Parent = pip
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.4
		stroke.Parent = pip
		pips[index] = pip
	end

	local function update()
		local level = model:GetAttribute("Level") or 1
		local maxed = level >= maxLevel
		for index, pip in pips do
			local filled = index <= level
			pip.BackgroundColor3 = if maxed then Color3.fromRGB(255, 205, 80) elseif filled then def.color else Color3.fromRGB(45, 48, 60)
			pip.BackgroundTransparency = if filled then 0 else 0.2
		end
		-- Le badge suit la hauteur de la tour (qui grandit à chaque niveau).
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.5 + level * 1.2 + (if maxed then 3.2 else 2), 0)
	end
	update()
	model:GetAttributeChangedSignal("Level"):Connect(update)
	billboard.Parent = model
end

function Effects.start()
	Remotes.get("TowerFired").OnClientEvent:Connect(onTowerFired)

	local towers = workspace:WaitForChild("Towers")
	towers.ChildAdded:Connect(addTowerBadge)
	for _, model in towers:GetChildren() do
		task.spawn(addTowerBadge, model)
	end

	local enemies = workspace:WaitForChild("Enemies")
	enemies.ChildAdded:Connect(addHealthBar)
	for _, enemy in enemies:GetChildren() do
		addHealthBar(enemy)
	end
end

return Effects
