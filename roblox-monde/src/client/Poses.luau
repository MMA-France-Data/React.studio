-- LES GESTES DES BRAS, faits par le jeu lui-même (aucune animation à mettre en ligne) : on tourne les épaules et les
-- coudes de chaque personnage, par-dessus son animation normale. Tous les joueurs voient les gestes des autres, parce
-- que chacun les rejoue chez lui à partir des attributs du joueur :
--   porter   : les deux bras levés au-dessus de la tête, quand il porte un œuf (BagNext) ou un familier (Held) ;
--   frapper  : un coup de poing du bras droit, à chaque appui dans une salle où on frappe (PunchAt) ;
--   soulever : sur le banc de musculation (Workout = « Force »), les bras poussent une barre de haut en bas ; la
--              barre est dessinée ici, entre les deux mains.
-- (Personnages R15 seulement : les autres gardent leur animation normale.)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PUNCH = 0.38 -- durée d'un coup d'épée, en secondes
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

	-- { lame, matiere de la lame, garde }
	local SWORDS = {
		{ Color3.fromRGB(214, 222, 236), Enum.Material.Metal, Color3.fromRGB(150, 110, 60) },
		{ Color3.fromRGB(255, 205, 70), Enum.Material.Metal, Color3.fromRGB(180, 60, 50) },
		{ Color3.fromRGB(90, 220, 255), Enum.Material.Neon, Color3.fromRGB(40, 70, 160) },
		{ Color3.fromRGB(190, 110, 255), Enum.Material.Neon, Color3.fromRGB(60, 30, 110) },
		{ Color3.fromRGB(255, 80, 70), Enum.Material.Neon, Color3.fromRGB(40, 40, 50) },
	}
	local function sword(tier: number): Model
		local look = SWORDS[tier]
		local model = Instance.new("Model")
		model.Name = "Sword"
		local function piece(name: string, size: Vector3, color: Color3, material: Enum.Material)
			local part = Instance.new("Part")
			part.Name = name
			part.Size = size
			part.Color = color
			part.Material = material
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Parent = model
		end
		piece("Blade", Vector3.new(0.22, 0.6, 3.6), look[1], look[2])
		-- LA TRAÎNÉE : un ruban de lumière entre le bas et la pointe de la lame, qui dessine l'arc du coup.
		local blade = model.Blade
		local low, tip = Instance.new("Attachment"), Instance.new("Attachment")
		low.Position, tip.Position = Vector3.new(0, 0, 1.2), Vector3.new(0, 0, -3.2)
		low.Parent, tip.Parent = blade, blade
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = low, tip
		trail.Lifetime = 0.26
		trail.MinLength = 0
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.FaceCamera = false
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.4, if tier == 1 then Color3.fromRGB(170, 225, 255) else look[1]),
			ColorSequenceKeypoint.new(1, if tier == 1 then Color3.fromRGB(120, 170, 255) else look[1]),
		})
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.45), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.35) })
		trail.Enabled = false
		trail.Parent = blade
		piece("Guard", Vector3.new(0.3, 1.5, 0.3), look[3], Enum.Material.Metal)
		piece("Grip", Vector3.new(0.3, 0.3, 1), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
		model.Parent = workspace
		return model
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
	RunService.Stepped:Connect(function(_, dt)
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
			local base = character:GetPivot().Position.Z < 34
			local carrying = (base and (other:GetAttribute("BagNext") or "") ~= "") or (other:GetAttribute("Held") or "") ~= ""
			local pressing = other:GetAttribute("Workout") == "Force"
			local blend = 1 - math.exp(-12 * dt)
			state.carry += ((if carrying then 1 else 0) - state.carry) * blend
			state.press += ((if pressing then 1 else 0) - state.press) * blend
			local sincePunch = now - (other:GetAttribute("PunchAt") or 0)
			-- LE COUP D'ÉPÉE : le bras se lève d'un coup, puis l'épée fend l'air de haut en bas, en biais (un coup vers la
			-- gauche, le suivant vers la droite), et le buste tourne avec elle. swing : où on en est, de 0 à 1.
			local swing = if sincePunch >= 0 and sincePunch < PUNCH then sincePunch / PUNCH else -1
			local punch = if swing < 0 then 0 elseif swing < 0.7 then 1 else (1 - swing) / 0.3
			local sideways = if math.floor((other:GetAttribute("PunchAt") or 0) * 10) % 2 == 0 then 1 else -1

			-- Les angles de chaque geste (une rotation positive autour de X lève le bras vers l'avant, puis vers le haut).
			local right, left = CFrame.identity, CFrame.identity
			local rightBend, leftBend = CFrame.identity, CFrame.identity
			local weight = math.max(state.carry, state.press, punch)
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
			if punch > 0 then
				-- Le poing droit part droit devant ; le bras gauche reste en garde.
				-- Bras levé (175 degrés) en un dixième du temps, puis il descend jusqu'à 5 degrés en accélérant.
				local lift = if swing < 0.12 then 175 * swing / 0.12 else 175 - 170 * math.clamp((swing - 0.12) / 0.5, 0, 1) ^ 1.6
				local sweep = math.clamp((swing - 0.12) / 0.5, 0, 1) * 2 - 1 -- de -1 (début du coup) à 1 (fin)
				right = CFrame.Angles(math.rad(lift), 0, math.rad(sideways * (30 - 18 * sweep)))
				rightBend = CFrame.Angles(math.rad(18 * (1 - math.abs(sweep))), 0, 0)
				left = left:Lerp(CFrame.Angles(math.rad(-25), 0, math.rad(12)), punch)
				leftBend = leftBend:Lerp(CFrame.Angles(math.rad(40), 0, 0), punch)
				local waist = joint(character, "UpperTorso", "Waist")
				if waist then
					waist.Transform = waist.Transform:Lerp(CFrame.Angles(math.rad(8 * sweep), math.rad(-sideways * 32 * sweep), 0), punch)
				end
			end
			if weight > 0.01 then
				rightShoulder.Transform = rightShoulder.Transform:Lerp(right, weight)
				leftShoulder.Transform = leftShoulder.Transform:Lerp(left, weight)
				if rightElbow then
					rightElbow.Transform = rightElbow.Transform:Lerp(rightBend, weight)
				end
				if leftElbow then
					leftElbow.Transform = leftElbow.Transform:Lerp(leftBend, weight)
				end
			end

			-- L'EPEE, dans la main droite (sa couleur change tous les cinq niveaux). Pas pendant qu'on porte.
			local rightHand, leftHand = character:FindFirstChild("RightHand"), character:FindFirstChild("LeftHand")
			local tier = math.clamp(((other:GetAttribute("Sword") or 1) - 1) // 5 + 1, 1, #SWORDS)
			if rightHand and not carrying then
				if not state.sword or state.swordTier ~= tier then
					if state.sword then
						state.sword:Destroy()
					end
					state.sword, state.swordTier = sword(tier), tier
				end
				local grip = rightHand.CFrame * CFrame.new(0, -0.25, 0)
				state.sword.Blade.CFrame = grip * CFrame.new(0, 0, -2.3)
				-- La traînée de lumière ne s'allume que pendant le coup.
				state.sword.Blade.Trail.Enabled = swing >= 0.08 and swing < 0.75
				state.sword.Guard.CFrame = grip * CFrame.new(0, 0, -0.4)
				state.sword.Grip.CFrame = grip * CFrame.new(0, 0, 0.1)
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
end
