-- Plugin de test automatique pour Roblox Studio (installé par run.ps1 dans %LOCALAPPDATA%\Roblox\Plugins).
--
-- Il ne fait RIEN dans une place normale : il s'arrête tout de suite si la place ne contient pas
-- ReplicatedStorage.__AutoPlayTest. Cet objet n'existe que dans les places de test construites par
-- run.ps1 / mkproj.cjs (jamais dans default.project.json, donc jamais dans le jeu publié).
--
-- Dans une place de test :
--   * en édition : lance Play tout seul (StudioTestService:ExecutePlayModeAsync) ;
--   * sur le serveur de test : exécute ReplicatedStorage.__AutoTestScript s'il existe, puis arrête
--     le test au bout de __AutoPlayTest.Value secondes ;
--   * sur le client de test : exécute ReplicatedStorage.__AutoTestClient s'il existe ;
--   * partout : copie la fenêtre Sortie vers http://127.0.0.1:34999 (logserver.cjs, sur ce PC
--     uniquement). Le client n'a pas le droit de faire des requêtes HTTP : il passe par le serveur.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

local marker = ReplicatedStorage:FindFirstChild("__AutoPlayTest")
if not marker then
	return
end
local ctx = RunService:IsEdit() and "EDIT" or (RunService:IsServer() and "SERVER" or "CLIENT")

-- Sortie : toutes les lignes (y compris celles d'avant le chargement du plugin) partent par paquets.
local queue = {}
local function push(kind, msg)
	table.insert(queue, string.format("[%s][%s][%.1f] %s", ctx, kind, os.clock(), msg))
end
for _, entry in LogService:GetLogHistory() do
	push(entry.messageType.Name, entry.message)
end
LogService.MessageOut:Connect(function(msg, messageType)
	push(messageType.Name, msg)
end)

local function post(text)
	pcall(function()
		HttpService:PostAsync("http://127.0.0.1:34999/log", text, Enum.HttpContentType.TextPlain)
	end)
end

local relay
if ctx == "SERVER" then
	relay = Instance.new("RemoteEvent")
	relay.Name = "__AutoTestLog"
	relay.OnServerEvent:Connect(function(_, text)
		if typeof(text) == "string" then
			post(text)
		end
	end)
	relay.Parent = ReplicatedStorage
elseif ctx == "CLIENT" then
	relay = ReplicatedStorage:WaitForChild("__AutoTestLog", 30)
end

task.spawn(function()
	while true do
		if #queue > 0 then
			local text = table.concat(queue, "\n")
			table.clear(queue)
			if ctx == "CLIENT" then
				if relay then
					relay:FireServer(text)
				end
			else
				post(text)
			end
		end
		task.wait(0.5)
	end
end)
push("Info", "[AUTOTEST] plugin loaded")

-- Exécute un scénario de test (ModuleScript qui renvoie function(log)).
local function runScenario(module, label)
	task.spawn(function()
		local ok, err = pcall(function()
			require(module)(push)
		end)
		push(ok and "Info" or "Error", `[AUTOTEST] {label} ` .. (if ok then "finished" else "FAILED: " .. tostring(err)))
	end)
end

local StudioTestService = game:GetService("StudioTestService")
if ctx == "EDIT" then
	task.delay(4, function()
		push("Info", "[AUTOTEST] starting play mode")
		local ok, result = pcall(function()
			return StudioTestService:ExecutePlayModeAsync({})
		end)
		push("Info", "[AUTOTEST] play mode ended " .. tostring(ok) .. " " .. tostring(result))
	end)
elseif ctx == "SERVER" then
	local scenario = ReplicatedStorage:FindFirstChild("__AutoTestScript")
	if scenario then
		runScenario(scenario, "server test")
	end
	task.delay(marker.Value, function()
		push("Info", "[AUTOTEST] ending test")
		task.wait(1.5)
		StudioTestService:EndTest("done")
	end)
else
	local scenario = ReplicatedStorage:FindFirstChild("__AutoTestClient")
	if scenario then
		runScenario(scenario, "client test")
	end
end
