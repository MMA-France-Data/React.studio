-- Test des MODÈLES 3D DES MONSTRES, côté client : tools/studio-test/run.ps1 -Test monsters.
-- (ReplicatedStorage.EnemyModels, src/shared/CustomModels.luau, galerie Studio src/client/EnemyGallery.luau)
--   1) le module, avec un modèle de test « Swarm » posé pendant la partie : il remplace les blocs des écuyers, sans ses
--      scripts ; paliers (« Swarm_3 » passe avant « Swarm ») ; animations lues dans le code ou dans le modèle ;
--   2) les vrais modèles du projet (assets/EnemyModels) : nom valable, bonne hauteur, tournés dans le sens de la
--      marche, animations publiées qui se chargent ; une photo de chacun en train de marcher (walk_<modèle>) ;
--   3) la galerie Studio construite avec ces modèles ;
--   4) un vrai niveau : ses monstres sont les vrais modèles (ou les blocs), à leur taille agrandie.
-- « SHOT:nom » = capture (out\monsters_<nom>.png). Un plugin ne peut pas cliquer : le niveau est lancé par le vrai
-- remote, comme le bouton « ▶ JOUER ».
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local CustomModels = require(Shared.CustomModels)
	local Enemies = require(Shared.Enemies)
	local IdleConfig = require(Shared.IdleConfig)
	local Levels = require(Shared.Levels)
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera

	local function say(message)
		log("Info", "[MONSTERS] " .. message)
	end
	local function shot(name)
		say("SHOT:monsters_" .. name)
		task.wait(1.2)
	end
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] monstres : {message}`)
	end
	-- Les textes flottants (MaxDistance) se basent sur le point visé par la caméra (Focus), qui suit normalement le
	-- personnage : on le place sur la cible, comme si le joueur s'y trouvait.
	local function look(from, at)
		camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(from, at)
		camera.Focus = CFrame.new(at)
	end
	local function restoreCamera()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
	-- Écrans du jeu cachés le temps d'une capture ; renvoie la fonction qui les remet.
	local function hideGuis()
		local hidden = {}
		for _, gui in player.PlayerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Enabled then
				gui.Enabled = false
				table.insert(hidden, gui)
			end
		end
		return function()
			for _, gui in hidden do
				gui.Enabled = true
			end
		end
	end
	local function finish()
		say("PHONE:done")
	end

	-- Le jeu est prêt (données du joueur chargées, son état publié).
	for _ = 1, 300 do
		if player:GetAttribute("LevelsState") ~= nil then
			break
		end
		task.wait(0.2)
	end
	task.wait(2)

	local modelsFolder = ReplicatedStorage:FindFirstChild("EnemyModels")
	check(modelsFolder ~= nil, "dossier ReplicatedStorage.EnemyModels présent (assets/EnemyModels via Rojo)")
	if not modelsFolder then
		modelsFolder = Instance.new("Folder")
		modelsFolder.Name = "EnemyModels"
		modelsFolder.Parent = ReplicatedStorage
	end
	-- Vrais modèles du projet (assets/EnemyModels, ex. le Roi carmin « Boss_0 ») : leur type les garde, les
	-- vérifications « blocs » ci-dessous en tiennent compte.
	local realModels = {}
	for _, child in modelsFolder:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			realModels[string.lower(child.Name)] = child.Name
		end
	end
	-- Nom du vrai modèle attendu pour ce type et ce palier (nil = blocs).
	local function realModelFor(enemyType, palier)
		return realModels[string.lower(`{enemyType}_{palier % 10}`)] or realModels[string.lower(enemyType)]
	end
	-- Vrais écuyers du projet (Swarm_0, Swarm_1...) : ils passeraient avant le modèle « Swarm » de test (nom
	-- exact du palier). Mis de côté pendant ses vérifications, remis dans le dossier pour celles des vrais
	-- modèles, puis à la fin.
	local realSwarms = {}
	for _, child in modelsFolder:GetChildren() do
		if (child:IsA("Model") or child:IsA("BasePart")) and string.match(string.lower(child.Name), "^swarm_?%d*$") then
			table.insert(realSwarms, child)
		end
	end
	local function hideRealSwarms(hidden)
		for _, model in realSwarms do
			model.Parent = if hidden then nil else modelsFolder
		end
		task.wait(0.1)
	end
	hideRealSwarms(true)
	local function scriptsIn(instance)
		local count = 0
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				count += 1
			end
		end
		return count
	end
	-- Modèle de test façon Toolbox : pièces ancrées et avec collision, soudées entre elles (WeldConstraint),
	-- 3 scripts (désactivés) dedans. Pièces de 2 studs empilées : 2 * partCount studs de haut.
	local function testModel(name, partCount)
		local model = Instance.new("Model")
		model.Name = name
		for i = 1, partCount do
			local part = Instance.new("Part")
			part.Name = "Piece" .. i
			part.Anchored = true
			part.Size = Vector3.new(2, 2, 2)
			part.Position = Vector3.new(0, 1 + (i - 1) * 2, 0)
			part.Color = Color3.fromRGB(80, 200, 90)
			part.Parent = model
			if i > 1 then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = model:FindFirstChild("Piece1")
				weld.Part1 = part
				weld.Parent = part
			end
		end
		model.PrimaryPart = model:FindFirstChild("Piece1")
		for _, className in { "Script", "LocalScript", "ModuleScript" } do
			local code = Instance.new(className)
			if code:IsA("BaseScript") then
				code.Enabled = false
			end
			code.Parent = model.PrimaryPart
		end
		return model
	end
	-- Modèle utilisé pour ce type et ce palier (nil = blocs), d'après une copie faite par le module.
	local function usedModel(enemyType, palier)
		local root = CustomModels.spawn(enemyType, Enemies.Defs[enemyType], palier)
		local name = root and root:GetAttribute("CustomModel")
		if root then
			root:Destroy()
		end
		return name
	end

	------------------------------------------------------------------
	-- 1) Module : modèle « Swarm » (2 pièces) posé pendant la partie.
	-- (task.wait après chaque changement du dossier : les événements peuvent arriver un peu après.)
	------------------------------------------------------------------
	local swarmModel = testModel("Swarm", 2)
	swarmModel.Parent = modelsFolder
	task.wait(0.1)
	local swarmDef = Enemies.Defs.Swarm
	local root, entry = CustomModels.spawn("Swarm", swarmDef, 0)
	check(root ~= nil and root:GetAttribute("CustomModel") == "Swarm", "écuyer (Swarm) : le modèle perso « Swarm » remplace les blocs")
	if root and entry then
		local parts, anchored, solid = 0, 0, 0
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
				anchored += if descendant.Anchored then 1 else 0
				solid += if descendant.CanCollide or descendant.CanQuery or descendant.CanTouch then 1 else 0
			end
		end
		check(
			scriptsIn(root) == 0 and scriptsIn(swarmModel) == 3,
			`scripts retirés de la copie ({scriptsIn(root)} restant ; l'original en garde {scriptsIn(swarmModel)})`
		)
		check(
			parts == 2 and anchored == 0 and solid == 0 and root.Anchored and root:FindFirstChildWhichIsA("WeldConstraint") ~= nil,
			`2 pièces non ancrées, sans collision, soudées à la racine ancrée ({parts} pièces, {anchored} ancrées, {solid} solides)`
		)
		local expected = CustomModels.targetHeight("Swarm", swarmDef)
		check(math.abs(entry.height - expected) < 0.05, `mis à l'échelle : {string.format("%.2f", entry.height)} studs de haut (attendu {string.format("%.2f", expected)}, 4 avant)`)
		root:Destroy()
	end
	-- Paliers : « Swarm_3 » passe avant « Swarm » aux niveaux 31-40 (et 131-140), pas ailleurs.
	local swarm3 = testModel("Swarm_3", 3)
	swarm3.Parent = modelsFolder
	task.wait(0.1)
	local at3, at13, at2 = usedModel("Swarm", 3), usedModel("Swarm", 13), usedModel("Swarm", 2)
	check(at3 == "Swarm_3" and at13 == "Swarm_3" and at2 == "Swarm", `Swarm_3 avant Swarm (palier 3 : {at3}, palier 13 : {at13}, palier 2 : {at2})`)
	swarm3:Destroy()
	task.wait(0.1)
	local after = usedModel("Swarm", 3)
	check(after == "Swarm", `Swarm_3 retiré pendant la partie : retour à « Swarm » (obtenu {after})`)
	-- Les autres types gardent leurs blocs (ou leur vrai modèle du projet).
	local wrong = {}
	for _, enemyType in Enemies.ORDER do
		if enemyType ~= "Swarm" and usedModel(enemyType, 0) ~= realModelFor(enemyType, 0) then
			table.insert(wrong, enemyType)
		end
	end
	check(#wrong == 0, `autres types : blocs, ou leur vrai modèle du projet ({if #wrong == 0 then "tous" else table.concat(wrong, ", ") .. " avec un autre modèle"})`)
	-- Le même modèle à deux tailles (les niveaux affichent les monstres plus gros : Levels.ENEMY_SCALE) : chacune a sa
	-- copie préparée, à sa hauteur.
	local bigDef = table.clone(swarmDef)
	bigDef.size = swarmDef.size * Levels.enemyScale("Swarm")
	local smallRoot, smallEntry = CustomModels.spawn("Swarm", swarmDef, 0)
	local bigRoot, bigEntry = CustomModels.spawn("Swarm", bigDef, 0)
	check(
		smallEntry ~= nil and bigEntry ~= nil and smallEntry ~= bigEntry
			and math.abs(bigEntry.height - CustomModels.targetHeight("Swarm", bigDef)) < 0.05
			and math.abs(smallEntry.height - CustomModels.targetHeight("Swarm", swarmDef)) < 0.05,
		`un modèle demandé à deux tailles : deux copies préparées ({if smallEntry then string.format("%.2f", smallEntry.height) else "?"} et {if bigEntry then string.format("%.2f", bigEntry.height) else "?"} studs de haut)`
	)
	if smallRoot then
		smallRoot:Destroy()
	end
	if bigRoot then
		bigRoot:Destroy()
	end

	-- Animations de marche et de mort : numéros écrits dans le code (CustomModels.SETTINGS) ou objets Animation
	-- du modèle (« Walking » / « Dead », les noms des exports Meshy). Animations de Roblox (marche et chute R15)
	-- pour le test : la mort doit se charger et se jouer.
	local WALK_TEST_ID, DEATH_TEST_ID = 507777826, 507767968
	-- (Swarm_5 et Swarm_6 peuvent aussi être de vrais écuyers, avec leurs réglages : ceux-ci sont mis de côté
	-- pendant le test puis remis, comme les modèles.)
	local realSettings5, realSettings6 = CustomModels.SETTINGS.swarm_5, CustomModels.SETTINGS.swarm_6
	CustomModels.SETTINGS.swarm_5 = { walk = WALK_TEST_ID, death = DEATH_TEST_ID }
	CustomModels.SETTINGS.swarm_6 = nil
	local swarm5 = testModel("Swarm_5", 2)
	swarm5.Parent = modelsFolder
	task.wait(0.1)
	local root5, entry5 = CustomModels.spawn("Swarm", swarmDef, 5)
	check(
		entry5 ~= nil
			and entry5.animation ~= nil
			and entry5.animation.AnimationId == `rbxassetid://{WALK_TEST_ID}`
			and entry5.deathAnimation ~= nil
			and entry5.deathAnimation.AnimationId == `rbxassetid://{DEATH_TEST_ID}`,
		"réglages du code (CustomModels.SETTINGS) : marche et mort de « Swarm_5 » lues"
	)
	if root5 and entry5 then
		root5.Parent = workspace
		local death = CustomModels.loadDeath(root5, entry5)
		local length = 0
		if death then
			death:Play()
			for _ = 1, 50 do
				length = death.Length
				if length > 0 then
					break
				end
				task.wait(0.1)
			end
			death:Stop(0)
			death:Destroy()
		end
		check(death ~= nil and length > 0, `animation de mort chargée et jouée (durée {string.format("%.2f", length)} s)`)
		root5:Destroy()
	end
	CustomModels.SETTINGS.swarm_5 = realSettings5
	swarm5:Destroy()
	local swarm6 = testModel("Swarm_6", 2)
	for name, id in { Walking = WALK_TEST_ID, Dead = DEATH_TEST_ID } do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = `rbxassetid://{id}`
		animation.Parent = swarm6
	end
	swarm6.Parent = modelsFolder
	task.wait(0.1)
	local root6, entry6 = CustomModels.spawn("Swarm", swarmDef, 6)
	check(
		entry6 ~= nil
			and entry6.animation ~= nil
			and entry6.animation.AnimationId == `rbxassetid://{WALK_TEST_ID}`
			and entry6.deathAnimation ~= nil
			and entry6.deathAnimation.AnimationId == `rbxassetid://{DEATH_TEST_ID}`,
		"objets Animation « Walking » et « Dead » du modèle reconnus (marche et mort)"
	)
	if root6 then
		root6:Destroy()
	end
	swarm6:Destroy()
	CustomModels.SETTINGS.swarm_6 = realSettings6
	hideRealSwarms(false)

	------------------------------------------------------------------
	-- 2) Vrais modèles du projet (assets/EnemyModels : Roi carmin « Boss_0 », troupes carmin...) : nom valable
	-- (<Type> ou <Type>_<palier>), à la bonne hauteur, tournés dans le sens de la marche (orteils, ou tête d'un
	-- cheval, vers -Z de la racine : CustomModels.frontDirection), leurs animations publiées
	-- (CustomModels.SETTINGS) se chargent.
	------------------------------------------------------------------
	local realCount = 0
	for lowerName, realName in realModels do
		realCount += 1
		local enemyType, palierText = string.match(realName, "^(%a+)_?(%d*)$")
		local def = enemyType and Enemies.Defs[enemyType]
		if not def then
			check(false, `vrai modèle « {realName} » : nom inconnu (attendu <Type> ou <Type>_<palier>, ex. Boss_0)`)
			continue
		end
		local palier = tonumber(palierText) or 0
		local realRoot, realEntry = CustomModels.spawn(enemyType, def, palier, CFrame.new(0, 200, 0))
		check(realRoot ~= nil and realEntry ~= nil and realRoot:GetAttribute("CustomModel") == realName, `« {realName} » : modèle perso utilisé ({enemyType}, palier {palier})`)
		if realRoot and realEntry then
			local settings = CustomModels.SETTINGS[lowerName]
			local expected = CustomModels.targetHeight(enemyType, def) * (if settings and settings.height then settings.height else 1)
			check(math.abs(realEntry.height - expected) < 0.1, `« {realName} » : {string.format("%.2f", realEntry.height)} studs de haut (attendu {string.format("%.2f", expected)})`)
			realRoot.Parent = workspace
			local front = CustomModels.frontDirection(realRoot)
			if front then
				local forward = -realRoot.CFrame:VectorToObjectSpace(front).Z
				check(forward > 0.9, `« {realName} » tourné dans le sens de la marche ({string.format("%.2f", forward)}, 1 = parfait)`)
			else
				say(`« {realName} » : pas d'os pour vérifier son sens de marche`)
			end
			local lengths, expectedTracks = {}, {}
			for label, pair in { marche = { CustomModels.loadWalk, realEntry.animation }, mort = { CustomModels.loadDeath, realEntry.deathAnimation } } do
				if not pair[2] then
					continue
				end
				table.insert(expectedTracks, label)
				local track = pair[1](realRoot, realEntry)
				local length = 0
				if track then
					track:Play()
					for _ = 1, 80 do
						length = track.Length
						if length > 0 then
							break
						end
						task.wait(0.1)
					end
					track:Stop(0)
					track:Destroy()
				end
				lengths[label] = length
			end
			local loaded = 0
			for _, label in expectedTracks do
				loaded += if lengths[label] > 0 then 1 else 0
			end
			check(
				loaded == #expectedTracks,
				`« {realName} » : animations chargées {loaded}/{#expectedTracks} (marche {string.format("%.2f", lengths.marche or 0)} s, mort {string.format("%.2f", lengths.mort or 0)} s)`
			)
			realRoot:Destroy()
		end
	end
	say(`vrais modèles du projet vérifiés : {realCount}`)

	-- Photos « walk_<modèle> » : chaque vrai modèle joue sa marche sur place (comme dans un niveau), vu de
	-- côté, avec une flèche rouge au sol dans son sens de déplacement (-Z de sa racine, comme PlotRenderer) :
	-- son visage doit regarder vers la pointe de la flèche. Et le sens mesuré par ses os pendant l'animation
	-- (orteils vers l'avant), en chiffres.
	do
		local restoreGuis = hideGuis()
		for _, realName in realModels do
			local enemyType, palierText = string.match(realName, "^(%a+)_?(%d*)$")
			local def = enemyType and Enemies.Defs[enemyType]
			if not def then
				continue
			end
			local origin = CFrame.new(40, 300, 40)
			local walker, walkerEntry = CustomModels.spawn(enemyType, def, tonumber(palierText) or 0, origin)
			if not (walker and walkerEntry and walkerEntry.animation) then
				if walker then
					walker:Destroy()
				end
				continue
			end
			walker.Parent = workspace
			local arrow = Instance.new("Part")
			arrow.Anchored = true
			arrow.CanCollide = false
			arrow.Material = Enum.Material.Neon
			arrow.Color = Color3.fromRGB(230, 40, 40)
			arrow.Size = Vector3.new(0.25, 0.25, def.size * 2)
			arrow.CFrame = origin * CFrame.new(0, -def.size / 2 + 0.15, -def.size * 1.5)
			arrow.Parent = workspace
			local tip = Instance.new("Part")
			tip.Shape = Enum.PartType.Ball
			tip.Anchored = true
			tip.CanCollide = false
			tip.Material = Enum.Material.Neon
			tip.Color = arrow.Color
			tip.Size = Vector3.one * 0.8
			tip.CFrame = origin * CFrame.new(0, -def.size / 2 + 0.15, -def.size * 2.5)
			tip.Parent = workspace
			local speed = def.speed * IdleConfig.ENEMY_SPEED_MULTIPLIER * IdleConfig.enemySpeedFactor(enemyType)
			local track = CustomModels.loadWalk(walker, walkerEntry)
			local forwardRaw, forwardFixed, earlyFlip, flip = nil, nil, nil, nil
			if track then
				-- Sens mesuré comme en jeu (CustomModels.measureFlip : à plusieurs moments du pas, jamais juste après
				-- Play, où les os sont encore au repos), remis à zéro pour le test. Sens affiché = moyenne sur
				-- plusieurs pas (à un moment du pas, les pieds peuvent pointer vers l'arrière).
				walkerEntry.flipWhenAnimated = nil
				walkerEntry.flipSamples = nil
				track:Play(0.2, 1, CustomModels.walkRate(walkerEntry, speed))
				earlyFlip = CustomModels.measureFlip(walker, walkerEntry, track)
				task.wait(0.5)
				local rawSum, rawCount = 0, 0
				local deadline = os.clock() + 4
				while flip == nil and os.clock() < deadline do
					task.wait()
					flip = CustomModels.measureFlip(walker, walkerEntry, track)
					local front = CustomModels.frontDirection(walker)
					if front then
						rawSum += -origin:VectorToObjectSpace(front).Z
						rawCount += 1
					end
				end
				forwardRaw = if rawCount > 0 then rawSum / rawCount else nil
				-- Comme PlotRenderer : si l'animation retourne ce modèle, sa racine fait un demi-tour.
				if flip then
					walker.CFrame = origin * CFrame.Angles(0, math.pi, 0)
				end
				task.wait(0.2)
				local fixedSum, fixedCount = 0, 0
				local stop = os.clock() + 1.2
				repeat
					task.wait()
					local front = CustomModels.frontDirection(walker)
					if front then
						fixedSum += -origin:VectorToObjectSpace(front).Z
						fixedCount += 1
					end
				until os.clock() >= stop
				forwardFixed = if fixedCount > 0 then fixedSum / fixedCount else nil
			end
			local function two(x)
				return if x then string.format("%.2f", x) else "?"
			end
			check(
				forwardFixed ~= nil and forwardFixed > 0.5,
				`« {realName} » marche vers l'avant, animation jouée (en moyenne {two(forwardRaw)} sans correction, {two(forwardFixed)} avec ; 1 = vers l'avant, -1 = à reculons ; retourné : {tostring(flip)})`
			)
			check(earlyFlip == nil, `« {realName} » : sens pas mesuré juste après le lancement de sa marche (obtenu {tostring(earlyFlip)}, attendu nil)`)
			local side = def.size * 2.2 + 3
			look(origin.Position + origin.RightVector * side + Vector3.new(0, def.size * 0.3, 0), origin.Position + Vector3.new(0, 0, -def.size * 0.5))
			shot("walk_" .. realName)
			if track then
				track:Stop(0)
				track:Destroy()
			end
			walker:Destroy()
			arrow:Destroy()
			tip:Destroy()
		end
		restoreGuis()
		restoreCamera()
	end
	hideRealSwarms(true)

	------------------------------------------------------------------
	-- 3) Galerie Studio construite avec le modèle de test : 10 écuyers « modèle perso », les 50 autres en blocs
	-- (sauf les cases des vrais modèles du projet, ex. le boss des niveaux 1-10 avec « Boss_0 »).
	------------------------------------------------------------------
	if not ReplicatedStorage:FindFirstChild("__AutoTestGallery") then
		local request = Instance.new("BoolValue")
		request.Name = "__AutoTestGallery"
		request.Parent = ReplicatedStorage
	end
	for _ = 1, 150 do
		if ReplicatedStorage:GetAttribute("GalleryReady") then
			break
		end
		task.wait(0.2)
	end
	local gallery = workspace:FindFirstChild("EnemyGallery (Studio)")
	check(gallery ~= nil and ReplicatedStorage:GetAttribute("GalleryReady") == true, "galerie des monstres construite")
	if gallery then
		local customSwarm, swarmTotal, customOther, otherTotal, galleryScripts = 0, 0, 0, 0, 0
		local plaques = { perso = 0, blocs = 0 }
		-- Cases des autres types qui doivent montrer un vrai modèle du projet (10 paliers dans la galerie).
		local expectedOther, unexpectedOther = 0, 0
		for _, enemyType in Enemies.ORDER do
			if enemyType ~= "Swarm" then
				for palier = 0, 9 do
					expectedOther += if realModelFor(enemyType, palier) then 1 else 0
				end
			end
		end
		-- Dans le Workspace : Piece1 juste sous le centre de la racine (le modèle suit sa racine) et Piece2
		-- toujours soudée au-dessus, à l'écart mis à l'échelle (hauteur visée / 2 pour 2 pièces).
		local expectedGap = CustomModels.targetHeight("Swarm", swarmDef) / 2
		local worstGap, worstOffset = 0, 0
		local signs = {}
		for _, child in gallery:GetChildren() do
			local enemyType = child:GetAttribute("EnemyType")
			if enemyType == "Swarm" then
				swarmTotal += 1
				customSwarm += if child:GetAttribute("CustomModel") == "Swarm" then 1 else 0
				galleryScripts += scriptsIn(child)
				local piece1, piece2 = child:FindFirstChild("Piece1", true), child:FindFirstChild("Piece2", true)
				if child:IsA("BasePart") and piece1 and piece2 then
					worstGap = math.max(worstGap, math.abs((piece2.Position - piece1.Position).Magnitude - expectedGap))
					local offset = child.CFrame:PointToObjectSpace(piece1.Position)
					worstOffset = math.max(worstOffset, Vector3.new(offset.X, 0, offset.Z).Magnitude)
				else
					worstGap = math.huge
				end
			elseif enemyType then
				otherTotal += 1
				local custom = child:GetAttribute("CustomModel")
				customOther += if custom ~= nil then 1 else 0
				unexpectedOther += if custom ~= nil and realModels[string.lower(custom)] == nil then 1 else 0
			elseif child.Name == "Plaque" then
				local label = child:FindFirstChildWhichIsA("TextLabel", true)
				local text = label and label.Text or ""
				if text:find("modèle perso") then
					plaques.perso += 1
				elseif text == "blocs" then
					plaques.blocs += 1
				end
			elseif child.Name == "Panneau" then
				local label = child:FindFirstChildWhichIsA("TextLabel", true)
				table.insert(signs, label and label.Text or "")
			end
		end
		check(
			swarmTotal > 0
				and customSwarm == swarmTotal
				and galleryScripts == 0
				and otherTotal > 0
				and customOther == expectedOther
				and unexpectedOther == 0,
			`galerie : écuyers avec le modèle perso {customSwarm}/{swarmTotal} (scripts {galleryScripts}), autres : {customOther} avec leur vrai modèle (attendu {expectedOther}), {otherTotal - customOther} en blocs`
		)
		check(
			plaques.perso == swarmTotal + expectedOther and plaques.blocs == otherTotal - expectedOther,
			`galerie : plaques « modèle perso » {plaques.perso} (attendu {swarmTotal + expectedOther}) et « blocs » {plaques.blocs} (attendu {otherTotal - expectedOther})`
		)
		check(
			swarmTotal > 0 and worstGap < 0.05 and worstOffset < 0.05,
			`galerie : modèle perso porté par sa racine, pièces soudées restées ensemble après la mise à l'échelle (écart {string.format("%.3f", worstGap)}, décalage {string.format("%.3f", worstOffset)} studs)`
		)
		table.sort(signs)
		check(
			#signs == 10 and string.find(signs[1] or "", "Niveaux 1-10 : Chevaliers carmin", 1, true) ~= nil
				and string.find(table.concat(signs, " | "), "Vagues", 1, true) == nil,
			`galerie : un panneau par territoire de 10 niveaux ({#signs} panneaux, le premier : « {tostring(signs[1])} »)`
		)
		local row = ReplicatedStorage:GetAttribute("GalleryRow1")
		local lookDirection = ReplicatedStorage:GetAttribute("GalleryLook")
		if typeof(row) == "Vector3" and typeof(lookDirection) == "Vector3" then
			-- Captures sans les écrans du jeu.
			local restoreGuis = hideGuis()
			look(row - lookDirection * 16 + Vector3.new(0, 9, 0), row)
			shot("gallery_custom_model")
			-- Le Roi carmin de près, de face (s'il est dans le projet).
			for _, child in gallery:GetChildren() do
				if child:IsA("BasePart") and child:GetAttribute("CustomModel") == "Boss_0" then
					look(child.Position - lookDirection * 13 + Vector3.new(0, 3, 0), child.Position + Vector3.new(0, 1, 0))
					shot("gallery_boss_0")
					break
				end
			end
			restoreGuis()
			restoreCamera()
		end
	end
	swarmModel:Destroy()
	hideRealSwarms(false) -- le niveau qui suit retrouve les vrais écuyers du projet (ou les blocs)
	task.wait(0.3)

	------------------------------------------------------------------
	-- 4) Un vrai niveau : chaque monstre affiché (PlotRenderer) est le vrai modèle de son type pour le 1er territoire
	-- (ou ses blocs), agrandi comme tous les monstres d'un niveau (Levels.ENEMY_SCALE).
	------------------------------------------------------------------
	local live = { count = 0, real = 0, bad = {}, wrongSize = 0 }
	local enemiesFolder = workspace:WaitForChild("PlotEnemies", 10)
	local liveConnection = nil
	if enemiesFolder then
		liveConnection = enemiesFolder.ChildAdded:Connect(function(child)
			task.wait() -- (ses attributs sont posés juste après sa création)
			local enemyType = child:GetAttribute("EnemyType")
			-- (les cibles de paille du camp ne sont pas des monstres)
			if not enemyType or child:FindFirstChild("StrawBody") then
				return
			end
			live.count += 1
			local custom = child:GetAttribute("CustomModel")
			local blocks = 0
			for _, piece in child:GetChildren() do
				blocks += if piece:IsA("BasePart") then 1 else 0
			end
			if custom ~= nil then
				live.real += 1
			end
			if custom ~= realModelFor(enemyType, 0) or (custom == nil and blocks == 0) then
				table.insert(live.bad, `{enemyType} : {tostring(custom)}`)
			end
			if child:IsA("BasePart") and math.abs(child.Size.X - Enemies.Defs[enemyType].size * Levels.enemyScale(enemyType)) > 0.05 then
				live.wrongSize += 1
			end
		end)
	end
	local levelAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LevelAction")
	levelAction:FireServer("Start", 1)
	local started = os.clock()
	while os.clock() - started < 25 and live.count < 6 do
		task.wait(0.5)
	end
	task.wait(1)
	shot("niveau")
	if liveConnection then
		liveConnection:Disconnect()
	end
	check(
		live.count >= 3 and #live.bad == 0 and live.wrongSize == 0,
		`niveau 1 : {live.count} monstres apparus, tous avec le vrai modèle de leur type ou leurs blocs (dont {live.real} vrais modèles ; à revoir : {table.concat(live.bad, ", ")}), agrandis comme prévu (taille fausse : {live.wrongSize})`
	)
	levelAction:FireServer("Quit")
	task.wait(1.5)

	finish()
end
