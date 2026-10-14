-- TEST DE L'ARGENT ILLIMITÉ ET DE LA PAGE « TOUS LES ANIMAUX » (sa demande du 15/10).
--   powershell -ExecutionPolicy Bypass -File tools/studio-test/run.ps1 -Test admin -Seconds 90
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
	check(debug:Invoke("Unlimited") == true, "l'argent illimité est allumé dans Studio")
	local before = state:GetAttribute("Money")
	local Players = game:GetService("Players")
	check(Players:GetPlayers()[1]:GetAttribute("Admin") == true, "le joueur de Studio a le bouton Admin")
	local spent = debug:Invoke("Buy", "w2", "elephant")
	check(spent == true, "l'espace des éléphants est construit")
	check(debug:Invoke("AdminAnimal", "Elephant", "m", false) == true, "un éléphant tout de suite")
	check(debug:Invoke("AdminAnimal", "Elephant", "f", true) == true, "une éléphante bébé tout de suite")
	check(debug:Invoke("AdminAnimal", "Tiger", "m", false) == false, "pas de tigre sans espace pour les tigres")
	check(state:GetAttribute("Money") >= before, "l'argent n'a pas baissé (" .. tostring(before) .. " → " .. tostring(state:GetAttribute("Money")) .. ")")
	workspace:SetAttribute("ShotCam", CFrame.lookAt(Vector3.new(-30, 34, 214), Vector3.new(10, 0, 150)))
	workspace:SetAttribute("OpenWindow", "adminAnimals")
	task.wait(2.5)
	log("Info", "SHOT:admin_tous")
	task.wait(0.8)
	workspace:SetAttribute("OpenWindow", "none")
	log("Info", "[ZOO] TEST:done")
end
