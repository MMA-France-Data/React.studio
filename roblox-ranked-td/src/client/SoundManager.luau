-- Sons du jeu, seulement chez ce joueur : aucun coût pour le serveur, rien n'est répliqué. Tous les réglages
-- (numéros des sons, volumes, limites) sont dans src/shared/Sounds.luau.
--
-- Sons 3D (tours, impacts, morts) : SoundManager.playAt(nom, position). Chaque son a quelques « voix » (un
-- Sound dans une Attachment de workspace.Terrain), créées une fois puis réutilisées : aucun objet créé à chaque
-- tir. Trop loin de la caméra (plus que sa « range ») : ignoré tout de suite. Les demandes d'une image sont
-- gardées, triées par distance à la caméra, et les plus proches jouent (update, à chaque image), avec 3 limites :
--   Sounds.MAX_COMBAT_SOUNDS sons 3D en même temps sur toute la map (sauf les sons « priority », la mort d'un
--     boss : ils passent toujours et ne comptent pas, sinon les flèches pourraient les étouffer),
--   maxAtOnce voix par son (au-delà, le nouveau est ignoré, on ne coupe pas celui qui joue),
--   un départ au plus tous les minInterval secondes par son (Vitesse x2 = 2 fois plus de tirs : ça tient).
-- Sons 2D (interface, ta parcelle) : SoundManager.play(nom), mêmes limites maxAtOnce et minInterval.
-- Boucle du rayon du Sorcier des arcanes : SoundManager.setLoop, seulement les Sounds.MAX_BEAM_LOOPS plus proches.
-- Musique en boucle (map principale ou match), avec fondu, en pause pendant la fenêtre « MATCH TROUVÉ ! ».
-- Bouton « SON » (tout / effets seuls / muet) : en haut, à gauche du compteur de pièces (sous le compteur sur un
-- écran de moins de ~1 140 px ; en match : sous ton panneau). Choix sauvegardé avec tes données (remote
-- « Settings », attribut « SoundMode » du joueur). « muet » coupe aussi les bruits de pas des personnages.
--
-- Qui déclenche quoi :
--   PlotRenderer : tirs et impacts des tours (paquet PlotShots), morts des ennemis, arrivée d'un boss ou d'un
--     colosse sur ta parcelle (PlotSync), pièces ramassées (CoinDrop), rayon du Sorcier ;
--   Effects : tirs des tours en match classé (TowerFired) ;
--   MachineUI : autel, forge et fanfare (tour légendaire, rune x50 / x100) ; ChallengeUI : récompense récupérée ;
--   ici : vague réussie / ratée et renaissance (attributs de ta parcelle), tour posée / améliorée / vendue,
--     emplacement débloqué, rune posée (dossier « Towers » de ta parcelle, seulement après une demande de
--     PlotUI : SoundManager.noteAction), « MATCH TROUVÉ ! » (attribut QueueState), fin du match (MatchResult),
--     tes tours en match (posée / améliorée / vendue, workspace.Towers), morts des ennemis en match, clic des
--     boutons, messages d'erreur (UI.onToast).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapLayout = require(Shared.MapLayout)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)
local UI = require(script.Parent.UI)

local SoundManager = {}

local SLOTS = Sounds.SLOTS
local DEFAULT_LENGTH = 1.5 -- durée comptée pour un son pas encore chargé (secondes)
local LOOP_CHECK_INTERVAL = 0.25 -- boucles des rayons : on choisit les plus proches 4 fois par seconde
local REQUEST_WINDOW = 4 -- une action demandée par PlotUI (poser, vendre...) attend la réponse du serveur au plus
local IMPACT_MARGIN = 20 -- la caméra bouge pendant le vol d'un projectile : un peu de marge (isAudible)
local LOCAL_CHOICE_HOLD = 3 -- après un clic sur « SON », on ignore l'ancien choix renvoyé par le serveur
local LEAK_DISTANCE = 6 -- match : un ennemi retiré à moins de ça du bout du chemin est arrivé à la base
-- Mort : son selon le type d'ennemi (les autres : EnemyDeath).
local DEATH_SOUNDS = { Boss = "BossDeath", Giant = "BigDeath", Tank = "BigDeath" }

