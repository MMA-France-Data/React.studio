-- Fiche d'une tour avec ses 3 niveaux côte à côte.
-- Utilisée pour la tour sélectionnée (niveau actuel, prochain niveau, gains) et
-- pour l'aperçu dans la boutique (currentLevel = 0 : rien de posé).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Towers = require(ReplicatedStorage:WaitForChild("Shared").Towers)
local UI = require(script.Parent.UI)

local TowerCard = {}
TowerCard.__index = TowerCard

TowerCard.WIDTH = 480
TowerCard.HEIGHT = 212 -- jusqu'à 6 lignes de stats (dont la vitesse d'attaque)

local GREEN = "#5AE08C"
local RED = "#F06464"

local function format(n: number): string
	if n == math.floor(n) then
		return tostring(n)
	end
	return (string.format("%.2f", n):gsub("0+$", ""))
end

-- { label, valeur, suffixe, plusPetitEstMieux }
local function statRows(def, stats)
	local rows = {
		{ "Dégâts", stats.damage, "", false },
		{ "Portée", stats.range, "", false },
		{ "Cadence", stats.cooldown, "s", true },
		-- Vitesse d'attaque : attaques par seconde (1 / cadence), arrondie à 0,01
		{ "Vitesse", math.floor(1 / stats.cooldown * 100 + 0.5) / 100, " atq/s", false },
		{ "DPS", math.floor(stats.damage / stats.cooldown * 10 + 0.5) / 10, "", false },
	}
	if def.kind == "Splash" then
		table.insert(rows, { "Zone", stats.splash, "", false })
	elseif def.kind == "Aura" then
		table.insert(rows, { "Ralenti", math.floor(stats.slow * 100 + 0.5), "%", false })
	end
	return rows
end

local function statsText(def, stats, previous): string
	local lines = {}
	local previousRows = previous and statRows(def, previous)
	for index, row in statRows(def, stats) do
		local label, value, suffix, lowerIsBetter = row[1], row[2], row[3], row[4]
		local line = `{label} <b>{format(value)}{suffix}</b>`
		if previousRows then
			local delta = value - previousRows[index][2]
			if math.abs(delta) > 1e-6 then
				local better = if lowerIsBetter then delta < 0 else delta > 0
				local sign = if delta > 0 then "+" else ""
				line ..= ` <font color="{if better then GREEN else RED}">({sign}{format(delta)})</font>`
			end
		end
		table.insert(lines, line)
	end
	return table.concat(lines, "\n")
end

local function pips(level: number, maxLevel: number): string
	return string.rep("●", level) .. string.rep("○", maxLevel - level)
end

function TowerCard.new(parent: Instance)
	local self = setmetatable({}, TowerCard)
	self.renderKey = nil

	self.frame = UI.new("Frame", {
		Size = UDim2.fromOffset(TowerCard.WIDTH, TowerCard.HEIGHT),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Parent = parent,
	}, { UI.corner(12), UI.padding(10) })
	self.stroke = UI.stroke(Color3.new(1, 1, 1), 2)
	self.stroke.Transparency = 0.2
	self.stroke.Parent = self.frame

	self.title = UI.label({
		Size = UDim2.new(0.62, 0, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = self.frame,
	})
	self.levelLabel = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.38, 0, 0, 26),
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 20,
		Parent = self.frame,
	})
	self.description = UI.label({
		Position = UDim2.new(0, 0, 0, 27),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UI.Colors.Muted,
		MaxTextSize = 14,
		Parent = self.frame,
	})

	local row = UI.new("Frame", {
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		Parent = self.frame,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self.cards = {}
	for index = 1, 3 do
		local card = UI.new("Frame", {
			Size = UDim2.new(1 / 3, -6, 1, 0),
			LayoutOrder = index,
			BackgroundColor3 = UI.Colors.PanelLight,
			Parent = row,
		}, { UI.corner(10), UI.padding(7) })
		local stroke = UI.stroke(Color3.new(1, 1, 1), 2)
		stroke.Parent = card
		local header = UI.label({
			Size = UDim2.new(1, 0, 0, 18),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = card,
		})
		local status = UI.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0.6, 0, 0, 18),
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 12,
			Parent = card,
		})
		local stats = UI.label({
			Position = UDim2.new(0, 0, 0, 21),
			Size = UDim2.new(1, 0, 1, -41),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			RichText = true,
			MaxTextSize = 13,
			Parent = card,
		})
		local cost = UI.label({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 17),
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 14,
			Parent = card,
		})
		self.cards[index] = { frame = card, stroke = stroke, header = header, status = status, stats = stats, cost = cost }
	end

	return self
