-- La PARCELLE d'un joueur est son CAMP D'ENTRAÎNEMENT (demande du propriétaire, 02/10/2026 : « tu peux gérer toute
-- la parcelle et le système d'évolution de tour ») :
--   * trois SOCLES d'entraînement (PlotLayout.SPOTS). Sur chacun : la tour qu'il y a mise (Hub/CampGame.luau : elle
--     tire sur des cibles roulantes), une étiquette (nom, étoiles d'évolution, niveau d'entraînement, barre d'XP,
--     XP par minute) et une invite « Gérer » qui ouvre l'onglet Entraînement de sa fenêtre (LevelsUI lit l'attribut
--     CampSlot de l'invite) ;
--   * devant l'entrée, la BOUTIQUE DES TOURS et la PORTE DES NIVEAUX (construites par Hub/HubMap.luau) : leur invite
--     ouvre l'onglet de ce nom (attribut CampTab) ;
--   * le tableau du fond affiche le camp (Hub/PlotBoard.luau lit les attributs Camp... de la parcelle).
-- Rien n'est sauvegardé ici : tout vient de data.levels (Hub/LevelsService.luau), relu à chaque changement
-- (Camp.refresh). Quand le joueur part, la parcelle redevient libre.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IdleTowers = require(Shared.IdleTowers)
local Levels = require(Shared.Levels)
local NumberFormat = require(Shared.NumberFormat)
local ProximityLabel = require(Shared.ProximityLabel)
local CampGame = require(script.Parent.CampGame)
local HubMap = require(script.Parent.HubMap)
local IdleTowerModel = require(script.Parent.IdleTowerModel)

local Camp = {}

-- [Player] = son CampGame. Hub/init.luau les fait avancer et envoie leurs paquets (cibles, tirs) au joueur et à ceux
-- qui s'approchent de sa parcelle.
Camp.games = {}

local LABEL_DISTANCE = Config.LabelDistance.Medium + 20 -- lisible depuis le point d'arrivée du joueur
local LABEL_HEIGHT = 11.5 -- studs au-dessus du socle (la plus haute tour, le Trébuchet, fait ~10 studs)
local LABEL_HEIGHT_EMPTY = 4
local OPEN_COLOR, LOCKED_COLOR = Color3.fromRGB(132, 124, 106), Color3.fromRGB(49, 47, 43)
local GOLD, IVORY, MUTED = Color3.fromRGB(255, 217, 61), Color3.new(1, 1, 1), Color3.fromRGB(220, 229, 244)
local INK = Color3.fromRGB(10, 12, 21)

-- Les vignettes de la boutique montrent les VRAIES tours, sans images à publier. Huit modèles statiques,
-- créés une fois, hors du Workspace : aucun tir, cible, évolution, invite ou effet de gameplay.
local function preparePreviews()
	if ReplicatedStorage:FindFirstChild("CampTowerPreviews") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CampTowerPreviews"
	for _, towerType in IdleTowers.ORDER do
		local model = IdleTowerModel.create(towerType, CFrame.new(), folder, {})
		local parts = 0
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") then
				parts += 1
				child.CanCollide = false
				child.CanTouch = false
				child.CanQuery = false
			end
		end
		model:SetAttribute("PreviewPartCount", parts)
	end
	folder.Parent = ReplicatedStorage
end

local dressings = {} -- [Player] = { plot, slots = { [i] = { pad, gui, title, sub, bar, fill, xp, prompt } }, signature }

local function text(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = parent
	return label
end

-- Étiquette et invite d'un socle d'entraînement.
local function dressPad(pad: BasePart, slotIndex: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CampLabel"
	-- Taille en studs (pas en pixels) : de loin les étiquettes de deux socles voisins (9 studs) ne se recouvrent pas ;
	-- de très près, elle ne grossit plus (DistanceLowerLimit).
	gui.Size = UDim2.fromScale(8.4, 2.7)
	gui.DistanceLowerLimit = 18
	gui.AlwaysOnTop = true
	ProximityLabel.register(gui, LABEL_DISTANCE)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(35, 38, 53)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = panel
	local edge = Instance.new("UIStroke")
	edge.Color = INK
	edge.Thickness = 3
	edge.Parent = panel
	local header = Instance.new("Frame")
	header.Name = "HeaderBand"
	header.Size = UDim2.fromScale(1, 0.4)
	header.BackgroundColor3 = Color3.fromRGB(0, 176, 255)
	header.BorderSizePixel = 0
	header.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(134, 164, 213))
	gradient.Rotation = 90
	gradient.Parent = header
	local title = text(panel, "Title", UDim2.fromScale(0.03, 0.025), UDim2.fromScale(0.94, 0.36), IVORY, Enum.Font.FredokaOne)
	local sub = text(panel, "Sub", UDim2.fromScale(0.03, 0.43), UDim2.fromScale(0.94, 0.24), MUTED, Enum.Font.BuilderSansBold)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.04, 0.7)
	bar.Size = UDim2.fromScale(0.92, 0.22)
	bar.BackgroundColor3 = INK
	bar.BorderSizePixel = 0
	bar.Parent = panel
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(91, 224, 26)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local xp = text(bar, "Xp", UDim2.new(), UDim2.fromScale(1, 1), IVORY, Enum.Font.FredokaOne)
	xp.ZIndex = 2
	gui.Parent = pad

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CampPrompt"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CampSlot", slotIndex)
	prompt.Parent = pad
	return { pad = pad, gui = gui, panel = panel, title = title, sub = sub, bar = bar, fill = fill, xp = xp, prompt = prompt }
