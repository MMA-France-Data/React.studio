-- Executes the real HUD and Animals menu section against minimal GUI/service mocks.
-- This is a behavior and geometry check, not proof of rendering in Roblox Studio.
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function signal()
	local callbacks = {}
	return { Connect = function(_, fn) table.insert(callbacks, fn); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in table.clone(callbacks) do fn(...) end end }
end
local Vector2, Vector3, UDim, UDim2, Color3 = {}, {}, {}, {}, {}
function Vector2.new(x, y) return { X = x or 0, Y = y or 0 } end
local vectorMeta = { __add = function(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end }
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vectorMeta) end
Vector2.zero = Vector2.new()
function UDim.new(s, o) return { Scale = s or 0, Offset = o or 0 } end
function UDim2.new(xs, xo, ys, yo) return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) } end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
local colorMeta = { __index = { Lerp = function(a, b, t) return Color3.new(a.R + (b.R-a.R)*t, a.G + (b.G-a.G)*t, a.B + (b.B-a.B)*t) end } }
function Color3.new(r, g, b) return setmetatable({ R = r, G = g, B = b }, colorMeta) end
function Color3.fromRGB(r, g, b) return Color3.new(r/255, g/255, b/255) end
local Enum = setmetatable({}, { __index = function(t, key)
	local group = setmetatable({}, { __index = function(g, name) local item = { Name = name }; rawset(g, name, item); return item end })
	rawset(t, key, group); return group
end })
local ColorSequence = { new = function(...) return {...} end }
local TweenInfo = { new = function(time) return { Time = time } end }
local CFrame = { lookAt = function() return {} end }
local viewport = Vector2.new(1280, 720)
local Instance, methods, meta = {}, {}, {}
function Instance.new(class, parent)
	local item = setmetatable({ _props = { Name = class, ClassName = class, Text = "", Visible = true, ZIndex = 1, BackgroundTransparency = 0, TextTransparency = 0,
		Size = UDim2.fromOffset(100, 100), Position = UDim2.new(), AnchorPoint = Vector2.zero }, _children = {}, _attributes = {}, _signals = {},
		Activated = signal(), AttributeChanged = signal(), CharacterAdded = signal(), OnClientEvent = signal(), calls = {} }, meta)
	if class == "UIScale" then item.Scale = 1 end
	item.Parent = parent
	return item
end
function meta.__index(self, key)
	if methods[key] then return methods[key] end
	if key == "AbsoluteSize" then return self._props.AbsoluteSize or viewport end
	if self._props[key] ~= nil then return self._props[key] end
	for _, child in self._children do if child.Name == key then return child end end
end
function meta.__newindex(self, key, value)
	local old = self._props[key]
	if key == "Parent" and old ~= value then
		if old then local i = table.find(old._children, self); if i then table.remove(old._children, i) end end
		if value then table.insert(value._children, self) end
	end
	self._props[key] = value
	if old ~= value and self._signals[key] then self._signals[key]:Fire() end
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants() local all = {}; for _, child in self._children do table.insert(all, child); for _, desc in child:GetDescendants() do table.insert(all, desc) end end; return all end
function methods:FindFirstChild(name) for _, child in self._children do if child.Name == name then return child end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "missing " .. name) end
function methods:FindFirstChildOfClass(class) for _, child in self._children do if child.ClassName == class then return child end end end
function methods:IsA(class) return self.ClassName == class end
function methods:GetPropertyChangedSignal(name) if not self._signals[name] then self._signals[name] = signal() end; return self._signals[name] end
function methods:GetAttributeChangedSignal(name) return self:GetPropertyChangedSignal("attribute:" .. name) end
function methods:GetAttribute(name) return self._attributes[name] end
function methods:SetAttribute(name, value) self._attributes[name] = value; self:GetAttributeChangedSignal(name):Fire(); self.AttributeChanged:Fire(name) end
function methods:Destroy() self.Parent = nil end
function methods:ClearAllChildren() for _, child in self:GetChildren() do child:Destroy() end end
function methods:FireServer(...) table.insert(self.calls, {...}) end
function methods:GetServerTimeNow() return 100 end
function methods:GetBoundingBox() return { Position = Vector3.new() }, Vector3.new(2, 3, 2) end
local task = { spawn = function() end, delay = function() end, defer = function(fn) fn() end }
local workspace = Instance.new("Workspace")
workspace.CurrentCamera = { ViewportSize = viewport }
for _, name in { "Gym", "Zones" } do local folder = Instance.new("Folder", workspace); folder.Name = name end
local player = Instance.new("Player")
local playerGui = Instance.new("PlayerGui", player)
player:SetAttribute("Coins", 12500)
player:SetAttribute("Bag", 2)
player:SetAttribute("BagList", "Duck:1:2")
player:SetAttribute("Team", "1")
player:SetAttribute("Places", 4)
player:SetAttribute("XpNeed", 2000)
local storage = Instance.new("ReplicatedStorage")
local services = { ReplicatedStorage = storage, Players = { LocalPlayer = player }, LocalizationService = { RobloxLocaleId = "fr-fr" },
	UserInputService = { TouchEnabled = false, KeyboardEnabled = true, InputBegan = signal() }, CollectionService = {},
	RunService = { IsStudio = function() return false end }, StarterGui = { SetCoreGuiEnabled = function() end }, TweenService = {} }