local player = Players.LocalPlayer
local mode = "All" -- choix du bouton « SON » (Sounds.MODES)
local lastLocalChoice = -math.huge
local folder: Folder? = nil -- SoundService.SonsDuJeu : sons 2D, groupes de volume
local effectsGroup: SoundGroup? = nil
local musicGroup: SoundGroup? = nil
local pools = {} -- [nom] = { voices = { voix }, lastPlayed }, voix = { sound, attachment, busyUntil, stopAt }
local stopping = {} -- voix à couper à leur heure stopAt (réglage stopAfter)
local queue = {} -- demandes 3D de l'image : { slot, position, distance, volumeScale } (tables réutilisées)
local queueCount = 0
local sorted = {}
local loops = {} -- [clé] = { slot, parent, wanted, strength, distance, sound, playing }
local loopCandidates = {}
local loopClock = 0
local requests = {} -- ["Place:3"] = heure de la demande (noteAction)
local music: Sound? = nil
local musicStarted = false
local musicTween: Tween? = nil
local musicStopped = false -- fin du match : la musique ne reprend plus
local matchFoundOpen = false -- fenêtre « MATCH TROUVÉ ! » ouverte : musique en pause
local refreshButton: () -> () = function() end
local previewSound: Sound? = nil

-- Compteurs (panneau et tests Studio).
SoundManager.stats = { requested = 0, played = 0 }

----------------------------------------------------------------------
-- Voix
----------------------------------------------------------------------

local function ensureInit()
	if folder then
		return
	end
	local root = Instance.new("Folder")
	root.Name = "SonsDuJeu"
	effectsGroup = Instance.new("SoundGroup")
	effectsGroup.Name = "Effets"
	effectsGroup.Volume = if mode == "Mute" then 0 else 1
	effectsGroup.Parent = root
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Musique"
	musicGroup.Volume = 1
	musicGroup.Parent = root
	root.Parent = SoundService
	folder = root
end

local function newSound(name: string, def): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = Sounds.assetId(def.id)
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.pitch or 1
	sound.Looped = def.loop == true
	sound.SoundGroup = if def.music then musicGroup else effectsGroup
	if def.range then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = math.min(Sounds.ROLLOFF_MIN_DISTANCE, def.range)
		sound.RollOffMaxDistance = def.range
	end
	return sound
end

-- Son 3D : dans une Attachment de workspace.Terrain, déplacée à chaque départ (pas de pièce à bouger).
-- Son 2D : dans SoundService.SonsDuJeu (entendu pareil partout).
local function newVoice(name: string, def)
	ensureInit()
	local sound = newSound(name, def)
	local attachment = nil
	if def.range then
		attachment = Instance.new("Attachment")
		attachment.Name = "Son_" .. name
		sound.Parent = attachment
		attachment.Parent = workspace.Terrain
	else
		sound.Parent = folder
	end
	return { sound = sound, attachment = attachment, busyUntil = 0, stopAt = nil }
end

local function poolOf(name: string)
	local pool = pools[name]
	if not pool then
		pool = { voices = {}, lastPlayed = -math.huge }
		pools[name] = pool
	end
	return pool
end

-- Une voix libre de ce son (créée s'il en manque, jusqu'à maxAtOnce), sinon nil.
local function freeVoice(name: string, def, pool, now: number)
	for _, voice in pool.voices do
		if voice.busyUntil <= now then
			return voice
		end
	end
	if #pool.voices < (def.maxAtOnce or 1) then
		local voice = newVoice(name, def)
		table.insert(pool.voices, voice)
		return voice
	end
	return nil
end

local function startVoice(voice, def, position: Vector3?, now: number, volumeScale: number?)
	local sound = voice.sound
	if position and voice.attachment then
		voice.attachment.WorldPosition = position
	end
	-- Petite variation de hauteur : 50 flèches ne sonnent pas toutes pareil.
	local speed = (def.pitch or 1) * (1 + (math.random() * 2 - 1) * (def.variation or 0))
	sound.PlaybackSpeed = speed
	sound.Volume = def.volume * (volumeScale or 1)
	sound.TimePosition = 0
	sound:Play()
	local length = sound.TimeLength
	local duration = (if length > 0 then length else DEFAULT_LENGTH) / speed
	if def.stopAfter and def.stopAfter < duration then
		duration = def.stopAfter
		if not voice.stopAt then
			table.insert(stopping, voice)
		end
		voice.stopAt = now + duration
	end
	voice.busyUntil = now + duration
	SoundManager.stats.played += 1
end

-- Sons 3D en train de jouer (comptés dans Sounds.MAX_COMBAT_SOUNDS ; pas les boucles des rayons, ni les sons
-- « priority »).
local function activeCombat(now: number): number
	local active = 0
	for name, pool in pools do
		if SLOTS[name].range and not SLOTS[name].priority then
			for _, voice in pool.voices do
				if voice.busyUntil > now then
					active += 1
				end
			end
		end
	end
	return active