end

function TowerCard:setVisible(visible: boolean)
	self.frame.Visible = visible
end

-- currentLevel = 0 : aperçu boutique. gold sert à colorer le prix du prochain niveau.
function TowerCard:render(towerType: string, currentLevel: number, gold: number)
	local def = Towers.Defs[towerType]
	local maxLevel = Towers.maxLevel(towerType)
	local nextCost = def.levels[currentLevel + 1] and def.levels[currentLevel + 1].cost
	local affordable = nextCost ~= nil and gold >= nextCost

	local key = `{towerType}:{currentLevel}:{affordable}`
	if key == self.renderKey then
		return
	end
	self.renderKey = key

	self.stroke.Color = def.color
	self.title.Text = def.displayName
	self.title.TextColor3 = def.color:Lerp(Color3.new(1, 1, 1), 0.35)
	self.description.Text = def.description
	if currentLevel == 0 then
		self.levelLabel.Text = `Pose : {def.levels[1].cost} or`
		self.levelLabel.TextColor3 = if affordable then UI.Colors.Gold else UI.Colors.Error
	else
		self.levelLabel.Text = `{pips(currentLevel, maxLevel)}  Niv. {currentLevel}/{maxLevel}`
		self.levelLabel.TextColor3 = if currentLevel >= maxLevel then UI.Colors.Gold else UI.Colors.Text
	end

	for index, card in self.cards do
		local stats = def.levels[index]
		local isNext = index == currentLevel + 1
		card.header.Text = `NIV. {index}`
		card.stats.Text = statsText(def, stats, if isNext and currentLevel > 0 then def.levels[currentLevel] else nil)

		if index < currentLevel then
			card.frame.BackgroundColor3 = UI.Colors.Panel
			card.stroke.Transparency = 1
			card.status.Text = "✓ ACQUIS"
			card.status.TextColor3 = UI.Colors.Success
			card.stats.TextTransparency = 0.45
			card.cost.Text = ""
		elseif index == currentLevel then
			card.frame.BackgroundColor3 = def.color:Lerp(UI.Colors.Panel, 0.6)
			card.stroke.Color = def.color
			card.stroke.Transparency = 0
			card.status.Text = "ACTUEL"
			card.status.TextColor3 = Color3.new(1, 1, 1)
			card.stats.TextTransparency = 0
			card.cost.Text = ""
		elseif isNext then
			card.frame.BackgroundColor3 = UI.Colors.PanelLight
			card.stroke.Color = if affordable then UI.Colors.Success else UI.Colors.Error
			card.stroke.Transparency = 0.2
			card.status.Text = if currentLevel == 0 then "POSE" else "PROCHAIN"
			card.status.TextColor3 = if affordable then UI.Colors.Success else UI.Colors.Error
			card.stats.TextTransparency = 0
			card.cost.Text = `{stats.cost} or`
			card.cost.TextColor3 = if affordable then UI.Colors.Gold else UI.Colors.Error
		else
			card.frame.BackgroundColor3 = UI.Colors.Panel
			card.stroke.Transparency = 1
			card.status.Text = "🔒"
			card.status.TextColor3 = UI.Colors.Muted
			card.stats.TextTransparency = 0.45
			card.cost.Text = `{stats.cost} or`
			card.cost.TextColor3 = UI.Colors.Muted
		end
	end
end

return TowerCard
