-- Faux Roblox pour tester src/client/AutoTranslate.luau et src/shared/Lang.luau sans Studio (utilisé par
-- autotranslate-test.cjs, qui colle ici les vraies sources et les tests de autotranslate-tests.luau, puis lance luau).
-- Juste ce dont ces deux modules ont besoin : instances (textes, parents, attributs), signaux (immédiats ou « différés »
-- comme Workspace.SignalBehavior = Deferred), joueur local, services. Rien de tout ça n'est dans le jeu.
local SOURCES = {}
--@@SOURCES@@

local realTypeof = typeof
local DEFERRED = false -- vrai : les événements attendent flush() (comme le mode différé de Roblox)
local queue = {}

----------------------------------------------------------------------
-- Signaux
----------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local connection = { connected = true, fn = fn }
	function connection:Disconnect()
		self.connected = false
	end
	table.insert(self.handlers, connection)
	return connection
end
function Signal:Fire(...)
	local list = table.clone(self.handlers)
	for _, connection in list do
		if connection.connected then
			if DEFERRED then
				table.insert(queue, { connection = connection, args = table.pack(...) })
			else
				connection.fn(...)
			end
		end
	end
end
function Signal:count()
	local n = 0
	for _, connection in self.handlers do
		if connection.connected then
			n += 1
		end
	end
	return n