end

local function listener(): Vector3?
	local camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position
end

----------------------------------------------------------------------
-- Jouer un son
----------------------------------------------------------------------

-- Son 2D (interface, ta parcelle). Renvoie vrai s'il joue.
function SoundManager.play(name: string, volumeScale: number?): boolean
	local def = SLOTS[name]
	if mode == "Mute" or not def or def.music then
		return false
	end
	local now = os.clock()
	local pool = poolOf(name)
	if now - pool.lastPlayed < (def.minInterval or 0) then
		return false
	end
	local voice = freeVoice(name, def, pool, now)
	if not voice then
		return false
	end
	startVoice(voice, def, nil, now, volumeScale)
	pool.lastPlayed = now
	return true
end

-- Son 3D à une position du monde : gardé jusqu'à la fin de l'image (voir SoundManager.flush).
function SoundManager.playAt(name: string, position: Vector3, volumeScale: number?)
	local def = SLOTS[name]
	if mode == "Mute" or not def or not def.range then
		return
	end
	local eye = listener()
	if not eye then
		return
	end
	local distance = (position - eye).Magnitude
	if distance > def.range then
		return -- trop loin : on ne l'entendrait pas
	end
	local pool = pools[name]
	if pool and os.clock() - pool.lastPlayed < (def.minInterval or 0) then
		return
	end
	SoundManager.stats.requested += 1
	queueCount += 1
	local request = queue[queueCount]
	if not request then
		request = {}
		queue[queueCount] = request
	end
	request.slot = name
	request.position = position
	request.distance = distance
	request.volumeScale = volumeScale or 1
end

-- Vrai si un son 3D à cette position serait entendu (avant de programmer un impact avec task.delay).
function SoundManager.isAudible(name: string, position: Vector3): boolean
	local def = SLOTS[name]
	local eye = listener()
	return mode ~= "Mute" and def ~= nil and def.range ~= nil and eye ~= nil and (position - eye).Magnitude <= def.range + IMPACT_MARGIN
end

local function byDistance(a, b): boolean
	return a.distance < b.distance
end