function services.CollectionService:GetTagged() return {} end
function services.CollectionService:GetInstanceAddedSignal() return signal() end
local game = { GetService = function(_, name) return assert(services[name], name) end }
for _, name in { "Equip", "SellPet", "PlaceEgg", "UpgradePen", "EquipBest", "TakeEgg", "UnequipAll", "FeedPet", "BagPet", "UnbagPet", "BuySword", "Notify", "Loot", "Attack", "Travel" } do
	local remote = Instance.new("RemoteEvent", storage); remote.Name = name
end
local UI = (function()
-- INSERT UI
end)()
local Layout = (function()
-- INSERT Layout
end)()
local NumberFormat = (function()
-- INSERT NumberFormat
end)()
local Config = (function()
-- INSERT Config
end)()
local Texts = (function()
-- INSERT Texts
end)()
local spots = { ["1"] = { a = "Horse", q = 6, v = 100, xp = 60 }, ["2"] = { a = "Duck", q = 1, v = 20, xp = 10 } }
local stored = { { a = "Sheep", q = 3, v = 30 } }
local Pets = { SPOTS_FREE = 4, GRADES = { "C", "B", "A", "S" }, GRADE_ODDS = { 60, 30, 9, 1 }, RARITIES = {} }
for i = 1, 6 do Pets.RARITIES[i] = { key = "rank" .. i, color = Color3.fromRGB(150, 190, 255) } end
Pets.decode = function() return spots end
Pets.decodeStore = function() return stored end
Pets.build = function() return nil end
Pets.spotPrice = function(places) return if places < 12 then 2000 else nil end
Pets.penLevel = function(places) return places end
Pets.damageOf = function(spot) return spot.v * 10 end
Pets.healthOf = function(spot) return spot.v * 20 end
Pets.incomeOf = function(_, v) return v end
Pets.gradeOf = function() return "A" end
Pets.levelOf = function() return 2 end
Pets.luckOf = function() return 3 end
Pets.xpNeed = function() return 100 end
local client = { MenuUI = UI, MenuLayout = Layout, Poses = function() end, CombatVFX = {}, SwordVisuals = {} }
storage.Shared = { Config = Config, Pets = Pets, Texts = Texts, NumberFormat = NumberFormat }
local script = { Parent = client }
local require = function(module) return module end
client.Animals = function(env)
	local ReplicatedStorage, MenuLayout = storage, Layout
	local tr, showToast = env.tr, env.showToast
	local GREEN, RED = Color3.fromRGB(110, 255, 80), Color3.fromRGB(255, 90, 90)
	local GRADE_COLORS = { A = UI.Colors.Gold }
	local EGG_COLORS = {}
	local function rarityInfo(rank) return Pets.RARITIES[rank] end
	local function amount(value) return env.num(value) end
	local function clock(value) return tostring(value) end
