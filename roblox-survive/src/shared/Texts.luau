-- Tous les textes du jeu, en français et en anglais. Le joueur voit le français si son Roblox est en français,
-- l'anglais sinon. Ajouter un texte = une ligne dans chaque langue.
local Texts = {}

Texts.fr = {
	gym = "SALLE DE SPORT",
	room = "SALLE %s",
	toRooms = "LES SALLES",
	coins = "pièces",
	Speed = "Tapis de course",
	Jump = "Trampoline",
	Force = "Musculation",
	statSpeed = "Vitesse",
	statJump = "Saut",
	statForce = "Force",
	level = "Niveau %d / %d",
	next = "Suivant : %s pièces",
	max = "NIVEAU MAXIMUM",
	upgrade = "Améliorer (%s pièces)",
	maxed = "Au maximum",
	bought = "%s : niveau %d !",
	poor = "Il te manque %s pièces",
	Lava = "LA LAVE MONTE !",
	Meteors = "PLUIE DE MÉTÉORITES !",
	Explosions = "EXPLOSIONS !",
	Ceiling = "LE PLAFOND TOMBE !",
	hintLava = "Grimpe le parcours",
	hintMeteors = "Évite les cercles rouges",
	hintExplosions = "Quitte les dalles rouges",
	hintCeiling = "Monte tout en haut, puis appuie vite sur E pour le repousser",
	prepare = "Prépare-toi… %d",
	doorOpen = "La porte est ouverte !",
	win = "SALLE %d RÉUSSIE !  +%s pièces",
	half = "+%s pièces pour avoir tenu %d secondes",
	finished = "BRAVO ! Tu as fini les %d salles !",
	ceiling = "PLAFOND",
	push = "POUSSE !",
	pushKey = "Appuie vite sur E",
	shortcut = "RACCOURCI\nSALLE %d",
	shortcutGo = "Aller à la salle %d",
	shortcutLocked = "Réussis la salle %d pour ouvrir ce raccourci",
	back = "Retour à la salle de sport",
	lift = "POUSSE ICI",
}

Texts.en = {
	gym = "GYM",
	room = "ROOM %s",
	toRooms = "THE ROOMS",
	coins = "coins",
	Speed = "Treadmill",
	Jump = "Trampoline",
	Force = "Weights",
	statSpeed = "Speed",
	statJump = "Jump",
	statForce = "Strength",
	level = "Level %d / %d",
	next = "Next: %s coins",
	max = "MAX LEVEL",
	upgrade = "Upgrade (%s coins)",
	maxed = "Maxed out",
	bought = "%s: level %d!",
	poor = "You need %s more coins",
	Lava = "THE LAVA IS RISING!",
	Meteors = "METEOR SHOWER!",
	Explosions = "EXPLOSIONS!",
	Ceiling = "THE CEILING IS FALLING!",
	hintLava = "Climb the course",
	hintMeteors = "Avoid the red circles",
	hintExplosions = "Get off the red tiles",
	hintCeiling = "Climb to the top, then mash E to push it back",
	prepare = "Get ready… %d",
	doorOpen = "The door is open!",
	win = "ROOM %d CLEARED!  +%s coins",
	half = "+%s coins for lasting %d seconds",
	finished = "WELL DONE! You cleared all %d rooms!",
	ceiling = "CEILING",
	push = "PUSH!",
	pushKey = "Mash E",
	shortcut = "SHORTCUT\nROOM %d",
	shortcutGo = "Go to room %d",
	shortcutLocked = "Clear room %d to open this shortcut",
	back = "Back to the gym",
	lift = "PUSH HERE",
}

Texts.ICONS = { Lava = "🌋", Meteors = "☄️", Explosions = "💣", Ceiling = "💪" }

-- 1 500 -> « 1 500 » (français) ou « 1,500 » (anglais).
function Texts.number(lang: string, value: number): string
	local text = tostring(math.floor(value))
	local separator = if lang == "fr" then " " else ","
	local result = text:reverse():gsub("(%d%d%d)", "%1" .. separator):reverse()
	if result:sub(1, #separator) == separator then
		result = result:sub(#separator + 1)
	end
	return result
end

function Texts.get(lang: string, key: string, ...): string
	local dictionary = Texts[lang] or Texts.en
	local text = dictionary[key] or Texts.en[key] or key
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end

return Texts
