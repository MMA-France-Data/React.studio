-- Test du JEU EN ÉQUIPE, côté serveur : tools/studio-test/run.ps1 -Test team.
-- Un Play de Studio n'a qu'un vrai joueur : ses coéquipiers sont des JOUEURS D'ESSAI (tables qui imitent un Player,
-- sans client : LevelsService.debug « TeamFake »), qui passent par les mêmes demandes que le remote LevelAction
-- (« TeamAs »). Le vrai jeu à plusieurs (deux vrais clients) reste à essayer à la main, avec un ami.
-- 1) Seul (le client attend) : invitations (refus, acceptation, conditions), lancement par le chef seulement (niveau
--    ouvert pour tous), partie à deux (or de chacun, tours de chacun, monstres plus résistants, l'or des monstres à
--    chacun), fin (pièces avec le bonus, niveau suivant ouvert pour chacun), départs (celui qui s'en va abandonne pour
--    lui seul, les autres continuent ; le dernier range la partie), équipe de quatre (PV, bonus de 40 %, équipe
--    complète), départ du jeu d'un joueur d'essai, le chef qui quitte l'équipe ; LES AMIS : bonus d'un ami Roblox sur
--    le serveur, ami venu grâce à une invitation (une seule fois), amis venus pendant son absence.
-- 2) Il donne la main au client (attribut TeamTestPhase = "Client" de ReplicatedStorage) et répond à ses demandes par
--    la RemoteFunction ReplicatedStorage.__TeamTest (joueurs d'essai, fin d'un niveau, données).
-- StudioDebug n'existe que dans Studio.
return function(log)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local dbg = game:GetService("ServerStorage"):WaitForChild("StudioDebug", 30)
	local Levels = require(ReplicatedStorage:WaitForChild("Shared").Levels)

	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] équipe (serveur) : {message}`)
	end

	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	for _ = 1, 150 do
		if dbg:Invoke(player, "Data") and typeof(player:GetAttribute("Plot")) == "number" and player:GetAttribute("LevelsState") ~= nil then
			break
		end
		task.wait(0.2)
	end
	local function levels(...)
		return dbg:Invoke(player, "Levels", ...)
	end
	local function action(...)
		return levels("Action", ...)
	end
	local function as(id, ...)
		return levels("TeamAs", id, ...)
	end
	local function fake(id)
		return levels("TeamFakeState", id) or {}
	end
	local function state()
		return levels("State")
	end
	local function decode(raw)
		if typeof(raw) ~= "string" then
			return nil
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		return if ok then decoded else nil
	end
	local function arenaFolder()
		local index = player:GetAttribute("LevelArena")
		local arenas = workspace:FindFirstChild("Arenas")
		return if typeof(index) == "number" and arenas then arenas:FindFirstChild("Arena" .. Levels.slotOf(index)) else nil
	end
	local function towersOf(arena, userId)
		local list = {}
		local folder = arena and arena:FindFirstChild("Towers")
		for _, model in if folder then folder:GetChildren() else {} do
			if model:IsA("Model") and model:GetAttribute("OwnerId") == userId then
				table.insert(list, model)
			end
		end
		return list
	end
	local me = player.UserId
	local myKey = Levels.memberKey(me)
	local name = player.DisplayName

	-- Le joueur a réussi 5 niveaux et possède le Totem de givre.
	for key, value in { best = 5, coins = 0, wins = 0, losses = 0, towers = { MachineGun = true, Bomb = true, Frost = true }, bar = { "MachineGun", "Bomb", "Frost" } } do
		levels("Set", key, value)
	end

	------------------------------------------------------------------
	-- Invitations
	------------------------------------------------------------------
	local robin = levels("TeamFake", "Robin", 5)
	local robinKey = Levels.memberKey(robin)
	local ok, why = action("TeamInvite", robin)
	check(ok and typeof(fake(robin).attributes.TeamInvite) == "string", `le joueur invite Robin : Robin reçoit l'invitation ({tostring(why)})`)
	ok = as(robin, "TeamAnswer", me, false)
	check(ok and fake(robin).attributes.TeamInvite == nil and player:GetAttribute("Team") == nil and state().team == nil, "Robin refuse : pas d'équipe")
	ok = as(robin, "TeamInvite", me)
	local invite = decode(player:GetAttribute("TeamInvite"))
	check(
		ok and invite ~= nil and invite.from == robin and invite.name == "Robin" and invite.seconds == Levels.TEAM_INVITE_SECONDS,
		`Robin invite le joueur : l'invitation lui arrive (attribut TeamInvite : de {invite and invite.name or "?"}, {invite and invite.seconds or "?"} s pour répondre)`
	)
	ok, why = action("TeamAnswer", robin + 1, true)
	check(not ok and why == "Cette invitation n'est plus valable", "une réponse à une autre invitation que la sienne est refusée")
	ok = action("TeamAnswer", robin, true)
	local team = decode(player:GetAttribute("Team"))
	check(
		ok and team and team.leader == robin and #team.members == 2 and team.members[1].id == robin and team.members[2].id == me and team.members[1].best == 5
			and player:GetAttribute("TeamInvite") == nil and fake(robin).attributes.Team == player:GetAttribute("Team"),
		"le joueur accepte : l'équipe de Robin (chef) et du joueur, publiée aux deux (attribut Team)"
	)
	local alex = levels("TeamFake", "Alex", 0)
	ok, why = action("TeamInvite", alex)
	check(not ok and why == "Seul le chef de l'équipe peut inviter", `un coéquipier qui n'est pas chef ne peut pas inviter (« {tostring(why)} »)`)
	ok, why = as(robin, "TeamInvite", alex)
	check(not ok and why == "Alex doit d'abord réussir le niveau 1", `on ne peut pas inviter un joueur qui n'a pas fini le niveau 1 (« {tostring(why)} »)`)
	ok, why = as(alex, "TeamInvite", robin)
	check(not ok and why == "Réussis d'abord le niveau 1 pour jouer en équipe", `ni inviter avant d'avoir fini le niveau 1 (« {tostring(why)} »)`)
	ok, why = action("Start", 2)
	check(not ok and why ~= nil and string.find(why, "Robin, le chef de ton équipe", 1, true) ~= nil, `un coéquipier ne lance pas les niveaux (« {tostring(why)} »)`)

	------------------------------------------------------------------
	-- Une partie à deux
	------------------------------------------------------------------
	levels("Set", "best", 2)
	ok, why = as(robin, "Start", 4)
	check(not ok and why == `Le niveau 4 n'est pas encore ouvert pour {name}`, `le chef ne lance qu'un niveau ouvert pour tous (« {tostring(why)} »)`)
	levels("Set", "best", 5)
	ok = as(robin, "Start", 3)
	local active = state().active
	local robinActive = fake(robin).active
	check(
		ok and active and active.level == 3 and active.team == 2 and active.players == 2 and robinActive and robinActive.index == active.index
			and player:GetAttribute("LevelArena") == active.index,
		"Robin lance le niveau 3 : le joueur est dans la même partie, deux joueurs"
	)
	local arena = arenaFolder()
	local gold3 = Levels.definition(3).gold
	local names = decode(arena and arena:GetAttribute("Team")) or {}
	check(
		arena ~= nil and arena:GetAttribute("TeamSize") == 2 and arena:GetAttribute("Gold_" .. myKey) == gold3 and arena:GetAttribute("Gold_" .. robinKey) == gold3
			and arena:GetAttribute("Training_" .. myKey) ~= nil and #names == 2 and names[1].name == "Robin" and names[2].id == me,
		`la zone publie l'or et l'entraînement de chacun, et les noms des joueurs ({#names} joueurs)`
	)
	check(active.firstHealth == Levels.buildQueue(3, 2)[1].health and active.firstHealth > Levels.buildQueue(3)[1].health, `monstres d'une équipe de deux : {active.firstHealth} PV au lieu de {Levels.buildQueue(3)[1].health}`)
	-- La carte d'équipe : un couloir chacun, une porte et le nom du joueur à l'entrée de chaque couloir.
	local mapFolder = arena and arena:FindFirstChild("Map")
	local laneNames = mapFolder and mapFolder:FindFirstChild("LaneNames")
	local signs = {}
	for index = 1, 2 do
		local anchor = laneNames and laneNames:FindFirstChild("Lane" .. index)
		local sign = anchor and anchor:FindFirstChild("Sign")
		signs[index] = if sign then sign.Label.Text else "?"
	end
	check(
		arena:GetAttribute("Map") == Levels.mapFor(3, 2) and arena:GetAttribute("Map") == "Valley_2" and signs[1] == "Robin" and signs[2] == name and #laneNames:GetChildren() == 2,
		`partie à deux sur la carte d'équipe « {tostring(arena:GetAttribute("Map"))} » : « {signs[1]} » à l'entrée du premier couloir, « {signs[2]} » du second`
	)
	local spots = Levels.MAPS[Levels.mapFor(3, 2)].spots
	ok = as(robin, "Place", "MachineGun", spots[1].X, spots[1].Z)
	local robinTowers = towersOf(arena, robin)
	check(ok and #robinTowers == 1 and fake(robin).active.gold == gold3 - 20 and state().active.gold == gold3, "Robin pose une tour avec SON or : elle est à lui (OwnerId)")
	local robinTower = robinTowers[1]
	ok, why = action("Upgrade", robinTower and robinTower:GetAttribute("TowerId"))
	local sold, whySell = action("Sell", robinTower and robinTower:GetAttribute("TowerId"))
	check(
		not ok and not sold and why ~= nil and string.find(why, "Ce n'est pas ta tour", 1, true) ~= nil and whySell == why and robinTower.Parent ~= nil,
		`le joueur ne peut ni améliorer ni vendre la tour de Robin (« {tostring(why)} »)`
	)
	ok = action("Place", "Frost", spots[2].X, spots[2].Z)
	local robinFrost, whyFrost = as(robin, "Place", "Frost", spots[3].X, spots[3].Z)
	check(ok and not robinFrost and whyFrost ~= nil and string.find(whyFrost, "barre", 1, true) ~= nil, "chacun ses tours : le joueur pose son Totem, pas Robin (il n'est pas dans sa barre)")
	levels("Skip", 3)
	local myBefore, robinBefore = state().active.gold, fake(robin).active.gold
	local killed = levels("KillAll")
	local myGain, robinGain = state().active.gold - myBefore, fake(robin).active.gold - robinBefore
	check(killed > 0 and myGain > 0 and myGain == robinGain, `l'or des monstres tués va à chacun, en entier ({killed} monstres : +{myGain} or au joueur, +{robinGain} à Robin)`)
	local coinsBefore, robinCoinsBefore = state().levels.coins, fake(robin).levels.coins
	levels("Finish", true)
	local result = decode(arena:GetAttribute("Result_" .. myKey)) or {}
	local robinResult = decode(arena:GetAttribute("Result_" .. robinKey)) or {}
	local replay = Levels.teamReward(Levels.reward(3, true, false), 2)
	check(
		result.won == true and result.team == 2 and result.reward == replay and robinResult.reward == replay and state().levels.coins == coinsBefore + replay
			and fake(robin).levels.coins == robinCoinsBefore + replay and replay > Levels.reward(3, true, false),
		`victoire à deux : chacun reçoit ses pièces avec le bonus de 10 % ({replay} au lieu de {Levels.reward(3, true, false)}), résumé à chacun (Result_<n°>)`
	)
	-- Première victoire des deux sur le niveau 6 : il s'ouvre pour chacun (« Niveau suivant » par le chef).
	ok = as(robin, "Start", 6)
	local sameZone = state().active and state().active.index == active.index
	levels("Finish", true)
	result = decode(arena:GetAttribute("Result_" .. myKey)) or {}
	check(
		ok and sameZone and result.firstClear == true and result.reward == Levels.teamReward(Levels.firstReward(6), 2) and state().levels.best == 6 and fake(robin).levels.best == 6,
		`niveau 6 réussi ensemble (même zone) : première victoire pour chacun (+{tostring(result.reward)} pièces), le niveau 7 s'ouvre pour les deux`
	)

	------------------------------------------------------------------
	-- Départs
	------------------------------------------------------------------
	as(robin, "Start", 7)
	action("Place", "MachineGun", spots[4].X, spots[4].Z)
	local lossesBefore = state().levels.losses
	action("Quit")
	robinActive = fake(robin).active
	check(
		state().active == nil and player:GetAttribute("LevelArena") == nil and robinActive and robinActive.players == 1 and robinActive.state == "Running"
			and #towersOf(arenaFolder() or workspace.Arenas:FindFirstChild("Arena" .. Levels.slotOf(robinActive.index)), me) == 1
			and state().levels.losses == lossesBefore + 1,
		"le joueur quitte le niveau : abandon pour lui seul (une défaite), Robin continue, la tour du joueur reste"
	)
	local zone = workspace.Arenas:FindFirstChild("Arena" .. Levels.slotOf(robinActive.index))
	check(zone ~= nil and zone:GetAttribute("Gold_" .. myKey) == nil and zone:GetAttribute("Gold_" .. robinKey) ~= nil, "celui qui s'en va n'a plus d'or publié dans la zone")
	as(robin, "Quit")
	check(fake(robin).active == nil and (zone:FindFirstChild("Towers") == nil or #zone.Towers:GetChildren() == 0) and zone:GetAttribute("TeamSize") == nil, "le dernier joueur quitte : la partie est rangée")
	as(robin, "Start", 7)
	as(robin, "Quit")
	active = state().active
	check(active ~= nil and active.players == 1 and active.state == "Running", "le chef quitte pendant le niveau : le joueur continue seul")
	action("Quit")
	as(robin, "TeamLeave")
	check(player:GetAttribute("Team") == nil and fake(robin).attributes.Team == nil and state().team == nil, "Robin quitte l'équipe : plus d'équipe (un joueur seul n'en a pas)")

	------------------------------------------------------------------
	-- Équipe de quatre
	------------------------------------------------------------------
	local sam, lou, max = levels("TeamFake", "Sam", 6), levels("TeamFake", "Lou", 6), levels("TeamFake", "Max", 6)
	for _, id in { robin, sam, lou } do
		action("TeamInvite", id)
		as(id, "TeamAnswer", me, true)
	end
	team = decode(player:GetAttribute("Team"))
	ok, why = action("TeamInvite", max)
	check(
		team and team.leader == me and #team.members == 4 and not ok and why == `Ton équipe est complète ({Levels.TEAM_MAX} joueurs au plus)`,
		`le joueur chef invite trois joueurs : équipe de quatre, complète (« {tostring(why)} »)`
	)
	ok, why = as(max, "TeamInvite", sam)
	check(not ok and why == "Sam est déjà dans une équipe", `un joueur déjà en équipe ne peut pas être invité (« {tostring(why)} »)`)
	ok = action("Start", 5)
	active = state().active
	check(ok and active and active.team == 4 and active.players == 4 and active.firstHealth == Levels.buildQueue(5, 4)[1].health, `niveau 5 à quatre : monstres x{Levels.teamHealth(4)} ({active and active.firstHealth or "?"} PV)`)
	local quadLanes = arenaFolder() and arenaFolder().Map:FindFirstChild("LaneNames")
	check(
		arenaFolder():GetAttribute("Map") == "Valley_4" and quadLanes ~= nil and #quadLanes:GetChildren() == 4 and quadLanes.Lane1.Sign.Label.Text == name,
		`à quatre : la carte d'équipe à quatre couloirs (« {tostring(arenaFolder():GetAttribute("Map"))} »), un nom à chaque entrée (le chef, qui a lancé : le premier)`
	)
	levels("Finish", true)
	result = decode(arenaFolder():GetAttribute("Result_" .. myKey)) or {}
	check(result.reward == Levels.teamReward(Levels.reward(5, true, false), 4) and result.team == 4, `victoire à quatre : bonus de 40 % ({tostring(result.reward)} pièces au lieu de {Levels.reward(5, true, false)})`)
	action("Quit")
	levels("TeamGone", sam)
	team = decode(player:GetAttribute("Team"))
	check(team and #team.members == 3, "un joueur quitte le jeu : il quitte aussi son équipe")
	action("TeamLeave")
	local robinTeam = decode(fake(robin).attributes.Team)
	check(player:GetAttribute("Team") == nil and robinTeam and robinTeam.leader == robin and #robinTeam.members == 2, "le chef quitte l'équipe : le suivant (Robin) devient chef")
	for _, id in { robin, alex, lou, max } do
		levels("TeamGone", id)
	end
	check(fake(robin).levels == nil and state().team == nil, "joueurs d'essai partis")
	-- Pas d'invitations en rafale (Hub/LevelTeams.luau) : une invitation qui attend sa réponse ne se renvoie pas ; après
	-- 2 refus de suite, plus d'invitation à ce joueur pendant une minute.
	local zoe = levels("TeamFake", "Zoe", 5)
	local firstInvite = action("TeamInvite", zoe)
	local tooSoon, tooSoonWhy = action("TeamInvite", zoe)
	as(zoe, "TeamAnswer", me, false)
	local secondInvite = action("TeamInvite", zoe)
	as(zoe, "TeamAnswer", me, false)
	local paused, pausedWhy = action("TeamInvite", zoe)
	check(
		firstInvite and not tooSoon and tooSoonWhy == nil and secondInvite and not paused
			and pausedWhy == "Zoe a refusé tes invitations : réessaie dans une minute",
		`invitations en rafale : la même encore pendant qu'elle attend sa réponse est ignorée ; après 2 refus de Zoe : « {tostring(pausedWhy)} »`
	)
	levels("TeamGone", zoe)

	------------------------------------------------------------------
	-- Les amis (« LES AMIS », Levels.luau)
	------------------------------------------------------------------
	for key, value in { best = 5, coins = 0, invitedBy = 0, invited = {} } do
		levels("Set", key, value)
	end
	-- Un ami Roblox sur le serveur : +10 % de pièces à la fin d'un niveau, même seul.
	local lou2 = levels("TeamFake", "Lou", 3)
	local friendsCount = levels("FriendFake", lou2)
	check(friendsCount == 1 and player:GetAttribute("FriendsHere") == 1, `un ami Roblox sur le serveur : attribut FriendsHere = {tostring(player:GetAttribute("FriendsHere"))}`)
	ok = action("Start", 3)
	levels("Finish", true)
	result = decode(arenaFolder() and arenaFolder():GetAttribute("Result_" .. myKey)) or {}
	local plain = Levels.reward(3, true, false)
	local withFriend = Levels.bonusReward(plain, 1, true)
	check(
		ok and result.friend == true and result.team == 1 and result.reward == withFriend and withFriend > plain,
		`niveau 3 gagné seul avec un ami sur le serveur : {tostring(result.reward)} pièces au lieu de {plain} (bonus d'ami de 10 %)`
	)
	action("Quit")
	levels("TeamGone", lou2)
	check(player:GetAttribute("FriendsHere") == 0, "l'ami s'en va : plus d'ami sur le serveur (FriendsHere = 0)")
	-- Un ami qui arrive grâce à l'invitation du joueur : 200 pièces pour chacun, une seule fois.
	local coinsBefore = state().levels.coins
	local nina = levels("TeamFake", "Nina", 0)
	local welcomed = levels("InviteJoin", nina)
	local ninaLevels = fake(nina).levels or {}
	local mine = state().levels
	check(
		welcomed == true and ninaLevels.coins == Levels.FRIENDS.INVITE_REWARD and ninaLevels.invitedBy == me and mine.coins == coinsBefore + Levels.FRIENDS.INVITE_REWARD
			and table.find(mine.invited, nina) ~= nil,
		`Nina arrive grâce à l'invitation du joueur : {tostring(ninaLevels.coins)} pièces pour elle, +{mine.coins - coinsBefore} pour le joueur`
	)
	local twice = levels("InviteJoin", nina)
	check(twice == false and state().levels.coins == coinsBefore + Levels.FRIENDS.INVITE_REWARD and (fake(nina).levels or {}).coins == Levels.FRIENDS.INVITE_REWARD, "une seule récompense par ami")
	levels("TeamGone", nina)
	-- Des amis venus grâce à lui pendant qu'il n'était pas là (noté dans le DataStore des invitations) : leurs
	-- récompenses à son arrivée, une fois.
	levels("InvitePending", 777001)
	levels("InvitePending", 777002)
	levels("InvitePending", 777001)
	local claimed = levels("InviteClaim")
	local claimedAgain = levels("InviteClaim")
	check(
		claimed == 2 and claimedAgain == 0 and state().levels.coins == coinsBefore + 3 * Levels.FRIENDS.INVITE_REWARD,
		`deux amis venus pendant son absence : {tostring(claimed)} récompenses à son retour, puis plus rien ({tostring(claimedAgain)})`
	)

	------------------------------------------------------------------
	-- Le client prend la main
	------------------------------------------------------------------
	for key, value in { best = 5, coins = 0, wins = 0, losses = 0, towers = { MachineGun = true, Bomb = true }, bar = { "MachineGun", "Bomb" } } do
		levels("Set", key, value)
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = "__TeamTest"
	remote.OnServerInvoke = function(who, command, ...)
		if who ~= player then
			return nil
		end
		if command == "Fake" then
			return levels("TeamFake", ...)
		elseif command == "As" then
			return levels("TeamAs", ...)
		elseif command == "FakeState" then
			return levels("TeamFakeState", ...)
		elseif command == "Gone" then
			return levels("TeamGone", ...)
		elseif command == "Friend" then
			return levels("FriendFake", ...)
		elseif command == "Finish" then
			return levels("Finish", ... == true)
		elseif command == "Set" then
			return levels("Set", ...) ~= nil
		elseif command == "State" then
			return state()
		end
		return nil
	end
	remote.Parent = ReplicatedStorage
	ReplicatedStorage:SetAttribute("TeamTestPhase", "Client")
	log("Info", "[EQUIPE] serveur du test prêt, le client prend la main")
end