-- INSERT AnimalsUI
end
(function()
-- INSERT Main
end)()
local gui = playerGui:WaitForChild("Hud")
local names = { "EggPanel", "PetPanel", "BagPanel", "SwordPanel", "ShopPanel" }
local buttons = { "EggButton", "PawButton", "BagButton", "SwordButton", "ShopButton" }
local function overlap(a, b) return a[1] < b[1]+b[3] and b[1] < a[1]+a[3] and a[2] < b[2]+b[4] and b[2] < a[2]+a[4] end
for _, screen in { {1280,720}, {1920,1080}, {820,600}, {706,300}, {844,390}, {360,640}, {390,844}, {320,568} } do
	viewport = Vector2.new(screen[1], screen[2]); gui.AbsoluteSize = viewport
	for i, name in names do
		local frame = gui[name]
		local geometry = Layout.window(name, screen[1], screen[2], UI.compact(viewport))
		local scale = UI.windowScale(viewport, Vector2.new(table.unpack(geometry.size)))
		check(frame.Scale.Scale == scale, name .. " actual scale")
		check(frame.Size.X.Offset * scale <= screen[1]-24+.01 and frame.Size.Y.Offset * scale <= screen[2]-24+.01, name .. " fits " .. screen[1] .. "x" .. screen[2])
		local rectangles = {}
		for key, rect in geometry do if key ~= "size" then
			check(rect[1] >= 0 and rect[2] >= 46 and rect[1]+rect[3] <= geometry.size[1] and rect[2]+rect[4] <= geometry.size[2], name .. "." .. key .. " bounds")
			for _, other in rectangles do check(not overlap(rect, other), name .. "." .. key .. " overlap") end
			table.insert(rectangles, rect)
		end end
		check(frame.Close.Size.X.Offset * scale >= 38 and frame.Close.Size.Y.Offset * scale >= 38, "usable close target")
		check(gui[buttons[i]].Caption.Visible and gui[buttons[i]].Caption.Text ~= "", "named navigation")
	end
	local hud = Layout.hud(screen[1], screen[2], UI.compact(viewport))
	local rectangles = {}
	for _, group in { hud.menus, { hud.wallet, hud.base, hud.luck, hud.level, hud.attack, hud.auto } } do
		for _, r in group do local scale = r[5] or 1; local rect = {r[1],r[2],r[3]*scale,r[4]*scale}
			check(rect[1]>=0 and rect[2]>=0 and rect[1]+rect[3]<=screen[1]+.01 and rect[2]+rect[4]<=screen[2]+.01, "HUD bounds")
			for _, other in rectangles do check(not overlap(rect, other), "HUD overlap on " .. screen[1] .. "x" .. screen[2]) end
			table.insert(rectangles,rect)
		end
	end
end
for i, name in names do
	gui[buttons[i]].Activated:Fire()
	check(gui[name].Visible, name .. " opens")
	check(gui.MenuBackdrop.Visible, "backdrop opens")
	for j, other in names do check(gui[other].Visible == (i == j), "one visible menu") end
	gui[name].Close.Activated:Fire()
	check(not gui[name].Visible and not gui.MenuBackdrop.Visible, "close restores HUD")
