-- PHOTOS DU ZOO : le parc vu de plusieurs endroits (entrée, place, mini-ferme, lac, espaces achetés), avec des visiteurs.
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test photo -Seconds 200
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

return function(log)
	local state = ReplicatedStorage:WaitForChild("ZooState")
	while not state:GetAttribute("Ready") do
		task.wait(0.2)
	end
	local debug = ServerStorage:WaitForChild("ZooDebug")
	log("Info", "[ZOO] blocs dans le parc : " .. tostring(debug:Invoke("Parts")))
	-- Quelques espaces achetés, pour voir leurs décors.
	for plot, habitat in { p1 = "deer", p3 = "capy", p10 = "lion", p8 = "gorilla", p6 = "bear", p5 = "croc", p2 = "wolf" } do
		debug:Invoke("Buy", plot, habitat)
	end
	debug:Invoke("Build", "cafe")
	debug:Invoke("Poop", "farm", 3)
	debug:Invoke("Sick", "farm")
	log("Info", "[ZOO] blocs avec les espaces : " .. tostring(debug:Invoke("Parts")))
	-- Le temps va plus vite : les visiteurs arrivent.
	debug:Invoke("Speed", 4)
	task.wait(30)
	debug:Invoke("Speed", 1)
	local v3 = Vector3.new
	local function shot(name: string, eye: Vector3, target: Vector3)
		workspace:SetAttribute("ShotCam", CFrame.lookAt(eye, target))
		task.wait(2.2)
		log("Info", "SHOT:zoo_" .. name)
		task.wait(1)
	end
	shot("entree", v3(34, 26, 262), v3(0, 6, 196))
	shot("place", v3(-30, 34, 214), v3(10, 0, 150))
	shot("ferme", v3(50, 14, 140), v3(86, 0, 166))
	shot("vue", v3(0, 230, 260), v3(0, 0, 0))
	shot("cerfs", v3(-42, 16, 140), v3(-86, 0, 162))
	shot("ours", v3(-80, 26, -100), v3(-80, -10, -150))
	shot("lions", v3(0, 20, -100), v3(0, 0, -156))
	shot("crocos", v3(104, 18, -30), v3(152, -2, -56))
	shot("loups", v3(-104, 16, 30), v3(-152, 2, 56))
	shot("gorilles", v3(-54, 18, -112), v3(-54, 2, -66))
	shot("capy", v3(104, 22, 20), v3(152, 0, 56))
	shot("cascade", v3(0, 14, 34), v3(0, 10, -16))
	-- La fenêtre du choix des animaux.
	local player = game:GetService("Players"):GetPlayers()[1]
	ReplicatedStorage.Remotes.ChoosePlot:FireClient(player, "p4")
	shot("choix", v3(-112, 16, -20), v3(-152, 0, -52))
	-- Les animaux de près.
	local function close(species: string, distance: number?)
		workspace:SetAttribute("ShotDistance", distance or 9)
		workspace:SetAttribute("ShotFollow", species)
		task.wait(2.2)
		log("Info", "SHOT:animal_" .. species)
		task.wait(0.8)
		workspace:SetAttribute("ShotFollow", nil)
	end
	close("Goat")
	close("Pig")
	close("Rooster", 6)
	close("Deer", 12)
	close("Lion", 12)
	close("Bear", 14)
	close("Gorilla", 12)
	local ray = workspace:Raycast(v3(84, 40, 159), v3(0, -80, 0))
	log("Info", "[ZOO] sol de la ferme : " .. tostring(ray and ray.Position.Y))
	local count, waiting = debug:Invoke("Queue")
	log("Info", "[ZOO] file : " .. tostring(count) .. " ; visiteurs : " .. tostring(waiting))
	log("Info", "[ZOO] TEST:done")
end
