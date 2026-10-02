-- Qui reçoit les cibles et les tirs du camp d'entraînement de chaque parcelle (map principale).
--
-- Le serveur n'envoie le paquet des cibles (PlotSync) et celui des tirs (PlotShots) d'une parcelle qu'aux
-- joueurs qui peuvent la voir : de ta parcelle, tu ne reçois pas les cibles et les tirs des autres (ça
-- ferait ramer les téléphones pour rien), seulement quand tu t'approches de leur parcelle.
--
-- La règle, pour une parcelle :
--   * son propriétaire la reçoit TOUJOURS, où qu'il soit ;
--   * un autre joueur commence à la recevoir quand son personnage est à moins de ENTER_MARGIN studs de son
--     terrain (le rectangle PlotLayout.WIDTH x PlotLayout.LENGTH, distance à plat, 0 dessus) ET plus près
--     d'elle que de sa propre parcelle (d'au moins CLOSER_MARGIN studs) ;
--   * il arrête de la recevoir à plus de LEAVE_MARGIN studs, ou quand il est plus près de sa parcelle que
--     d'elle (de plus de CLOSER_MARGIN studs). Les deux écarts (22 / 28 et ± 5) évitent le clignotement
--     quand on marche juste sur le bord (hystérésis) ;
--   * sans personnage (mort, en train d'apparaître) : seulement sa parcelle.
-- Pourquoi « plus près d'elle que de la tienne » : côté place centrale, deux parcelles voisines ne sont qu'à
-- ~20 studs l'une de l'autre (coins intérieurs). Avec la marge seule, on recevrait sa voisine en restant dans
-- le coin de sa parcelle. Avec cette règle, sur ta parcelle et devant ses deux bâtiments, tu ne reçois que
-- la tienne.
--
-- Hub/init.luau appelle compute quelques fois par seconde (REFRESH_INTERVAL) avec la position des joueurs,
-- envoie les paquets aux joueurs de la liste, et un paquet « Clear » (PlotSync) à ceux qui viennent d'arrêter
-- de recevoir une parcelle : leur client l'efface tout de suite (PlotRenderer). Aucune autre donnée du jeu
-- n'est lue ici : les tests Studio appellent ces fonctions avec de fausses positions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotLayout = require(ReplicatedStorage:WaitForChild("Shared").PlotLayout)

local PlotInterest = {}

PlotInterest.ENTER_MARGIN = 22 -- studs autour du terrain pour commencer à recevoir une parcelle
PlotInterest.LEAVE_MARGIN = 28 -- studs autour du terrain pour arrêter (un peu plus loin : pas de clignotement)
PlotInterest.CLOSER_MARGIN = 5 -- écart pour « plus près d'elle que de ta parcelle » (même idée)
PlotInterest.REFRESH_INTERVAL = 0.25 -- secondes entre deux calculs de « qui est près » (pas à chaque image)

-- Distance à plat (studs) entre une position du monde et le terrain d'une parcelle : 0 dessus.
function PlotInterest.distanceTo(plotIndex: number, position: Vector3): number
	local offset = PlotLayout.toLocal(plotIndex, position)
	local dx = math.max(math.abs(offset.X) - PlotLayout.WIDTH / 2, 0)
	local dz = math.max(math.abs(offset.Z) - PlotLayout.LENGTH / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Règle pour UN joueur et UNE parcelle qui n'est pas la sienne : vrai s'il doit la recevoir.
-- position = position de son personnage (nil = pas de personnage), ownIndex = sa parcelle (nil = aucune),
-- wasNear = il la recevait déjà (il faut aller un peu plus loin pour arrêter que pour commencer).
function PlotInterest.isNear(plotIndex: number, position: Vector3?, ownIndex: number?, wasNear: boolean?): boolean
	if not position then
		return false
	end
	local distance = PlotInterest.distanceTo(plotIndex, position)
	local ownDistance = if ownIndex then PlotInterest.distanceTo(ownIndex, position) else math.huge
	if wasNear then
		return distance <= PlotInterest.LEAVE_MARGIN and distance <= ownDistance + PlotInterest.CLOSER_MARGIN
	end
	return distance <= PlotInterest.ENTER_MARGIN and distance + PlotInterest.CLOSER_MARGIN <= ownDistance
end

-- Calcul complet, quelques fois par seconde.
--   viewers = liste de { key = le joueur (n'importe quelle valeur dans les tests), position = Vector3?, plot = number? }
--   near = mémoire gardée entre deux appels : [key] = { [plotIndex] = true } (parcelles des AUTRES qu'il reçoit).
--          Mise à jour ici ; les joueurs absents de viewers en sont retirés.
-- Renvoie :
--   recipients = { [plotIndex] = { key, ... } } : qui reçoit chaque parcelle (son propriétaire compris) ;
--   leaving = liste de { key, plotIndex } : parcelles que ce joueur vient d'arrêter de recevoir (à effacer chez lui).
function PlotInterest.compute(viewers, near)
	local recipients = {}
	for plotIndex = 1, PlotLayout.COUNT do
		recipients[plotIndex] = {}
	end
	local leaving = {}
	local present = {}
	for _, viewer in viewers do
		local key = viewer.key
		present[key] = true
		local previous = near[key] or {}
		local current = {}
		for plotIndex = 1, PlotLayout.COUNT do
			if plotIndex == viewer.plot then
				table.insert(recipients[plotIndex], key) -- sa parcelle : toujours
			elseif PlotInterest.isNear(plotIndex, viewer.position, viewer.plot, previous[plotIndex]) then
				current[plotIndex] = true
				table.insert(recipients[plotIndex], key)
			elseif previous[plotIndex] then
				table.insert(leaving, { key = key, plotIndex = plotIndex })
			end
		end
		near[key] = current
	end
	for key in near do
		if not present[key] then
			near[key] = nil -- joueur parti
		end
	end
	return recipients, leaving
end

return PlotInterest
