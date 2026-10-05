-- Tests de src/client/AutoTranslate.luau (avec le vrai Lang.luau et le vrai Glossaire) dans le faux Roblox de
-- autotranslate-mock.luau. Lancés par : node tools/lang/autotranslate-test.cjs (4 fois : événements immédiats ou
-- différés, joueur français qui passe en anglais ou joueur anglais dès le départ).
local mode, startLanguage = ...
DEFERRED = mode == "deferred"
startLanguage = startLanguage or "fr"
print(`--- événements {mode}, langue au départ {startLanguage}`)
local settle = flush

-- Interface et monde AVANT le départ d'AutoTranslate
local screen = new("ScreenGui", { Name = "HUD", Parent = playerGui })
local title = new("TextLabel", { Name = "Title", Text = "Archer du rempart", Parent = screen })
local button = new("TextButton", { Text = "Suivant", Parent = screen })
local box = new("TextBox", { Text = "Archer du rempart", Parent = screen })
local numbers = new("TextLabel", { Text = "💰 1.5K", Parent = screen })
local studioGui = new("ScreenGui", { Name = "SoundPanel", Parent = playerGui })
studioGui:SetAttribute("NoTranslate", true)
local studioLabel = new("TextLabel", { Text = "Suivant", Parent = studioGui })
local nameLabel = new("TextLabel", { Text = "Maël", Parent = screen })
local part = new("Part", { Parent = work })
local billboard = new("BillboardGui", { Parent = part })
local worldLabel = new("TextLabel", { Text = "Vague 7", Parent = billboard })
local prompt = new("ProximityPrompt", { ActionText = "Ouvrir", ObjectText = "Totem de givre", Parent = part })

localPlayer:SetAttribute("Lang", startLanguage)
local AutoTranslate = load(new("ModuleScript", { Name = "AutoTranslate" }))
AutoTranslate.start()
settle()
local studio = localPlayer:FindFirstChild("AutoTranslateStudio")
check(studio ~= nil, "BindableFunction Studio créée")

if startLanguage == "fr" then
	same("français : texte inchangé", title.Text, "Archer du rempart")
	same("français : aucune écriture", title._writes, 0)
	same("français : seul le bouclier écoute l'écran", playerGui.DescendantAdded:count(), 1)
	same("français : seul le bouclier écoute le monde", work.DescendantAdded:count(), 1)
	same("français : aucun texte suivi", studio:Invoke("Tracked"), 0)
	same("français : langue", AutoTranslate.language(), "fr")
	same("français : AutoLocalize d'un texte inchangé", title.AutoLocalize, true)
	-- Le bouclier : Roblox ne traduit rien du jeu, même pour un joueur français (écrans, panneaux du monde, invites)
	same("français : écran protégé", screen.AutoLocalize, false)
	same("français : écran d'un outil Studio protégé", studioGui.AutoLocalize, false)
	same("français : panneau du monde protégé", billboard.AutoLocalize, false)
	same("français : invite protégée", prompt.AutoLocalize, false)
	same("français : un objet sans texte n'est pas touché", part.AutoLocalize, true)
	local frenchGui = new("ScreenGui", { Name = "Later", Parent = playerGui })
	local frenchPanel = new("SurfaceGui", { Parent = part })
	local frenchPrompt = new("ProximityPrompt", { ActionText = "Ouvrir", Parent = part })
	settle()
	same("français : nouvel écran protégé", frenchGui.AutoLocalize, false)
	same("français : nouveau panneau protégé", frenchPanel.AutoLocalize, false)
	same("français : nouvelle invite protégée", frenchPrompt.AutoLocalize, false)
	same("français : nouvelle invite pas traduite", frenchPrompt.ActionText, "Ouvrir")
	same("français : toujours aucune écriture", title._writes, 0)
	-- Passage en anglais en direct
	localPlayer:SetAttribute("Lang", "en")
	settle()
end