end
local function click(object) object.Activated:Fire() end
click(gui.PawButton)
click(gui.PetPanel.Best); click(gui.PetPanel.None); click(gui.PetPanel.AddPlace)
click(gui.PetPanel.Sheet.Equip); click(gui.PetPanel.Sheet.ToBag)
check(#storage.EquipBest.calls == 1 and #storage.UnequipAll.calls == 1 and #storage.UpgradePen.calls == 1, "bulk and pen actions")
check(storage.Equip.calls[1][1] == 1 and storage.BagPet.calls[1][1] == 1, "selected animal is preserved")
click(gui.PetPanel.Sheet.Feed)
local petGrid = gui.PetPanel:FindFirstChild("GridBack").Grid
click(petGrid.Pet2); check(#storage.FeedPet.calls == 0, "feeding still requires confirmation")
click(petGrid.Pet2); check(storage.FeedPet.calls[1][1] == 1 and storage.FeedPet.calls[1][2] == 2, "confirmed feeding arguments")
click(gui.SwordButton); click(gui.SwordPanel.Buy)
check(#storage.BuySword.calls == 1, "sword action")
click(gui.BagButton); click(gui.BagPanel.GridBack.Grid.Bag1)
check(storage.UnbagPet.calls[1][1] == 1, "unbag action")
click(gui.Auto); check(gui.Auto.ActiveMark.Visible, "auto has explicit on state")
click(gui.Auto); check(not gui.Auto.ActiveMark.Visible, "auto has explicit off state")
click(gui.ToBase); check(storage.Travel.calls[1][1] == "base", "base action")
for _, test in { {0,"0"}, {950,"950"}, {1000,"1K"}, {12500,"12.5K"}, {1e6,"1M"}, {1e27,"1Oc"}, {-12500,"−12.5K"}, {math.huge,"∞"}, {0/0,"0"} } do
	check(NumberFormat.short(test[1]) == test[2], "number format " .. test[2])
end
check(NumberFormat.short(12500, "fr") == "12,5K", "French number formatting")
click(gui.ShopButton)
player:SetAttribute("Coins", 1e21)
check(gui.Wallet.Coins.Text == "1Sx", "large wallet stays abbreviated")
local rows = {}; for _, child in gui.ShopPanel:GetChildren() do if child.Name == "Row" then table.insert(rows, child) end end
check(rows[1].Buy.BackgroundColor3 == UI.Colors.Green, "affordable purchase state")
player:SetAttribute("Coins", 0)
check(rows[1].Buy.BackgroundColor3 == UI.Colors.Red, "unaffordable purchase state")
click(rows[1].Buy); click(rows[2].Buy)
check(#storage.BuySword.calls == 2 and #storage.UpgradePen.calls == 2, "shop remotes preserved")
viewport = Vector2.new(1280, 720); gui.AbsoluteSize = viewport
workspace:SetAttribute("PhoneHud", true)
check(gui.ShopPanel.Size.Y.Offset == 276, "forced phone layout")
workspace:SetAttribute("PhoneHud", false)
local function luminance(color)
	local function linear(v) return if v <= .04045 then v / 12.92 else ((v + .055) / 1.055)^2.4 end
	return .2126*linear(color.R) + .7152*linear(color.G) + .0722*linear(color.B)
end
for _, fill in { UI.Colors.Blue, UI.Colors.Green, UI.Colors.Red, UI.Colors.Purple, UI.Colors.Teal, UI.Colors.Orange, UI.Colors.Panel, UI.Colors.Card } do
	check((luminance(UI.Colors.Text)+.05)/(luminance(fill)+.05) >= 4.5, "button/text contrast")
end
print("MENU_UI_CHECKS_OK: " .. checks .. " geometry, behavior, contrast and number-format assertions; real HUD + menu source, mocked Roblox services")
gui.Toast.Visible = false -- deferred toast fades are intentionally not simulated
player:SetAttribute("Coins", 12500)
-- Export only presentation properties, for optional approximate local previews.
local function json(value)
	local kind = type(value)
	if kind == "string" then return '"' .. value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t') .. '"' end
	if kind == "boolean" or kind == "number" then return tostring(value) end
	if kind ~= "table" then return "null" end
	local all = {}
	if #value > 0 then for _, item in value do table.insert(all, json(item)) end; return "[" .. table.concat(all, ',') .. "]" end
	for key, item in value do if type(item) ~= "function" then table.insert(all, json(tostring(key)) .. ":" .. json(item)) end end
	return "{" .. table.concat(all, ',') .. "}"
end
local function presentation(node)
	local props = {}
	for _, key in { "Name", "ClassName", "Visible", "Position", "Size", "AnchorPoint", "ZIndex", "BackgroundColor3", "BackgroundTransparency", "Text", "TextColor3", "TextTransparency", "TextXAlignment", "Rotation", "Color", "Thickness", "Transparency", "CornerRadius", "Scale", "MaxTextSize", "MinTextSize", "CellSize", "CellPadding", "AspectRatio", "DominantAxis", "ApplyStrokeMode" } do
		props[key] = node._props[key]
	end
	props.children = {}
	for _, child in node:GetChildren() do table.insert(props.children, presentation(child)) end
	return props
end
for _, screen in { {1280,720}, {706,300}, {360,640} } do
	viewport = Vector2.new(screen[1], screen[2]); gui.AbsoluteSize = viewport
	for i, name in names do
		gui[buttons[i]].Activated:Fire()
		print("SNAPSHOT:" .. json({ name = name .. "-" .. screen[1], width = screen[1], height = screen[2], tree = presentation(gui) }))
		gui[name].Close.Activated:Fire()
	end
	print("SNAPSHOT:" .. json({ name = "HUD-" .. screen[1], width = screen[1], height = screen[2], tree = presentation(gui) }))
end
