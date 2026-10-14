-- TEST DU STOCK, DES STANDS, DE LA VIE DES ANIMAUX ET DES ÉVÉNEMENTS (sa demande du 15/10 : 1, 2, 4, 5).
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test life -Seconds 260
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local state = ReplicatedStorage:WaitForChild("ZooState")
	while not state:GetAttribute("Ready") do
		task.wait(0.2)
	end
	local debug = ServerStorage:WaitForChild("ZooDebug")
	local v3 = Vector3.new
	local function check(ok: boolean, label: string)
		log(if ok then "Info" else "Error", (if ok then "[PASS] " else "[FAIL] ") .. label)
	end
	local function shot(name: string, eye: Vector3?, target: Vector3?, window: string?)
		if eye then
			workspace:SetAttribute("ShotCam", CFrame.lookAt(eye, target))
		end
		if window then
			workspace:SetAttribute("OpenWindow", window)
		end
		task.wait(2)
		log("Info", "SHOT:" .. name)
		task.wait(0.8)
		if window then
			workspace:SetAttribute("OpenWindow", "none")
		end
	end

	-- 1. LE STOCK : une commande, le camion, les cartons sur le quai, le magasinier qui les range.
	local hayBefore = debug:Invoke("Stock", "hay")
	check(hayBefore == 20, "le stock de départ : 20 foin")
	debug:Invoke("Order", { hay = 2, drinks = 1 }, 2)
	task.wait(9)
	check(debug:Invoke("Boxes") == 3, "le camion a livré 3 cartons sur le quai (" .. tostring(debug:Invoke("Boxes")) .. ")")
	shot("quai_livraison", v3(-4, 16, 200), v3(-24, 2, 184))
	debug:Invoke("Hire", "storekeeper")
	local waited = 0
	while debug:Invoke("Boxes") > 0 and waited < 60 do
		task.wait(1)
		waited += 1
	end
	waited = 0
	while (debug:Invoke("Stock", "hay") < hayBefore + 20 or debug:Invoke("Stock", "drinks") < 24) and waited < 20 do
		task.wait(1)
		waited += 1
	end
	check(debug:Invoke("Stock", "hay") == hayBefore + 20, "le magasinier a rangé le foin (" .. tostring(debug:Invoke("Stock", "hay")) .. ")")
	check(debug:Invoke("Stock", "drinks") == 24, "et les boissons (" .. tostring(debug:Invoke("Stock", "drinks")) .. ")")

	-- 2. LES STANDS : une buvette (le magasinier la remplit), des toilettes ; des visiteurs assoiffés.
	debug:Invoke("Buy", "w1", "deer")
	check(debug:Invoke("BuildShop", "k3", "drinks") == true, "buvette construite")
	check(debug:Invoke("BuildShop", "k4", "toilets") == true, "toilettes construites")
	waited = 0
	while (debug:Invoke("Shop", "k3").n or 0) == 0 and waited < 60 do
		task.wait(1)
		waited += 1
	end
	check((debug:Invoke("Shop", "k3").n or 0) > 0, "le magasinier a rempli la buvette (" .. tostring(debug:Invoke("Shop", "k3").n) .. ")")
	shot("stands", v3(-150, 20, 130), v3(-150, 4, 88))
	debug:Invoke("Hire", "cashier")
	debug:Invoke("Speed", 3)
	task.wait(25)
	debug:Invoke("Speed", 1)
	debug:Invoke("Thirsty")
	local stockBefore = debug:Invoke("Shop", "k3").n
	task.wait(40)
	local today = debug:Invoke("Today")
	check((debug:Invoke("Shop", "k3").n or 0) < stockBefore or (today.money.shops or 0) > 0, "des visiteurs ont acheté à boire (ventes : " .. tostring(today.money.shops) .. " $)")
	log("Info", "[ZOO] poubelles : " .. table.concat(debug:Invoke("Bins"), ","))

	-- 4. LES MALADIES : examiner, le mauvais médicament ne marche pas, le bon oui.
	local sick = debug:Invoke("Sick", "farm", "worms")
	check(debug:Invoke("Animal", sick).d == "worms", "un animal a des parasites")
	debug:Invoke("Examine", sick)
	check(debug:Invoke("Animal", sick).e == true, "il est examiné")
	check(debug:Invoke("Treat", sick, "syrup") == false, "le sirop ne soigne pas les parasites")
	check(debug:Invoke("Treat", sick, "vermi") == true, "le vermifuge le soigne")

	-- 4. LA GROSSESSE, LA NAISSANCE, LA VIEILLESSE.
	local stag = debug:Invoke("Give", "w1", "Deer", "m", "Parc des Cimes")
	local doe = debug:Invoke("Give", "w1", "Deer", "f", "Zoo de la Vallée")
	debug:Invoke("Conceive", 1)
	debug:Invoke("Night")
	check((debug:Invoke("Animal", doe).g or 0) > 0, "la biche est enceinte (naissance le jour " .. tostring(debug:Invoke("Animal", doe).g) .. ")")
	debug:Invoke("Pregnant", doe, stag, 1)
	debug:Invoke("Night")
	local fawn = false
	for _, animal in debug:Invoke("InSpace", "w1") do
		if animal.ma == doe and animal.pa == stag then
			fawn = true
		end
	end
	check(fawn, "le faon est né, de ses deux parents")
	local sick2 = debug:Invoke("Sick", "w1", "cold")
	debug:Invoke("Examine", sick2)
	workspace:SetAttribute("FicheId", doe)
	shot("fiche_enceinte", nil, nil, "fiche_id")
	debug:Invoke("Age", stag, 200)
	debug:Invoke("Night")
	check(debug:Invoke("Animal", stag) == nil, "le vieux cerf est mort de vieillesse")

	-- 5. LA MÉTÉO ET L'INSPECTEUR.
	debug:Invoke("Weather", "rain", "inspection")
	debug:Invoke("SpawnVisitor", "inspector")
	shot("pluie", v3(10, 30, 230), v3(0, 0, 150))
	waited = 0
	while not debug:Invoke("Today").inspection and waited < 240 do
		task.wait(1)
		waited += 1
	end
	check(debug:Invoke("Today").inspection ~= nil, "l'inspecteur a donné sa note : " .. tostring(debug:Invoke("Today").inspection))
	debug:Invoke("Weather", "sun", nil)

	-- Les fenêtres.
	workspace:SetAttribute("ShotCam", CFrame.lookAt(v3(-30, 34, 214), v3(10, 0, 150)))
	shot("fenetre_commandes", nil, nil, "orders")
	shot("fenetre_prix", nil, nil, "prices")
	shot("fenetre_pharmacie", nil, nil, "pharmacy")
	shot("fenetre_stand", nil, nil, "buildShop")
	debug:Invoke("Toy", "w1", "salt")
	shot("fenetre_jeux", nil, nil, "toys")
	log("Info", "[ZOO] TEST:done")
end
