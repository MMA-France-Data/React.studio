-- Traduction automatique de tout ce qui s'affiche, côté client.
-- Le jeu écrit tous ses textes en français. Pour un joueur NON francophone (attribut « Lang » = "en", mis par le
-- serveur d'après sa langue Roblox, voir Shared/Lang.luau), ce module remplace chaque texte affiché par sa
-- traduction anglaise (dictionnaires Shared/LangEN) :
--   * les TextLabel et TextButton de son écran (PlayerGui) et des panneaux du monde (SurfaceGui, BillboardGui) ;
--   * les invites ProximityPrompt (ActionText « Ouvrir », ObjectText « BOUTIQUE DES TOURS »...).
-- Jamais les TextBox (où le joueur écrit). Un texte est traduit quand il apparaît, puis à chaque fois que le jeu (ou
-- le serveur) le change : le jeu continue d'écrire en français, sans rien savoir de l'anglais. Pour chaque texte, on
-- garde le texte français d'origine : retour au français en direct si la langue change (attribut « Lang »).
-- Rien ne se traduit sous un objet qui a l'attribut NoTranslate = true (outils Studio, noms de joueurs...), ni un texte
-- qui est juste le nom d'un joueur. La traduction automatique de Roblox est coupée sur chaque texte suivi
-- (AutoLocalize = false) : elle prendrait notre anglais pour du français.
-- Coût : un joueur francophone ne paie rien (juste l'écoute de l'attribut « Lang ») ; un joueur anglais : un tour de
-- tous les objets au départ, puis seulement quand un objet apparaît ou qu'un texte change (jamais à chaque image), et
-- les traductions déjà faites sont gardées en mémoire (Lang.luau).
-- Le code du jeu ne doit donc jamais RELIRE un .Text pour décider quelque chose (il peut être en anglais) : il garde
-- son propre texte français (ou AutoTranslate.original).
-- Studio seulement : BindableFunction « AutoTranslateStudio » dans le joueur (tests automatiques, voir setupStudioDebug).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lang = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lang"))

local AutoTranslate = {}

-- Propriétés traduites selon la classe de l'objet.
local PROPERTIES = {
	TextLabel = { "Text" },
	TextButton = { "Text" },
	ProximityPrompt = { "ActionText", "ObjectText" },
}

local player = Players.LocalPlayer
local shown = Lang.FRENCH -- langue affichée en ce moment
-- [objet] = { texts = { [propriété] = { original = texte français, written = notre traduction affichée ou nil } },
--             connections = { ... } }
local records = {}
local trackedCount = 0
local rootConnections = {} -- apparitions dans l'écran et le monde, arrivées et départs des joueurs
local playerNames = {} -- [nom, nom affiché ou « @nom » d'un joueur] = true : jamais traduits
local started = false

-- Vrai si l'objet (ou un de ses parents) a l'attribut NoTranslate = true.
local function excluded(instance: Instance): boolean
	local current: Instance? = instance
	for _ = 1, 24 do
		if not current or current == game then
			return false
		end
		if current:GetAttribute("NoTranslate") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Affiche la traduction du texte d'origine (rien à faire en français, ou si la traduction est identique).
local function show(instance: Instance, property: string, entry)
	if shown == Lang.FRENCH then
		return
	end
	local source = entry.original
	if typeof(source) ~= "string" or playerNames[source] then
		return
	end
	local translated = Lang.translate(source, shown)
	if translated ~= source then
		local target: any = instance
		entry.written = translated -- (avant d'écrire : l'écriture déclenche changed, qui la reconnaît)
		target[property] = translated
	end
end

-- Le texte d'un objet suivi a changé : notre propre traduction (rien à faire), ou un nouveau texte français du jeu.
local function changed(instance: Instance, property: string)
	local record = records[instance]
	local entry = record and record.texts[property]
	if not entry then
		return
	end
	local current = (instance :: any)[property]
	if entry.written ~= nil and current == entry.written then
		return
	end
	entry.original = current
	entry.written = nil
	show(instance, property, entry)
end

-- La traduction automatique de Roblox (Creator Dashboard, partie Localisation, parfois allumée par défaut) ne doit
-- jamais toucher un texte que nous traduisons : elle prendrait notre anglais pour du français. Chaque texte suivi
-- (joueur anglais seulement) a donc AutoLocalize = false, remis comme avant au retour au français. (pcall : propriété
-- absente dans les tests hors de Roblox)
local function setAutoLocalize(instance: Instance, value: boolean)
	pcall(function()
		(instance :: any).AutoLocalize = value
	end)
end

-- Arrête de suivre un objet. restore = remettre d'abord son texte français (objet retiré de l'écran mais pas détruit :
-- s'il revient, il est suivi de nouveau à partir de son texte français).
local function forget(instance: Instance, restore: boolean?)
	local record = records[instance]
	if not record then
		return
	end
	records[instance] = nil
	trackedCount -= 1
	for _, connection in record.connections do
		connection:Disconnect()
	end
	if restore then
		local target: any = instance
		for property, entry in record.texts do
			if entry.written ~= nil and target[property] == entry.written then
				target[property] = entry.original
			end
		end
		if record.autoLocalize then
			setAutoLocalize(instance, true)
		end
	end
end

-- Oublie les objets sortis du jeu (détruits, ou retirés de l'écran et du monde). Normalement fait à leur destruction
-- (Destroying) ; ceci rattrape les autres cas. Appelé de temps en temps (après au moins PRUNE_EVERY nouveaux objets
-- suivis, et au moins autant que d'objets déjà suivis : le coût reste petit), jamais à chaque image.
local PRUNE_EVERY = 500
local trackedSincePrune = 0
local function prune()
	trackedSincePrune = 0
	for instance in records do
		if not instance:IsDescendantOf(game) then
			forget(instance, true)
		end
	end
end

-- Commence à suivre un objet s'il a du texte à traduire (appelé pour CHAQUE objet qui apparaît : très court pour les
-- autres classes).
local function track(instance: Instance)
	local properties = PROPERTIES[instance.ClassName]
	if not properties or records[instance] or excluded(instance) then
		return
	end
	trackedSincePrune += 1
	if trackedSincePrune >= math.max(PRUNE_EVERY, trackedCount) then
		prune()
	end
	local record = { texts = {}, connections = {}, autoLocalize = false }
	records[instance] = record
	trackedCount += 1
	-- (avant d'écrire l'anglais : la traduction automatique de Roblox ne le verra jamais, voir setAutoLocalize)
	local ok, autoLocalize = pcall(function()
		return (instance :: any).AutoLocalize
	end)
	if ok and autoLocalize == true then
		record.autoLocalize = true
		setAutoLocalize(instance, false)
	end
	for _, property in properties do
		local entry = { original = (instance :: any)[property], written = nil }
		record.texts[property] = entry
		table.insert(record.connections, instance:GetPropertyChangedSignal(property):Connect(function()
			changed(instance, property)
		end))
		show(instance, property, entry)
	end
	table.insert(record.connections, instance.Destroying:Connect(function()
		forget(instance)
	end))
end

local function refreshPlayerNames()
	table.clear(playerNames)
	for _, other in Players:GetPlayers() do
		playerNames[other.Name] = true
		playerNames[other.DisplayName] = true
		playerNames["@" .. other.Name] = true
	end
end

-- Passe en anglais : suit tous les textes déjà là, puis ceux qui apparaissent.
local function watchAll()
	local playerGui = player:WaitForChild("PlayerGui")
	refreshPlayerNames()
	table.insert(rootConnections, Players.PlayerAdded:Connect(refreshPlayerNames))
	table.insert(rootConnections, Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayerNames)
	end))
	table.insert(rootConnections, playerGui.DescendantAdded:Connect(track))
	table.insert(rootConnections, workspace.DescendantAdded:Connect(track))
	for _, instance in playerGui:GetDescendants() do
		track(instance)
	end
	for _, instance in workspace:GetDescendants() do
		track(instance)
	end
end

-- Retour au français : chaque texte traduit reprend son texte d'origine, et plus rien n'est suivi (coût nul).
local function restoreAll()
	shown = Lang.FRENCH
	for _, connection in rootConnections do
		connection:Disconnect()
	end
	table.clear(rootConnections)
	for instance, record in records do
		local target: any = instance
		for property, entry in record.texts do
			if entry.written ~= nil and target[property] == entry.written then
				target[property] = entry.original
			end
		end
		if record.autoLocalize then
			setAutoLocalize(instance, true)
		end
		for _, connection in record.connections do
			connection:Disconnect()
		end
	end
	table.clear(records)
	trackedCount = 0
	trackedSincePrune = 0
	table.clear(playerNames)
end

-- Change la langue affichée ("fr" ou "en" ; rien = celle du joueur, Lang.current). Sans effet si c'est déjà elle.
function AutoTranslate.setLanguage(language: string?)
	local wanted = if language == nil then Lang.current() else Lang.fromLocale(language)
	if wanted == shown then
		return
	end
	if shown ~= Lang.FRENCH then
		restoreAll()
	end
	shown = wanted
	if wanted ~= Lang.FRENCH then
		watchAll()
	end
end

-- Langue affichée en ce moment ("fr" ou "en").
function AutoTranslate.language(): string
	return shown
end

-- Texte français d'origine d'un objet (propriété "Text" par défaut) : celui que le jeu a écrit, même s'il est affiché
-- en anglais. Objet non suivi (joueur francophone...) : son texte actuel.
function AutoTranslate.original(instance: Instance, property: string?): string?
	local name = property or "Text"
	local record = records[instance]
	local entry = record and record.texts[name]
	if entry then
		return entry.original
	end
	local ok, value = pcall(function()
		return (instance :: any)[name]
	end)
	return if ok and typeof(value) == "string" then value else nil
end

-- Studio seulement (jamais dans le jeu publié) : BindableFunction « AutoTranslateStudio » dans le joueur, pour les
-- tests automatiques (tools/studio-test). Un scénario de test a sa propre copie des modules : il passe par elle
-- pour lire l'état de CETTE copie.
--   Invoke("Language")               -> langue affichée ("fr" ou "en")
--   Invoke("Tracked")                -> nombre de textes suivis
--   Invoke("Original", objet, prop?) -> texte français d'origine de l'objet (nil s'il n'est pas suivi)
--   Invoke("Misses") / Invoke("ClearMisses") -> textes sans traduction notés par Lang (liste) / vider la liste
--   Invoke("Problems")               -> problèmes des dictionnaires ; Invoke("Entries") -> nombre de traductions
--   Invoke("Translate", texte, langue?) -> traduction (anglais par défaut)
local function setupStudioDebug()
	if not RunService:IsStudio() then
		return
	end
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "AutoTranslateStudio"
	bindable.OnInvoke = function(command: string, ...)
		if command == "Language" then
			return shown
		elseif command == "Tracked" then
			prune() -- (sans les objets sortis du jeu)
			return trackedCount
		elseif command == "Original" then
			local instance, property = ...
			local record = typeof(instance) == "Instance" and records[instance]
			local entry = record and record.texts[property or "Text"]
			return entry and entry.original
		elseif command == "Misses" then
			return Lang.getMisses()
		elseif command == "ClearMisses" then
			Lang.clearMisses()
			return true
		elseif command == "Problems" then
			return Lang.getProblems()
		elseif command == "Entries" then
			return Lang.entryCount()
		elseif command == "Translate" then
			local text, language = ...
			return Lang.translate(text, language or Lang.ENGLISH)
		end
		return nil
	end
	bindable.Parent = player
end

-- Démarré une seule fois par Main.client.luau, avant les interfaces.
function AutoTranslate.start()
	if started then
		return
	end
	started = true
	setupStudioDebug()
	player:GetAttributeChangedSignal(Lang.ATTRIBUTE):Connect(function()
		AutoTranslate.setLanguage(Lang.current())
	end)
	AutoTranslate.setLanguage(Lang.current())
end

return AutoTranslate