end
-- Mode différé : lance les événements en attente (et ceux qu'ils déclenchent), comme Roblox avant l'image suivante.
local function flush()
	local guard = 0
	while #queue > 0 do
		guard += 1
		assert(guard < 100000, "boucle infinie d'événements")
		local item = table.remove(queue, 1)
		if item.connection.connected then
			item.connection.fn(table.unpack(item.args, 1, item.args.n))
		end
	end
end

----------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------
local IS = {
	TextLabel = { "TextLabel", "GuiObject", "GuiBase2d", "Instance" },
	TextButton = { "TextButton", "GuiButton", "GuiObject", "GuiBase2d", "Instance" },
	TextBox = { "TextBox", "GuiObject", "GuiBase2d", "Instance" },
	Frame = { "Frame", "GuiObject", "GuiBase2d", "Instance" },
	ScreenGui = { "ScreenGui", "LayerCollector", "GuiBase2d", "Instance" },
	BillboardGui = { "BillboardGui", "LayerCollector", "GuiBase2d", "Instance" },
	SurfaceGui = { "SurfaceGui", "LayerCollector", "GuiBase2d", "Instance" },
	ProximityPrompt = { "ProximityPrompt", "Instance" },
}
local Mock = {}
local Methods = {}
local function new(className, props)
	local self = setmetatable({
		_class = className,
		-- (AutoLocalize : vrai par défaut, comme dans Roblox)
		_props = { Name = className, Text = "", ActionText = "", ObjectText = "", Visible = true, Enabled = true, AutoLocalize = true },
		_children = {},
		_attributes = {},
		_propSignals = {},
		_attrSignals = {},
		_parent = nil,
		_signals = { DescendantAdded = Signal.new(), Destroying = Signal.new(), ChildAdded = Signal.new() },
		_writes = 0, -- nombre d'écritures de Text / ActionText / ObjectText (tests)
	}, Mock)
	for key, value in props or {} do
		if key ~= "Parent" then
			self._props[key] = value
		end
	end
	if props and props.Parent then
		self.Parent = props.Parent
	end
	return self
end
Mock.__index = function(self, key)
	if Methods[key] then
		return Methods[key]
	end
	if key == "ClassName" then
		return rawget(self, "_class")
	elseif key == "Parent" then
		return rawget(self, "_parent")
	end
	local signals = rawget(self, "_signals")
	if signals[key] then
		return signals[key]
	end
	local value = rawget(self, "_props")[key]
	if value ~= nil then
		return value
	end
	for _, child in rawget(self, "_children") do
		if child._props.Name == key then
			return child
		end
	end
	return nil
end
local function descendantsOf(self, list)
	for _, child in self._children do
		table.insert(list, child)
		descendantsOf(child, list)
	end
	return list
end
Mock.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			local index = table.find(old._children, self)
			if index then
				table.remove(old._children, index)
			end
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(value._children, self)
			value._signals.ChildAdded:Fire(self)
			local added = { self }
			descendantsOf(self, added)
			local ancestor = value
			while ancestor do
				for _, instance in added do
					ancestor._signals.DescendantAdded:Fire(instance)
				end
				ancestor = rawget(ancestor, "_parent")
			end
		end
		return
	end
	local props = rawget(self, "_props")
	local old = props[key]
	props[key] = value
	if key == "Text" or key == "ActionText" or key == "ObjectText" then
		rawset(self, "_writes", rawget(self, "_writes") + 1)
	end
	if old ~= value then
		local signal = rawget(self, "_propSignals")[key]
		if signal then
			signal:Fire()
		end
	end
end
function Methods:IsA(className)
	local list = IS[self._class]
	if list then
		return table.find(list, className) ~= nil
	end
	return self._class == className or className == "Instance"
end
function Methods:GetPropertyChangedSignal(property)
	self._propSignals[property] = self._propSignals[property] or Signal.new()
	return self._propSignals[property]
end
function Methods:GetAttribute(name)
	return self._attributes[name]
end
function Methods:SetAttribute(name, value)
	local old = self._attributes[name]
	self._attributes[name] = value
	if old ~= value and self._attrSignals[name] then
		self._attrSignals[name]:Fire()
	end
end
function Methods:GetAttributeChangedSignal(name)
	self._attrSignals[name] = self._attrSignals[name] or Signal.new()
	return self._attrSignals[name]
end
function Methods:GetChildren()
	return table.clone(self._children)
end
function Methods:GetDescendants()
	return descendantsOf(self, {})
end
function Methods:FindFirstChild(name)
	for _, child in self._children do
		if child._props.Name == name then
			return child
		end
	end
	return nil
end
function Methods:WaitForChild(name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild : " .. tostring(name) .. " absent")
	return child
end
function Methods:IsDescendantOf(ancestor)
	local current = self._parent
	while current do
		if current == ancestor then
			return true
		end
		current = current._parent
	end
	return false
end
function Methods:FindFirstAncestorWhichIsA(className)
	local current = self._parent
	while current do
		if current:IsA(className) then
			return current
		end
		current = current._parent
	end
	return nil
end
-- Comme Roblox : Destroying (pour l'objet et ses descendants), puis toutes les connexions coupées, parent retiré. En
-- mode différé, le Destroying en attente n'arrive donc jamais (le pire cas : AutoTranslate doit s'en sortir).
function Methods:Destroy()
	local all = { self }
	descendantsOf(self, all)
	for _, instance in all do
		instance._signals.Destroying:Fire()
	end
	for _, instance in all do
		for _, signal in instance._propSignals do
			for _, connection in signal.handlers do
				connection.connected = false
			end
		end
		for _, signal in instance._signals do
			for _, connection in signal.handlers do
				connection.connected = false
			end
		end
	end
	self.Parent = nil
end
function Methods:Invoke(...)
	return self._props.OnInvoke(...)
end
function Methods:GetPlayers()
	local list = {}
	for _, child in self._children do
		if child._class == "Player" then
			table.insert(list, child)
		end
	end
	return list
end
-- (tests) nombre de connexions encore branchées sur une propriété
function Methods:propertyConnections(property)
	local signal = self._propSignals[property]
	return if signal then signal:count() else 0
end

----------------------------------------------------------------------
-- Monde : DataModel, joueur local (Studio, langue Roblox anglaise), Shared avec Lang, Config, LangEN, LangES et LangPT
----------------------------------------------------------------------
local LOCALE = "en-us"
local STUDIO = true
local gameRoot = new("DataModel", { Name = "Game" })
local players = new("Players", { Name = "Players", Parent = gameRoot })
local replicated = new("ReplicatedStorage", { Name = "ReplicatedStorage", Parent = gameRoot })
local work = new("Workspace", { Name = "Workspace", Parent = gameRoot })
local shared = new("Folder", { Name = "Shared", Parent = replicated })
local configModule = new("ModuleScript", { Name = "Config", Parent = shared })
new("ModuleScript", { Name = "Lang", Parent = shared })
local langFolder = new("Folder", { Name = "LangEN", Parent = shared })
local glossaryModule = new("ModuleScript", { Name = "Glossary", Parent = langFolder })
local testModule = new("ModuleScript", { Name = "Test", Parent = langFolder })
local testModuleES = new("ModuleScript", { Name = "Test", Parent = new("Folder", { Name = "LangES", Parent = shared }) })
local testModulePT = new("ModuleScript", { Name = "Test", Parent = new("Folder", { Name = "LangPT", Parent = shared }) })
local localPlayer = new("Player", { Name = "Maelu", DisplayName = "Maël", LocaleId = LOCALE, Parent = players })
local playerGui = new("PlayerGui", { Name = "PlayerGui", Parent = localPlayer })
players._props.LocalPlayer = localPlayer
players._signals.PlayerAdded = Signal.new()
players._signals.PlayerRemoving = Signal.new()
local runService = {
	IsStudio = function()
		return STUDIO
	end,
	IsClient = function()
		return true
	end,
	IsServer = function()
		return false
	end,
}
local localization = setmetatable({}, {
	__index = function(_, key)
		if key == "RobloxLocaleId" then
			return LOCALE
		end
		return nil
	end,
})
local services = {
	Players = players,
	ReplicatedStorage = replicated,
	RunService = runService,
	LocalizationService = localization,
	Workspace = work,
}
function Methods:GetService(name)
	return services[name]
end

-- Modules : chaque source tourne avec son propre « script » et les faux game / workspace / Instance / task.
local loaded = {}
local makeEnv
local function load(module)
	if loaded[module] ~= nil then
		return loaded[module]
	end
	local source = SOURCES[module._props.Name]
	assert(source, "source absente : " .. module._props.Name)
	local chunk = assert(loadstring(source, "=" .. module._props.Name))
	setfenv(chunk, makeEnv(module))
	local result = chunk()
	loaded[module] = result
	return result
end
local CONFIG = { STUDIO_LANGUAGE = "auto" }
local TEST_DICTIONARY = { -- (en plus du vrai Glossaire)
	["Suivant"] = "Next",
	["Vague {1}"] = "Wave {1}",
	["Ouvrir"] = "Open",
}
local TEST_DICTIONARY_ES = { -- (seul dictionnaire espagnol : le reste est pris en anglais)
	["Archer du rempart"] = "Arquero de la muralla",
	["Suivant"] = "Siguiente",
	["Vague {1}"] = "Oleada {1}",
	["Ouvrir"] = "Abrir",
}
local TEST_DICTIONARY_PT = { -- (seul dictionnaire portugais)
	["Suivant"] = "Próximo",
	["Vague {1}"] = "Onda {1}",
}
makeEnv = function(module)
	return setmetatable({
		game = gameRoot,
		workspace = work,
		script = module,
		typeof = function(value)
			if getmetatable(value) == Mock then
				return "Instance"
			end
			return realTypeof(value)
		end,
		warn = function(...)
			print("[warn]", ...)
		end,
		Instance = {
			new = function(className)
				return new(className)
			end,
		},
		task = {
			defer = function(fn, ...)
				local args = table.pack(...)
				local connection = { connected = true, fn = function()
					fn(table.unpack(args, 1, args.n))
				end }
				table.insert(queue, { connection = connection, args = table.pack() })
			end,
			spawn = function(fn, ...)
				fn(...)
			end,
		},
		require = function(target)
			if target == configModule then
				return CONFIG
			elseif target == testModule then
				return TEST_DICTIONARY
			elseif target == testModuleES then
				return TEST_DICTIONARY_ES
			elseif target == testModulePT then
				return TEST_DICTIONARY_PT
			end
			return load(target)
		end,
	}, { __index = _G })
end

----------------------------------------------------------------------
-- Tests (autotranslate-tests.luau)
----------------------------------------------------------------------
local passed, failed = 0, 0
local function check(ok, label, detail)
	if ok then
		passed += 1
	else
		failed += 1
		print("[FAIL] " .. label .. (if detail then " : " .. tostring(detail) else ""))
	end
end
local function same(label, got, expected)
	check(got == expected, label, `obtenu « {tostring(got)} », attendu « {tostring(expected)} »`)
end
local _ = glossaryModule -- (lu par Lang dans le dossier LangEN)

--@@TESTS@@

print(`{passed} tests réussis, {failed} ratés`)
if failed > 0 then
	error(`{failed} test(s) raté(s)`, 0)
end