same("anglais : langue", AutoTranslate.language(), "en")
same("anglais : nom traduit", title.Text, "Rampart Archer")
same("anglais : bouton traduit", button.Text, "Next")
same("anglais : TextBox jamais touchée", box.Text, "Archer du rempart")
same("anglais : nombres inchangés", numbers.Text, "💰 1.5K")
same("anglais : nombres jamais réécrits", numbers._writes, 0)
same("anglais : outil Studio (NoTranslate) pas traduit", studioLabel.Text, "Suivant")
same("anglais : nom du joueur pas traduit", nameLabel.Text, "Maël")
same("anglais : panneau du monde traduit", worldLabel.Text, "Wave 7")
same("anglais : invite ActionText", prompt.ActionText, "Open")
same("anglais : invite ObjectText", prompt.ObjectText, "Frost Totem")
same("anglais : Studio Language", studio:Invoke("Language"), "en")
same("anglais : texte d'origine (Studio)", studio:Invoke("Original", title), "Archer du rempart")
same("anglais : texte d'origine (API)", AutoTranslate.original(title), "Archer du rempart")
same("anglais : texte d'origine d'une invite", studio:Invoke("Original", prompt, "ObjectText"), "Totem de givre")
-- La traduction automatique de Roblox ne touche jamais un texte traduit par nous (AutoLocalize = false)
same("anglais : AutoLocalize coupé (texte)", title.AutoLocalize, false)
same("anglais : AutoLocalize coupé (invite)", prompt.AutoLocalize, false)
same("anglais : écran protégé (bouclier)", screen.AutoLocalize, false)
same("anglais : panneau du monde protégé (bouclier)", billboard.AutoLocalize, false)
same("anglais : écran d'un outil Studio protégé (bouclier)", studioGui.AutoLocalize, false)
same("anglais : AutoLocalize de la TextBox inchangé", box.AutoLocalize, true)
same("anglais : AutoLocalize d'un outil Studio inchangé", studioLabel.AutoLocalize, true)

-- Nouveaux textes
local later = new("TextLabel", { Text = "Suivant", Parent = screen })
settle()
same("nouveau texte traduit", later.Text, "Next")
local gui2 = new("ScreenGui", { Name = "Other" })
local frame = new("Frame", { Parent = gui2 })
local nested = new("TextLabel", { Text = "Vague 3", Parent = frame })
gui2.Parent = playerGui
settle()
same("nouvel écran entier traduit", nested.Text, "Wave 3")
same("nouvel écran protégé (bouclier)", gui2.AutoLocalize, false)

-- Le jeu change ses textes
worldLabel.Text = "Vague 8"
settle()
same("texte changé par le jeu : retraduit", worldLabel.Text, "Wave 8")
local writesBefore = worldLabel._writes
worldLabel.Text = "Vague 8"
settle()
same("même texte français réécrit : traduit", worldLabel.Text, "Wave 8")
check(worldLabel._writes - writesBefore <= 2, "réécriture : 2 écritures au plus", worldLabel._writes - writesBefore)
worldLabel.Text = "Vague 11"
worldLabel.Text = "Vague 12"
settle()
same("deux changements d'affilée : le dernier gagne", worldLabel.Text, "Wave 12")
worldLabel.Text = "Texte inconnu"
settle()
same("texte inconnu gardé", worldLabel.Text, "Texte inconnu")
check(table.find(studio:Invoke("Misses"), "Texte inconnu") ~= nil, "texte inconnu noté (Studio)")
worldLabel.Text = "12:34"
settle()
same("texte sans mot gardé", worldLabel.Text, "12:34")
worldLabel.Text = "Vague 9"
settle()
same("de nouveau traduit", worldLabel.Text, "Wave 9")
same("texte d'origine suivi", AutoTranslate.original(worldLabel), "Vague 9")
-- Nombre seul écrit à la française (ex. « 7,5 ») : écriture anglaise, puis retour
local decimal = new("TextLabel", { Text = "7,5", Parent = screen })
settle()
same("nombre seul : virgule -> point", decimal.Text, "7.5")
same("nombre seul : texte d'origine", AutoTranslate.original(decimal), "7,5")

