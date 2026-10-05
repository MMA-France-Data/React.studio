-- Langue des joueurs et traduction des textes du jeu (français -> anglais, espagnol, portugais).
-- Le jeu est écrit en français. Un joueur dont la langue Roblox commence par « fr » garde ces textes ; « es » voit
-- l'espagnol, « pt » le portugais (du Brésil), et TOUS les autres l'anglais.
--
-- COMMENT AJOUTER UNE TRADUCTION
--   1. Ouvre un dictionnaire de src/shared/LangEN/ : Game (les textes du jeu) ou Glossary (les noms du jeu : tours,
--      monstres..., à reprendre partout à l'identique). Un nouveau fichier posé dans ce dossier est lu tout seul par
--      le jeu ; pour les tests hors de Studio, l'ajouter aussi dans tools/lang/load.luau.
--   2. Ajoute une ligne  ["texte français"] = "English text",  Le texte français doit être EXACTEMENT celui qui
--      s'affiche : mêmes accents, espaces, ponctuation, « », emoji, balises <b>…</b>, retours à la ligne \n.
--   3. Un texte avec des nombres ou des noms qui changent : remplace chaque partie qui change par {1}, {2}...
--        ["Il te faut {1} pièces pour {2}"] = "You need {1} coins for {2}",
--      Dans la traduction, les {n} peuvent changer de place. Un nom mis dans un {n} (tour, rareté, ennemi...) est
--      traduit tout seul s'il a sa propre ligne dans un dictionnaire, et en anglais, les virgules des nombres
--      deviennent des points (« 0,05 » -> « 0.05 »). Un modèle doit toujours garder des mots fixes (jamais seulement
--      « {1} {2} »).
--   4. Ajoute la MÊME ligne (même texte français) dans le même fichier de src/shared/LangES/ (espagnol) et de
--      src/shared/LangPT/ (portugais du Brésil). Une ligne oubliée là : le joueur voit l'anglais à la place, et
--      tools/lang/check.luau la signale.
--   5. Vérifie (sans Studio) : luau.exe tools/lang/check.luau -a "texte à traduire" (voir tools/lang/).
--
-- ORDRE DE RECHERCHE d'une traduction (Lang.translate) :
--   texte exact -> modèles avec {n} (celui qui a le plus de mots fixes gagne) -> même texte sans les espaces du
--   début et de la fin -> texte entier dans une balise (<b>…</b>, <font …>…</font>) : son intérieur -> même texte
--   sans ce qui n'est pas des lettres au début, à la fin, ou des deux côtés (emoji, étoiles, nombres, « » :
--   « 🔒 Totem de givre », « Archer du rempart ★★ », « 1. Catapulte » : inutile d'écrire une ligne pour chacun) ->
--   texte sur plusieurs lignes : chaque ligne -> ligne coupée par « • » ou « · » : chaque morceau. Un texte sans mot (nombres,
--   « 1.5K », « x10 », emoji) n'est jamais cherché : seuls ses nombres peuvent changer d'écriture (anglais : « 7,5 » ->
--   « 7.5 », « 2,5 % » -> « 2.5% » ; portugais : « 2,5 % » -> « 2,5% »). En espagnol ou en portugais, un texte absent
--   de leurs dictionnaires est cherché dans les dictionnaires anglais. Un texte inconnu reste en français (et, dans
--   Studio, il est noté dans une liste par langue : Lang.getMisses ; un texte pris en anglais y est noté aussi).
--
-- LA LANGUE D'UN JOUEUR
--   * Le serveur lui met l'attribut « Lang » ("fr", "en", "es" ou "pt") dès son arrivée (Lang.startServer, dans
--     Main.server.luau), d'après sa langue Roblox (Player.LocaleId).
--   * Le client traduit tout ce qui s'affiche (src/client/AutoTranslate.luau), messages du serveur compris : le
--     serveur envoie toujours ses textes en français. Avant l'arrivée de l'attribut, le client prend sa langue Roblox.
--   * Dans Studio : Config.STUDIO_LANGUAGE ("auto" = comme dans le jeu publié, "fr", "en", "es" ou "pt" pour tester).
--     Pendant les tests automatiques (tools/studio-test), toujours le français : leurs vérifications lisent les
--     textes français.
--
-- Hors de Roblox (tests avec luau.exe), seul le traducteur marche : les dictionnaires s'ajoutent avec
-- Lang.addDictionary (voir tools/lang/load.luau).

local Lang = {}

