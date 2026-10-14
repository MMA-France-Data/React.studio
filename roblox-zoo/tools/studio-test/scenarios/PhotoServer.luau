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
	for plot, habitat in { s1 = "deer", w2 = "bear", c4 = "lion", e1 = "elephant", c1 = "gorilla", n2 = "croc", e3 = "wolf", c7 = "tiger" } do
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
	shot("vue", v3(0, 190, 330), v3(0, 0, -120))
	shot("vue_nord", v3(-330, 170, -40), v3(0, 0, -300))
	shot("entree", v3(34, 26, 262), v3(0, 6, 196))
	shot("place", v3(-30, 34, 214), v3(10, 0, 150))
	shot("cerfs", v3(-40, 22, 120), v3(-130, 0, 165))
	shot("ours", v3(-205, 30, -60), v3(-285, -10, -87))
	shot("lions", v3(20, 26, -230), v3(-57, 0, -255))
	shot("elephants", v3(205, 30, 80), v3(285, 0, 43))
	shot("gorilles", v3(-145, 24, -195), v3(-145, 0, -110))
	shot("crocos", v3(0, 26, -440), v3(0, -2, -537))
	shot("lac", v3(-60, 26, 70), v3(-120, 6, 10))
	shot("reserve2", v3(10, 14, 20), v3(36, 4, 10))
	-- La fenêtre du choix des animaux.
	local player = game:GetService("Players"):GetPlayers()[1]
	ReplicatedStorage.Remotes.ChoosePlot:FireClient(player, "w4")
	shot("choix", v3(-205, 20, -320), v3(-285, 0, -347))
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
	close("Deer", 12)
	close("Lion", 12)
	close("Bear", 14)
	close("Elephant", 26)
	close("Tiger", 12)
	local ray = workspace:Raycast(v3(84, 40, 159), v3(0, -80, 0))
	log("Info", "[ZOO] sol de la ferme : " .. tostring(ray and ray.Position.Y))
	local count, waiting = debug:Invoke("Queue")
	log("Info", "[ZOO] file : " .. tostring(count) .. " ; visiteurs : " .. tostring(waiting))
	log("Info", "[ZOO] TEST:done")
end
