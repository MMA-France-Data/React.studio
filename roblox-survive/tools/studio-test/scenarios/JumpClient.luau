-- Mesure la plus haute marche qu'un personnage grimpe d'un saut en courant, par rapport à sa hauteur de saut
-- (JumpHeight). Sert à régler Config.stepHeight : les grandes marches des salles de lave doivent passer avec le
-- niveau de saut demandé, pas avec le niveau d'en dessous (15 % de saut en moins).
-- Le personnage court vers un bloc et saute à plusieurs distances du bord ; une hauteur est « passée » si au
-- moins un essai arrive dessus. (À la distance 0, collé au bloc, il lui arrive de sauter deux fois : ne pas s'y
-- fier.) Mesure du 05/10/2026 : la marche passe jusqu'à « saut + 1,8 stud » environ (saut 7,2 : 9,0 ; saut 9,52 :
-- 10,95 au moins).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BASE = Vector3.new(400, 100, 0)
local EDGE = 24 -- distance entre le départ et le bloc

return function(log)
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	task.wait(3)
	local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
	pcall(function()
		controls:Disable()
	end)

	local function block(size: Vector3, position: Vector3): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = size
		part.Position = position
		part.Parent = workspace
		return part
	end
	block(Vector3.new(120, 2, 30), BASE + Vector3.new(30, -1, 0))
	local ledge = block(Vector3.new(14, 1, 20), BASE)

	local function attempt(height: number, distance: number): boolean
		ledge.Size = Vector3.new(14, height, 20)
		ledge.Position = BASE + Vector3.new(EDGE + 7, height / 2, 0)
		character:PivotTo(CFrame.new(BASE + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, math.rad(-90), 0))
		root.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.4)
		local jumped, best, far = false, 0, 0
		local started = os.clock()
		-- Juste après les commandes du joueur (priorité Input), sinon elles remettent le déplacement à zéro.
		RunService:BindToRenderStep("JumpTest", Enum.RenderPriority.Input.Value + 5, function()
			-- Court vers le bloc, s'arrête une fois dessus (ou passé le bord).
			humanoid:Move(if root.Position.X < BASE.X + EDGE + 5 then Vector3.new(1, 0, 0) else Vector3.zero, false)
			-- Demande le saut jusqu'à ce que le personnage ait vraiment décollé.
			if not jumped and root.Position.X >= BASE.X + EDGE - 1 - distance then
				humanoid.Jump = true
				jumped = humanoid.FloorMaterial == Enum.Material.Air
			end
		end)
		while os.clock() - started < 2.6 do
			task.wait()
			far = math.max(far, root.Position.X - BASE.X)
			best = math.max(best, root.Position.Y - BASE.Y)
			if root.Position.X > BASE.X + EDGE + 1 then
				best = math.max(best, root.Position.Y - BASE.Y)
			end
		end
		RunService:UnbindFromRenderStep("JumpTest")
		log("Debug", string.format("[SURVIVE]   essai h=%.2f d=%.1f : x max %.1f, y max %.2f, fin (%.1f, %.2f), saut=%s", height, distance, far, best, root.Position.X - BASE.X, root.Position.Y - BASE.Y, tostring(jumped)))
		humanoid:Move(Vector3.zero, false)
		-- Debout sur le bloc : le milieu du corps est 3 studs au-dessus.
		return root.Position.X > BASE.X + EDGE + 1 and root.Position.Y - BASE.Y > height + 2
	end

	for _, jumpHeight in { 7.2, 9.52, 12.6 } do
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = jumpHeight
		local highest, misses = 0, 0
		for step = 0, 16 do
			local ratio = 0.6 + step * 0.05
			local passed = {}
			for _, distance in { 0, 1, 2, 3.5 } do
				if attempt(ratio * jumpHeight, distance) then
					table.insert(passed, distance)
				end
			end
			log("Info", string.format("[SURVIVE] saut %.2f : marche x%.2f (%.2f studs) : %s", jumpHeight, ratio, ratio * jumpHeight, if #passed > 0 then "passe (distances " .. table.concat(passed, ", ") .. ")" else "ne passe pas"))
			if #passed > 0 then
				highest, misses = ratio, 0
			else
				misses += 1
				if misses >= 2 then
					break
				end
			end
		end
		log("Info", string.format("[SURVIVE] saut %.2f : plus haute marche passée = x%.2f", jumpHeight, highest))
	end
	log("Info", "[SURVIVE] TEST:done")
end
