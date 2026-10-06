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

local PUNCH = 0.32 -- durée d'un coup de poing, en secondes
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
			local carrying = (other:GetAttribute("BagNext") or "") ~= "" or (other:GetAttribute("Held") or "") ~= ""
			local pressing = other:GetAttribute("Workout") == "Force"
			local blend = 1 - math.exp(-12 * dt)
			state.carry += ((if carrying then 1 else 0) - state.carry) * blend
			state.press += ((if pressing then 1 else 0) - state.press) * blend
			local sincePunch = now - (other:GetAttribute("PunchAt") or 0)
			local punch = if sincePunch >= 0 and sincePunch < PUNCH then math.sin(math.pi * sincePunch / PUNCH) else 0

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
				right = right:Lerp(CFrame.Angles(math.rad(95), 0, math.rad(6)), punch)
				rightBend = rightBend:Lerp(CFrame.identity, punch)
				left = left:Lerp(CFrame.Angles(math.rad(45), 0, 0), punch * 0.6)
				leftBend = leftBend:Lerp(CFrame.Angles(math.rad(70), 0, 0), punch * 0.6)
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

			-- La barre du banc : entre les deux mains.
			local rightHand, leftHand = character:FindFirstChild("RightHand"), character:FindFirstChild("LeftHand")
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
