-- Effets visuels purement côté client : tirs des tours, zones de feu et ronces, rayon, marques des contrôles et du
-- poison (appelés par PlotRenderer).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CombatVFX = require(script.Parent.CombatVFX)

local Effects = {}

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

-- Cercle bleu simple du Totem de givre (CombatVFX.circle).
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
	if typeof(current) ~= "CFrame" then return end -- (tour sans repère de visée : rien à tourner)
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
-- travel = durée du vol imposée (le serveur applique les dégâts à l'arrivée) ;
-- impactRadius > 0 = petite explosion à l'arrivée (carreau de la Baliste) ;
-- follow = projectile qui suit sa cible (voir playTowerShot) : à chaque image, il vole vers le
-- point que renvoie follow() au lieu de `to`, et l'explosion a lieu là où il arrive.
-- tint = flèche aux couleurs d'une tour spéciale (l'Arc carmin) : sa traînée, ses plumes, et un éclat à l'arrivée.
local function linearProjectile(from: Vector3, to: Vector3, color: Color3, heavy: boolean, travel: number?, impactRadius: number?, follow: (() -> Vector3)?, flaming: boolean?, tint: Color3?)
	local delta = to - from
	if delta.Magnitude < 0.1 then
		return
	end
	local projectile = projectilePart(color, if heavy then Vector3.new(0.22, 0.22, 2.8) else Vector3.new(0.12, 0.12, 1.8), Enum.Material.Metal)
	local direction = delta.Unit
	projectile.CFrame = CFrame.lookAt(from, from + direction)
	CombatVFX.decorateArrow(projectile, heavy, flaming == true, tint)
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
				elseif tint then
					Effects.burst(landing, 1, tint, 0.18)
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
	elseif tint then
		task.delay(duration, Effects.burst, to, 1, tint, 0.18)
	end
end

-- Étourdissement du Trébuchet royal : même doré que le disque des ennemis étourdis (PlotRenderer).
local STUN_COLOR = Color3.fromRGB(255, 212, 90)

-- Pierre de siège avec une vraie trajectoire parabolique.
-- travel = durée du vol imposée, sinon calculée avec la distance.
-- size / material / onImpact : grosse pierre du Trébuchet royal (sinon rocher de 0,9 et petite explosion).
-- follow = rocher qui suit sa cible (Catapulte, voir playTowerShot) : à chaque image, la cloche
-- (même hauteur) retombe sur le point que renvoie follow() au lieu de `to`, et l'explosion a lieu là.
-- shape = forme du projectile (une boule sinon) : le bloc de glace de la Catapulte de givre.
local function arcingProjectile(from: Vector3, to: Vector3, color: Color3, radius: number, travel: number?, size: number?, material: Enum.Material?, onImpact: ((Vector3) -> ())?, follow: (() -> Vector3)?, shape: Enum.PartType?)
	local projectile = projectilePart(color, Vector3.one * (size or 0.9), material or Enum.Material.Rock)
	projectile.Shape = shape or Enum.PartType.Ball
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
-- (sauf ceux déjà contrôlés par une autre tour, règle des contrôles de Hub/Combat.luau).
local function trebuchetImpact(to: Vector3, radius: number, color: Color3)
	CombatVFX.stoneImpact(effectsFolder, to, math.max(2, radius * 0.45), color)
	Effects.pulse(to, math.max(1, radius), STUN_COLOR)
end