end

local function setLabelHeight(entry, height: number)
	-- StudsOffsetWorldSpace suit l'orientation du socle (un cylindre couché) : on lui donne la verticale du monde
	-- dans son repère.
	entry.gui.StudsOffsetWorldSpace = entry.pad.CFrame:VectorToObjectSpace(Vector3.new(0, height, 0))
end

local function decimal(value: number): string
	local rounded = math.floor(value * 10 + 0.5) / 10
	return (string.gsub(tostring(rounded), "%.", ","))
end

-- Remet tout d'accord avec les données du joueur (emplacements, XP, pièces) : tours posées, étiquettes, invites,
-- tableau. Appelé à chaque publication de son état (Hub/LevelsService.luau) ; ne fait rien si rien n'a changé.
function Camp.refresh(player: Player, levels)
	local game = Camp.games[player]
	local dressing = dressings[player]
	if not game or not dressing or not levels then
		return
	end
	local parts = { tostring(levels.best), tostring(levels.coins), tostring(#levels.slots) }
	for index, slot in levels.slots do
		table.insert(parts, `{index}:{slot.tower}:{slot.level}:{math.floor((levels.xp[slot.tower] or 0) * 10 + 0.5)}`)
	end
	local owned = 0
	for _ in levels.towers do
		owned += 1
	end
	table.insert(parts, tostring(owned))
	local signature = table.concat(parts, "|")
	if signature == dressing.signature then
		return
	end
	dressing.signature = signature

	game:refresh(levels)
	local training = Levels.trainingLevels(levels)
	local summary = {}
	for slotIndex, entry in dressing.slots do
		local slot = levels.slots[slotIndex]
		local pad = entry.pad
		local isNext = slotIndex == #levels.slots + 1
		local shown = slot ~= nil or isNext
		pad.Transparency = if slot then 0 elseif isNext then 0.35 else 1
		pad.Color = if slot then OPEN_COLOR else LOCKED_COLOR
		pad.CanCollide = shown
		pad.CanQuery = shown
		-- (gui.Enabled appartient à ProximityLabel, qui allume l'étiquette de près : on cache son contenu)
		entry.panel.Visible = shown
		entry.prompt.Enabled = shown
		entry.bar.Visible = false
		if slot then
			local def = IdleTowers.Defs[slot.tower]
			local rate = Levels.TRAINING.SLOT_RATE[slot.level] or 0
			entry.prompt.ObjectText = `Emplacement d'entraînement {slotIndex}`
			entry.prompt.ActionText = if def then "Gérer" else "Choisir une tour"
			if def then
				local xp = levels.xp[slot.tower] or 0
				local trained = training[slot.tower] or 0
				local stars = Levels.stars(Levels.evolutionStage(slot.tower, trained))
				local done, needed = Levels.trainingProgress(xp)
				entry.title.Text = if stars ~= "" then `{def.displayName} {stars}` else def.displayName
				entry.title.TextColor3 = IVORY
				entry.sub.Text = `Entraînement {trained}/{Levels.TRAINING.MAX_LEVEL} • +{decimal(rate)} XP/min`
				entry.bar.Visible = true
				entry.fill.Size = UDim2.fromScale(if needed > 0 then math.clamp(done / needed, 0, 1) else 1, 1)
				entry.xp.Text = if needed > 0 then `{math.floor(done)} / {needed} XP` else "ENTRAÎNEMENT MAX"
				setLabelHeight(entry, LABEL_HEIGHT)
				table.insert(summary, if stars ~= "" then `{def.displayName} {stars}` else def.displayName)
			else
				entry.title.Text = `EMPLACEMENT {slotIndex}`
				entry.title.TextColor3 = IVORY
				entry.sub.Text = "Libre : choisis une tour à entraîner"
				setLabelHeight(entry, LABEL_HEIGHT_EMPTY)
			end
		elseif isNext then
			local price = Levels.TRAINING.SLOT_UNLOCK_COST[slotIndex] or 0
			entry.title.Text = `🔒 EMPLACEMENT {slotIndex}`
			entry.title.TextColor3 = GOLD
			entry.sub.Text = `Ouvrir : {NumberFormat.short(price)} pièces de niveau`
			entry.prompt.ObjectText = `Emplacement d'entraînement {slotIndex}`
			entry.prompt.ActionText = "Ouvrir"
			setLabelHeight(entry, LABEL_HEIGHT_EMPTY)
		end
	end
	-- Tableau du fond de la parcelle (Hub/PlotBoard.luau).
	game:setAttr("CampBest", levels.best)
	game:setAttr("CampCoins", levels.coins)
	game:setAttr("CampTowers", owned)
	game:setAttr("CampTraining", table.concat(summary, "  ·  "))
end

-- La parcelle `plot` (Hub/HubMap.luau) de ce joueur devient son camp. levels = data.levels.
function Camp.start(player: Player, plot, levels)
	if Camp.games[player] then
		return
	end
	preparePreviews()
	local dressing = { plot = plot, slots = {}, signature = nil }
	-- Socles d'entraînement : chacun reçoit son étiquette et son invite.
	local campSpot = {}
	for slotIndex, spotIndex in Levels.CAMP.SPOTS do
		campSpot[spotIndex] = slotIndex
	end
	for _, pad in plot.spots:GetChildren() do
		local slotIndex = if pad:IsA("BasePart") then campSpot[pad:GetAttribute("SpotIndex")] else nil
		if slotIndex and slotIndex <= #Levels.TRAINING.SLOT_UNLOCK_COST then
			dressing.slots[slotIndex] = dressPad(pad, slotIndex)
		end
	end
	dressings[player] = dressing
	Camp.games[player] = CampGame.new(plot, player, levels)
	Camp.refresh(player, levels)
end

-- Fin du camp (le joueur part) : la parcelle redevient libre, ses socles vides.
function Camp.stop(player: Player)
	local game = Camp.games[player]
	local dressing = dressings[player]
	Camp.games[player] = nil
	dressings[player] = nil
	if game then
		game:destroy()
	end
	if not dressing then
		return
	end
	for _, entry in dressing.slots do
		entry.gui:Destroy()
		entry.prompt:Destroy()
	end
	HubMap.resetPads(dressing.plot)
end

return Camp