Lang.FRENCH = "fr"
Lang.ENGLISH = "en"
Lang.SPANISH = "es"
Lang.PORTUGUESE = "pt"
Lang.ATTRIBUTE = "Lang" -- attribut du joueur : "fr", "en", "es" ou "pt"

-- Langues traduites, et le dossier de leurs dictionnaires (dans Shared). Le français n'en a pas : c'est la langue du jeu.
Lang.FOLDERS = { en = "LangEN", es = "LangES", pt = "LangPT" }
-- Une traduction absente des dictionnaires espagnols ou portugais : on prend l'anglais (plus clair que le français).
local FALLBACK = { es = "en", pt = "en" }
-- Début du code de langue Roblox -> langue du jeu (toutes les autres : l'anglais).
local LOCALE_PREFIXES = { fr = "fr", es = "es", pt = "pt" }

local CACHE_LIMIT = 4000 -- textes déjà traduits gardés en mémoire, par langue (au-delà : vidée, puis se remplit)
local MISS_LIMIT = 400 -- textes sans traduction notés au plus, par langue (Studio)
local MAX_DEPTH = 3 -- traduction des morceaux dans les morceaux (valeurs {n}, balises) : jamais plus profond

-- Dans Roblox ? (hors de Roblox, game et script n'existent pas)
local IN_ROBLOX = typeof(game) == "Instance" and typeof(script) == "Instance"

local Players, RunService, LocalizationService, ReplicatedStorage, Config
if IN_ROBLOX then
	Players = game:GetService("Players")
	RunService = game:GetService("RunService")
	LocalizationService = game:GetService("LocalizationService")
	ReplicatedStorage = game:GetService("ReplicatedStorage")
	local configModule = script.Parent:FindFirstChild("Config")
	Config = if configModule then require(configModule) :: any else nil
end

----------------------------------------------------------------------
-- Langue des joueurs
----------------------------------------------------------------------

-- Langue du jeu d'après le code de langue Roblox : « fr » (fr-fr, fr-ca...) -> "fr", « es » (es-es, es-mx...) -> "es",
-- « pt » (pt-br, pt-pt) -> "pt", tous les autres -> "en".
function Lang.fromLocale(localeId: string?): string
	if typeof(localeId) == "string" then
		local language = LOCALE_PREFIXES[string.lower(string.sub(localeId, 1, 2))]
		if language then
			return language
		end
	end
	return Lang.ENGLISH
end

-- "fr", "en", "es" ou "pt" si c'est une langue connue, sinon nil.
local function known(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	return if value == Lang.FRENCH or Lang.FOLDERS[value] ~= nil then value else nil
end

-- Langue imposée dans Studio (nil = aucune, et toujours nil dans le jeu publié). Tests automatiques
-- (ReplicatedStorage.__AutoPlayTest) : le français, car leurs vérifications lisent les textes français.
local function studioLanguage(): string?
	if not IN_ROBLOX or not RunService:IsStudio() then
		return nil
	end
	if ReplicatedStorage:FindFirstChild("__AutoPlayTest") then
		return Lang.FRENCH
	end
	return known(Config and Config.STUDIO_LANGUAGE)
end

-- Langue d'un joueur d'après ses réglages Roblox, sans regarder l'attribut « Lang » (Studio : Config.STUDIO_LANGUAGE).
-- Sur le client, pour le joueur local : LocalizationService.RobloxLocaleId, sinon Player.LocaleId.
function Lang.detect(player: Player?): string
	local forced = studioLanguage()
	if forced then
		return forced
	end
	local locale = nil
	if IN_ROBLOX and RunService:IsClient() and (player == nil or player == Players.LocalPlayer) then
		local ok, value = pcall(function()
			return LocalizationService.RobloxLocaleId
		end)
		locale = if ok then value else nil
	end
	if (typeof(locale) ~= "string" or locale == "") and player then
		local ok, value = pcall(function()
			return player.LocaleId
		end)
		locale = if ok then value else nil
	end
	return Lang.fromLocale(locale)
end

-- Langue d'un joueur : son attribut « Lang » (mis par le serveur), sinon ses réglages Roblox (Lang.detect).
-- Serveur : pour traduire un texte qui ne passe pas par l'écran du joueur (ex. un message de player:Kick) :
--   player:Kick(Lang.translate("Texte français", Lang.forPlayer(player)))
function Lang.forPlayer(player: Player?): string
	local attribute = if player then known(player:GetAttribute(Lang.ATTRIBUTE)) else nil
	return attribute or Lang.detect(player)
end

-- Langue du joueur de ce client ("fr" sur le serveur et hors de Roblox).
function Lang.current(): string
	if not IN_ROBLOX or not RunService:IsClient() then
		return Lang.FRENCH
	end
	return Lang.forPlayer(Players.LocalPlayer)
end

-- Serveur : attribut « Lang » de chaque joueur dès son arrivée, remis à jour si sa langue
-- Roblox change pendant la partie. Appelée une seule fois par Main.server.luau.
local serverStarted = false
function Lang.startServer()
	if not IN_ROBLOX or serverStarted then
		return
	end
	serverStarted = true
	local function apply(player: Player)
		local language = Lang.detect(player)
		if player:GetAttribute(Lang.ATTRIBUTE) ~= language then
			player:SetAttribute(Lang.ATTRIBUTE, language)
		end
	end
	local function setup(player: Player)
		apply(player)
		pcall(function()
			player:GetPropertyChangedSignal("LocaleId"):Connect(function()
				apply(player)
			end)
		end)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

----------------------------------------------------------------------
-- Dictionnaires : un jeu par langue traduite, chargé au premier texte à traduire dans cette langue (un joueur
-- francophone n'en charge jamais, un joueur anglais ne charge que l'anglais)
----------------------------------------------------------------------
local sets = {} -- [langue] = jeu de dictionnaires (voir newSet)
local problems: { string } = {}
local caches = {} -- [langue] = { [texte français] = traduction }
local cacheSizes = {} -- [langue] = nombre de textes dans caches[langue]
local recordMisses = IN_ROBLOX and RunService:IsStudio()
local misses = {} -- [langue] = { seen = { [texte] = true }, list = { texte... } }

local function newSet(language: string)
	return {
		language = language,
		folderLoaded = false, -- dossier de la langue lu (Roblox)
		indexDirty = true, -- index des modèles à refaire
		exact = {} :: { [string]: string }, -- texte français exact -> traduction
		values = {} :: { [string]: string }, -- toutes les clés (exactes et modèles) -> traduction (doublons)
		owners = {} :: { [string]: string }, -- clé -> nom du dictionnaire qui l'a donnée
		templates = {}, -- modèles avec {n}, du plus précis au moins précis (voir compileTemplate)
		byPrefix = {}, -- [premier octet du début fixe] = modèles qui commencent par des mots
		bySuffix = {}, -- [dernier octet de la fin fixe] = modèles qui commencent par {n} et finissent par des mots
		floating = {}, -- modèles qui commencent ET finissent par {n}
		entryCount = 0,
	}
end

-- Le jeu de dictionnaires d'une langue traduite ("en", "es", "pt"), créé (vide) au premier appel.
local function getSet(language: string)
	local set = sets[language]
	if not set then
		set = newSet(language)
		sets[language] = set
	end
	return set
end

-- Un problème dans un dictionnaire (doublon, modèle impossible...) : noté (Lang.getProblems), et affiché dans Studio.
local function problem(message: string)
	table.insert(problems, message)
	if IN_ROBLOX and RunService:IsStudio() then
		warn("[Lang] " .. message)
	end
end

-- Vide la mémoire des textes déjà traduits, dans toutes les langues (les tables restent les mêmes : une traduction en
-- cours peut continuer à écrire dans la sienne).
local function clearCaches()
	for language, cache in caches do
		table.clear(cache)
		cacheSizes[language] = 0
	end
end

-- Une lettre : ASCII, ou premier octet d'une lettre accentuée (é, è, à, ç, ô... : octet 195 ; œ : octet 197).
local LETTER = "[%a\195\197]"

-- Vrai si le texte contient au moins un mot. Les nombres (même avec leur suffixe : 1.5K, 2.3Qa, 1e96, x10, ×3, 10s),
-- les emoji et la ponctuation seuls n'ont rien à traduire.
local function hasWords(text: string): boolean
	if not string.find(text, LETTER) then
		return false
	end
	local rest = string.gsub(text, "\195\151", "") -- « × »
	rest = string.gsub(rest, "x?%d+[%.,]?%d*%a*", "")
	return string.find(rest, LETTER) ~= nil
end
Lang.hasWords = hasWords

-- Échappe les caractères spéciaux des motifs de Luau (^$()%.[]*+-?).
local function escapePattern(text: string): string
	return (string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Prépare un modèle : ["Il te faut {1} pièces pour {2}"] -> motif "^Il te faut (.-) pièces pour (.-)$", ordre des {n}
-- dans le texte français, début et fin fixes (tri rapide), longueur des mots fixes (le plus précis gagne).
local function compileTemplate(set, key: string, value: string, source: string)
	local pieces = { "^" }
	local literals = {}
	local order = {}
	local position = 1
	while true do
		local first, last, number = string.find(key, "{(%d+)}", position)
		local literal = string.sub(key, position, if first then first - 1 else #key)
		table.insert(literals, literal)
		table.insert(pieces, escapePattern(literal))
		if not first then
			break
		end
		table.insert(order, tonumber(number))
		table.insert(pieces, "(.-)")
		position = last + 1
	end
	table.insert(pieces, "$")
	local fixed = table.concat(literals)
	if not string.find(fixed, LETTER) then
		problem(`{source} : modèle ignoré, il n'a aucun mot fixe : « {key} »`)
		return
	end
	for index = 2, #literals - 1 do
		if literals[index] == "" then
			problem(source .. " : deux {n} collés dans « " .. key .. " » (le premier restera vide)")
			break
		end
	end
	for number in string.gmatch(value, "{(%d+)}") do
		if not table.find(order, tonumber(number)) then
			problem(source .. " : {" .. number .. "} de la traduction absent du texte français : « " .. key .. " »")
		end
	end
	table.insert(set.templates, {
		key = key,
		value = value,
		pattern = table.concat(pieces),
		order = order,
		prefix = literals[1],
		suffix = literals[#literals],
		fixed = #fixed,
		rank = 0,
		-- Une valeur {n} ne passe à la ligne (ou par-dessus un « • » / « · ») que si le texte français en a un :
		-- sinon « Vague {1} » avalerait « Vague 5\nSuivant » en entier au lieu de laisser traduire chaque ligne.
		newlines = string.find(key, "\n", 1, true) ~= nil,
		bullets = string.find(key, "•", 1, true) ~= nil,
		dots = string.find(key, "·", 1, true) ~= nil,
	})
end

-- Vrai si les valeurs {n} trouvées restent sur une ligne et dans un morceau (voir newlines, bullets, dots plus haut).
local function capturesFit(template, captures: { string }): boolean
	for _, capture in captures do
		if (not template.newlines and string.find(capture, "\n", 1, true))
			or (not template.bullets and string.find(capture, "•", 1, true))
			or (not template.dots and string.find(capture, "·", 1, true))
		then
			return false
		end
	end
	return true
end

-- Ajoute les lignes d'un dictionnaire au jeu d'une langue. Une clé déjà donnée par un autre dictionnaire garde sa
-- première traduction (le Glossaire est lu en premier) : si la traduction diffère, c'est un problème.
local function addEntries(set, dictionary: { [any]: any }, source: string)
	for key, value in dictionary do
		if typeof(key) ~= "string" or typeof(value) ~= "string" then
			problem(`{source} : ligne ignorée (texte français et traduction doivent être des textes) : {tostring(key)}`)
			continue
		end
		local owner = set.owners[key]
		if owner then
			if set.values[key] ~= value then
				problem(`« {key} » traduit deux fois ({owner} : « {set.values[key]} » ; {source} : « {value} ») : {owner} gagne`)
			end
			continue
		end
		set.owners[key] = source
		set.values[key] = value
		set.entryCount += 1
		if string.find(key, "{%d+}") then
			compileTemplate(set, key, value, source)
		else
			if string.find(value, "{%d+}") then
				problem(source .. " : {n} dans la traduction mais pas dans le texte français : « " .. key .. " »")
			end
			set.exact[key] = value
		end
	end
	set.indexDirty = true
	clearCaches()
end

-- Roblox : tous les ModuleScript du dossier de la langue (Shared/LangEN, LangES, LangPT), le Glossaire d'abord, puis
-- par ordre alphabétique.
local function loadFolder(set)
	if set.folderLoaded then
		return
	end
	set.folderLoaded = true
	if not IN_ROBLOX then
		return
	end
	local folderName = Lang.FOLDERS[set.language]
	local folder = folderName and script.Parent:FindFirstChild(folderName)
	if not folder then
		problem(`dossier Shared/{tostring(folderName)} introuvable : aucune traduction ({set.language})`)
		return
	end
	local modules = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a, b)
		if (a.Name == "Glossary") ~= (b.Name == "Glossary") then
			return a.Name == "Glossary"
		end
		return a.Name < b.Name
	end)
	for _, module in modules do
		local ok, dictionary = pcall(require, module)
		if ok and typeof(dictionary) == "table" then
			addEntries(set, dictionary, `{folderName}/{module.Name}`)
		else
			problem(`dictionnaire {folderName}/{module.Name} illisible : {tostring(dictionary)}`)
		end
	end
end

-- Range les modèles : du plus précis (le plus de mots fixes) au moins précis, puis par début / fin fixe.
local function rebuildIndex(set)
	set.indexDirty = false
	table.sort(set.templates, function(a, b)
		if a.fixed ~= b.fixed then
			return a.fixed > b.fixed
		end
		return a.key < b.key
	end)
	table.clear(set.byPrefix)
	table.clear(set.bySuffix)
	table.clear(set.floating)
	for rank, template in set.templates do
		template.rank = rank
		if template.prefix ~= "" then
			local byte = string.byte(template.prefix, 1)
			set.byPrefix[byte] = set.byPrefix[byte] or {}
			table.insert(set.byPrefix[byte], template)
		elseif template.suffix ~= "" then
			local byte = string.byte(template.suffix, -1)
			set.bySuffix[byte] = set.bySuffix[byte] or {}
			table.insert(set.bySuffix[byte], template)
		else
			table.insert(set.floating, template)
		end
	end
end

local function ensureReady(set)
	if not set.folderLoaded then
		loadFolder(set)
	end
	if set.indexDirty then
		rebuildIndex(set)
	end
end

----------------------------------------------------------------------
-- Traduction
----------------------------------------------------------------------

-- Premier modèle de la liste (déjà triée) qui correspond au texte entier, et ses valeurs {n}.
local function firstMatch(list, text: string)
	if not list then
		return nil, nil
	end
	local length = #text
	for _, template in list do
		if template.fixed <= length then
			local prefix, suffix = template.prefix, template.suffix
			if (prefix == "" or string.sub(text, 1, #prefix) == prefix) and (suffix == "" or string.sub(text, -#suffix) == suffix) then
				local captures = { string.match(text, template.pattern) }
				if captures[1] ~= nil and capturesFit(template, captures) then
					return template, captures
				end
			end
		end
	end
	return nil, nil
end

-- Le modèle le plus précis qui correspond au texte (ou nil).
local function findTemplate(set, text: string)
	local best, bestCaptures = firstMatch(set.byPrefix[string.byte(text, 1)], text)
	local template, captures = firstMatch(set.bySuffix[string.byte(text, -1)], text)
	if template and (not best or template.rank < best.rank) then
		best, bestCaptures = template, captures
	end
	template, captures = firstMatch(set.floating, text)
	if template and (not best or template.rank < best.rank) then
		best, bestCaptures = template, captures
	end
	return best, bestCaptures
end

local translateCore: (any, string, number) -> string?

-- Nombres écrits à la française dans un texte SANS mot (une valeur seule, ex. les chiffres de la fiche d'une tour),
-- écrits comme dans les phrases traduites. Anglais : la virgule des nombres devient un point (« 7,5 » -> « 7.5 ») et
-- l'espace avant « % » disparaît (« 2,5 % » -> « 2.5% »). Portugais : la virgule reste, l'espace avant « % »
-- disparaît (« 2,5% »). Espagnol : rien ne change (« 2,5 % »). Pas de dictionnaire ni de mémoire : juste l'écriture.
local function localNumbers(text: string, language: string): string
	if language == Lang.ENGLISH and string.find(text, "%d,%d") then
		text = string.gsub(text, "(%d),(%d)", "%1.%2")
	end
	if (language == Lang.ENGLISH or language == Lang.PORTUGUESE) and string.find(text, "%d %%") then
		text = string.gsub(text, "(%d) %%", "%1%%")
	end
	return text
end

-- Espagnol : une phrase qui finit par « ! » ou « ? » commence par « ¡ » ou « ¿ » (« Rejouer ! » -> « ¡Repetir! »).
-- `tail` : ce qui suit la phrase traduite.
local function openingMark(language: string, inner: string, tail: string): string
	if language ~= Lang.SPANISH then
		return inner
	end
	local mark = string.sub(tail, 1, 1)
	if mark == "!" and string.sub(inner, 1, 2) ~= "¡" then
		return "¡" .. inner
	elseif mark == "?" and string.sub(inner, 1, 2) ~= "¿" then
		return "¿" .. inner
	end
	return inner
end

-- Espagnol : un « ¡ » ou un « ¿ » suivi d'emoji ou de symboles passe après eux (un modèle « ¡{1} está en línea! »
-- rempli avec « 🟢 Robin » -> « 🟢 ¡Robin está en línea! »).
local function moveOpeningMark(text: string): string
	local mark = string.sub(text, 1, 2)
	if mark ~= "¡" and mark ~= "¿" then
		return text
	end
	local position = 3
	while true do
		local byte = string.byte(text, position)
		if byte == 32 then
			position += 1
		elseif byte and byte >= 226 then
			-- (premier octet d'un emoji ou d'un symbole : ★, ✓, ⏩, 🟢... ; puis ses octets suivants)
			position += 1
			while true do
				local following = string.byte(text, position)
				if not following or following < 128 or following > 191 then
					break
				end
				position += 1
			end
		else
			break
		end
	end
	if position == 3 then
		return text
	end
	return string.sub(text, 3, position - 1) .. mark .. string.sub(text, position)
end

-- Place de la première et de la dernière LETTRE du texte (lettres sans accent, ou avec : é, è, à, ç, œ...). Ce qui est
-- avant et après : symboles, emoji, étoiles, nombres, ponctuation, espaces. nil si le texte n'a aucune lettre.
local function letterSpan(text: string): (number?, number?)
	local first = string.find(text, LETTER)
	if not first then
		return nil, nil
	end
	local last = #text
	while last > first do
		local byte = string.byte(text, last)
		if (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) then
			break
		elseif byte >= 128 and byte <= 191 then
			-- (2e octet d'une lettre accentuée : son 1er octet est 195 ou 197)
			local lead = string.byte(text, last - 1)
			if lead == 195 or lead == 197 then
				break
			end
		end
		last -= 1
	end
	return first, last
end

-- Valeur d'un {n} : traduite si elle a sa traduction (nom de tour, rareté...), sinon gardée, avec ses virgules de
-- nombres changées en points en anglais (« 0,05 » -> « 0.05 »).
local function translateValue(set, value: string, depth: number): string
	if value == "" then
		return value
	end
	local direct = set.exact[value]
	if direct then
		return direct
	end
	if depth < MAX_DEPTH and hasWords(value) then
		local translated = translateCore(set, value, depth + 1)
		if translated then
			return translated
		end
	end
	if set.language == Lang.ENGLISH and string.find(value, "%d,%d") then
		value = string.gsub(value, "(%d),(%d)", "%1.%2")
	end
	return value
end

-- Texte traduit d'un modèle, avec ses {n} remplis (dans l'ordre de la traduction).
local function fill(set, template, captures: { string }, depth: number): string
	local filled = {}
	for index, number in template.order do
		filled[number] = translateValue(set, captures[index], depth)
	end
	local result = string.gsub(template.value, "{(%d+)}", function(number)
		return filled[tonumber(number)] -- (absente : le {n} reste tel quel)
	end)
	return if set.language == Lang.SPANISH then moveOpeningMark(result) else result
end

-- Exact, modèle, sans les espaces autour, ou intérieur d'une balise qui entoure tout. nil = pas de traduction.
translateCore = function(set, text: string, depth: number): string?
	local direct = set.exact[text]
	if direct then
		return direct
	end
	local template, captures = findTemplate(set, text)
	if template then
		return fill(set, template, captures, depth)
	end
	-- Espaces au début ou à la fin : on traduit le milieu et on les remet.
	local firstByte, lastByte = string.byte(text, 1), string.byte(text, -1)
	local spaced = firstByte == 32 or firstByte == 9 or firstByte == 10 or lastByte == 32 or lastByte == 9 or lastByte == 10
	local before, middle, after = nil, nil, nil
	if spaced then
		before, middle, after = string.match(text, "^(%s*)(.-)(%s*)$")
	end
	if middle and middle ~= "" and #middle < #text then
		local inner = set.exact[middle]
		if not inner then
			local innerTemplate, innerCaptures = findTemplate(set, middle)
			inner = if innerTemplate then fill(set, innerTemplate, innerCaptures, depth) else nil
		end
		if inner then
			return before .. inner .. after
		end
	end
	-- Tout le texte dans une seule balise (<b>…</b>, <font color="…">…</font>) : on traduit l'intérieur.
	if depth < MAX_DEPTH then
		local open, tag, inside, close = string.match(text, "^(<(%a+)[^>]*>)(.-)(</%a+>)$")
		if open and close == `</{tag}>` and inside ~= "" and not string.find(inside, "<", 1, true) then
			local inner = translateCore(set, inside, depth + 1)
			if inner then
				return open .. inner .. close
			end
		end
	end
	-- Ce qui n'est pas des lettres au début ou à la fin (emoji, étoiles, nombres, ponctuation : « 🔒 Totem de givre »,
	-- « Archer du rempart ★★ », « 1. Catapulte ») : on traduit le reste et on les remet, avec leurs nombres écrits
	-- comme dans la langue. D'abord sans le début seulement (le reste peut être un modèle qui finit par un nombre :
	-- « 🔒 EMPLACEMENT 2 »), puis sans la fin seulement, puis sans les deux. Jamais pour un texte de plusieurs lignes
	-- (chaque ligne est traduite à part, voir Lang.translate). La ponctuation qui suit est écrite sans espace devant,
	-- comme en anglais, en espagnol et en portugais (« Rejouer ! » -> « Replay! », « ¡Repetir! »).
	if depth < MAX_DEPTH and not string.find(text, "\n", 1, true) then
		local first, last = letterSpan(text)
		if first and last and (first > 1 or last < #text) then
			local language = set.language
			local head, tail = string.sub(text, 1, first - 1), string.sub(text, last + 1)
			tail = string.gsub(tail, "^ ([:!%?;])", "%1")
			if first > 1 then
				local inner = translateCore(set, string.sub(text, first), depth + 1)
				if inner then
					return localNumbers(head, language) .. inner
				end
			end
			if last < #text then
				local inner = translateCore(set, string.sub(text, 1, last), depth + 1)
				if inner then
					return openingMark(language, inner, tail) .. localNumbers(tail, language)
				end
			end
			if first > 1 and last < #text then
				local inner = translateCore(set, string.sub(text, first, last), depth + 1)
				if inner then
					return localNumbers(head, language) .. openingMark(language, inner, tail) .. localNumbers(tail, language)
				end
			end
		end
	end
	return nil
end

-- Note un texte sans traduction dans cette langue (Studio : liste Lang.getMisses).
local function noteMiss(language: string, text: string)
	if not recordMisses then
		return
	end
	local entry = misses[language]
	if not entry then
		entry = { seen = {}, list = {} }
		misses[language] = entry
	end
	if entry.seen[text] or #entry.list >= MISS_LIMIT then
		return
	end
	entry.seen[text] = true
	table.insert(entry.list, text)
end

-- Un texte (ou un morceau) entier dans la langue du jeu de dictionnaires, sinon, pour l'espagnol et le portugais,
-- en anglais : ce texte est alors noté comme manquant dans sa langue. nil = aucune traduction.
local function translateWhole(set, text: string): string?
	local result = translateCore(set, text, 0)
	if result then
		return result
	end
	local fallbackLanguage = FALLBACK[set.language]
	if fallbackLanguage then
		local fallback = getSet(fallbackLanguage)
		ensureReady(fallback)
		result = translateCore(fallback, text, 0)
		if result then
			noteMiss(set.language, text)
		end
	end
	return result
end

-- Coupe une ligne à ses séparateurs « • » et « · » (espaces autour compris) : { morceau, séparateur, morceau... }.
local SEPARATORS = { "•", "·" }
local function splitSegments(line: string): { string }
	local pieces = {}
	local position = 1
	while true do
		local first, last = nil, nil
		for _, mark in SEPARATORS do
			local markFirst, markLast = string.find(line, "%s*" .. mark .. "%s*", position)
			if markFirst and (not first or markFirst < first) then
				first, last = markFirst, markLast
			end
		end
		if not first then
			table.insert(pieces, string.sub(line, position))
			return pieces
		end
		table.insert(pieces, string.sub(line, position, first - 1))
		table.insert(pieces, string.sub(line, first, last))
		position = last + 1
	end
end

-- Une ligne : entière, sinon morceau par morceau (« • », « · »). Un morceau inconnu reste en français.
local function translateLine(set, line: string): string
	if not hasWords(line) then
		return localNumbers(line, set.language)
	end
	local whole = translateWhole(set, line)
	if whole then
		return whole
	end
	local pieces = splitSegments(line)
	if #pieces == 1 then
		noteMiss(set.language, line)
		return line
	end
	for index = 1, #pieces, 2 do
		local piece = pieces[index]
		if hasWords(piece) then
			local translated = translateWhole(set, piece)
			if translated then
				pieces[index] = translated
			else
				noteMiss(set.language, piece)
			end
		else
			pieces[index] = localNumbers(piece, set.language)
		end
	end
	return table.concat(pieces)
end

-- Traduit un texte français dans la langue `language` ("fr", "en", "es", "pt", ou un code de langue Roblox ; rien = la
-- langue de ce client). En français, ou sans traduction connue, le texte revient tel quel.
function Lang.translate(text: string, language: string?): string
	if typeof(text) ~= "string" then
		return text
	end
	local target = if language == nil then Lang.current() else Lang.fromLocale(language)
	if target == Lang.FRENCH then
		return text
	end
	if not hasWords(text) then
		return localNumbers(text, target) -- (jamais cherché dans les dictionnaires, ni gardé en mémoire)
	end
	-- (d'abord les dictionnaires : les charger vide la mémoire des traductions)
	local set = getSet(target)
	ensureReady(set)
	local cache = caches[target]
	if not cache then
		cache = {}
		caches[target] = cache
		cacheSizes[target] = 0
	end
	local cached = cache[text]
	if cached then
		return cached
	end
	local result
	if string.find(text, "\n", 1, true) then
		result = translateWhole(set, text)
		if not result then
			local lines = string.split(text, "\n")
			for index, line in lines do
				lines[index] = translateLine(set, line)
			end
			result = table.concat(lines, "\n")
		end
	else
		result = translateLine(set, text)
	end
	if (cacheSizes[target] or 0) >= CACHE_LIMIT then
		table.clear(cache)
		cacheSizes[target] = 0
	end
	cache[text] = result
	cacheSizes[target] = (cacheSizes[target] or 0) + 1
	return result
end

-- Raccourci côté client : traduit dans la langue de ce joueur (pour un texte qui ne passe pas par un TextLabel).
function Lang.t(text: string): string
	return Lang.translate(text, Lang.current())
end

----------------------------------------------------------------------
-- Outils (tests Studio, luau.exe)
----------------------------------------------------------------------

-- Langue traduite d'un argument des outils ("en" par défaut), ou nil pour le français (il n'a pas de dictionnaire).
local function toolLanguage(language: string?): string?
	local target = Lang.fromLocale(language or Lang.ENGLISH)
	return if target == Lang.FRENCH then nil else target
end

-- Ajoute un dictionnaire { ["texte français"] = "traduction" } à une langue ("en" par défaut ; hors de Roblox : les
-- fichiers de LangEN, LangES, LangPT, voir tools/lang/load.luau). Dans Roblox, le dossier de la langue est lu
-- d'abord : ses traductions gardent la priorité.
function Lang.addDictionary(dictionary: { [string]: string }, name: string?, language: string?)
	local target = toolLanguage(language)
	if not target then
		problem(`{name or "?"} : le français n'a pas de dictionnaire (c'est la langue du jeu)`)
		return
	end
	local set = getSet(target)
	loadFolder(set)
	addEntries(set, dictionary, name or "?")
end

-- Nombre de traductions chargées dans une langue ("en" par défaut).
function Lang.entryCount(language: string?): number
	local target = toolLanguage(language)
	if not target then
		return 0
	end
	local set = getSet(target)
	ensureReady(set)
	return set.entryCount
end

-- Problèmes trouvés dans les dictionnaires de toutes les langues (doublons, modèles impossibles...).
function Lang.getProblems(): { string }
	for language in Lang.FOLDERS do
		ensureReady(getSet(language))
	end
	return table.clone(problems)
end

-- Textes sans traduction notés dans une langue ("en" par défaut), dans l'ordre où ils sont apparus. En espagnol et en
-- portugais, les textes pris en anglais y sont aussi. Notés dans Studio, ou après setRecordMisses(true).
function Lang.getMisses(language: string?): { string }
	local target = toolLanguage(language)
	local entry = target and misses[target]
	return if entry then table.clone(entry.list) else {}
end
-- Vide les listes de toutes les langues, et la mémoire des textes déjà traduits (chaque texte est de nouveau cherché,
-- donc noté s'il manque).
function Lang.clearMisses()
	table.clear(misses)
	clearCaches()
end
function Lang.setRecordMisses(enabled: boolean)
	recordMisses = enabled == true
end

-- Nombre de textes gardés en mémoire pour cette langue (tests).
function Lang.cacheSize(language: string?): number
	return cacheSizes[Lang.fromLocale(language or Lang.ENGLISH)] or 0
end

-- Tests hors de Roblox : oublie tous les dictionnaires ajoutés, la mémoire et les listes des textes sans traduction.
function Lang.reset()
	table.clear(sets)
	table.clear(problems)
	table.clear(caches)
	table.clear(cacheSizes)
	table.clear(misses)
end

return Lang
