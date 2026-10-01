-- Dictionnaire anglais : ta PARCELLE et ses tours.
-- Textes de src/client/PlotUI.luau (compteur de pièces, panneau des emplacements, cartes et fiches des tours, runes
-- à poser, remplacement, vente), TowerCard.luau et TowerPlacement.luau (fiche et pose des tours du match classé),
-- PlotRenderer.luau (textes flottants : « Niv. X », montants des pièces...) et Effects.luau, et des modules partagés :
-- IdleTowers.luau (noms, descriptions, « idéale contre », sortes de tours, limite de tours identiques), IdleConfig.luau
-- (raretés, runes, types de vagues...), Enemies.luau et Towers.luau (tours du classé).
-- Une ligne : ["texte français exact"] = "English", ; un texte qui change : {1}, {2}... (mode d'emploi en haut de
-- Shared/Lang.luau). Noms du jeu : Glossary.luau.
-- Les textes avec « " » (balises <font color="...">) sont écrits entre apostrophes droites : '...'.
-- Une longue fiche (plusieurs lignes, morceaux séparés par « • » ou « · ») est traduite ligne par ligne, puis
-- morceau par morceau : chaque ligne ou morceau a donc sa propre ligne ici.
-- Vérifier : luau.exe tools/lang/check.luau (depuis roblox-ranked-td).
return {
	["Détails & effets"] = "Details & effects",
	["← Statistiques"] = "← Stats",
	["Choisis ta tour • utilise ◀ ▶ pour les autres"] = "Pick your tower • use ◀ ▶ for more",
	----------------------------------------------------------------------
	-- Tours du mode solo (IdleTowers.luau) : descriptions. Les nombres viennent des réglages : {1}, {2}...
	----------------------------------------------------------------------
	["Flèches enflammées : chaque flèche laisse une petite zone de feu qui brûle les ennemis ({1} % de ses dégâts par seconde)."] = "Fire arrows: each arrow leaves a small fire zone that burns enemies ({1}% of its damage per second).",
	["Ralentit de {1} % tout ce qui passe dans son aura et rend ces ennemis fragiles : +{2} % de dégâts reçus de tes autres tours (sauf le Mage des tempêtes), +{3} % par niveau."] = "Slows everything in its aura by {1}% and makes those enemies fragile: +{2}% damage taken from your other towers (except the Storm Mage), +{3}% per level.",
	["Projette des rochers sur une zone : idéale contre les hordes."] = "Hurls boulders onto an area: great against hordes.",
	["Foudroie une petite zone et ralentit très fort (-{1} %) mais brièvement les ennemis touchés. Ne se cumule pas avec le Totem de givre."] = "Strikes a small area with lightning: a very strong but brief slow (-{1}%) on the enemies hit. Doesn't stack with the Frost Totem.",
	["Un carreau perçant à longue portée : il vise le plus résistant (entre ennemis presque aussi résistants, celui qui en aligne le plus) et transperce jusqu'à {1} ennemis sur sa ligne."] = "A long-range piercing bolt: it targets the toughest enemy (if several are almost as tough, the one lining up the most enemies) and pierces up to {1} enemies in its line.",
	["Rayon continu : ses dégâts montent tant qu'il reste sur la même cible (jusqu'à x{1}). Terrible contre les boss et les colosses, faible contre les ennemis rapides."] = "Continuous beam: its damage ramps up while it stays on the same target (up to x{1}). Deadly against bosses and colossi, weak against fast enemies.",
	["Un éclair ancien rebondit entre quatre ennemis."] = "An ancient lightning bolt bounces between four enemies.",
	["Une pierre runique écrase le plus gros groupe d'ennemis à portée et les étourdit un instant."] = "A runic stone crushes the biggest group of enemies in range and stuns them for a moment.",

	-- « Idéale contre : ... » (idealAgainst)
	["les files d'ennemis et l'escorte des boss (le feu brûle ceux qui suivent)"] = "lines of enemies and boss escorts (the fire burns those behind)",
	["les Charges de cavalerie et les Levées ; rend tes autres tours plus fortes"] = "Cavalry Charges and Squire Levies; makes your other towers stronger",
	["les foules tassées (Levées d'écuyers)"] = "packed crowds (Squire Levies)",
	["les petits groupes rapides (cavaliers) : coups de frein très forts"] = "small fast groups (riders): very strong slows",
	["les chevaliers lourds, les boss et les petits groupes alignés ({1} ennemis au plus par carreau)"] = "heavy knights, bosses and small lined-up groups ({1} enemies max per bolt)",
	["les boss, les colosses et les ennemis lents"] = "bosses, colossi and slow enemies",
	["les vagues nombreuses (4 ennemis par éclair)"] = "large waves (4 enemies per strike)",
	["les grosses foules, n'importe où sur le chemin (faible contre un boss seul)"] = "big crowds, anywhere on the path (weak against a lone boss)",

	-- Limite de tours identiques (IdleTowers.copiesText, copiesLimitMessage : cartes, fiche, messages du serveur)
	["{1}/{2} posées"] = "{1}/{2} placed",
	["Maximum {1} {2} sur ta parcelle ({3})"] = "{2}: max {1} on your plot ({3})",
	["Maximum {1} {2} sur ta parcelle ({3}) : vends-en une pour en poser une autre"] = "{2}: max {1} on your plot ({3}). Sell one to place another",

	----------------------------------------------------------------------
	-- Panneau des tours de ta parcelle (PlotUI.luau)
	----------------------------------------------------------------------
	["TRÉSOR DU FIEF"] = "KEEP TREASURY",
	["X"] = "X", -- (bouton fermer : rien à traduire, évite juste un « texte sans traduction »)
	["🔒 Emplacement {1}"] = "🔒 Spot {1}",
	["Emplacement {1}"] = "Spot {1}",
	["Débloque-le pour y poser une tour. Chaque achat augmente le prix des suivants."] = "Unlock it to place a tower here. Each purchase raises the price of the next ones.",
	["Débloquer • {1} pièces"] = "Unlock • {1} coins",
	["Pose en cours…"] = "Placing…",
	["Choisis une tour à poser (survole une carte : contre quoi elle est idéale) :"] = "Pick a tower to place (hover a card to see what it's best against):",
	["{1} • idéale contre : {2}"] = "{1} • best against: {2}",
	["{1} • Niv. {2}"] = "{1} • Lv. {2}",
	["Remplacer : {1} • Niv. {2}"] = "Replace: {1} • Lv. {2}",
	["Choisis la nouvelle tour (elle repart au niveau 1 ; tu récupères {1} % : +{2}) :"] = "Pick the new tower (it restarts at level 1; you get back {1}%: +{2}):",
	["Remplacement en cours…"] = "Replacing…",
	["Remplacer…"] = "Replace…",
	["Remplacement : retour au niveau 1, avec confirmation"] = "Replacing: back to level 1, with confirmation",
	["← Garder ma tour"] = "← Keep my tower",
	["Annuler"] = "Cancel",
	["Confirmer le remplacement"] = "Confirm replacement",
	["Améliorer [E] • {1}"] = "Upgrade [E] • {1}",
	["Confirmer la vente • +{1}"] = "Confirm sale • +{1}",
	["Vendre • +{1}"] = "Sell • +{1}",

	-- Messages (toasts) du panneau
	["{1} : invoque-la à l'autel des héros !"] = "{1}: summon it at the Heroes' Altar!",
	["Il te faut {1} pièces"] = "You need {1} coins",
	["Cette tour est déjà posée ici"] = "This tower is already placed here",
	["La tour a changé entre-temps : rien n'a été remplacé"] = "The tower changed in the meantime: nothing was replaced",

	-- Cartes des tours : sorte de tour (kindLabel)
	["Cible unique"] = "Single target",
	["Zone"] = "Area",
	["Zone autour"] = "Area around",
	["Chaîne (4 cibles)"] = "Chain (4 targets)",
	["Rayon continu"] = "Continuous beam",
	["Carreau perçant"] = "Piercing bolt",
	["Flèches de feu"] = "Fire arrows",
	["Contrôle + fragilité"] = "Control + fragility",
	["Vise la foule + étourdit"] = "Targets crowds + stuns",
	["Zone + gros frein"] = "Area + strong slow",
	["Ralentit 1 cible"] = "Slows 1 target",

	-- Cartes des tours : chiffres (morceaux séparés par « · »)
	["DÉGÂTS PAR COUP"] = "DAMAGE PER HIT",
	["dégâts/s · max {1}"] = "damage/s · max {1}",
	["{1} atq/s"] = "{1} atk/s", -- (UI.attackSpeed)
	["continu"] = "continuous", -- (UI.towerSpeed : rayon du Sorcier)
	["portée {1}"] = "range {1}",
	["Zone rayon {1}"] = "Area radius {1}",
	["Perce {1} ennemis"] = "Pierces {1} enemies",
	["Aura rayon {1}"] = "Aura radius {1}",
	["{1} cibles"] = "{1} targets",
	["1 cible"] = "1 target",
	["Étourdit {1} s"] = "Stuns {1} s",
	["Ralentit {1} %"] = "Slows {1}%",
	["Fragilité +{1} %"] = "Fragility +{1}%",
	["Feu {1}/s"] = "Fire {1}/s",
	["x{1} en {2} s"] = "x{1} in {2} s",
	["🔒 Autel"] = "🔒 Altar",
	["POSÉE"] = "PLACED",
	["COMPLET"] = "FULL",

	-- Fiche d'une tour posée : chiffres du haut
	["DÉGÂTS / COUP"] = "DAMAGE / HIT",
	["DÉGÂTS / SECONDE"] = "DAMAGE / SECOND",
	["CADENCE"] = "FIRE RATE",
	["PORTÉE"] = "RANGE",
	["max {1}"] = "max {1}",
	["Niv. {1} : {2}"] = "Lv. {1}: {2}",
	["Attaques par seconde"] = "Attacks per second",
	["studs"] = "studs",

	-- Fiche d'une tour posée : 1re ligne (dégâts, niveau suivant, vitesse, portée), entière puis en morceaux
	["Dégâts <b>{1}</b> par coup  →  {2} au niveau {3}  •  <b>{4}</b>  •  Portée <b>{5}</b>"] = "Damage <b>{1}</b> per hit  →  {2} at level {3}  •  <b>{4}</b>  •  Range <b>{5}</b>",
	["Rayon <b>{1} → {2}</b> dégâts/s  →  {3} → {4} au niveau {5}  •  <b>continu</b>  •  Portée <b>{6}</b>"] = "Beam <b>{1} → {2}</b> damage/s  →  {3} → {4} at level {5}  •  <b>continuous</b>  •  Range <b>{6}</b>",
	["Dégâts <b>{1}</b> par coup  →  {2} au niveau {3}"] = "Damage <b>{1}</b> per hit  →  {2} at level {3}",
	["Rayon <b>{1} → {2}</b> dégâts/s  →  {3} → {4} au niveau {5}"] = "Beam <b>{1} → {2}</b> damage/s  →  {3} → {4} at level {5}",
	["Portée <b>{1}</b>"] = "Range <b>{1}</b>",

	-- Fiche : qui la tour touche et comment elle vise
	["Zone : rayon <b>{1}</b> studs autour de l'impact"] = "Area: <b>{1}</b>-stud radius around the impact",
	["Carreau perçant : jusqu'à <b>{1}</b> ennemis, sa cible et les premiers sur sa ligne (largeur <b>{2}</b> studs)"] = "Piercing bolt: up to <b>{1}</b> enemies, its target and the first ones in its line (<b>{2}</b> studs wide)",
	["Aura : tous les ennemis à <b>{1}</b> studs"] = "Aura: all enemies within <b>{1}</b> studs",
	["Éclair sur <b>{1}</b> ennemis (les plus avancés)"] = "Lightning hits <b>{1}</b> enemies (the furthest ahead)",
	["Rayon sur 1 cible, gardée tant qu'elle est à portée (idéal dans un virage)"] = "Beam on 1 target, kept while it stays in range (ideal on a bend)",
	["vise le plus gros groupe du chemin"] = "targets the biggest group on the path",
	["choisit le plus résistant"] = "picks the toughest",
	["vise le plus résistant"] = "targets the toughest",
	["vise le plus avancé"] = "targets the enemy furthest ahead",

	-- Fiche : effets (contrôle, fragilité, feu, montée du rayon)
	["Étourdit <b>{1} s</b> (pas de cumul avec les ralentissements)"] = "Stuns <b>{1} s</b> (doesn't stack with slows)",
	["Étourdit <b>{1} s</b>, puis {2} s d'immunité (pas de cumul avec les ralentissements)"] = "Stuns <b>{1} s</b>, then {2} s of immunity (doesn't stack with slows)",
	["Ralentit de <b>{1} %</b> pendant {2} s (pas de cumul)"] = "Slows by <b>{1}%</b> for {2} s (doesn't stack)",
	["Ralentit de <b>{1} %</b> pendant {2} s, puis {3} s d'immunité (pas de cumul)"] = "Slows by <b>{1}%</b> for {2} s, then {3} s of immunity (doesn't stack)",
	["Fragilité : <b>+{1} %</b> de dégâts reçus de tes autres tours (sauf Mage)  →  +{2} % au niveau {3}"] = "Fragility: <b>+{1}%</b> damage taken from your other towers (except Mage)  →  +{2}% at level {3}",
	["Fragilité : <b>+{1} %</b> de dégâts reçus de tes autres tours (sauf Mage) (maximum)"] = "Fragility: <b>+{1}%</b> damage taken from your other towers (except Mage) (max)",
	["Feu au sol : <b>{1}</b> dégâts/s pendant {2} s (rayon {3})"] = "Ground fire: <b>{1}</b> damage/s for {2} s (radius {3})",
	["Montée : x{1} en {2} s sur la même cible"] = "Ramp-up: x{1} in {2} s on the same target",
	["ne profite pas de la fragilité du Totem"] = "doesn't benefit from the Totem's fragility",

	-- Fiche : « Idéale contre », runes posées, doublons et limite
	['<font color="#D8AA4C">Idéale contre :</font> {1}'] = '<font color="#D8AA4C">Best against:</font> {1}',
	['<font color="#D8AA4C">Runes :</font> aucune (1 de dégâts + 1 de vitesse possibles)'] = '<font color="#D8AA4C">Runes:</font> none (1 damage + 1 speed possible)',
	['<font color="#D8AA4C">Runes :</font> {1}  •  {2}'] = '<font color="#D8AA4C">Runes:</font> {1}  •  {2}',
	['<font color="#D8AA4C">Runes :</font> {1}'] = '<font color="#D8AA4C">Runes:</font> {1}',
	["pas de rune de dégâts"] = "no damage rune",
	["pas de rune de vitesse"] = "no speed rune",
	["Doublons : {1} (+{2} % de dégâts)"] = "Duplicates: {1} (+{2}% damage)",
	['<font color="#D8AA4C">Limite :</font> {1} par parcelle ({2}) • {3}'] = '<font color="#D8AA4C">Limit:</font> {1} per plot ({2}) • {3}',
	['<font color="#D8AA4C">Limite :</font> {1} par parcelle ({2})'] = '<font color="#D8AA4C">Limit:</font> {1} per plot ({2})',
	['Doublons : {1} (+{2} % de dégâts)  •  <font color="#D8AA4C">Limite :</font> {3} par parcelle ({4}) • {5}'] = 'Duplicates: {1} (+{2}% damage)  •  <font color="#D8AA4C">Limit:</font> {3} per plot ({4}) • {5}',

	-- Runes à poser sur la tour (bas du panneau)
	["Forge des runes pour obtenir des bonus"] = "Forge runes to get bonuses",
	["Poser une rune :"] = "Place a rune:",
	["x{1} dégâts ({2})"] = "x{1} damage ({2})",
	["x{1} vitesse ({2})"] = "x{1} speed ({2})",
	["Remplacer {1} ?"] = "Replace {1}?",

	-- Confirmation du remplacement (les couleurs #xxxxxx sont des {n})
	['Remplacer ton <font color="#{1}">{2} niv. {3}</font> par <font color="#{4}">{5}</font> ?'] = 'Replace your <font color="#{1}">{2} Lv. {3}</font> with <font color="#{4}">{5}</font>?',
	["Tu récupères {1} % : <b>{2} pièces</b>."] = "You get back {1}%: <b>{2} coins</b>.",
	["{1} coûte {2} pièces et repart au <b>niveau 1</b>."] = "{1} costs {2} coins and starts over at <b>level 1</b>.",
	["Sa rune retourne dans ton inventaire : {1}."] = "Its rune goes back to your inventory: {1}.",
	["Ses runes retournent dans ton inventaire : {1}, {2}."] = "Its runes go back to your inventory: {1}, {2}.",
	['<font color="#F06464">Ton inventaire est plein : {1} sera PERDUE.</font>'] = '<font color="#F06464">Your inventory is full: {1} will be LOST.</font>',
	['<font color="#F06464">Ton inventaire est plein : {1}, {2} seront PERDUES.</font>'] = '<font color="#F06464">Your inventory is full: {1}, {2} will be LOST.</font>',

	----------------------------------------------------------------------
	-- Textes flottants des parcelles (PlotRenderer.luau)
	----------------------------------------------------------------------
	["Niv. {1}"] = "Lv. {1}",

	----------------------------------------------------------------------
	-- Runes, raretés et vagues (IdleConfig.luau)
	----------------------------------------------------------------------
	-- Noms des runes (displayName, et nom court runeShortName)
	["x2 dégâts"] = "x2 damage",
	["x3 dégâts"] = "x3 damage",
	["x5 dégâts"] = "x5 damage",
	["x10 dégâts"] = "x10 damage",
	["x20 dégâts"] = "x20 damage",
	["x50 dégâts"] = "x50 damage",
	["x100 dégâts"] = "x100 damage",
	["x2 vitesse d'attaque"] = "x2 attack speed",
	["x2 vitesse"] = "x2 speed",
	["x{1} dégâts"] = "x{1} damage", -- (une future rune)
	["x{1} vitesse"] = "x{1} speed",
	-- Sortes d'emplacement de rune (RUNE_SLOTS)
	["dégâts"] = "damage",
	["vitesse"] = "speed",
	-- Forge bloquée (FORGE_NO_TOWER, FORGE_ALL_BEST : bouton de la forge et messages)
	["Pose d'abord une tour"] = "Place a tower first",
	["Toutes tes tours ont les meilleures runes"] = "All your towers have the best runes",
	-- Raretés en majuscules (string.upper ne change pas les lettres accentuées : « LéGENDAIRE »)
	["COMMUNE"] = "COMMON",
	["RARE"] = "RARE",
	["ÉPIQUE"] = "EPIC",
	["LéGENDAIRE"] = "LEGENDARY",
	-- Types de vagues (WAVE_TYPES : pas affichés aujourd'hui)
	["Escarmouche"] = "Skirmish",
	["Levée des écuyers"] = "Squire Levy",
	["Charge de cavalerie"] = "Cavalry Charge",
	["Garde colossale"] = "Colossal Guard",
	["SEIGNEUR DE GUERRE"] = "WARLORD",
	["Fantassins, cavaliers et garde lourde"] = "Footmen, riders and heavy guards",
	["Une foule de jeunes soldats : les attaques de zone brillent"] = "A crowd of young soldiers: area attacks shine",
	["Les cavaliers sont très rapides : ralentis-les !"] = "Riders are very fast: slow them down!",
	["Un chevalier colossal : concentre tes dégâts"] = "A colossal knight: focus your damage",
	["Un immense chevalier mène l'assaut : concentre toute ta puissance"] = "A huge knight leads the assault: focus all your power",

	-- Très grand nombre (NumberFormat.short : « MAX »)
	["MAX"] = "MAX",

	----------------------------------------------------------------------
	-- Match classé : tours (Towers.luau), fiche des 3 niveaux (TowerCard.luau), pose (TowerPlacement.luau,
	-- Placement.luau). Or du match : « or » -> gold.
	----------------------------------------------------------------------
	["Archer"] = "Archer",
	["Arbalétrier"] = "Crossbowman",
	["Mage de givre"] = "Frost Mage",
	["Une pluie de flèches sur l'ennemi le plus avancé."] = "A rain of arrows on the enemy furthest ahead.",
	["Très longue portée, vise l'armure la plus résistante."] = "Very long range, targets the toughest armor.",
	["Projette des rochers qui frappent toute une zone."] = "Hurls boulders that hit a whole area.",
	["Un mage ancien ralentit et blesse les assaillants à portée."] = "An ancient mage slows and hurts attackers in range.",

	-- Fiche des 3 niveaux
	["DPS PAR CIBLE"] = "DPS PER TARGET",
	["Pose : {1} or"] = "Cost: {1} gold", -- (prix de pose, en haut à droite de la fiche)
	["{1}  Niv. {2}/{3}"] = "{1}  Lv. {2}/{3}",
	["NIV. {1}"] = "LV. {1}",
	["✓ ACQUIS"] = "✓ OWNED",
	["ACTUEL"] = "CURRENT",
	["POSE"] = "PLACE",
	["PROCHAIN"] = "NEXT",
	["{1} or"] = "{1} gold",
	-- Lignes de stats, sans puis avec l'écart avec le niveau d'avant (« (+10) » en couleur)
	["Dégâts <b>{1}</b>"] = "Damage <b>{1}</b>",
	['Dégâts <b>{1}</b> <font color="{2}">({3})</font>'] = 'Damage <b>{1}</b> <font color="{2}">({3})</font>',
	['Portée <b>{1}</b> <font color="{2}">({3})</font>'] = 'Range <b>{1}</b> <font color="{2}">({3})</font>',
	["Cadence <b>{1}s</b>"] = "Cooldown <b>{1}s</b>",
	['Cadence <b>{1}s</b> <font color="{2}">({3})</font>'] = 'Cooldown <b>{1}s</b> <font color="{2}">({3})</font>',
	["Vitesse <b>{1} atq/s</b>"] = "Speed <b>{1} atk/s</b>",
	['Vitesse <b>{1} atq/s</b> <font color="{2}">({3})</font>'] = 'Speed <b>{1} atk/s</b> <font color="{2}">({3})</font>',
	["Zone <b>{1}</b>"] = "Area <b>{1}</b>",
	['Zone <b>{1}</b> <font color="{2}">({3})</font>'] = 'Area <b>{1}</b> <font color="{2}">({3})</font>',
	["Ralenti <b>{1}%</b>"] = "Slow <b>{1}%</b>",
	['Ralenti <b>{1}%</b> <font color="{2}">({3})</font>'] = 'Slow <b>{1}%</b> <font color="{2}">({3})</font>',

	-- Pose d'une tour du match (messages)
	["Pas assez d'or"] = "Not enough gold",
	["La partie n'a pas encore commencé"] = "The match hasn't started yet",
	["Position invalide"] = "Invalid position",
	["Tu ne peux construire que sur ton terrain"] = "You can only build on your side",
	["Trop proche du chemin"] = "Too close to the path",
	["Trop proche de la base"] = "Too close to the base",
	["Trop proche d'une autre tour"] = "Too close to another tower",
}