-- Carreau perçant de la Baliste lourde (appelé par PlotRenderer à l'impact) : une traînée au ras
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

-- Éclair en zigzag (Mage des tempêtes, Oracle de la foudre) : 7 segments à cœur clair qui s'effacent vite, puis une petite
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

-- Projectiles des tours spéciales (def.shot, IdleTowers.luau) : la traînée dorée de l'Arc carmin, la graine épineuse
-- du Lance-ronces, le bloc de glace de la Catapulte de givre.
local CRIMSON_GOLD = Color3.fromRGB(255, 196, 70)
local THORN_SEED = Color3.fromRGB(70, 118, 44)
local ICE_BLOCK = Color3.fromRGB(196, 236, 255)

local ARROW_TYPES = { MachineGun = true, Rocket = true }
local SIEGE_TYPES = { Bomb = true, Orbital = true }

local MUZZLE_PARTS = {
	MachineGun = { "Arrow" },
	Rocket = { "Bolt", "BoltHead" },
	Bomb = { "Boulder" },
	Orbital = { "RunicStone" },
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
	elseif towerType == "Rocket" then
		recoil(model, { CrossbowArm = true, CrossbowString = true, BowArm = true, String = true }, CFrame.new(0, 0, 0.32), 0.1, 0.12)
		hideBriefly(model, { Bolt = true }, 0.28)
		return 0.09
	elseif towerType == "MachineGun" then
		recoil(model, { BowUpper = true, BowLower = true }, CFrame.new(0, 0, 0.18) * CFrame.Angles(0, 0, math.rad(5)), 0.08, 0.14)
		hideBriefly(model, { Arrow = true }, 0.22)
		return 0.07
	elseif towerType == "Bomb" then
		recoil(model, { ThrowingArm = true, Spoon = true }, CFrame.Angles(math.rad(52), 0, 0), 0.13, 0.42)
		hideBriefly(model, { Boulder = true }, 0.55)
		return 0.12
	elseif towerType == "Orbital" then
		recoil(model, { TrebuchetArm = true, Sling = true }, CFrame.Angles(math.rad(58), 0, 0), 0.16, 0.55)
		recoil(model, { Counterweight = true }, CFrame.new(0, -0.5, 0), 0.16, 0.55)
		hideBriefly(model, { RunicStone = true }, 0.7)
		return 0.15
	elseif towerType == "Tesla" then
		recoil(model, { Staff = true }, CFrame.Angles(0, 0, math.rad(-10)), 0.1, 0.22)
	elseif towerType == "Laser" then
		recoil(model, { ArcaneShard1 = true, ArcaneShard2 = true, ArcaneShard3 = true }, CFrame.new(0, 0.35, 0), 0.1, 0.2)
	elseif towerType == "Chain" then
		recoil(model, { Conductor = true, Prong = true, Spark = true }, CFrame.new(0, 0.28, 0), 0.08, 0.18)
	end
	return 0
end

-- flightTime : secondes réelles avant l'impact, envoyées par le serveur. Le projectile part après l'animation
-- de la tour et arrive pile à ce moment-là (quand les dégâts tombent).
-- follow (flèche, rocher de la Catapulte, carreau de la Baliste) : fonction qui renvoie,
-- à chaque image, le point où le projectile doit tomber (l'ennemi visé tel qu'il est affiché, ou le point prévu
-- s'il a disparu, voir PlotRenderer) : il arrive là où le serveur fait tomber les dégâts. La tour vise quand
-- même le point prévu au départ. Sans follow, le projectile va tout droit à `to`.
-- towerType = la SILHOUETTE de la tour (IdleTowers.shapeOf : son animation, d'où part le tir) ; style = l'allure du
-- projectile d'une tour spéciale (def.shot : "Crimson", "Thorn", "Ice"), nil = celui de la silhouette.
function Effects.playTowerShot(from: Vector3, to: Vector3, towerType: string, radius: number, color: Color3, kind: string, towerModel: Model?, flightTime: number?, follow: (() -> Vector3)?, style: string?)
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
		elseif style == "Crimson" then
			-- Arc carmin : une grosse flèche rouge, traînée dorée, un éclat à l'arrivée.
			linearProjectile(from, to, color, true, travel, nil, follow, false, CRIMSON_GOLD)
		elseif style == "Thorn" then
			-- Lance-ronces : une graine épineuse en cloche ; les ronces poussent là où elle tombe (PlotRenderer : addFire).
			arcingProjectile(from, to, THORN_SEED, radius, travel, 0.6, Enum.Material.Grass, function(at)
				Effects.burst(at, 1.4, color, 0.2)
			end, follow)
		elseif style == "Ice" then
			-- Catapulte de givre : un bloc de glace en cloche ; à l'impact, des éclats et le cercle bleu de sa zone (les
			-- monstres dedans sont ralentis).
			arcingProjectile(from, to, ICE_BLOCK, radius, travel, 1, Enum.Material.Ice, function(at)
				CombatVFX.stoneImpact(effectsFolder, at, math.max(1.8, radius * 0.5), ICE_BLOCK)
				Effects.circle(at, radius, color)
			end, follow, Enum.PartType.Block)
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
				towerType == "Rocket",
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
		end
	end)
end

----------------------------------------------------------------------
-- Zones de feu et rayon continu (appelés par PlotRenderer)
----------------------------------------------------------------------

-- Fait disparaître une part en douceur, puis la détruit.
function Effects.fadeOut(part: BasePart, duration: number)
	CombatVFX.fadeOut(part, duration)
end

-- Feu au sol : plusieurs foyers, braises, fumée. PlotRenderer garde la durée serveur inchangée.
function Effects.firePatch(position: Vector3, radius: number): BasePart
	return CombatVFX.firePatch(effectsFolder, position, radius)
end

-- Ronces au sol (Lance-ronces) : des épines et des bulles de poison. Même durée et même fin que le feu.
function Effects.thornPatch(position: Vector3, radius: number): BasePart
	return CombatVFX.thornPatch(effectsFolder, position, radius)
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

function Effects.setStatusVisual(anchor: BasePart, source: string?, fragile: boolean, poisoned: boolean?)
	CombatVFX.setStatus(anchor, source, fragile, poisoned == true)
end

return Effects