-- Objet détruit : oublié (par Destroying, ou par le ménage quand Destroying n'arrive pas, en mode différé)
local tracked = studio:Invoke("Tracked")
later:Destroy()
settle()
same("objet détruit oublié", studio:Invoke("Tracked"), tracked - 1)

-- Objet retiré sans être détruit, puis remis
local floating = new("TextLabel", { Text = "Suivant", Parent = screen })
settle()
same("objet retiré : traduit avant", floating.Text, "Next")
floating.Parent = nil
settle()
local trackedNow = studio:Invoke("Tracked") -- (fait le ménage : objets sortis du jeu)
same("objet retiré : texte français remis", floating.Text, "Suivant")
same("objet retiré : plus suivi", trackedNow, tracked - 1)
floating.Parent = screen
settle()
same("objet remis : traduit de nouveau", floating.Text, "Next")
same("objet remis : texte d'origine français", AutoTranslate.original(floating), "Suivant")
local moved = new("TextLabel", { Text = "Vague 4", Parent = screen })
settle()
moved.Parent = billboard -- (déplacé sans passer hors du jeu : toujours suivi)
settle()
same("objet déplacé : toujours traduit", moved.Text, "Wave 4")
moved.Text = "Vague 5"
settle()
same("objet déplacé : toujours suivi", moved.Text, "Wave 5")

-- Invite changée par le serveur
prompt.ObjectText = "Catapulte"
settle()
same("invite changée : retraduite", prompt.ObjectText, "Catapult")

-- Retour au français en direct
localPlayer:SetAttribute("Lang", "fr")
settle()
same("retour : nom", title.Text, "Archer du rempart")
same("retour : bouton", button.Text, "Suivant")
same("retour : texte changé pendant l'anglais", worldLabel.Text, "Vague 9")
same("retour : écran ajouté pendant l'anglais", nested.Text, "Vague 3")
same("retour : invite ActionText", prompt.ActionText, "Ouvrir")
same("retour : invite ObjectText", prompt.ObjectText, "Catapulte")
same("retour : TextBox", box.Text, "Archer du rempart")
same("retour : nombre seul", decimal.Text, "7,5")
same("retour : AutoLocalize remis (texte)", title.AutoLocalize, true)
same("retour : invite toujours protégée (bouclier)", prompt.AutoLocalize, false)
same("retour : écran toujours protégé (bouclier)", screen.AutoLocalize, false)
same("retour : plus rien de suivi", studio:Invoke("Tracked"), 0)
same("retour : seul le bouclier écoute l'écran", playerGui.DescendantAdded:count(), 1)
same("retour : seul le bouclier écoute le monde", work.DescendantAdded:count(), 1)
same("retour : plus d'écoute des textes", title:propertyConnections("Text"), 0)
same("retour : plus d'écoute des invites", prompt:propertyConnections("ObjectText"), 0)
worldLabel.Text = "Vague 10"
settle()
same("en français, le jeu écrit sans traduction", worldLabel.Text, "Vague 10")
local added = new("TextLabel", { Text = "Suivant", Parent = screen })
settle()
same("en français, nouveau texte gardé", added.Text, "Suivant")

-- De nouveau l'anglais
localPlayer:SetAttribute("Lang", "en")
settle()
same("anglais encore : texte changé en français", worldLabel.Text, "Wave 10")
same("anglais encore : texte ajouté en français", added.Text, "Next")
same("anglais encore : nom", title.Text, "Rampart Archer")

-- L'espagnol en direct (depuis l'anglais), puis le portugais : chaque texte repart de son français et se traduit ;
-- un texte absent de leurs dictionnaires est pris en anglais (et noté)
localPlayer:SetAttribute("Lang", "es")
settle()
same("espagnol : langue", AutoTranslate.language(), "es")
same("espagnol : nom traduit", title.Text, "Arquero de la muralla")
same("espagnol : bouton traduit", button.Text, "Siguiente")
same("espagnol : panneau du monde", worldLabel.Text, "Oleada 10")
same("espagnol : invite ActionText", prompt.ActionText, "Abrir")
same("espagnol : ligne absente -> anglais", prompt.ObjectText, "Catapult")
check(table.find(studio:Invoke("Misses", "es"), "Catapulte") ~= nil, "espagnol : texte pris en anglais noté (Studio)")
same("espagnol : nombre seul, virgule gardée", decimal.Text, "7,5")
same("espagnol : TextBox jamais touchée", box.Text, "Archer du rempart")
same("espagnol : texte d'origine", AutoTranslate.original(title), "Archer du rempart")
localPlayer:SetAttribute("Lang", "pt")
settle()
same("portugais : langue", AutoTranslate.language(), "pt")
same("portugais : bouton traduit", button.Text, "Próximo")
same("portugais : nom absent -> anglais", title.Text, "Rampart Archer")
same("portugais : panneau du monde", worldLabel.Text, "Onda 10")
localPlayer:SetAttribute("Lang", "en")
settle()
same("anglais de nouveau : bouton", button.Text, "Next")
same("anglais de nouveau : nombre seul", decimal.Text, "7.5")

-- Rapidité : 2000 textes qui apparaissent, puis 20 000 réécritures en français (déjà traduites)
local started = os.clock()
local many = {}
for index = 1, 2000 do
	many[index] = new("TextLabel", { Text = "Vague " .. index, Parent = screen })
end
settle()
local appear = (os.clock() - started) / 2000 * 1e6
started = os.clock()
for _ = 1, 10 do
	for index = 1, 2000 do
		many[index].Text = "Vague " .. index
	end
	settle()
end
local rewrite = (os.clock() - started) / 20000 * 1e6
same("rapidité : textes traduits", many[1500].Text, "Wave 1500")
print(string.format("rapidité (faux Roblox) : %.1f µs par texte qui apparaît, %.1f µs par réécriture en français", appear, rewrite))