-- Joue les demandes 3D de l'image : les plus proches d'abord, dans les limites. Renvoie combien ont démarré.
function SoundManager.flush(): number
	if queueCount == 0 then
		return 0
	end
	local now = os.clock()
	for i = 1, queueCount do
		sorted[i] = queue[i]
	end
	queueCount = 0
	if #sorted > 1 then
		table.sort(sorted, byDistance)
	end
	local active = activeCombat(now)
	local startedCount = 0
	for _, request in sorted do
		local def = SLOTS[request.slot]
		-- Limite atteinte : seuls les sons « priority » (mort d'un boss) passent encore.
		if active >= Sounds.MAX_COMBAT_SOUNDS and not def.priority then
			continue
		end
		local pool = poolOf(request.slot)
		if now - pool.lastPlayed >= (def.minInterval or 0) then
			local voice = freeVoice(request.slot, def, pool, now)
			if voice then
				startVoice(voice, def, request.position, now, request.volumeScale)
				pool.lastPlayed = now
				if not def.priority then
					active += 1
				end
				startedCount += 1
			end
		end
	end
	table.clear(sorted)
	return startedCount
end

----------------------------------------------------------------------
-- Boucles (rayon du Sorcier des arcanes)
----------------------------------------------------------------------

-- À appeler à chaque image pour chaque rayon (clé = la tour) : wanted = le rayon touche, parent = la pièce d'où
-- part le son, strength = 0 (rayon qui démarre) à 1 (au maximum : plus fort et plus aigu).
function SoundManager.setLoop(key: any, name: string, parent: BasePart?, wanted: boolean, strength: number?)
	local loop = loops[key]
	if not loop then
		if not wanted then
			return
		end
		loop = { slot = name, parent = nil, wanted = false, strength = 0, distance = 0, sound = nil, playing = false }
		loops[key] = loop
	end
	loop.wanted = wanted and parent ~= nil
	if parent then
		loop.parent = parent
	end
	loop.strength = math.clamp(strength or 0, 0, 1)
end

-- La tour a disparu : sa boucle aussi.
function SoundManager.removeLoop(key: any)
	local loop = loops[key]
	if loop then
		if loop.sound then
			loop.sound:Destroy()
		end
		loops[key] = nil
	end
end

local function stopLoop(loop)
	if loop.playing then
		loop.playing = false
		if loop.sound then
			loop.sound:Stop()
		end
	end
end

-- Les boucles voulues, à portée, les plus proches d'abord : Sounds.MAX_BEAM_LOOPS jouent, les autres se taisent.
local function updateLoops()
	local eye = listener()
	table.clear(loopCandidates)
	for _, loop in loops do
		local def = SLOTS[loop.slot]
		local parent = loop.parent
		local ok = mode ~= "Mute" and eye ~= nil and loop.wanted and def ~= nil and parent ~= nil and parent.Parent ~= nil
		if ok then
			loop.distance = (parent.Position - eye).Magnitude
			ok = loop.distance <= def.range
		end
		if ok then
			table.insert(loopCandidates, loop)
		else
			stopLoop(loop)
		end
	end
	if #loopCandidates > 1 then
		table.sort(loopCandidates, byDistance)
	end
	for index, loop in loopCandidates do
		if index > Sounds.MAX_BEAM_LOOPS then
			stopLoop(loop)
			continue
		end
		local def = SLOTS[loop.slot]
		if not loop.sound or loop.sound.Parent ~= loop.parent then
			if loop.sound then
				loop.sound:Destroy()
			end
			ensureInit()
			loop.sound = newSound(loop.slot, def)
			loop.sound.Parent = loop.parent
			loop.playing = false
		end
		loop.sound.Volume = def.volume * (0.6 + 0.4 * loop.strength)
		loop.sound.PlaybackSpeed = (def.pitch or 1) * (0.9 + 0.25 * loop.strength)
		if not loop.playing then
			loop.playing = true
			loop.sound:Play()
		end
	end
	table.clear(loopCandidates)
end

----------------------------------------------------------------------
-- Musique et bouton « SON »
----------------------------------------------------------------------

local function musicWanted(): boolean
	return mode == "All" and not matchFoundOpen and not musicStopped
end

-- Fondu vers le volume voulu (0 = pause à la fin du fondu).
local function refreshMusic()
	local sound = music
	if not sound then
		return
	end
	local def = SLOTS[sound.Name]
	local wanted = musicWanted()
	if musicTween then
		musicTween:Cancel()
		musicTween = nil
	end
	if wanted then
		if not musicStarted then
			musicStarted = true
			sound.Volume = 0
			sound:Play()
		elseif not sound.IsPlaying then
			sound:Resume()
		end
	elseif not sound.IsPlaying then
		return
	end
	local tween = TweenService:Create(sound, TweenInfo.new(Sounds.MUSIC_FADE_TIME), { Volume = if wanted then def.volume else 0 })
	musicTween = tween
	tween:Play()
	if not wanted then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and not musicWanted() then
				sound:Pause()
			end
		end)
	end
end

local function applyMode(newMode: string)
	if not table.find(Sounds.MODES, newMode) then
		return
	end
	mode = newMode
	if effectsGroup then
		effectsGroup.Volume = if mode == "Mute" then 0 else 1
	end
	if mode == "Mute" then
		for _, loop in loops do
			stopLoop(loop)
		end
	end
	refreshMusic()
	refreshButton()
end

-- Choix sauvegardé (attribut « SoundMode » publié par le serveur, PlayerData).
local function readSavedMode()
	local saved = player:GetAttribute("SoundMode")
	if typeof(saved) == "string" and saved ~= mode and os.clock() - lastLocalChoice > LOCAL_CHOICE_HOLD then
		applyMode(saved)
	end
end

