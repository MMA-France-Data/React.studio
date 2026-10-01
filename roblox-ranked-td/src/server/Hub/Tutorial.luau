-- Tuto des nouveaux joueurs, côté serveur (le tuto lui-même : src/client/TutorialUI.luau).
-- Le serveur garde « tuto fini » dans les données du joueur (PlayerData : tutorialDone, faux pour un nouveau
-- joueur ; les anciennes sauvegardes des joueurs qui ont déjà joué comptent comme « fini »), publié dans l'attribut
-- TutorialDone du joueur (PlayerData.refresh). Le client prévient à la fin du tuto ou quand on clique « Passer »
-- (remote TutorialAction) : le serveur vérifie le message (texte connu, numéro d'étape valable, données chargées,
-- un message toutes les 0,5 s au plus) et note le drapeau (sauvegardé avec les autres données).
-- Le tuto ne donne rien et ne change rien au classé : un nouveau joueur paie tout avec ses pièces de départ
-- (IdleConfig.STARTING_COINS = 50 : tour 10 + amélioration 20 + un lancer x1 de l'autel au record 1 = 3, total 33 ;
-- vérifié par le test Studio). Pas de lancer gratuit.
-- Studio seulement : « Replay » recommence le tuto au début (tutorialDone = faux, et l'attribut TutorialReplay
-- du joueur augmente de 1 : le client relance le tuto, même pendant les tests automatiques). Refusé dans le jeu
-- publié (RunService:IsStudio()).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankedGate = require(Shared.RankedGate)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.Parent.PlayerData)

local Tutorial = {}

Tutorial.STEP_COUNT = 6 -- nombre d'étapes du tuto quand le classé est ouvert (TutorialUI.luau)
local ACTION_COOLDOWN = 0.5 -- secondes entre deux messages acceptés d'un même joueur (anti-spam)

local lastActionAt = {} -- [Player] = os.clock() du dernier message accepté
local lastFinish = {} -- [Player] = { action, step } : dernière fin reçue (tests Studio)

-- Nombre d'étapes montrées au joueur. Classé fermé (Config.RANKED_OPEN = false, Shared/RankedGate.luau) : le tuto ne
-- montre pas l'étape de la zone classée (demande du propriétaire, 01/10/2026), il en reste 5, numérotées de 1 à 5.
function Tutorial.stepCount(): number
	return if RankedGate.isOpen() then Tutorial.STEP_COUNT else Tutorial.STEP_COUNT - 1
end

-- Tuto fini (« Done ») ou passé (« Skip ») : le drapeau part avec la prochaine sauvegarde, et le client est
-- prévenu par l'attribut TutorialDone. step = étape atteinte (de 1 à Tutorial.stepCount()), seulement pour le
-- journal et les tests.
local function finish(player: Player, data, action: string, step: any): boolean
	if data.tutorialDone == true then
		return false
	end
	local total = Tutorial.stepCount()
	local reached = nil
	if typeof(step) == "number" and step == step then
		reached = math.clamp(math.floor(step), 1, total)
	end
	data.tutorialDone = true
	player:SetAttribute("TutorialDone", true)
	lastFinish[player] = { action = action, step = reached }
	local how = if action == "Done" then "terminé" else "passé"
	print(`[Tuto] {player.Name} : tuto {how}{if reached then ` (étape {reached}/{total})` else ""}`)
	return true
end

-- Studio seulement : le tuto recommence au début. Renvoie vrai si c'est fait (faux dans le jeu publié).
function Tutorial.replay(player: Player, data): boolean
	if not RunService:IsStudio() or not data then
		return false
	end
	data.tutorialDone = false
	lastFinish[player] = nil
	player:SetAttribute("TutorialDone", false)
	player:SetAttribute("TutorialReplay", (tonumber(player:GetAttribute("TutorialReplay")) or 0) + 1)
	return true
end

-- Tests Studio (StudioDebug « Tutorial », Hub/init.luau) : "Replay" = recommencer au début (renvoie vrai),
-- sinon l'état : { done = tutorialDone des données, attribute = attribut TutorialDone, lastAction = "Done" | "Skip"
-- | nil, lastStep = étape atteinte, steps = nombre d'étapes en ce moment (Tutorial.stepCount), replays = attribut
-- TutorialReplay }.
function Tutorial.debug(player: Player, data, command: string?)
	if command == "Replay" then
		return Tutorial.replay(player, data)
	end
	local last = lastFinish[player]
	return {
		done = data.tutorialDone == true,
		attribute = player:GetAttribute("TutorialDone"),
		lastAction = last and last.action,
		lastStep = last and last.step,
		steps = Tutorial.stepCount(),
		replays = player:GetAttribute("TutorialReplay") or 0,
	}
end

function Tutorial.start()
	-- client -> serveur : ("Done", étape) | ("Skip", étape) | "Replay" (Studio seulement). Voir Remotes.luau.
	Remotes.get("TutorialAction").OnServerEvent:Connect(function(player, action, step)
		local now = os.clock()
		if typeof(action) ~= "string" or now - (lastActionAt[player] or -math.huge) < ACTION_COOLDOWN then
			return
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		lastActionAt[player] = now
		if action == "Done" or action == "Skip" then
			finish(player, data, action, step)
		elseif action == "Replay" then
			Tutorial.replay(player, data) -- ne fait rien hors de Studio
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastActionAt[player] = nil
		lastFinish[player] = nil
	end)
end

return Tutorial
