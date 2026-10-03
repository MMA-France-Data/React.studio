-- ÉQUIPES pour jouer un niveau à plusieurs (règles : Shared/Levels.luau, « JOUER EN ÉQUIPE » ; la partie elle-même :
-- LevelGame.luau ; le lancement et les récompenses : LevelsService.luau). Ici, seulement QUI est avec qui :
--   * une équipe = un chef et ses coéquipiers, Levels.TEAM_MAX joueurs au plus ; un joueur n'est que dans une équipe ;
--   * le chef (ou un joueur seul, qui devient le chef) invite un joueur du serveur qui n'est dans aucune équipe ;
--     l'invité accepte ou refuse dans les Levels.TEAM_INVITE_SECONDS secondes (une invitation à la fois : la nouvelle
--     remplace l'ancienne) ;
--   * il faut avoir réussi le niveau 1 (le tuto) pour inviter ou être invité ;
--   * chacun peut quitter l'équipe ; si le chef s'en va, le suivant devient chef ; une équipe d'un seul joueur n'en est
--     plus une ;
--   * publié à chaque changement, pour l'interface (client/LevelsUI.luau) : attribut « Team » de chaque coéquipier
--     (JSON { leader = UserId du chef, members = { { id = UserId, name, best = plus haut niveau réussi } }, le chef
--     en premier ; absent = pas d'équipe) et attribut « TeamInvite » de l'invité (JSON { from = UserId, name,
--     seconds = temps pour répondre } ; absent = pas d'invitation).
-- Les joueurs sont repérés par leur UserId. Tests Studio : des joueurs d'essai (tables qui imitent un Player, voir
-- LevelsService.debug « TeamFake ») passent par les mêmes fonctions.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)

local LevelTeams = {}

local teams = {} -- [Player] = son équipe : { leader = Player, members = { Player } (le chef en premier) }
local invites = {} -- [Player invité] = { from = Player }

-- Branché par LevelsService (LevelTeams.init) : données des niveaux d'un joueur (nil si pas chargées), Player d'un
-- UserId, message à un joueur.
local hooks = {
	levelsOf = function(_player: any): any
		return nil
	end,
	playerById = function(_id: number): any
		return nil
	end,
	notify = function(_player: any, _message: string, _kind: string?) end,
}

function LevelTeams.init(options)
	hooks.levelsOf = options.levelsOf
	hooks.playerById = options.playerById
	hooks.notify = options.notify
end

local function nameOf(player): string
	return tostring(player.DisplayName or player.Name or "?")
end

-- L'équipe d'un joueur, ou nil s'il joue seul.
function LevelTeams.teamOf(player)
	return teams[player]
end

-- Les joueurs de l'équipe d'un joueur (le chef en premier), ou { lui } s'il joue seul.
function LevelTeams.membersOf(player): { any }
	local team = teams[player]
	return if team then table.clone(team.members) else { player }
end

-- Vrai s'il peut lancer un niveau : il joue seul, ou il est le chef de son équipe.
function LevelTeams.isLeader(player): boolean
	local team = teams[player]
	return team == nil or team.leader == player
end

-- Republie l'équipe à chacun de ses joueurs (après un changement, ou quand le niveau réussi d'un joueur monte).
local function publishTeam(team)
	local members = {}
	for _, member in team.members do
		local levels = hooks.levelsOf(member)
		table.insert(members, { id = member.UserId, name = nameOf(member), best = if levels then levels.best else 0 })
	end
	local text = HttpService:JSONEncode({ leader = team.leader.UserId, members = members })
	for _, member in team.members do
		if member.Parent then
			member:SetAttribute("Team", text)
		end
	end
end

function LevelTeams.refresh(player)
	local team = teams[player]
	if team then
		publishTeam(team)
	end
end

local function publishInvite(player)
	if not player.Parent then
		return
	end
	local invite = invites[player]
	player:SetAttribute("TeamInvite", if invite
		then HttpService:JSONEncode({ from = invite.from.UserId, name = nameOf(invite.from), seconds = Levels.TEAM_INVITE_SECONDS })
		else nil)
end

