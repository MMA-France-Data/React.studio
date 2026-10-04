-- Test du JEU EN ÉQUIPE, côté client (la vraie interface) : tools/studio-test/run.ps1 -Test team.
-- Il attend que le serveur (scenarios/TeamServer.luau) ait fini ses vérifications, puis joue avec des joueurs d'essai
-- (demandes par la RemoteFunction __TeamTest : créer un joueur d'essai, le faire inviter, lancer, poser, quitter) :
--   1) la fenêtre du camp : le bouton « 👥 ÉQUIPE » et sa page (texte, « TU JOUES SEUL », personne d'autre) ;
--   2) une invitation de Robin : le panneau, son texte, son temps ; « Refuser » ; une 2e invitation, « Accepter » ;
--      la page de l'équipe (Robin chef), les boutons des niveaux (« 👥 LE CHEF ») ;
--   3) Robin lance un niveau : le joueur y entre, sur la carte d'équipe (un couloir chacun : le nom de chacun au-dessus
--      de sa porte, des monstres dans les deux couloirs) ; son or à lui (pas celui de Robin), l'or de Robin sous le
--      bandeau, la tour de Robin (son menu dit à qui elle est, sans « Améliorer » ni « Vendre »), le joueur pose sa tour ;
--   4) l'écran de fin : la récompense avec le bonus, « Robin choisit la suite » ; Robin lance la suite : le joueur y
--      entre ; il quitte : retour au camp, Robin continue seul ;
--   5) le joueur chef d'une équipe : « 🔒 ÉQUIPE » sur un niveau pas encore ouvert pour son coéquipier, il lance un
--      niveau, son écran de fin garde « Niveau suivant », qui emmène l'équipe ; quitter l'équipe ;
--   6) à la taille d'un téléphone (750 x 332) : la page de l'équipe et le panneau d'invitation tiennent dans l'écran ;
--   7) les amis : le panneau « ami en ligne » et son « Inviter », le bouton « Inviter des amis » ; Robin est un ami
--      Roblox (sur le serveur) pendant le niveau à deux : l'écran de fin dit aussi le bonus d'ami.
-- « SHOT:nom » = capture (out\team_<nom>.png) ; « PHONE:want=... » = run.ps1 redimensionne la fenêtre de Studio.
return function(log)
	local GuiService = game:GetService("GuiService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Levels = require(Shared.Levels)
	local NumberFormat = require(Shared.NumberFormat)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local function say(message)
		log("Info", "[EQUIPE] " .. message)
	end
	local function shot(name)
		say("SHOT:team_" .. name)
		task.wait(1.6)
	end
	local function check(ok, message)
		log(if ok then "Info" else "Error", `[{if ok then "PASS" else "FAIL"}] équipe : {message}`)
	end
	local function waitFor(condition, seconds)
		local deadline = os.clock() + seconds
		while os.clock() < deadline do
			if condition() then
				return true
			end
			task.wait(0.1)
		end
		return condition()
	end
	local function finish()
		say("TEAM:client=done")
		task.wait(1.5)
		say("PHONE:done")
	end

	local ready = waitFor(function()
		return ReplicatedStorage:GetAttribute("TeamTestPhase") == "Client"
	end, 240)
	local test = ReplicatedStorage:FindFirstChild("__TeamTest")
	local campGui = playerGui:WaitForChild("Levels", 30)
	local hudGui = playerGui:WaitForChild("LevelHud", 30)
	local inviteGui = playerGui:WaitForChild("TeamInvite", 30)
	if not ready or not test or not campGui or not hudGui or not inviteGui then
		check(false, `test impossible (serveur prêt : {tostring(ready)}, écrans : {tostring(campGui ~= nil)}, {tostring(hudGui ~= nil)}, {tostring(inviteGui ~= nil)})`)
		finish()
		return
	end
	local window = campGui:WaitForChild("Window")
	local levelAction = ReplicatedStorage.Remotes.LevelAction
	local topBar = (GuiService:GetGuiInset()).Y
	local function screenSize()
		local viewport = workspace.CurrentCamera.ViewportSize
		return Vector2.new(viewport.X, viewport.Y - topBar)
	end
	local counter = 0
	local function act(gui, command)
		counter += 1
		gui:SetAttribute("TestAction", `{command}#{counter}`)
		task.wait(0.2)
	end
	local function shown(object)
		local current = object
		while current and not current:IsA("LayerCollector") do
			if current:IsA("GuiObject") and not current.Visible then
				return false
			end
			current = current.Parent
		end
		return current ~= nil and current:IsA("ScreenGui") and current.Enabled
	end
	local function rect(object)
		local position, size = object.AbsolutePosition, object.AbsoluteSize
		return position.X, position.Y, position.X + size.X, position.Y + size.Y
	end
	local function onScreen(object)
		local screen = screenSize()
		local l, t, r, b = rect(object)
		return l >= -1 and t >= -1 and r <= screen.X + 1 and b <= screen.Y + 1
	end
	local function overlap(a, b)
		local al, at, ar, ab = rect(a)
		local bl, bt, br, bb = rect(b)
		return math.min(ar, br) - math.max(al, bl) > 2 and math.min(ab, bb) - math.max(at, bt) > 2
	end
	local function arenaFolder()
		local index = player:GetAttribute("LevelArena")
		local arenas = workspace:FindFirstChild("Arenas")
		return if typeof(index) == "number" and arenas then arenas:FindFirstChild("Arena" .. Levels.slotOf(index)) else nil
	end
	local function towersOf(userId)
		local list = {}
		local arena = arenaFolder()
		local folder = arena and arena:FindFirstChild("Towers")
		for _, model in if folder then folder:GetChildren() else {} do
			if model:IsA("Model") and model:GetAttribute("OwnerId") == userId then
				table.insert(list, model)
			end
		end
		return list
	end
	local function inLevel(number)
		local arena = arenaFolder()
		return hudGui.Enabled and arena ~= nil and arena:GetAttribute("Level") == number and arena:GetAttribute("State") == "Running"
	end
	local me = player.UserId
	local myKey = Levels.memberKey(me)
	local name = player.DisplayName
	local fakes = {}
	local function newFake(fakeName, best)
		local id = test:InvokeServer("Fake", fakeName, best)
		table.insert(fakes, id)
		return id
	end
	local function as(id, ...)
		return test:InvokeServer("As", id, ...)
	end

	task.spawn(function()
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	end)
	test:InvokeServer("Set", "best", 5)
	task.wait(0.5)

	------------------------------------------------------------------
	-- 1) La fenêtre du camp : le bouton « 👥 ÉQUIPE » et sa page
	------------------------------------------------------------------
	act(campGui, "Open")
	local teamButton = window:WaitForChild("TeamButton")
	task.wait(0.4)
	check(
		shown(teamButton) and teamButton.Text == "👥 ÉQUIPE" and not overlap(teamButton, window.Title) and not overlap(teamButton, window.Coins) and not overlap(teamButton, window.Close),
		`bouton « {teamButton.Text} » dans l'en-tête de la fenêtre, sans recouvrir le titre, les pièces ni « X »`
	)
	act(campGui, "Team")
	local page = window:WaitForChild("PageTeam")
	task.wait(0.3)
	check(
		page.Visible and not window.Page1.Visible and string.find(page.Help.Text, "+10 % à deux, +30 % à trois, +40 % à quatre", 1, true) ~= nil
			and page.MembersTitle.Text == "TU JOUES SEUL : invite des joueurs ci-dessous" and page.OthersEmpty.Visible and not page.Leave.Visible,
		`page de l'équipe : les règles (bonus 10 / 30 / 40 %), « {page.MembersTitle.Text} », personne d'autre dans ce serveur`
	)
	shot("page_seul")

	------------------------------------------------------------------
	-- 2) Une invitation de Robin
	------------------------------------------------------------------
	local robin = newFake("Robin", 5)
	as(robin, "TeamInvite", me)
	local panel = inviteGui:WaitForChild("Panel")
	local arrived = waitFor(function()
		return panel.Visible
	end, 4)
	task.wait(0.3)
	check(
		arrived and panel.Text.Text == "Robin t'invite à jouer en équipe !" and string.find(panel.Timer.Text, "⏳", 1, true) ~= nil and onScreen(panel)
			and panel.Accept.Text == "✓ Accepter" and panel.Decline.Text == "Refuser",
		`invitation : « {panel.Text.Text} » ({panel.Timer.Text}), « {panel.Accept.Text} » / « {panel.Decline.Text} », dans l'écran`
	)
	shot("invitation")
	act(campGui, "TeamDecline")
	check(
		waitFor(function()
			return not panel.Visible and player:GetAttribute("TeamInvite") == nil
		end, 3) and player:GetAttribute("Team") == nil,
		"« Refuser » : le panneau se ferme, pas d'équipe"
	)
	as(robin, "TeamInvite", me)
	waitFor(function()
		return panel.Visible
	end, 4)
	act(campGui, "TeamAccept")
	local joined = waitFor(function()
		return player:GetAttribute("Team") ~= nil and not panel.Visible
	end, 4)
	task.wait(1.2)
	check(
		joined and page.MembersTitle.Text == "L'ÉQUIPE DE Robin (2/4)" and page.Member1.Visible and page.Member1.Label.Text == "👑 Robin : niveau 5 réussi"
			and page.Member2.Label.Text == `{name} (toi) : niveau 5 réussi` and page.Leave.Visible and teamButton.Text == "👥 ÉQUIPE (2)",
		`« Accepter » : « {page.MembersTitle.Text} », « {page.Member1.Label.Text} », « {page.Member2.Label.Text} », bouton « {teamButton.Text} »`
	)
	shot("page_equipe")
	-- Robin est aussi un ami Roblox du joueur : bonus d'ami sur le serveur.
	test:InvokeServer("Friend", robin)
	check(
		waitFor(function()
			return page.FriendsHere.Text == "🤝 Amis Roblox sur ce serveur : 1 (+10 % de pièces)"
		end, 3),
		`Robin est un ami Roblox : « {page.FriendsHere.Text} »`
	)
	act(campGui, "Tab:Niveaux")
	task.wait(0.3)
	local cards = window.Page1
	check(
		cards.Level3.Play.Text == "👥 LE CHEF" and cards.Level6.Play.Text == "👥 LE CHEF" and cards.Level7.Play.Text == "🔒",
		`pas chef : les boutons des niveaux disent « {cards.Level3.Play.Text} » (c'est Robin qui lance)`
	)

	------------------------------------------------------------------
	-- 3) Robin lance un niveau : le joueur y entre
	------------------------------------------------------------------
	as(robin, "Start", 3)
	local entered = waitFor(function()
		return inLevel(3)
	end, 8)
	task.wait(0.8)
	check(entered and not window.Visible, "Robin lance le niveau 3 : le joueur y entre (fenêtre du camp fermée, écran du niveau)")
	local arena = arenaFolder()
	local teamMap = Levels.mapFor(3, 2)
	local spots = Levels.MAPS[teamMap].spots
	-- La carte d'équipe : deux couloirs (Robin, le chef, a le premier), une porte et un nom à l'entrée de chacun.
	local mapFolder = arena and arena:FindFirstChild("Map")
	local gates = 0
	for _, child in if mapFolder then mapFolder:GetChildren() else {} do
		if child.Name == "GateTower" then
			gates += 1
		end
	end
	local laneNames = mapFolder and mapFolder:FindFirstChild("LaneNames")
	local function signText(index)
		local anchor = laneNames and laneNames:FindFirstChild("Lane" .. index)
		local sign = anchor and anchor:FindFirstChild("Sign")
		return if sign and sign.Enabled and sign:GetAttribute("NoTranslate") == true then sign.Label.Text else nil
	end
	check(
		arena:GetAttribute("Map") == teamMap and teamMap == "Valley_2" and gates == 4 and signText(1) == "Robin" and signText(2) == name and signText(3) == nil,
		`carte d'équipe « {tostring(arena:GetAttribute("Map"))} » : {gates / 2} portes, « {tostring(signText(1))} » au-dessus du premier couloir, « {tostring(signText(2))} » au-dessus du second`
	)
	-- Des monstres affichés dans les deux couloirs (celui du haut : Robin, celui du bas : le joueur ; ils se rejoignent
	-- au milieu du terrain).
	local arenaCFrame = Levels.arenaCFrame(Levels.slotOf(player:GetAttribute("LevelArena")))
	local function corridors()
		local top, bottom = 0, 0
		local enemies = workspace:FindFirstChild("PlotEnemies")
		for _, part in if enemies then enemies:GetChildren() else {} do
			if part:IsA("BasePart") then
				local at = arenaCFrame:PointToObjectSpace(part.Position)
				if math.abs(at.X) < 70 and at.X < -4 then
					top += if at.Z < -5 then 1 else 0
					bottom += if at.Z > 5 then 1 else 0
				end
			end
		end
		return top, bottom
	end
	local bothCorridors = waitFor(function()
		local top, bottom = corridors()
		return top > 0 and bottom > 0
	end, 20)
	local top, bottom = corridors()
	check(bothCorridors, `des monstres dans les deux couloirs avant leur rencontre ({top} en haut, {bottom} en bas)`)
	shot("carte_equipe")
	as(robin, "Place", "MachineGun", spots[1].X, spots[1].Z)
	waitFor(function()
		return #towersOf(robin) == 1
	end, 4)
	local strip = hudGui.TopStrip
	local myGoldShown = waitFor(function()
		local mine = arena:GetAttribute("Gold_" .. myKey)
		return typeof(mine) == "number" and strip.Gold.Text == `💰 {NumberFormat.short(mine)}`
	end, 3)
	check(
		myGoldShown and arena:GetAttribute("Gold") ~= arena:GetAttribute("Gold_" .. myKey),
		`le bandeau montre l'or du joueur (« {strip.Gold.Text} »), pas celui de Robin ({tostring(arena:GetAttribute("Gold"))} : il a posé une tour)`
	)
	local teamInfo = hudGui.TeamInfo
	check(
		teamInfo.Visible and string.find(teamInfo.Text, "Robin 💰", 1, true) ~= nil and onScreen(teamInfo) and not overlap(teamInfo, strip),
		`sous le bandeau, l'or de Robin : « {teamInfo.Text} »`
	)
	local bar = hudGui.TowerBar
	check(string.sub(bar.Tower_MachineGun.Copies.Text, 1, 3) == "0/5", `la tour de Robin ne compte pas dans les limites du joueur (« {bar.Tower_MachineGun.Copies.Text} »)`)
	act(hudGui, `Tap:{spots[1].X},{spots[1].Z}`)
	local menu = hudGui.TowerMenu
	waitFor(function()
		return menu.Visible
	end, 3)
	task.wait(0.3)
	check(
		menu.Visible and string.find(menu.Stats.Text, "Tour de Robin", 1, true) ~= nil and not menu.Upgrade.Visible and not menu.Sell.Visible,
		`la tour de Robin : son menu dit à qui elle est (« {string.gsub(menu.Stats.Text, "\n", " ⏎ ")} »), sans « Améliorer » ni « Vendre »`
	)
	shot("tour_de_robin")
	act(hudGui, "Select:MachineGun")
	act(hudGui, `Tap:{spots[2].X},{spots[2].Z}`)
	local placed = waitFor(function()
		return #towersOf(me) == 1
	end, 4)
	act(hudGui, `Tap:{spots[2].X},{spots[2].Z}`)
	task.wait(0.3)
	check(placed and menu.Visible and menu.Upgrade.Visible and menu.Sell.Visible, "le joueur pose sa tour : son menu a « Améliorer » et « Vendre »")
	shot("niveau_a_deux")

	------------------------------------------------------------------
	-- 4) L'écran de fin, la suite choisie par Robin, le joueur qui s'en va
	------------------------------------------------------------------
	test:InvokeServer("Finish", true)
	local endScreen = hudGui.EndScreen
	waitFor(function()
		return endScreen.Visible
	end, 5)
	task.wait(0.5)
	local endPanel = endScreen.Panel
	local reward = Levels.bonusReward(Levels.reward(3, true, false), 2, true) -- (bonus d'équipe et bonus d'ami)
	check(
		endScreen.Visible and endPanel.Reward.Text == `+{NumberFormat.short(reward)} 💵` and string.find(endPanel.Details.Text, "Bonus d'équipe (2 joueurs) : +10 % de pièces", 1, true) ~= nil
			and string.find(endPanel.Details.Text, "🤝 Bonus d'ami sur le serveur : +10 % de pièces", 1, true) ~= nil,
		`écran de fin : « {endPanel.Reward.Text} » avec le bonus d'équipe (« {string.gsub(endPanel.Details.Text, "\n", " ⏎ ")} »)`
	)
	check(
		endPanel.Next.Text == "⏳ Robin choisit la suite" and not endPanel.Replay.Visible and endPanel.Camp.Visible,
		`pas chef : « {endPanel.Next.Text} », pas de « Rejouer », « Retour au camp » reste`
	)
	shot("fin_coequipier")
	as(robin, "Start", 4)
	check(
		waitFor(function()
			return inLevel(4) and not endScreen.Visible
		end, 8),
		"Robin lance le niveau 4 : le joueur y passe avec lui"
	)
	act(hudGui, "Quit")
	act(hudGui, "Quit")
	local back = waitFor(function()
		return player:GetAttribute("LevelArena") == nil and not hudGui.Enabled
	end, 5)
	local robinState = test:InvokeServer("FakeState", robin)
	check(
		back and robinState.active ~= nil and robinState.active.players == 1 and robinState.active.state == "Running",
		"le joueur quitte : retour au camp, Robin continue seul"
	)
	as(robin, "Quit")
	as(robin, "TeamLeave")
	check(
		waitFor(function()
			return player:GetAttribute("Team") == nil
		end, 3),
		"Robin quitte l'équipe : le joueur joue seul"
	)

	------------------------------------------------------------------
	-- 5) Le joueur chef d'une équipe
	------------------------------------------------------------------
	local alex = newFake("Alex", 2)
	act(campGui, `TeamInvite:{alex}`)
	as(alex, "TeamAnswer", me, true)
	waitFor(function()
		return player:GetAttribute("Team") ~= nil
	end, 4)
	act(campGui, "Team")
	task.wait(1.2)
	check(page.MembersTitle.Text == "TON ÉQUIPE (2/4) : tu es le chef" and page.Member2.Label.Text == "Alex : niveau 2 réussi", `chef : « {page.MembersTitle.Text} », « {page.Member2.Label.Text} »`)
	act(campGui, "Tab:Niveaux")
	task.wait(0.3)
	check(
		cards.Level3.Play.Text == "REJOUER" and cards.Level4.Play.Text == "🔒 ÉQUIPE" and cards.Level6.Play.Text == "🔒 ÉQUIPE",
		`chef : les niveaux ouverts pour tous se lancent (niveau 3 « {cards.Level3.Play.Text} »), les autres disent « {cards.Level4.Play.Text} » (Alex n'a réussi que le niveau 2)`
	)
	shot("niveaux_chef")
	levelAction:FireServer("Start", 3)
	check(
		waitFor(function()
			-- (l'écran du niveau suit les attributs de la zone à l'image suivante : on attend aussi le texte)
			return inLevel(3) and string.find(hudGui.TeamInfo.Text, "Alex 💰", 1, true) ~= nil
		end, 8),
		`le chef lance le niveau 3 : l'équipe y entre (« {hudGui.TeamInfo.Text} »)`
	)
	test:InvokeServer("Finish", true)
	waitFor(function()
		return endScreen.Visible
	end, 5)
	task.wait(0.5)
	check(endPanel.Next.Text == "Niveau 4 ▶" and endPanel.Replay.Visible, `chef : l'écran de fin garde « {endPanel.Next.Text} » et « Rejouer »`)
	act(hudGui, "Next")
	check(
		waitFor(function()
			return inLevel(4) and arenaFolder():GetAttribute("TeamSize") == 2
		end, 8),
		"« Niveau 4 ▶ » : l'équipe passe au niveau 4 (ouvert pour Alex grâce à cette victoire)"
	)
	act(hudGui, "Quit")
	act(hudGui, "Quit")
	waitFor(function()
		return player:GetAttribute("LevelArena") == nil
	end, 5)
	as(alex, "Quit")
	act(campGui, "TeamLeave")
	act(campGui, "Team")
	check(
		waitFor(function()
			return player:GetAttribute("Team") == nil and page.MembersTitle.Text == "TU JOUES SEUL : invite des joueurs ci-dessous"
		end, 4) and not page.Leave.Visible and teamButton.Text == "👥 ÉQUIPE",
		"« Quitter l'équipe » : le joueur joue de nouveau seul"
	)
	act(campGui, "Close")

	------------------------------------------------------------------
	-- 7) Les amis : le panneau « ami en ligne » (comme si Robin venait de se connecter), son bouton « Inviter », le
	--    bouton « Inviter des amis » de la page de l'équipe (l'invitation de Roblox ne s'ouvre pas dans Studio : le
	--    test lit l'attribut LastInvite de l'écran « Levels »)
	------------------------------------------------------------------
	act(campGui, "FriendOnline:123456:Robin")
	local friendGui = playerGui:WaitForChild("FriendOnline", 5)
	local notice = friendGui and friendGui:FindFirstChild("Panel")
	waitFor(function()
		return notice ~= nil and notice.Visible
	end, 3)
	task.wait(0.3)
	check(
		notice ~= nil and notice.Visible and friendGui.Enabled and notice.Text.Text == "🟢 Robin est en ligne ! Invite-le : +200 💵 pour vous deux s'il vient."
			and notice.Invite.Text == "📨 Inviter" and onScreen(notice),
		`panneau « ami en ligne » : « {notice and notice.Text.Text or "?"} », bouton « {notice and notice.Invite.Text or "?"} », dans l'écran`
	)
	shot("ami_en_ligne")
	act(campGui, "FriendInvite")
	check(
		waitFor(function()
			return not notice.Visible and not friendGui.Enabled
		end, 3) and campGui:GetAttribute("LastInvite") == 123456,
		"« Inviter » : l'invitation de Roblox pour Robin, et le panneau se ferme"
	)
	act(campGui, "FriendOnline:654321:Sam")
	act(campGui, "FriendClose")
	check(
		waitFor(function()
			return not notice.Visible
		end, 3) and campGui:GetAttribute("LastInvite") == 123456,
		"« X » : le panneau se ferme sans inviter"
	)
	act(campGui, "Team")
	task.wait(0.4)
	act(campGui, "InviteFriends")
	check(
		page.InviteFriends.Visible and page.InviteFriends.Text == "📨 Inviter des amis" and campGui:GetAttribute("LastInvite") == 0
			and page.FriendsHere.Text == "🤝 Amis Roblox sur ce serveur : 1 (+10 % de pièces)" and not overlap(page.InviteFriends, page.Help),
		`page de l'équipe : « {page.InviteFriends.Text} » ouvre l'invitation de Roblox (au choix) ; Robin, encore sur le serveur : « {page.FriendsHere.Text} »`
	)
	act(campGui, "Close")

	------------------------------------------------------------------
	-- 6) À la taille d'un téléphone (750 x 332)
	------------------------------------------------------------------
	local function fitTo(width, height)
		local stableSince, deadline = nil, os.clock() + 90
		while os.clock() < deadline do
			local size = screenSize()
			if math.abs(size.X - width) <= 6 and math.abs(size.Y - height) <= 6 then
				stableSince = stableSince or os.clock()
				if os.clock() - stableSince >= 4 then
					return true
				end
				task.wait(0.25)
			else
				stableSince = nil
				say(`PHONE:want={width}x{height};have={math.floor(size.X)}x{math.floor(size.Y)}`)
				task.wait(0.9)
			end
		end
		return false
	end
	local phone = fitTo(750, 332)
	check(phone, `fenêtre de Studio à la taille d'un téléphone ({math.floor(screenSize().X)} x {math.floor(screenSize().Y)})`)
	if phone then
		act(campGui, "Team")
		task.wait(0.6)
		check(
			onScreen(teamButton) and shown(page) and onScreen(page.Help) and not overlap(teamButton, window.Title) and not overlap(teamButton, window.Close),
			`téléphone : le bouton « 👥 ÉQUIPE » et le texte de la page tiennent dans l'écran ({math.floor(teamButton.AbsoluteSize.X)} x {math.floor(teamButton.AbsoluteSize.Y)} px)`
		)
		shot("tel_page")
		local sam = newFake("Sam", 4)
		as(sam, "TeamInvite", me)
		waitFor(function()
			return panel.Visible
		end, 4)
		task.wait(0.4)
		check(
			panel.Visible and onScreen(panel) and panel.Accept.AbsoluteSize.Y >= 30 and not overlap(panel.Accept, panel.Decline),
			`téléphone : le panneau d'invitation tient dans l'écran, boutons de {math.floor(panel.Accept.AbsoluteSize.Y)} px de haut`
		)
		shot("tel_invitation")
		act(campGui, "TeamDecline")
		act(campGui, "Close")
	end

	for _, id in fakes do
		test:InvokeServer("Gone", id)
	end
	finish()
end
