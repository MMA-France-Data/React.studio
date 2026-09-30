-- Scénario de test côté client (exécuté par le plugin AutoPlayTest, map principale et match).
-- « SHOT:nom » dans la sortie = run.ps1 prend une capture de Studio (out\nom.png).
-- Un plugin ne peut pas simuler de clic : on déplace la caméra, on affiche les fenêtres
-- directement et on envoie les actions par les vrais remotes.
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local mode = ReplicatedStorage:GetAttribute("ServerMode")

	local function say(message)
		log("Info", "[CTEST] " .. message)
	end
	local function shot(name)
		say("SHOT:" .. name)
		task.wait(1.2)
	end
	-- Les textes flottants (MaxDistance) se basent sur le point visé par la caméra (Focus), qui suit
	-- normalement le personnage : on le place sur la cible, comme si le joueur s'y trouvait.
	local function look(from, at)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(from, at)
		camera.Focus = CFrame.new(at)
	end
	local function restoreCamera()
		camera.CameraType = Enum.CameraType.Custom
	end
	-- Premier bouton visible dont le texte (ou celui d'un de ses textes) contient le motif.
	local function findButton(pattern)
		for _, gui in player.PlayerGui:GetDescendants() do
			if (gui:IsA("TextButton") or gui:IsA("TextLabel")) and gui.Visible and gui.Text:find(pattern) then
				local button = gui
				while button and not button:IsA("GuiButton") do
					button = button.Parent
				end
				if button then
					return button
				end
			end
		end
		return nil
	end

	if mode == "Match" then
		task.wait(8)
		-- Envois retirés : le HUD du match a sa boutique de tours mais aucun texte d'envoi.
		local function findText(pattern)
			for _, gui in player.PlayerGui:GetDescendants() do
				if (gui:IsA("TextButton") or gui:IsA("TextLabel")) and gui.Text:find(pattern) then
					return gui
				end
			end
			return nil
		end
		local hud = player.PlayerGui:FindFirstChild("Match")
		local shop, sends = findText("Archer"), findText("[Ee]nvo[iy]")
		local hudOk = hud ~= nil and shop ~= nil and sends == nil
		log(
			if hudOk then "Info" else "Error",
			`[{if hudOk then "PASS" else "FAIL"}] HUD du match sans panneau d'envois (HUD {hud ~= nil}, boutique {shop ~= nil}, texte d'envoi : {if sends then sends.Text else "aucun"})`
		)
		shot("match_player")
		look(Vector3.new(0, 140, 160), Vector3.new(0, 0, 0))
		shot("match_aerial")
		restoreCamera()
		task.wait(25)
		shot("match_fight")
		return
	end

	-- Map principale : vue du joueur, vue aérienne, centre, ma parcelle
	task.wait(3)

	----------------------------------------------------------------------
	-- Sons (src/shared/Sounds.luau, src/client/SoundManager.luau) : le bouton « SON » ne couvre pas la carte de rang,
	-- chaque son se charge dans Studio (numéro valide, son public et gratuit), puis la limite des sons de combat
	-- tient : 200 tirs à la même image n'en font jouer que Sounds.MAX_COMBAT_SOUNDS au plus, et un seul par son
	-- (minInterval). Tout petit volume.
	-- Lancé à part (task.spawn, fonction sans nom : limite des 200 variables locales) : il ne retarde pas les
	-- autres tests.
	----------------------------------------------------------------------
	task.spawn(function()
		-- Bouton « SON » (SoundManager) : à gauche du compteur de pièces ou juste dessous, jamais sur la carte de
		-- rang (LobbyUI : 260 x 130 px à 16 px du bord en haut à gauche).
		local soundGui = player.PlayerGui:FindFirstChild("SoundButton")
		local soundButton = soundGui and soundGui:FindFirstChild("SoundButton")
		if soundButton then
			local at, size = soundButton.AbsolutePosition, soundButton.AbsoluteSize
			local clear = at.X >= 16 + 260 or at.Y >= 16 + 130
			log(
				if clear then "Info" else "Error",
				`[{if clear then "PASS" else "FAIL"}] bouton « SON » sans couvrir la carte de rang (x {math.floor(at.X)}, y {math.floor(at.Y)}, {math.floor(size.X)} x {math.floor(size.Y)} px, écran {math.floor(camera.ViewportSize.X)} px)`
			)
		else
			log("Error", "[FAIL] bouton « SON » introuvable (PlayerGui.SoundButton)")
		end

		local ContentProvider = game:GetService("ContentProvider")
		local SoundService = game:GetService("SoundService")
		local Sounds = require(ReplicatedStorage.Shared.Sounds)
		local testFolder = Instance.new("Folder")
		testFolder.Name = "__TestSons"
		testFolder.Parent = SoundService
		local names, list, byName = {}, {}, {}
		for name, def in Sounds.SLOTS do
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = Sounds.assetId(def.id)
			sound.Volume = 0
			sound.Parent = testFolder
			byName[name] = sound
			table.insert(list, sound)
			table.insert(names, name)
		end
		table.sort(names)
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
		end)
		local deadline = os.clock() + 30
		local function allLoaded()
			for _, sound in list do
				if not (sound.IsLoaded and sound.TimeLength > 0) then
					return false
				end
			end
			return true
		end
		while os.clock() < deadline and not allLoaded() do
			task.wait(0.25)
		end
		local loaded = 0
		for _, name in names do
			local def, sound = Sounds.SLOTS[name], byName[name]
			local ok = sound.IsLoaded and sound.TimeLength > 0
			loaded += if ok then 1 else 0
			log(
				if ok then "Info" else "Error",
				`[{if ok then "PASS" else "FAIL"}] son « {def.name} » ({name}, id {def.id}) : {if ok then `chargé, {string.format("%.2f", sound.TimeLength)} s` else "ne se charge pas (numéro faux, son privé ou payant ?)"}`
			)
		end
		say(`sons chargés : {loaded}/{#names}`)
		testFolder:Destroy()

		-- Limite des sons de combat : 200 demandes à la même image, réparties sur tous les sons 3D (un seul départ
		-- par son, MAX_COMBAT_SOUNDS en tout au plus), puis 200 demandes d'un seul son (une seule voix démarre).
		local clientFolder = player:WaitForChild("PlayerScripts"):WaitForChild("Client", 10)
		local managerModule = clientFolder and clientFolder:FindFirstChild("SoundManager")
		if not managerModule then
			log("Error", "[FAIL] sons : module SoundManager introuvable (PlayerScripts.Client)")
			return
		end
		local SoundManager = require(managerModule)
		-- (Sans les sons « priority » : la mort d'un boss passe exprès au-delà de la limite.)
		local combat = {}
		for _, name in names do
			local def = Sounds.SLOTS[name]
			if def.range and not def.loop and not def.priority then
				table.insert(combat, name)
			end
		end
		local started, cap, active = SoundManager.testBurst(combat, 200)
		local capOk = started <= cap and active <= cap and (started >= 1 or active >= cap)
		log(
			if capOk then "Info" else "Error",
			`[{if capOk then "PASS" else "FAIL"}] sons : 200 tirs à la même image ({#combat} sons 3D) -> {started} démarrés, {active} en train de jouer (limite {cap})`
		)
		task.wait(6) -- les sons du test précédent sont finis
		local single = SoundManager.testBurst({ "ArcherShot" }, 200)
		log(
			if single <= 1 then "Info" else "Error",
			`[{if single <= 1 then "PASS" else "FAIL"}] sons : 200 flèches à la même image -> {single} son (1 au plus : un départ toutes les {Sounds.SLOTS.ArcherShot.minInterval} s)`
		)

		-- Musiques qui s'enchaînent (Sounds.PLAYLISTS.Hub) : on saute à 1 s de la fin du morceau en cours, un autre
		-- morceau de la liste doit démarrer tout seul (et avancer). Le Sound du jeu est cherché dans SoundService
		-- (dossier « SonsDuJeu » : le require du test n'a pas la même copie du module que Main.client).
		local function findMusic()
			for _, descendant in SoundService:GetDescendants() do
				if
					descendant:IsA("Sound")
					and descendant.Parent
					and descendant.Parent.Name == "SonsDuJeu"
					and table.find(Sounds.PLAYLISTS.Hub, descendant.Name)
				then
					return descendant
				end
			end
			return nil
		end
		local musicDeadline = os.clock() + 40
		local music = findMusic()
		while os.clock() < musicDeadline and not (music and music.IsPlaying and music.TimeLength > 0) do
			task.wait(0.25)
			music = music or findMusic()
		end
		if not music then
			log("Error", "[FAIL] musiques : pas de musique dans SoundService.SonsDuJeu")
			return
		end
		local before = music.Name
		if not (music.IsPlaying and music.TimeLength > 0) then
			log("Error", `[FAIL] musiques : « {before} » ne joue pas (bouton « SON » sur {player:GetAttribute("SoundMode") or "?"})`)
			return
		end
		-- (un Sound neuf par morceau : on cherche celui qui a pris la place)
		music.TimePosition = math.max(0, music.TimeLength - 1)
		musicDeadline = os.clock() + 30
		local current = music
		while os.clock() < musicDeadline do
			task.wait(0.25)
			current = findMusic()
			if current and current ~= music and current.IsPlaying and current.TimePosition > 0.5 then
				break
			end
		end
		local chained = current ~= nil
			and current ~= music
			and current.Name ~= before
			and table.find(Sounds.PLAYLISTS.Hub, current.Name) ~= nil
			and current.IsPlaying
			and current.TimePosition > 0.5
		log(
			if chained then "Info" else "Error",
			`[{if chained then "PASS" else "FAIL"}] musiques : fin de « {before} » -> « {if current then current.Name else "aucune"} » ({if current and current.IsPlaying then "joue" else "ne joue pas"}, {if current then string.format("%.1f", current.TimePosition) else "?"} s)`
		)
	end)

	shot("hub_player")
	-- HUD de la parcelle (PlotUI) : la vague, le record et les ennemis restants sont sur le tableau « CHRONIQUES DU
	-- FIEF » de la parcelle : plus de panneau de vague en haut de l'écran, seulement le compteur de pièces.
	do
		local plotGui = player.PlayerGui:FindFirstChild("Plot")
		local waveTexts, coinsLabel = {}, nil
		for _, gui in (if plotGui then plotGui:GetDescendants() else {}) do
			if gui:IsA("TextLabel") then
				local text = gui.Text
				if string.find(text, "^💰") then
					coinsLabel = gui
				elseif string.find(text, "^Vague %d") or string.find(text, "vague ratée") or string.find(text, "Ennemis restants") or string.find(text, "Prochaine vague") then
					table.insert(waveTexts, text)
				end
			end
		end
		local hudOk = plotGui ~= nil and coinsLabel ~= nil and coinsLabel.Visible and #waveTexts == 0
		log(
			if hudOk then "Info" else "Error",
			`[{if hudOk then "PASS" else "FAIL"}] HUD de la parcelle : compteur de pièces ({coinsLabel and coinsLabel.Text}), plus de panneau de vague ({#waveTexts} texte(s) de vague : {table.concat(waveTexts, " | ")})`
		)
	end
	look(Vector3.new(0, 230, 290), Vector3.new(0, 0, 0))
	shot("hub_aerial")
	look(Vector3.new(0, 25, 70), Vector3.new(0, 4, 0))
	shot("hub_center")
	local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
	local plotIndex = player:GetAttribute("Plot")
	if plotIndex then
		local cf = PlotLayout.cframe(plotIndex)
		task.wait(8) -- tours posées par le scénario serveur, vague en cours
		look(cf:PointToWorldSpace(Vector3.new(32, 26, -45)), cf:PointToWorldSpace(Vector3.new(0, 2, -18)))
		shot("hub_plot_fight")
		look(cf:PointToWorldSpace(Vector3.new(-10, 12, -2)), cf:PointToWorldSpace(Vector3.new(6, 3, -22)))
		shot("hub_towers_close")
		-- Le personnage s'approche des tours (caméra normale) : les étiquettes proches doivent apparaître.
		restoreCamera()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		-- Étiquettes « Niv. X » allumées (ProximityLabel) : aucune de loin, toutes de près.
		local function enabledLevelTags()
			local enabled, total = 0, 0
			for _, gui in workspace:GetDescendants() do
				if gui:IsA("BillboardGui") and gui.Name == "LevelTag" then
					total += 1
					enabled += if gui.Enabled then 1 else 0
				end
			end
			return enabled, total
		end
		if root then
			local home = root.CFrame
			root.CFrame = CFrame.new(cf:PointToWorldSpace(Vector3.new(-20, 4, -75))) -- loin des tours
			task.wait(0.8)
			local far, total = enabledLevelTags()
			log(if far == 0 then "Info" else "Error", `[{if far == 0 then "PASS" else "FAIL"}] loin des tours : {far}/{total} étiquettes affichées`)
			root.CFrame = CFrame.new(cf:PointToWorldSpace(Vector3.new(0, 4, -22))) -- au milieu des tours
			task.wait(0.8)
			local near = enabledLevelTags()
			log(if near == total and total > 0 then "Info" else "Error", `[{if near == total and total > 0 then "PASS" else "FAIL"}] près des tours : {near}/{total} étiquettes affichées`)
			shot("hub_near_towers")
			root.CFrame = home
		end
	end
	restoreCamera()
	task.wait(1)

	-- Renaissance (run à la vague 50 préparée par le scénario serveur)
	local rebirthButton = findButton("Renaissance")
	if rebirthButton then
		shot("hub_ui")
		local rebirthGui = player.PlayerGui:FindFirstChild("Rebirth")
		local overlay = rebirthGui and rebirthGui:FindFirstChildWhichIsA("TextButton")
		if overlay then
			overlay.Visible = true
			task.wait(0.8)
			shot("rebirth_window")
			overlay.Visible = false
		else
			log("Error", "[CTEST] fenêtre de renaissance introuvable")
		end
		ReplicatedStorage.Remotes.PlotAction:FireServer("Rebirth")
		task.wait(0.4)
		shot("rebirth_done")
	else
		log("Error", "[CTEST] bouton Renaissance introuvable")
	end

	-- Autel des héros (machine à tours) : fenêtre, puis un achat x10 et son résumé.
	-- (Ouverte par le plugin, via la commande « CMD:OpenMachine », comme son ProximityPrompt.)
	task.wait(1)
	say("CMD:OpenMachine:Tower")
	task.wait(1.5)
	shot("altar")
	ReplicatedStorage.Remotes.MachineAction:FireServer("SpinTower", 10)
	task.wait(3)
	shot("altar_x10")

	-- Défis classés : bouton « ⚔ DÉFIS » (colonne de gauche) et fenêtre (3 + 2 défis, bouton « X »), qui
	-- ne couvre ni le chat (en bas à gauche) ni la liste des joueurs (en haut à droite) sur un écran d'ordinateur.
	do
		-- L'autel est encore ouvert : son voile (plein écran) passerait par-dessus. (Les boutons de la colonne de
		-- gauche sont dans le même ScreenGui : on ne cache que le voile.)
		local machines = player.PlayerGui:FindFirstChild("Machines")
		for _, child in (if machines then machines:GetChildren() else {}) do
			if child:IsA("TextButton") and child.Size == UDim2.fromScale(1, 1) then
				child.Visible = false
			end
		end
		local challengesButton = findButton("DÉFIS")
		local challengesGui = player.PlayerGui:FindFirstChild("Challenges")
		local overlay = challengesGui and challengesGui:FindFirstChild("Overlay")
		local window = overlay and overlay:FindFirstChild("Window")
		local found = challengesButton ~= nil and window ~= nil
		log(if found then "Info" else "Error", `[{if found then "PASS" else "FAIL"}] bouton « DÉFIS » et fenêtre des défis présents`)
		if found then
			overlay.Visible = true
			task.wait(1)
			local claimButtons, closeFound = 0, false
			for _, descendant in window:GetDescendants() do
				if descendant:IsA("TextButton") then
					claimButtons += if descendant.Text == "Récupérer" then 1 else 0
					closeFound = closeFound or descendant.Text == "X"
				end
			end
			local rowsOk = claimButtons == 5 and closeFound
			log(if rowsOk then "Info" else "Error", `[{if rowsOk then "PASS" else "FAIL"}] fenêtre des défis : {claimButtons} lignes (attendu 5), bouton X {closeFound}`)
			local screen = challengesGui.AbsoluteSize
			if screen.X >= 1000 then
				local left, right = window.AbsolutePosition.X, window.AbsolutePosition.X + window.AbsoluteSize.X
				local top, bottom = window.AbsolutePosition.Y, window.AbsolutePosition.Y + window.AbsoluteSize.Y
				-- À droite du chat (500 px), et à gauche de la liste des joueurs (420 px de large) ou sous elle
				-- (310 px de haut) : réglages de ChallengeUI.luau.
				local placed = left >= 499 and (right <= screen.X - 419 or top >= 309) and bottom <= screen.Y + 1
				log(
					if placed then "Info" else "Error",
					`[{if placed then "PASS" else "FAIL"}] fenêtre des défis sans couvrir le chat ni la liste des joueurs (x de {math.floor(left)} à {math.floor(right)}, y de {math.floor(top)} à {math.floor(bottom)}, écran {math.floor(screen.X)} x {math.floor(screen.Y)})`
				)
			else
				say(`écran étroit ({math.floor(screen.X)} px) : fenêtre des défis seulement réduite`)
			end
			shot("challenges_panel")
			overlay.Visible = false
		end
	end

	----------------------------------------------------------------------
	-- Modèles perso des ennemis (ReplicatedStorage.EnemyModels, CustomModels.luau) : un modèle « Swarm »
	-- posé pendant la partie sert aux nouveaux écuyers, sans ses scripts (les vrais écuyers du projet sont mis
	-- de côté pendant ce temps) ; les autres types gardent leurs blocs ou leur vrai modèle du projet.
	-- Vérifié par le module (tous les cas), par la galerie Studio (construite avec) et par les
	-- ennemis des parcelles qui apparaissent pendant le test (PlotRenderer).
	----------------------------------------------------------------------
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] {message}`)
	end
	local Enemies = require(ReplicatedStorage.Shared.Enemies)
	local CustomModels = require(ReplicatedStorage.Shared.CustomModels)
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

	-- 1) Module : modèle « Swarm » (2 pièces) posé pendant la partie.
	-- (task.wait après chaque changement du dossier : les événements peuvent arriver un peu après.)
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
	-- Paliers : « Swarm_3 » passe avant « Swarm » aux vagues 31-40 (et 131-140), pas ailleurs.
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

	-- Animations de marche et de mort : numéros écrits dans le code (CustomModels.SETTINGS) ou objets Animation
	-- du modèle (« Walking » / « Dead », les noms des exports Meshy). Animations de Roblox (marche et chute R15)
	-- pour le test : la mort doit se charger et se jouer.
	local WALK_TEST_ID, DEATH_TEST_ID = 507777826, 507767968
	CustomModels.SETTINGS.swarm_5 = { walk = WALK_TEST_ID, death = DEATH_TEST_ID }
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
	CustomModels.SETTINGS.swarm_5 = nil
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
	hideRealSwarms(false)

	-- Vrais modèles du projet (assets/EnemyModels : Roi carmin « Boss_0 », troupes carmin...) : nom valable
	-- (<Type> ou <Type>_<palier>), à la bonne hauteur, tournés dans le sens de la marche (orteils, ou tête d'un
	-- cheval, vers -Z de la racine : CustomModels.frontDirection), leurs animations publiées
	-- (CustomModels.SETTINGS) se chargent.
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
		local root, entry = CustomModels.spawn(enemyType, def, palier, CFrame.new(0, 200, 0))
		check(root ~= nil and entry ~= nil and root:GetAttribute("CustomModel") == realName, `« {realName} » : modèle perso utilisé ({enemyType}, palier {palier})`)
		if root and entry then
			local settings = CustomModels.SETTINGS[lowerName]
			local expected = CustomModels.targetHeight(enemyType, def) * (if settings and settings.height then settings.height else 1)
			check(math.abs(entry.height - expected) < 0.1, `« {realName} » : {string.format("%.2f", entry.height)} studs de haut (attendu {string.format("%.2f", expected)})`)
			root.Parent = workspace
			local front = CustomModels.frontDirection(root)
			if front then
				local forward = -root.CFrame:VectorToObjectSpace(front).Z
				check(forward > 0.9, `« {realName} » tourné dans le sens de la marche ({string.format("%.2f", forward)}, 1 = parfait)`)
			else
				say(`« {realName} » : pas d'os pour vérifier son sens de marche`)
			end
			local lengths, expectedTracks = {}, {}
			for label, pair in { marche = { CustomModels.loadWalk, entry.animation }, mort = { CustomModels.loadDeath, entry.deathAnimation } } do
				if not pair[2] then
					continue
				end
				table.insert(expectedTracks, label)
				local track = pair[1](root, entry)
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
			root:Destroy()
		end
	end
	say(`vrais modèles du projet vérifiés : {realCount}`)

	-- Photos « walk_<modèle> » : chaque vrai modèle joue sa marche sur place (comme sur la parcelle), vu de
	-- côté, avec une flèche rouge au sol dans son sens de déplacement (-Z de sa racine, comme PlotRenderer) :
	-- son visage doit regarder vers la pointe de la flèche. Et le sens mesuré par ses os pendant l'animation
	-- (orteils vers l'avant), en chiffres.
	do
		local IdleConfig = require(ReplicatedStorage.Shared.IdleConfig)
		local hidden = {}
		for _, gui in player.PlayerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Enabled then
				gui.Enabled = false
				table.insert(hidden, gui)
			end
		end
		for _, realName in realModels do
			local enemyType, palierText = string.match(realName, "^(%a+)_?(%d*)$")
			local def = enemyType and Enemies.Defs[enemyType]
			if not def then
				continue
			end
			local origin = CFrame.new(40, 300, 40)
			local root, entry = CustomModels.spawn(enemyType, def, tonumber(palierText) or 0, origin)
			if not (root and entry and entry.animation) then
				if root then
					root:Destroy()
				end
				continue
			end
			root.Parent = workspace
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
			local track = CustomModels.loadWalk(root, entry)
			local forwardRaw, forwardFixed, earlyFlip, flip = nil, nil, nil, nil
			if track then
				-- Sens mesuré comme en jeu (CustomModels.measureFlip : à plusieurs moments du pas, jamais juste après
				-- Play, où les os sont encore au repos), remis à zéro pour le test. Sens affiché = moyenne sur
				-- plusieurs pas (à un moment du pas, les pieds peuvent pointer vers l'arrière).
				entry.flipWhenAnimated = nil
				entry.flipSamples = nil
				track:Play(0.2, 1, CustomModels.walkRate(entry, speed))
				earlyFlip = CustomModels.measureFlip(root, entry, track)
				task.wait(0.5)
				local rawSum, rawCount = 0, 0
				local deadline = os.clock() + 4
				while flip == nil and os.clock() < deadline do
					task.wait()
					flip = CustomModels.measureFlip(root, entry, track)
					local front = CustomModels.frontDirection(root)
					if front then
						rawSum += -origin:VectorToObjectSpace(front).Z
						rawCount += 1
					end
				end
				forwardRaw = if rawCount > 0 then rawSum / rawCount else nil
				-- Comme PlotRenderer : si l'animation retourne ce modèle, sa racine fait un demi-tour.
				if flip then
					root.CFrame = origin * CFrame.Angles(0, math.pi, 0)
				end
				task.wait(0.2)
				local fixedSum, fixedCount = 0, 0
				local stop = os.clock() + 1.2
				repeat
					task.wait()
					local front = CustomModels.frontDirection(root)
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
			root:Destroy()
			arrow:Destroy()
			tip:Destroy()
		end
		for _, gui in hidden do
			gui.Enabled = true
		end
		restoreCamera()
	end
	hideRealSwarms(true)

	-- 2) En jeu : les ennemis qui apparaissent sur les parcelles à partir de maintenant (PlotRenderer).
	local live = { swarm = 0, swarmBad = 0, other = 0, otherBad = 0 }
	local liveConnection = nil
	local enemiesFolder = workspace:FindFirstChild("PlotEnemies")
	if enemiesFolder then
		liveConnection = enemiesFolder.ChildAdded:Connect(function(child)
			local enemyType = child:GetAttribute("EnemyType")
			if enemyType == "Swarm" then
				live.swarm += 1
				if child:GetAttribute("CustomModel") ~= "Swarm" or scriptsIn(child) > 0 then
					live.swarmBad += 1
				end
			elseif enemyType then
				local blocks = 0
				for _, piece in child:GetChildren() do
					blocks += if piece:IsA("BasePart") then 1 else 0
				end
				live.other += 1
				-- Blocs, ou un vrai modèle du projet (ex. Normal_0 aux vagues 1-10) ; jamais un modèle de test.
				local custom = child:GetAttribute("CustomModel")
				if custom ~= nil then
					live.otherReal = (live.otherReal or 0) + 1
				end
				if (custom ~= nil and realModels[string.lower(custom)] == nil) or (custom == nil and blocks == 0) then
					live.otherBad += 1
				end
			end
		end)
	end
	local liveStart = os.clock()

	-- 3) Galerie Studio construite avec le modèle : 10 écuyers « modèle perso », les 50 autres en blocs (sauf
	-- les cases des vrais modèles du projet, ex. le boss des vagues 1-10 avec « Boss_0 »).
	if not ReplicatedStorage:FindFirstChild("__AutoTestGallery") then
		local request = Instance.new("BoolValue")
		request.Name = "__AutoTestGallery"
		request.Parent = ReplicatedStorage
	end
	for _ = 1, 100 do
		if ReplicatedStorage:GetAttribute("GalleryReady") then
			break
		end
		task.wait(0.2)
	end
	local gallery = workspace:FindFirstChild("EnemyGallery (Studio)")
	check(gallery ~= nil and ReplicatedStorage:GetAttribute("GalleryReady") == true, "galerie des ennemis construite")
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
		local row = ReplicatedStorage:GetAttribute("GalleryRow1")
		local lookDirection = ReplicatedStorage:GetAttribute("GalleryLook")
		if typeof(row) == "Vector3" and typeof(lookDirection) == "Vector3" then
			-- Captures sans les fenêtres du jeu (les autres tests en ouvrent pendant ce temps).
			local hidden = {}
			for _, gui in player.PlayerGui:GetChildren() do
				if gui:IsA("ScreenGui") and gui.Enabled then
					gui.Enabled = false
					table.insert(hidden, gui)
				end
			end
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
			for _, gui in hidden do
				gui.Enabled = true
			end
			restoreCamera()
		end
	end

	-- Fin de l'observation des parcelles : au plus 30 s après la pose du modèle, moins si des ennemis d'autres
	-- types sont déjà apparus (les vagues du test n'ont pas forcément d'écuyers).
	while os.clock() - liveStart < 30 and live.other < 3 do
		task.wait(0.5)
	end
	if liveConnection then
		liveConnection:Disconnect()
	end
	if live.swarm > 0 then
		check(live.swarmBad == 0, `parcelles : nouveaux écuyers avec le modèle perso {live.swarm - live.swarmBad}/{live.swarm}`)
	else
		say("parcelles : aucun écuyer apparu pendant le test (pas de Levée) : modèle vérifié par le module et la galerie")
	end
	if live.other > 0 then
		check(
			live.otherBad == 0,
			`parcelles : nouveaux ennemis des autres types en blocs ou avec leur vrai modèle {live.other - live.otherBad}/{live.other} (dont {live.otherReal or 0} vrais modèles)`
		)
	else
		say("parcelles : aucun nouvel ennemi d'un autre type pendant le test")
	end
	swarmModel:Destroy()
	hideRealSwarms(false) -- le reste de la partie retrouve les vrais écuyers du projet (ou les blocs)

	----------------------------------------------------------------------
	-- Classé : bouton « ⚔ S'INSCRIRE AU CLASSÉ » seulement dans le cercle de l'arène, statut de la recherche (en
	-- bas à droite, au-dessus du panneau des tours s'il est ouvert) et fenêtre « MATCH TROUVÉ ! ». Le scénario
	-- serveur joue un adversaire factice (file en mémoire dans Studio, pas de téléportation) : il donne la main
	-- au client avec l'attribut AutoTestRanked de ReplicatedStorage (« Client »), puis attend son inscription
	-- et son ACCEPTER, envoyés par les vrais remotes (comme les boutons : un plugin ne peut pas cliquer).
	-- Dans sa propre fonction (limite des 200 variables locales de Luau).
	----------------------------------------------------------------------
	local function testRanked()
		local function waitFor(condition, timeout)
			local deadline = os.clock() + timeout
			while os.clock() < deadline do
				if condition() then
					return true
				end
				task.wait(0.1)
			end
			return condition() == true
		end
		-- Vraiment à l'écran : lui et tous ses parents visibles, dans un ScreenGui allumé.
		local function shown(object)
			local current = object
			while current and not current:IsA("ScreenGui") do
				if current:IsA("GuiObject") and not current.Visible then
					return false
				end
				current = current.Parent
			end
			return current ~= nil and current.Enabled
		end
		local function queueState()
			return player:GetAttribute("QueueState") or "Idle"
		end
		local function inCircle(value)
			return player:GetAttribute("InRankedCircle") == value
		end
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		local signUpButton = lobby and lobby:FindFirstChild("SignUpButton", true)
		local status = lobby and lobby:FindFirstChild("QueueStatus", true)
		local statusText = status and status:FindFirstChild("StatusText")
		local cancelButton = status and status:FindFirstChild("CancelButton")
		local acceptGui = player.PlayerGui:FindFirstChild("RankedAccept")
		local window = acceptGui and acceptGui:FindFirstChild("Window", true)
		local found = signUpButton ~= nil and statusText ~= nil and cancelButton ~= nil and window ~= nil
		check(found, "classé : bouton « S'INSCRIRE », statut de la recherche et fenêtre « MATCH TROUVÉ ! » présents")
		local turn = waitFor(function()
			return ReplicatedStorage:GetAttribute("AutoTestRanked") == "Client"
		end, 120)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (found and turn and root) then
			check(false, `classé : test du client impossible (main donnée par le serveur : {turn}, personnage : {root ~= nil})`)
			return
		end
		restoreCamera()
		local home = root.CFrame
		local circle = PlotLayout.RANKED_CIRCLE_POSITION
		local inside = CFrame.new(circle + Vector3.new(0, 3, 0))
		local outside = CFrame.new(circle + Vector3.new(0, 3, PlotLayout.RANKED_CIRCLE_RADIUS + 12))

		-- Hors du cercle : pas de bouton. Dans le cercle : le bouton apparaît. Ressorti : il disparaît.
		root.CFrame = outside
		local outOk = waitFor(function()
			return inCircle(false)
		end, 3)
		check(outOk and not shown(signUpButton), `classé : hors du cercle, pas de bouton « S'INSCRIRE » (InRankedCircle = {player:GetAttribute("InRankedCircle")})`)
		root.CFrame = inside
		local inOk = waitFor(function()
			return inCircle(true) and shown(signUpButton)
		end, 3)
		check(
			inOk and string.find(signUpButton.Text, "S'INSCRIRE AU CLASSÉ", 1, true) ~= nil,
			`classé : dans le cercle, bouton « {signUpButton.Text} » affiché`
		)
		-- Ni sur la carte de rang et la colonne de gauche (x < 276), ni sur le panneau des tours (en bas à droite,
		-- ~316 px de haut), ni sur le chat (en bas à gauche, moins haut que le panneau des tours).
		local screen = lobby.AbsoluteSize
		if screen.X >= 1000 then
			local left, top = signUpButton.AbsolutePosition.X, signUpButton.AbsolutePosition.Y
			local bottom = top + signUpButton.AbsoluteSize.Y
			local placed = left >= 276 and bottom <= screen.Y - 316
			check(
				placed,
				`classé : bouton « S'INSCRIRE » sans couvrir la colonne de gauche, le chat ni le panneau des tours (x {math.floor(left)}, y de {math.floor(top)} à {math.floor(bottom)}, écran {math.floor(screen.X)} x {math.floor(screen.Y)})`
			)
		end
		shot("ranked_signup")
		root.CFrame = outside
		check(
			waitFor(function()
				return inCircle(false) and not shown(signUpButton)
			end, 3),
			"classé : ressorti du cercle, le bouton disparaît"
		)

		-- Inscription dans le cercle (vrai remote, comme le bouton) : statut « Recherche d'un adversaire… » + ANNULER.
		root.CFrame = inside
		waitFor(function()
			return inCircle(true)
		end, 3)
		ReplicatedStorage.Remotes.QueueAction:FireServer("Join")
		local searching = waitFor(function()
			return queueState() == "Searching" and shown(status)
		end, 5)
		task.wait(0.3)
		check(
			searching
				and string.find(statusText.Text, "Recherche d'un adversaire", 1, true) ~= nil
				and shown(cancelButton)
				and cancelButton.Text == "ANNULER"
				and not shown(signUpButton),
			`classé : inscrit -> « {statusText.Text} » et ANNULER en bas à droite, plus de bouton « S'INSCRIRE »`
		)
		shot("ranked_searching")
		-- Panneau des tours ouvert (PlotUI, en bas à droite) : le statut monte juste au-dessus.
		local plotGui = player.PlayerGui:FindFirstChild("Plot")
		local towerPanel = plotGui and plotGui:FindFirstChild("TowerPanel")
		if towerPanel then
			local wasVisible = towerPanel.Visible
			towerPanel.Visible = true
			task.wait(0.4)
			local statusBottom = status.AbsolutePosition.Y + status.AbsoluteSize.Y
			local panelTop = towerPanel.AbsolutePosition.Y
			check(
				statusBottom <= panelTop + 1,
				`classé : panneau des tours ouvert -> le statut passe au-dessus (bas du statut {math.floor(statusBottom)}, haut du panneau {math.floor(panelTop)})`
			)
			towerPanel.Visible = wasVisible
		else
			check(false, "classé : panneau des tours (PlotUI « TowerPanel ») introuvable")
		end

		-- Il repart jouer, toujours inscrit : le serveur fait s'inscrire un adversaire -> « MATCH TROUVÉ ! ».
		root.CFrame = home
		local pending = waitFor(function()
			return queueState() == "Pending" and shown(window)
		end, 20)
		task.wait(0.3)
		local title = window:FindFirstChild("Title")
		local opponent = window:FindFirstChild("Opponent")
		local acceptButton = window:FindFirstChild("AcceptButton")
		local refuseButton = window:FindFirstChild("RefuseButton")
		local timer = window:FindFirstChild("Timer")
		local waiting = window:FindFirstChild("Waiting")
		local opponentName = player:GetAttribute("MatchOpponent")
		check(
			pending
				and title and string.find(title.Text, "MATCH TROUVÉ", 1, true) ~= nil
				and typeof(opponentName) == "string" and opponent and string.find(opponent.Text, opponentName, 1, true) ~= nil
				and acceptButton and shown(acceptButton) and acceptButton.Text == "ACCEPTER"
				and refuseButton and shown(refuseButton) and refuseButton.Text == "REFUSER"
				and timer and shown(timer),
			`classé : fenêtre « {title and title.Text} » : « {opponent and opponent.Text} », barre du temps, ACCEPTER et REFUSER`
		)
		shot("ranked_accept")
		ReplicatedStorage.Remotes.QueueAction:FireServer("Accept")
		local waitingOk = waitFor(function()
			return queueState() == "Accepted" and waiting ~= nil and shown(waiting)
				and string.find(waiting.Text, "En attente de l'adversaire", 1, true) ~= nil
		end, 5)
		check(
			waitingOk and not shown(acceptButton) and not shown(refuseButton),
			`classé : ACCEPTER -> « {waiting and waiting.Text} », plus de boutons`
		)

		-- L'adversaire accepte : le match partirait (Studio : pas de téléportation), fenêtre et statut se ferment.
		local closed = waitFor(function()
			return queueState() == "Idle" and not shown(window) and not shown(status)
		end, 15)
		check(closed, `classé : les deux ont accepté -> fenêtre et statut fermés, plus inscrit ({queueState()})`)
	end
	testRanked()
end
