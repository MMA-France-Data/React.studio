-- LES GESTES DES BRAS, faits par le jeu lui-même (aucune animation à mettre en ligne) : on tourne les épaules et les
-- coudes de chaque personnage, par-dessus son animation normale. Tous les joueurs voient les gestes des autres, parce
-- que chacun les rejoue chez lui à partir des attributs du joueur :
--   porter   : les deux bras levés au-dessus de la tête, quand il porte un œuf (BagNext) ou un familier (Held) ;
--   frapper  : deux tailles circulaires alternées, gauche-droite puis droite-gauche (PunchAt) ;
--   soulever : sur le banc de musculation (Workout = « Force »), les bras poussent une barre de haut en bas ; la
--              barre est dessinée ici, entre les deux mains.
-- (Personnages R15 seulement : les autres gardent leur animation normale.)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatMotion = require(script.Parent.CombatMotion)
local SwordVisuals = require(script.Parent.SwordVisuals)
local CombatVFX = require(script.Parent.CombatVFX)
local PUNCH = CombatMotion.duration
local PRESS = 1 -- un aller-retour de la barre par seconde (deux pas d'entraînement)

-- L'articulation d'un membre. Les personnages recents n'ont plus de Motor6D mais des AnimationConstraint : les
-- deux ont la propriete Transform, c'est elle qu'on tourne.
local function joint(character: Model, part: string, name: string): any
	local limb = character:FindFirstChild(part)
	local motor = limb and limb:FindFirstChild(name)
	if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then
		return motor
	end
	-- (Ou rangee ailleurs dans le personnage, sous le meme nom.)
	for _, item in character:GetDescendants() do
		if item.Name == name and (item:IsA("Motor6D") or item:IsA("AnimationConstraint")) then
			return item
		end
	end
	return nil
end

return function()
	local states = {} -- [personnage] = { carry, press, bar }
	local BONE_PARTS = { ["Waist"] = "UpperTorso", ["Neck"] = "Head", ["RightShoulder"] = "RightUpperArm", ["LeftShoulder"] = "LeftUpperArm", ["RightElbow"] = "RightLowerArm", ["LeftElbow"] = "LeftLowerArm", ["RightWrist"] = "RightHand", ["LeftWrist"] = "LeftHand", ["RightHip"] = "RightUpperLeg", ["LeftHip"] = "LeftUpperLeg", ["Root"] = "LowerTorso", ["RightKnee"] = "RightLowerLeg", ["LeftKnee"] = "LeftLowerLeg", ["RightAnkle"] = "RightFoot", ["LeftAnkle"] = "LeftFoot" }
	local overlays = {}
	local function apply(link, transform)
		local previous = overlays[link]
		local baseline = if previous then previous.before else link.Transform
		link.Transform = transform
		overlays[link] = { before = baseline, after = transform }
	end
	-- Remove only our previous layer before the Animator evaluates the next frame.
	-- This also prevents accumulation on a throttled or temporarily idle Animator.
	RunService.PreAnimation:Connect(function()
		for link, layer in overlays do
			if link.Parent and link.Transform == layer.after then link.Transform = layer.before end
		end
		table.clear(overlays)
	end)
	local function clear(character: Model)
		local state = states[character]
		if state and state.bar then
			state.bar:Destroy()
		end
		if state and state.sword then
			state.sword:Destroy()
		end
		states[character] = nil
	end


	local function barbell(): Model
		local model = Instance.new("Model")
		model.Name = "Barbell"
		local function piece(name: string, size: Vector3, offset: number, color: Color3)
			local part = Instance.new("Part")
			part.Name = name
			part.Shape = Enum.PartType.Cylinder
			part.Size = size
			part.Color = color
			part.Material = Enum.Material.Metal
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part:SetAttribute("Offset", offset)
			part.Parent = model
			return part
		end
		model.PrimaryPart = piece("Bar", Vector3.new(7, 0.35, 0.35), 0, Color3.fromRGB(190, 194, 204))
		for _, side in { -1, 1 } do
			piece("Plate", Vector3.new(0.5, 2.2, 2.2), side * 3, Color3.fromRGB(40, 44, 56))
			piece("PlateSmall", Vector3.new(0.4, 1.6, 1.6), side * 2.5, Color3.fromRGB(220, 60, 50))
		end
		model.Parent = workspace
		return model
	end

	-- Après les animations du personnage, avant l'affichage : c'est là qu'on peut tourner les articulations.
	RunService.PreSimulation:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for character in states do
			if not character:IsDescendantOf(workspace) then
				clear(character)
			end
		end
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if not character then
				continue
			end
			local rightShoulder = joint(character, "RightUpperArm", "RightShoulder")
			local leftShoulder = joint(character, "LeftUpperArm", "LeftShoulder")
			local rightElbow = joint(character, "RightLowerArm", "RightElbow")
			local leftElbow = joint(character, "LeftLowerArm", "LeftElbow")
			if not rightShoulder or not leftShoulder then
				continue
			end
			local state = states[character]
			if not state then
				state = { carry = 0, press = 0 }
				states[character] = state
			end
			-- (Un oeuf ne se porte bras leves que dans la base : dehors, on se bat.)
			local base = true -- (un œuf ne se voit que si le joueur l'a sorti de son sac : il le porte alors partout)
			local carrying = (base and (other:GetAttribute("BagNext") or "") ~= "") or (other:GetAttribute("Held") or "") ~= ""
			local pressing = other:GetAttribute("Workout") == "Force"
			local blend = 1 - math.exp(-12 * dt)
			state.carry += ((if carrying then 1 else 0) - state.carry) * blend
			state.press += ((if pressing then 1 else 0) - state.press) * blend
			local stamp = other:GetAttribute("PunchAt") or 0
			local sincePunch = now - stamp
			local variant = CombatMotion.observeAttack(state, stamp, sincePunch)
			local combat = if not carrying and not pressing then CombatMotion.sample(variant, sincePunch) else nil
			if combat and sincePunch >= 0.065 and state.lastVfxStamp ~= stamp then
				state.lastVfxStamp = stamp
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then CombatVFX.slash(root.CFrame, SwordVisuals.tier(other:GetAttribute("Sword") or 1), variant) end
			end


			-- Les angles de chaque geste (une rotation positive autour de X lève le bras vers l'avant, puis vers le haut).
			local right, left = CFrame.identity, CFrame.identity
			local rightBend, leftBend = CFrame.identity, CFrame.identity
			local weight = math.max(state.carry, state.press)
			if state.press > 0.01 then
				-- Couché sur le banc : les bras pointent vers le haut et poussent la barre.
				local push = 0.5 + 0.5 * math.sin(now * math.pi * 2 * PRESS)
				right = CFrame.Angles(math.rad(70 + 22 * push), 0, math.rad(-8))
				left = CFrame.Angles(math.rad(70 + 22 * push), 0, math.rad(8))
				rightBend = CFrame.Angles(math.rad(75 * (1 - push)), 0, 0)
				leftBend = rightBend
			elseif state.carry > 0.01 then
				-- Les deux bras levés, un peu écartés, qui tiennent la charge au-dessus de la tête.
				right = CFrame.Angles(math.rad(172), 0, math.rad(-10))
				left = CFrame.Angles(math.rad(172), 0, math.rad(10))
			end
			if weight > 0.01 then
				apply(rightShoulder, rightShoulder.Transform:Lerp(right, weight))
				apply(leftShoulder, leftShoulder.Transform:Lerp(left, weight))
				if rightElbow then
					apply(rightElbow, rightElbow.Transform:Lerp(rightBend, weight))
				end
				if leftElbow then
					apply(leftElbow, leftElbow.Transform:Lerp(leftBend, weight))
				end
			end

			-- Full-body authored combat, layered over walking. No root displacement.
			if combat then
				for name, value in combat do
					local link = joint(character, BONE_PARTS[name] or "", name)
					if link then apply(link, value * link.Transform) end
				end
			end
			local rightHand, leftHand = character:FindFirstChild("RightHand"), character:FindFirstChild("LeftHand")
			local tier = SwordVisuals.tier(other:GetAttribute("Sword") or 1)
			if rightHand and not carrying and not pressing then
				if not state.sword or state.swordTier ~= tier then
					if state.sword then state.sword:Destroy() end
					state.sword, state.swordTier = SwordVisuals.build(tier, workspace), tier
				end
				state.swordHand = rightHand
				state.swordSwing = combat ~= nil and CombatMotion.trail(sincePunch)
			elseif state.sword then
				state.sword:Destroy()
				state.sword = nil
			end

			-- La barre du banc : entre les deux mains.
			if state.press > 0.5 and rightHand and leftHand then
				if not state.bar then
					state.bar = barbell()
				end
				local middle = (rightHand.Position + leftHand.Position) / 2
				local along = (rightHand.Position - leftHand.Position)
				along = if along.Magnitude > 0.05 then along.Unit else Vector3.xAxis
				for _, part in state.bar:GetChildren() do
					-- Un cylindre a son axe le long de X.
					local at = middle + along * (part:GetAttribute("Offset") or 0)
					part.CFrame = CFrame.lookAt(at, at + along) * CFrame.Angles(0, math.rad(90), 0)
				end
			elseif state.bar then
				state.bar:Destroy()
				state.bar = nil
			end
		end
	end)
	RunService.PreRender:Connect(function()
		for _, state in states do
			if state.sword and state.swordHand and state.swordHand.Parent then
				state.sword:PivotTo(state.swordHand.CFrame * CFrame.new(0, -0.25, 0))
				SwordVisuals.setSwing(state.sword, state.swordSwing == true)
			end
		end
	end)
end
