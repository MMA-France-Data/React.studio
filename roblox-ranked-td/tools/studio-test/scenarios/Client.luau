-- Scénario de test côté client (exécuté par le plugin AutoPlayTest, map principale et match).
-- « SHOT:nom » dans la sortie = run.ps1 prend une capture de Studio (out\nom.png).
-- Un plugin ne peut pas simuler de clic : on déplace la caméra, on affiche les fenêtres
-- directement et on envoie les actions par les vrais remotes.
return function(log)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local mode = ReplicatedStorage:GetAttribute("ServerMode")

	local function say(message)
		log("Info", "[CTEST] " .. message)
	end
	local function shot(name)
		say("SHOT:" .. name)
		task.wait(1.2)
	end
	local function look(from, at)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(from, at)
	end
	local function restoreCamera()
		camera.CameraType = Enum.CameraType.Custom
	end
	-- Premier bouton visible dont le texte (ou celui d'un de ses textes) contient le motif.
	local function findButton(pattern)
		for _, gui in player.PlayerGui:GetDescendants() do
			if (gui:IsA("TextButton") or gui:IsA("TextLabel")) and gui.Visible and gui.Text:find(pattern) then
				local button = gui
				while button and not button:IsA("GuiButton") do
					button = button.Parent
				end
				if button then
					return button
				end
			end
		end
		return nil
	end

	if mode == "Match" then
		task.wait(8)
		shot("match_player")
		look(Vector3.new(0, 140, 160), Vector3.new(0, 0, 0))
		shot("match_aerial")
		restoreCamera()
		task.wait(25)
		shot("match_fight")
		return
	end

	-- Map principale : vue du joueur, vue aérienne, centre, ma parcelle
	task.wait(3)
	shot("hub_player")
	look(Vector3.new(0, 230, 290), Vector3.new(0, 0, 0))
	shot("hub_aerial")
	look(Vector3.new(0, 25, 70), Vector3.new(0, 4, 0))
	shot("hub_center")
	local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
	local plotIndex = player:GetAttribute("Plot")
	if plotIndex then
		local cf = PlotLayout.cframe(plotIndex)
		task.wait(8) -- tours posées par le scénario serveur, vague en cours
		look(cf:PointToWorldSpace(Vector3.new(32, 26, -45)), cf:PointToWorldSpace(Vector3.new(0, 2, -18)))
		shot("hub_plot_fight")
		look(cf:PointToWorldSpace(Vector3.new(-10, 12, -2)), cf:PointToWorldSpace(Vector3.new(6, 3, -22)))
		shot("hub_towers_close")
	end
	restoreCamera()
	task.wait(1)

	-- Renaissance (run à la vague 50 préparée par le scénario serveur)
	local rebirthButton = findButton("Renaissance")
	if rebirthButton then
		shot("hub_ui")
		local rebirthGui = player.PlayerGui:FindFirstChild("Rebirth")
		local overlay = rebirthGui and rebirthGui:FindFirstChildWhichIsA("TextButton")
		if overlay then
			overlay.Visible = true
			task.wait(0.8)
			shot("rebirth_window")
			overlay.Visible = false
		else
			log("Error", "[CTEST] fenêtre de renaissance introuvable")
		end
		ReplicatedStorage.Remotes.PlotAction:FireServer("Rebirth")
		task.wait(0.4)
		shot("rebirth_done")
	else
		log("Error", "[CTEST] bouton Renaissance introuvable")
	end
end
