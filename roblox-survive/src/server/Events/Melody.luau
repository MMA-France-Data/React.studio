-- LA MÉLODIE (salle casse-tête) : le mur joue une suite de notes, chaque note allume une couleur. Il faut la refaire
-- en marchant sur les dalles de la même couleur, dans le même ordre. La suite s'allonge à chaque manche réussie.
-- Une erreur blesse tout le monde et le mur rejoue la suite. Réussir toutes les manches ouvre la porte tout de
-- suite ; si le temps est fini avant, tout le monde est éliminé.
-- Les couleurs suffisent pour jouer sans le son.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Parent.Build)

local Melody = {}

local NOTES = {
	{ color = Color3.fromRGB(255, 70, 70), pitch = 1 },
	{ color = Color3.fromRGB(70, 150, 255), pitch = 1.26 },
	{ color = Color3.fromRGB(80, 220, 100), pitch = 1.5 },
	{ color = Color3.fromRGB(255, 215, 60), pitch = 2 },
}
local PADS = { Vector3.new(-20, 0, -16), Vector3.new(20, 0, -16), Vector3.new(-20, 0, 18), Vector3.new(20, 0, 18) }
local PAD_RADIUS = 6.5
local NOTE_ON, NOTE_GAP = 0.55, 0.2 -- secondes : une note allumée, puis le noir avant la suivante
-- Sons fournis avec Roblox (aucun numéro de la bibliothèque) : une même note courte, jouée plus ou moins aiguë.
local NOTE_SOUND = "rbxasset://sounds/volume_slider.ogg"
local WRONG_SOUND = "rbxasset://sounds/ouch.ogg"

local function dim(color: Color3): Color3
	return color:Lerp(Color3.fromRGB(30, 30, 40), 0.6)
end

function Melody.new(ctx, params)
	local self = {}
	local random = Random.new()
	local folder = ctx.room.folder
	local pads, panels, sounds = {}, {}, {}

	for i, note in NOTES do
		local pad = Build.disc(ctx.static, "Pad" .. i, PAD_RADIUS * 2, 0.3, ctx.center + PADS[i] + Vector3.new(0, 0.2, 0), dim(note.color))
		pad.CanCollide = false
		pad.CanQuery = false
		pads[i] = pad
		-- Le mur du fond : quatre grands panneaux au-dessus de la porte.
		panels[i] = Build.part(
			ctx.static,
			"Panel" .. i,
			Vector3.new(9, 9, 0.6),
			ctx.center + Vector3.new(-16.5 + (i - 1) * 11, 21, ctx.halfZ - 1.4),
			dim(note.color)
		)
		local sound = Instance.new("Sound")
		sound.SoundId = NOTE_SOUND
		sound.PlaybackSpeed = note.pitch
		sound.Volume = 1.5
		sound.RollOffMaxDistance = 200
		sound.Parent = panels[i]
		sounds[i] = sound
	end
	local wrong = Instance.new("Sound")
	wrong.SoundId = WRONG_SOUND
	wrong.Volume = 1
	wrong.RollOffMaxDistance = 200
	wrong.Parent = panels[1]
	ctx.room.melodyPads = pads

	local sequence, round, index = {}, 1, 1
	local phase, timer, shown = "Pause", 0, 0
	local solved = false
	local lit = {} -- [note] = secondes restantes allumée
	local inside = {} -- [note] = un joueur était dessus à l'image d'avant

	local function publish()
		folder:SetAttribute("Melody", string.format("%s|%d|%d|%d|%d", phase, round, params.rounds, index, #sequence))
		ctx.room.melody = { sequence = sequence, phase = phase, round = round, index = index }
	end
	local function light(note: number, seconds: number, sound: boolean)
		lit[note] = seconds
		pads[note].Color = NOTES[note].color
		pads[note].Material = Enum.Material.Neon
		panels[note].Color = NOTES[note].color
		panels[note].Material = Enum.Material.Neon
		if sound then
			sounds[note]:Play()
		end
	end
	local function unlight(note: number)
		lit[note] = nil
		pads[note].Color = dim(NOTES[note].color)
		pads[note].Material = Enum.Material.SmoothPlastic
		panels[note].Color = dim(NOTES[note].color)
		panels[note].Material = Enum.Material.SmoothPlastic
	end
	local function addNote()
		local note
		repeat
			note = random:NextInteger(1, #NOTES)
		until note ~= sequence[#sequence] -- jamais deux fois la même à la suite (il faudrait sortir de la dalle)
		table.insert(sequence, note)
	end
	local function setPhase(name: string, seconds: number)
		phase, timer = name, seconds
		publish()
	end
	local function occupied(note: number): boolean
		for _, entry in ctx.players() do
			local offset = entry.root.Position - pads[note].Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= PAD_RADIUS and offset.Y < 8 then
				return true
			end
		end
		return false
	end

	local function press(note: number)
		if note == sequence[index] then
			light(note, 0.4, true)
			index += 1
			if index > #sequence then
				if round >= params.rounds then
					solved = true
					setPhase("Done", 0)
				else
					round += 1
					index = 1
					addNote()
					setPhase("Pause", 1.2)
				end
			else
				publish()
			end
		else
			wrong:Play()
			for _, entry in ctx.players() do
				ctx.damage(entry.player, Config.DAMAGE.Melody)
			end
			index = 1
			setPhase("Pause", 1.2)
		end
	end

	function self.start()
		table.clear(sequence)
		for _ = 1, params.start do
			addNote()
		end
		round, index, solved = 1, 1, false
		for note in NOTES do
			unlight(note)
		end
		setPhase("Pause", 2)
	end

	function self.update(dt: number, _elapsed: number)
		for note, left in lit do
			lit[note] = left - dt
			if lit[note] <= 0 then
				unlight(note)
			end
		end
		if phase == "Pause" then
			timer -= dt
			if timer <= 0 then
				shown = 0
				setPhase("Show", 0)
			end
		elseif phase == "Show" then
			timer -= dt
			if timer <= 0 then
				shown += 1
				if shown > #sequence then
					for note in NOTES do
						inside[note] = occupied(note)
					end
					setPhase("Play", 0)
				else
					light(sequence[shown], NOTE_ON, true)
					timer = NOTE_ON + NOTE_GAP
				end
			end
		elseif phase == "Play" then
			for note in NOTES do
				local now = occupied(note)
				if now and not inside[note] then
					inside[note] = now
					press(note)
					if phase ~= "Play" then
						break
					end
				end
				inside[note] = now
			end
		end
	end

	function self.solved(): boolean
		return solved
	end

	-- Fin du temps : la salle est perdue si la mélodie n'est pas finie.
	function self.timeout(): boolean
		return not solved
	end

	function self.stop()
		for note in NOTES do
			unlight(note)
		end
		phase = "Pause"
		folder:SetAttribute("Melody", nil)
	end

	return self
end

return Melody
