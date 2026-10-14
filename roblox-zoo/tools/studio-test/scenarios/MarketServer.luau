-- TEST DU MARCHÉ, DES FAMILLES ET DU SCANNER (sa demande du 14/10) :
--   un espace se construit vide ; on y met des animaux achetés au Marché ; un frère et une sœur ont un bébé
--   consanguin ; un échange remplace un animal par un animal d'une autre famille ; le scanner fait passer un visiteur.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test market -Seconds 200
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local state = ReplicatedStorage:WaitForChild("ZooState")
	while not state:GetAttribute("Ready") do
		task.wait(0.2)
	end
	local debug = ServerStorage:WaitForChild("ZooDebug")
	local function check(ok: boolean, label: string)
		log(if ok then "Info" else "Error", (if ok then "[PASS] " else "[FAIL] ") .. label)
	end

	-- 1. L'espace se construit vide.
	debug:Invoke("Buy", "s1", "deer")
	check(#debug:Invoke("InSpace", "s1") == 0, "l'espace des cerfs est construit vide")

	-- 2. Le Marché : un cerf adulte et une biche bébé.
	local male = debug:Invoke("Offer", "Deer", "m", false)
	local baby = debug:Invoke("Offer", "Deer", "f", true)
	check(debug:Invoke("BuyOffer", male) == true, "achat d'un cerf au Marché")
	check(debug:Invoke("BuyOffer", baby) == true, "achat d'une biche bébé au Marché")
	local deer = debug:Invoke("InSpace", "s1")
	check(#deer == 2 and deer[1].fam == "Zoo de la Vallée", "les deux cerfs sont dans l'espace, de la famille du zoo vendeur (" .. tostring(deer[1] and deer[1].fam) .. ")")
	local sheepOffer = debug:Invoke("Offer", "Sheep", "m", false)
	check(debug:Invoke("BuyOffer", sheepOffer) == false, "pas d'achat de mouton sans espace pour les moutons")

	-- 3. La consanguinité : un frère et une sœur moutons (mêmes parents n°901 et n°902), seuls dans leur espace.
	debug:Invoke("Buy", "s2", "sheep")
	local brother = debug:Invoke("Give", "s2", "Sheep", "m", "Ferme test", 901, 902)
	local sister = debug:Invoke("Give", "s2", "Sheep", "f", "Ferme test", 901, 902)
	debug:Invoke("Breed", "s2", "Sheep", 5)
	debug:Invoke("Night")
	local babies = {}
	for _, animal in debug:Invoke("InSpace", "s2") do
		if animal.pa == brother and animal.ma == sister then
			table.insert(babies, animal)
		end
	end
	check(#babies > 0 and babies[1].c == true, "frère et sœur : " .. #babies .. " agneau(x) consanguin(s)")

	-- 4. L'échange : le frère part, un bélier d'une autre famille arrive.
	local swap = debug:Invoke("SwapOffer", "Sheep", "m")
	check(debug:Invoke("DoSwap", swap, brother) == true, "échange fait")
	local newcomer, stillThere = nil, false
	for _, animal in debug:Invoke("InSpace", "s2") do
		if animal.id == brother then
			stillThere = true
		elseif animal.x == "m" and animal.fam == "Parc des Cimes" then
			newcomer = animal
		end
	end
	check(not stillThere and newcomer ~= nil, "le bélier donné est parti, un bélier du Parc des Cimes est arrivé")

	-- 5. Le scanner : un visiteur au guichet, le joueur dans la cabine, il vise le billet et clique.
	debug:Invoke("Speed", 4)
	local waited = 0
	while (debug:Invoke("Queue")) == 0 and waited < 40 do
		task.wait(0.5)
		waited += 0.5
	end
	debug:Invoke("Speed", 0.2)
	local ticket = workspace.Park:WaitForChild("Ticket")
	waited = 0
	while ticket.Transparency > 0.5 and waited < 30 do
		task.wait(0.3)
		waited += 0.3
	end
	check(ticket.Transparency < 0.5, "le billet est tendu à la fenêtre")
	local before = debug:Invoke("Today").visitors
	workspace:SetAttribute("GoBooth", true)
	task.wait(3)
	local player = game:GetService("Players"):GetPlayers()[1]
	check(player.Character and player.Character:FindFirstChild("Scanner") ~= nil, "le joueur a le scanner en main dans la cabine")
	log("Info", "SHOT:scanner_yeux")
	task.wait(1)
	-- (Le scanner en main, vu de côté.)
	local root = player.Character.HumanoidRootPart
	workspace:SetAttribute("ShotCam", CFrame.lookAt(root.Position + root.CFrame.RightVector * 4 + root.CFrame.LookVector * 3 + Vector3.new(0, 1.5, 0), root.Position + Vector3.new(0, 0.5, 0)))
	task.wait(1.5)
	log("Info", "SHOT:scanner_main")
	task.wait(1)
	workspace:SetAttribute("ShotCam", nil)
	task.wait(0.5)
	workspace:SetAttribute("DoScan", true)
	task.wait(1.5)
	check(debug:Invoke("Today").visitors == before + 1, "le billet scanné fait entrer le visiteur")
	workspace:SetAttribute("GoBooth", false)
	debug:Invoke("Speed", 1)

	-- 6. Les fenêtres.
	local function shot(name: string, window: string)
		workspace:SetAttribute("OpenWindow", window)
		task.wait(2)
		log("Info", "SHOT:" .. name)
		task.wait(0.8)
	end
	workspace:SetAttribute("ShotCam", CFrame.lookAt(Vector3.new(-30, 30, 214), Vector3.new(10, 0, 150)))
	-- (Renommer un agneau depuis sa fiche.)
	local lamb = babies[1]
	if lamb then
		workspace:SetAttribute("DoRename", lamb.id)
		task.wait(1.5)
		local renamed = false
		for _, animal in debug:Invoke("InSpace", "s2") do
			if animal.id == lamb.id and animal.n == "Biscuit" then
				renamed = true
			end
		end
		check(renamed, "l'agneau s'appelle maintenant Biscuit")
	end
	local named = true
	for _, animal in debug:Invoke("InSpace", "farm") do
		if not animal.n or animal.n == "" then
			named = false
		end
	end
	check(named, "chaque animal a un prénom")
	shot("fenetre_marche", "market")
	shot("fenetre_marche_safari", "market3")
	shot("fenetre_echange", "swap")
	shot("fenetre_fiche", "fiche")
	shot("fenetre_animaux", "animals")
	workspace:SetAttribute("OpenWindow", "none")
	log("Info", "[ZOO] TEST:done")
end