-- Bouton « SON » : 2 lignes, comme le bouton Vitesse x2 (ShopUI). Carte principale : en haut, juste à gauche du
-- compteur de pièces (centré, 360 px ; le bouton Vitesse x2 est à sa droite), s'il tient à droite de la carte de
-- rang (LobbyUI : 260 px de large à 16 px du bord, donc un écran d'au moins ~1 140 px) ; sinon (petit portable,
-- tablette, téléphone), sous le compteur, pour ne pas couvrir la carte de rang. Match : sous ton panneau (en haut
-- à gauche).
local BUTTON_WIDTH = 96
local COUNTER_GAP = 188 -- du centre de l'écran au bord droit du bouton (moitié du compteur de 360 px + 8 px)
local RANK_CARD_RIGHT = 16 + 260 + 8 -- bord droit de la carte de rang (LobbyUI) + 8 px d'écart
local SEND_DELAY = 0.5 -- le choix part au serveur un peu après le dernier clic (voir createButton)
local sendPending = false
local function createButton(serverMode: string)
	local gui = UI.screen("SoundButton")
	local hub = serverMode ~= "Match"
	local button = UI.button({
		Name = "SoundButton",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 16, 0, 120),
		Size = UDim2.fromOffset(BUTTON_WIDTH, 44),
		BackgroundColor3 = UI.Colors.PanelLight,
		Text = "",
		Parent = gui,
	})
	if hub then
		local function place()
			local camera = workspace.CurrentCamera
			local width = if camera then camera.ViewportSize.X else 0
			-- Assez large : le bouton tient entre la carte de rang et le compteur (sinon il cacherait la carte).
			local fits = width / 2 - COUNTER_GAP - BUTTON_WIDTH >= RANK_CARD_RIGHT
			button.AnchorPoint = if fits then Vector2.new(1, 0) else Vector2.new(0.5, 0)
			button.Position = if fits then UDim2.new(0.5, -COUNTER_GAP, 0, 9) else UDim2.new(0.5, 0, 0, 56)
		end
		place()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
		end
	end
	UI.label({
		Size = UDim2.new(1, 0, 0, 19),
		Font = Enum.Font.GothamBlack,
		Text = "SON",
		MaxTextSize = 18,
		Parent = button,
	})
	local modeLabel = UI.label({
		Name = "ModeText",
		Position = UDim2.new(0, 0, 0, 20),
		Size = UDim2.new(1, 0, 0, 12),
		MaxTextSize = 11,
		Parent = button,
	})
	refreshButton = function()
		modeLabel.Text = Sounds.MODE_LABELS[mode] or ""
		button.BackgroundColor3 = if mode == "Mute" then UI.Colors.Error else UI.Colors.PanelLight
	end
	refreshButton()
	button.Activated:Connect(function()
		local index = table.find(Sounds.MODES, mode) or 1
		local nextMode = Sounds.MODES[index % #Sounds.MODES + 1]
		lastLocalChoice = os.clock()
		applyMode(nextMode)
		-- Sauvegarde : seulement le choix final, SEND_DELAY s après le 1er clic. Le serveur ignore 2 réglages à
		-- moins de 0,2 s d'écart : 2 clics rapides « tout » -> « muet » auraient sauvegardé « effets seuls ».
		if not sendPending then
			sendPending = true
			task.delay(SEND_DELAY, function()
				sendPending = false
				Remotes.get("Settings"):FireServer("SoundMode", mode)
			end)
		end
		UI.toast(`Son : {Sounds.MODE_LABELS[nextMode]}`, "Info")
	end)
end

----------------------------------------------------------------------
-- Ce que le client voit déjà passer (aucun message en plus du serveur)
----------------------------------------------------------------------

-- PlotUI note chaque demande (« Place », « Sell », « BuySpot », « ApplyBonus » + emplacement) : le son joue
-- quand le serveur l'a vraiment fait (tour arrivée, partie...), jamais pour les tours chargées à l'arrivée.
function SoundManager.noteAction(action: string, spot: any)
	requests[`{action}:{spot}`] = os.clock()
end

local function consume(action: string, spot: any): boolean
	local key = `{action}:{spot}`
	local at = requests[key]
	if at and os.clock() - at <= REQUEST_WINDOW then
		requests[key] = nil
		return true
	end
	return false
end

-- Ta parcelle : vague réussie / ratée, renaissance, emplacement débloqué, tours posées / améliorées / vendues.
local function watchOwnPlot()
	local plotIndex = player:GetAttribute("Plot")
	while typeof(plotIndex) ~= "number" do
		player:GetAttributeChangedSignal("Plot"):Wait()
		plotIndex = player:GetAttribute("Plot")
	end
	local plots = workspace:WaitForChild("Hub"):WaitForChild("Plots")
	local plot = plots:WaitForChild("Plot" .. plotIndex)

	local lastState = plot:GetAttribute("State")
	local runningWave = plot:GetAttribute("Wave")
	local lastRebirths = plot:GetAttribute("Rebirths")
	local lastRebirthAt = -math.huge
	plot:GetAttributeChangedSignal("Rebirths"):Connect(function()
		local rebirths = plot:GetAttribute("Rebirths")
		if typeof(rebirths) == "number" and typeof(lastRebirths) == "number" and rebirths > lastRebirths then
			lastRebirthAt = os.clock()
			SoundManager.play("Rebirth")
		end
		lastRebirths = rebirths
	end)
	-- Fin de vague (Running -> Intermission) : la vague a monté = réussie, sinon ratée (à la vague 1, une vague
	-- ratée reste à 1). Attributs lus un peu après : Wave peut arriver juste après State. Pas pendant une
	-- renaissance (elle a son propre son).
	plot:GetAttributeChangedSignal("State"):Connect(function()
		local state = plot:GetAttribute("State")
		if state == "Running" then
			runningWave = plot:GetAttribute("Wave")
		elseif state == "Intermission" and lastState == "Running" then
			local startWave = runningWave
			task.delay(0.25, function()
				if os.clock() - lastRebirthAt < 2 then
					return
				end
				local wave = plot:GetAttribute("Wave")
				if typeof(wave) == "number" and typeof(startWave) == "number" and wave > startWave then
					SoundManager.play("WaveCleared")
				else
					SoundManager.play("WaveFailed")
				end
			end)
		end
		lastState = state
	end)
	plot:GetAttributeChangedSignal("OwnedSpots"):Connect(function()
		for key in requests do
			local spot = string.match(key, "^BuySpot:(%d+)$")
			if spot and consume("BuySpot", spot) then
				SoundManager.play("SpotUnlocked")
				return
			end
		end
	end)

	-- (Le dossier « Towers » arrive quand tes données sont chargées : attente sans avertissement dans la Sortie.)
	local towers = plot:WaitForChild("Towers", 120)
	if not towers then
		return
	end
	local levels = {} -- [modèle] = niveau connu
	local function track(model: Instance)
		if not model:IsA("Model") or levels[model] ~= nil then
			return
		end
		levels[model] = model:GetAttribute("Level") or 1
		model:GetAttributeChangedSignal("Level"):Connect(function()
			local level = model:GetAttribute("Level")
			local before = levels[model]
			if typeof(level) == "number" and typeof(before) == "number" and level > before then
				SoundManager.play("TowerUpgraded")
			end
			levels[model] = level
		end)
		model:GetAttributeChangedSignal("Bonus"):Connect(function()
			if consume("ApplyBonus", model:GetAttribute("SpotIndex")) then
				SoundManager.play("RuneApplied")
			end
		end)
	end
	for _, model in towers:GetChildren() do
		track(model)
	end
	towers.ChildAdded:Connect(function(model)
		track(model)
		if consume("Place", model:GetAttribute("SpotIndex")) then
			SoundManager.play("TowerPlaced")
		end
	end)
	towers.ChildRemoved:Connect(function(model)
		levels[model] = nil
		if consume("Sell", model:GetAttribute("SpotIndex")) then
			SoundManager.play("TowerSold")
		end
	end)
end

-- Classé : « MATCH TROUVÉ ! » (QueueState passe à Pending) ; musique en pause tant que la fenêtre est ouverte.
local function watchQueue()
	local lastState = player:GetAttribute("QueueState")
	local function update()
		local state = player:GetAttribute("QueueState") or "Idle"
		if state == "Pending" and lastState ~= "Pending" then
			SoundManager.play("MatchFound")
		end
		local open = state == "Pending" or state == "Accepted" or state == "Found" or state == "Teleporting"
		if open ~= matchFoundOpen then
			matchFoundOpen = open
			refreshMusic()
		end
		lastState = state
	end
	player:GetAttributeChangedSignal("QueueState"):Connect(update)
end

-- Match classé : tes tours posées / améliorées / vendues (dossier workspace.Towers, attribut OwnerUserId : jamais
-- celles de l'adversaire ni du bot).
local function watchMatchTowers()
	local towers = workspace:WaitForChild("Towers")
	local levels = {} -- [modèle] = niveau connu (seulement tes tours)
	local function track(model: Instance, placed: boolean)
		if not model:IsA("Model") or levels[model] ~= nil or model:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		levels[model] = model:GetAttribute("Level") or 1
		if placed then
			SoundManager.play("TowerPlaced")
		end
		model:GetAttributeChangedSignal("Level"):Connect(function()
			local level = model:GetAttribute("Level")
			local before = levels[model]
			if typeof(level) == "number" and typeof(before) == "number" and level > before then
				SoundManager.play("TowerUpgraded")
			end
			if levels[model] ~= nil then
				levels[model] = level
			end
		end)
	end
	for _, model in towers:GetChildren() do
		track(model, false)
	end
	towers.ChildAdded:Connect(function(model)
		track(model, true)
	end)
	towers.ChildRemoved:Connect(function(model)
		if levels[model] ~= nil then
			levels[model] = nil
			SoundManager.play("TowerSold")
		end
	end)
end

-- Match classé : tes tours (juste au-dessus), morts des ennemis (pièce retirée loin de la base) et fin du match.
local function watchMatch()
	task.spawn(watchMatchTowers)
	Remotes.get("MatchResult").OnClientEvent:Connect(function(result)
		if typeof(result) ~= "table" then
			return
		end
		if result.outcome == "Win" then
			SoundManager.play("MatchVictory")
		elseif result.outcome == "Loss" then
			SoundManager.play("MatchDefeat")
		end
		musicStopped = true
		refreshMusic()
	end)
	task.spawn(function()
		local enemies = workspace:WaitForChild("Enemies")
		local localEnd = MapLayout.pointAt(MapLayout.PATH_LENGTH)
		enemies.ChildRemoved:Connect(function(part)
			if not part:IsA("BasePart") then
				return
			end
			local position = part.Position
			local lane = part:GetAttribute("Lane")
			if typeof(lane) == "number" then
				local base = MapLayout.toWorld(lane, localEnd)
				if Vector3.new(position.X - base.X, 0, position.Z - base.Z).Magnitude < LEAK_DISTANCE then
					return -- arrivé à la base, pas tué
				end
			end
			SoundManager.playAt(DEATH_SOUNDS[part.Name] or "EnemyDeath", position)
		end)
	end)
end

-- Clic sur les boutons : tous ceux qui s'éclairent au survol (AutoButtonColor), pas les voiles sombres des
-- fenêtres. Attribut « NoClickSound » = pas de clic (boutons « Jouer » du panneau Studio).
local function hookButtons()
	local playerGui = player:WaitForChild("PlayerGui")
	local hooked = setmetatable({}, { __mode = "k" })
	local function hook(instance: Instance)
		if not instance:IsA("GuiButton") or hooked[instance] then
			return
		end
		hooked[instance] = true
		instance.Activated:Connect(function()
			if instance.AutoButtonColor and not instance:GetAttribute("NoClickSound") then
				SoundManager.play("Click")
			end
		end)
	end
	playerGui.DescendantAdded:Connect(hook)
	for _, instance in playerGui:GetDescendants() do
		hook(instance)
	end
end

-- Bruits de pas, sauts... des personnages (sons de Roblox, créés chez chaque joueur par RbxCharacterSounds) :
-- rangés dans le groupe « Effets », donc coupés eux aussi par « muet » (inchangés sinon).
local function watchCharacterSounds()
	local function route(instance: Instance)
		if instance:IsA("Sound") and instance.SoundGroup == nil then
			instance.SoundGroup = effectsGroup
		end
	end
	local function watchCharacter(character: Model)
		character.DescendantAdded:Connect(route)
		for _, descendant in character:GetDescendants() do
			route(descendant)
		end
	end
	local function watchPlayer(other: Player)
		other.CharacterAdded:Connect(watchCharacter)
		if other.Character then
			watchCharacter(other.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
end

-- Charge les sons à l'avance (sinon le premier tir de chaque sorte serait muet le temps du téléchargement).
local function preload()
	local list = {}
	local temporary = {}
	for name, def in SLOTS do
		if def.music then
			continue
		end
		if def.loop then
			local sound = newSound(name, def)
			sound.Parent = folder
			table.insert(temporary, sound)
			table.insert(list, sound)
			continue
		end
		local pool = poolOf(name)
		if #pool.voices == 0 then
			table.insert(pool.voices, newVoice(name, def))
		end
		table.insert(list, pool.voices[1].sound)
	end
	if music then
		table.insert(list, music)
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
	for _, sound in temporary do
		sound:Destroy()
	end
end

----------------------------------------------------------------------
-- Démarrage (Main.client.luau, avant les autres modules)
----------------------------------------------------------------------

-- Prochain morceau de la liste (au hasard, jamais le même deux fois de suite).
local function nextTrack(playlist: { string }, current: string?): string?
	local choices = {}
	for _, name in playlist do
		if name ~= current and SLOTS[name] then
			table.insert(choices, name)
		end
	end
	if #choices == 0 then
		return current
	end
	return choices[math.random(1, #choices)]
end

-- serverMode = "Match" (serveur de match) ou autre (map principale).
function SoundManager.start(serverMode: string)
	ensureInit()
	-- Musique de ce serveur : les morceaux de Sounds.PLAYLISTS à la suite. Un Sound neuf par morceau, créé à la
	-- fin du précédent (son nom = celui du morceau : refreshMusic y lit le volume voulu). Changer le SoundId du
	-- même Sound à la fin d'un morceau ne relançait pas la lecture : silence après le premier morceau.
	local playlist = Sounds.PLAYLISTS[if serverMode == "Match" then "Match" else "Hub"] or {}
	local function useTrack(name: string): Sound
		local sound = newSound(name, SLOTS[name])
		sound.Looped = #playlist <= 1
		sound.Volume = 0
		sound.Parent = folder
		music = sound
		sound.Ended:Connect(function()
			if music ~= sound then
				return
			end
			local following = nextTrack(playlist, sound.Name)
			if not following or not SLOTS[following] then
				return
			end
			local nextSound = useTrack(following)
			sound:Destroy()
			if musicTween then
				musicTween:Cancel()
				musicTween = nil
			end
			if musicWanted() then
				-- Nouveau morceau : même fondu qu'au démarrage. Sinon (coupée, fenêtre « MATCH TROUVÉ ! ») :
				-- refreshMusic le lancera quand la musique sera de nouveau voulue.
				nextSound:Play()
				local tween = TweenService:Create(nextSound, TweenInfo.new(Sounds.MUSIC_FADE_TIME), { Volume = SLOTS[following].volume })
				musicTween = tween
				tween:Play()
			end
		end)
		return sound
	end
	local first = nextTrack(playlist, nil)
	if first and SLOTS[first] then
		useTrack(first)
	end
	createButton(serverMode)
	player:GetAttributeChangedSignal("SoundMode"):Connect(readSavedMode)
	-- La musique démarre quand le choix sauvegardé est connu (données chargées, 6 s au plus) : un joueur qui
	-- a coupé la musique ne l'entend pas démarrer.
	task.spawn(function()
		local deadline = os.clock() + 6
		while player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
			task.wait(0.2)
		end
		readSavedMode()
		refreshMusic()
	end)

	-- Messages d'erreur (UI.toast « Error », du client ou du serveur) : petit son « refusé ».
	UI.onToast = function(_message: string, kind: string?)
		if kind == "Error" then
			SoundManager.play("Error")
		end
	end
	task.spawn(hookButtons)
	watchCharacterSounds()
	if serverMode == "Match" then
		watchMatch()
	else
		task.spawn(watchOwnPlot)
		watchQueue()
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		-- Sons longs coupés à leur heure (réglage stopAfter).
		for i = #stopping, 1, -1 do
			local voice = stopping[i]
			if voice.stopAt and now >= voice.stopAt then
				voice.sound:Stop()
				voice.stopAt = nil
				table.remove(stopping, i)
			elseif not voice.stopAt then
				table.remove(stopping, i)
			end
		end
		SoundManager.flush()
		loopClock += dt
		if loopClock >= LOOP_CHECK_INTERVAL then
			loopClock = 0
			updateLoops()
		end
	end)
	task.spawn(preload)
end

----------------------------------------------------------------------
-- Studio : écoute depuis le panneau « SONS (Studio) » et test automatique
----------------------------------------------------------------------

-- Joue un son en 2D, quel que soit le bouton « SON » (panneau Studio). Les boucles s'arrêtent au bout de 4 s,
-- les musiques de 30 s. Renvoie le Sound (sa durée : TimeLength, une fois chargé).
function SoundManager.preview(name: string): Sound?
	local def = SLOTS[name]
	if not def then
		return nil
	end
	ensureInit()
	SoundManager.stopPreview()
	local sound = newSound(name, def)
	sound.SoundGroup = nil
	sound.Looped = false
	sound.RollOffMaxDistance = 10000
	sound.Parent = folder
	sound:Play()
	previewSound = sound
	local limit = if def.music then 30 elseif def.loop then 4 else def.stopAfter
	if limit then
		task.delay(limit, function()
			if previewSound == sound then
				sound:Stop()
			end
		end)
	end
	return sound
end

function SoundManager.stopPreview()
	if previewSound then
		previewSound:Destroy()
		previewSound = nil
	end
end

-- Test automatique (tools/studio-test) : `count` demandes 3D À LA MÊME IMAGE, tout près de la caméra, réparties
-- sur les sons `names` (pas de son « priority » : ils passent exprès au-delà de la limite), à tout petit volume,
-- puis une seule mise en file. Renvoie : combien ont démarré, la limite Sounds.MAX_COMBAT_SOUNDS et le nombre de
-- sons 3D qui jouent juste après.
function SoundManager.testBurst(names: { string }, count: number): (number, number, number)
	ensureInit()
	local eye = listener() or Vector3.zero
	local savedMode = mode
	mode = "All"
	for i = 1, count do
		local offset = Vector3.new(math.random() * 6 - 3, 0, math.random() * 6 - 3)
		SoundManager.playAt(names[(i - 1) % #names + 1], eye + offset, 0.05)
	end
	mode = savedMode
	local startedCount = SoundManager.flush()
	return startedCount, Sounds.MAX_COMBAT_SOUNDS, activeCombat(os.clock())
end

return SoundManager