-- Peut-il jouer en équipe (données chargées, niveau 1 réussi) ? who = son nom dans le message (nil : c'est toi).
local function ready(player, who: string?): (boolean, string?)
	local levels = hooks.levelsOf(player)
	if not levels then
		return false, if who then `Les données de {who} ne sont pas encore chargées` else "Tes données ne sont pas encore chargées"
	end
	if levels.best < 1 then
		return false, if who then `{who} doit d'abord réussir le niveau 1` else "Réussis d'abord le niveau 1 pour jouer en équipe"
	end
	return true, nil
end

-- `from` invite le joueur de UserId `targetId`. Renvoie (vrai) ou (faux, raison).
function LevelTeams.invite(from, targetId: any): (boolean, string?)
	local target = if typeof(targetId) == "number" then hooks.playerById(targetId) else nil
	if not target or target == from or not target.Parent then
		return false, "Ce joueur n'est plus là"
	end
	local ok, reason = ready(from)
	if not ok then
		return false, reason
	end
	local team = teams[from]
	if team and team.leader ~= from then
		return false, "Seul le chef de l'équipe peut inviter"
	end
	if team and #team.members >= Levels.TEAM_MAX then
		return false, `Ton équipe est complète ({Levels.TEAM_MAX} joueurs au plus)`
	end
	if teams[target] then
		return false, `{nameOf(target)} est déjà dans une équipe`
	end
	ok, reason = ready(target, nameOf(target))
	if not ok then
		return false, reason
	end
	local invite = { from = from }
	invites[target] = invite
	publishInvite(target)
	task.delay(Levels.TEAM_INVITE_SECONDS, function()
		if invites[target] == invite then
			invites[target] = nil
			publishInvite(target)
		end
	end)
	hooks.notify(from, `Invitation envoyée à {nameOf(target)}`, "Info")
	return true, nil
end

-- Réponse de `player` à l'invitation du joueur de UserId `fromId` (accept = vrai : il rejoint son équipe).
function LevelTeams.answer(player, fromId: any, accept: boolean): (boolean, string?)
	local invite = invites[player]
	if not invite or invite.from.UserId ~= fromId then
		return false, "Cette invitation n'est plus valable"
	end
	invites[player] = nil
	publishInvite(player)
	local from = invite.from
	if not accept then
		hooks.notify(from, `{nameOf(player)} a refusé ton invitation`, "Info")
		return true, nil
	end
	if not from.Parent then
		return false, `{nameOf(from)} n'est plus là`
	end
	if teams[player] then
		return false, "Tu es déjà dans une équipe : quitte-la d'abord"
	end
	local team = teams[from]
	if team and team.leader ~= from then
		return false, `{nameOf(from)} n'est plus le chef de son équipe`
	end
	if team and #team.members >= Levels.TEAM_MAX then
		return false, `L'équipe de {nameOf(from)} est complète`
	end
	if not team then
		team = { leader = from, members = { from } }
		teams[from] = team
	end
	table.insert(team.members, player)
	teams[player] = team
	publishTeam(team)
	for _, member in team.members do
		if member ~= player then
			hooks.notify(member, `{nameOf(player)} rejoint ton équipe !`, "Success")
		end
	end
	hooks.notify(player, `Tu joues maintenant dans l'équipe de {nameOf(team.leader)}`, "Success")
	return true, nil
end

-- `player` quitte son équipe (bouton « Quitter l'équipe », ou départ du jeu). Si c'était le chef, le suivant le
-- devient ; un joueur resté seul n'a plus d'équipe.
function LevelTeams.leave(player): (boolean, string?)
	local team = teams[player]
	if not team then
		return false, nil
	end
	teams[player] = nil
	table.remove(team.members, table.find(team.members, player))
	if player.Parent then
		player:SetAttribute("Team", nil)
	end
	if team.leader == player then
		team.leader = team.members[1]
	end
	if #team.members <= 1 then
		for _, member in team.members do
			teams[member] = nil
			if member.Parent then
				member:SetAttribute("Team", nil)
			end
			hooks.notify(member, `{nameOf(player)} a quitté l'équipe : tu joues seul`, "Info")
		end
	else
		publishTeam(team)
		for _, member in team.members do
			hooks.notify(member, `{nameOf(player)} a quitté l'équipe`, "Info")
		end
	end
	return true, nil
end

-- Un joueur quitte le serveur : il quitte son équipe ; l'invitation qu'il a reçue et celles qu'il a envoyées
-- disparaissent.
function LevelTeams.removePlayer(player)
	LevelTeams.leave(player)
	invites[player] = nil
	for target, invite in invites do
		if invite.from == player then
			invites[target] = nil
			publishInvite(target)
		end
	end
end

return LevelTeams
