-- LES SONS DU JEU (demandes du créateur, 09/10).
-- POUR CHANGER OU AJOUTER UN SON : mettre son numéro de la boutique des créateurs de Roblox à la place de l'`id`
-- (« rbxassetid://NUMÉRO »). Un `id` vide (« "" ») = pas de son, sans erreur : c'est une place qui attend son numéro.
--   volume : de 0 à 1 ; pitch : la hauteur (1 = normal), tirée au hasard entre les deux nombres à chaque fois ;
--   gap : pas plus d'une fois toutes les `gap` secondes (les pièces tombent par dizaines).
-- DEUX RÉGLAGES DE VOLUME, que le joueur change avec la roue dentée (attributs « VolMusic » et « VolFx », de 0 à
-- 100) : la musique, et tout le reste (coups, pièces, clics, pas).
-- Les sons déjà en place sont tous fournis par Roblox, sans rien à importer : les trois sons de l'épée classique
-- et les fichiers livrés avec le jeu lui-même (« rbxasset://sounds/... »).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Sounds = {}

Sounds.LIST = {
	-- LE COUP D'ÉPÉE : faible (sa demande), et par-dessus le son propre à l'épée (SWORD_VOICE), très faible lui aussi.
	swing = { id = "rbxassetid://12222216", volume = 0.22, pitch = { 0.9, 1.15 }, gap = 0.05 },
	swingBig = { id = "rbxassetid://12222208", volume = 0.25, pitch = { 0.85, 1 }, gap = 0.05 }, -- un coup sur trois
	sword = { id = "rbxassetid://12222225", volume = 0.6, pitch = { 1, 1 } }, -- une nouvelle épée
	coin = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.5, pitch = { 1.5, 1.9 }, gap = 0.08 }, -- des pièces
	boss = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.6, pitch = { 0.9, 1 } }, -- un boss battu
	level = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.6, pitch = { 1.25, 1.25 } }, -- un niveau gagné
	hatch = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.6, pitch = { 1.3, 1.5 } }, -- un œuf qui éclot
	click = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.35, pitch = { 1, 1 }, gap = 0.04 }, -- un bouton
	-- LES SONS PROPRES AUX ÉPÉES (voir SWORD_VOICE) : à remplir avec les numéros du créateur.
	tiger = { id = "", volume = 0.12, pitch = { 0.9, 1.1 }, gap = 0.35 }, -- le grognement du tigre
}
-- Le son qu'une épée ajoute à chacun de ses coups, selon son modèle (SwordPalette.gameOrder).
Sounds.SWORD_VOICE = { TigerClaw = "tiger" }
-- LES MUSIQUES : jouées l'une après l'autre, en boucle, doucement. À remplir avec les numéros du créateur.
Sounds.MUSIC = {}
Sounds.MUSIC_VOLUME = 0.35 -- le volume de la musique quand son réglage est à 100
-- Les réglages au départ (de 0 à 100).
Sounds.DEFAULT_MUSIC, Sounds.DEFAULT_FX = 30, 70

local player = Players.LocalPlayer
local made, last = {}, {}
local random = Random.new()

local function level(name: string, fallback: number): number
	return math.clamp(tonumber(player:GetAttribute(name)) or fallback, 0, 100) / 100
end

function Sounds.play(name: string)
	local info = Sounds.LIST[name]
	if not info or info.id == "" then
		return
	end
	local now = os.clock()
	if info.gap and now - (last[name] or 0) < info.gap then
		return
	end
	last[name] = now
	local sound = made[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Monde_" .. name
		sound.SoundId = info.id
		sound.Parent = SoundService
		made[name] = sound
	end
	sound.Volume = info.volume * level("VolFx", Sounds.DEFAULT_FX)
	sound.PlaybackSpeed = random:NextNumber(info.pitch[1], info.pitch[2])
	-- (PlayLocalSound : le même son peut se superposer à lui-même, et seul ce joueur l'entend.)
	SoundService:PlayLocalSound(sound)
end

-- La musique de fond, et les bruits de pas du personnage (ceux de Roblox), qui suivent les réglages.
function Sounds.start()
	local music = Instance.new("Sound")
	music.Name = "Monde_Music"
	music.Parent = SoundService
	local track = 0
	local function nextTrack()
		if #Sounds.MUSIC == 0 then
			return
		end
		track = track % #Sounds.MUSIC + 1
		music.SoundId = Sounds.MUSIC[track]
		music:Play()
	end
	music.Ended:Connect(nextTrack)
	local function tune()
		music.Volume = Sounds.MUSIC_VOLUME * level("VolMusic", Sounds.DEFAULT_MUSIC)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			for _, sound in root:GetChildren() do
				if sound:IsA("Sound") then
					if not sound:GetAttribute("Base") then
						sound:SetAttribute("Base", sound.Volume)
					end
					sound.Volume = sound:GetAttribute("Base") * level("VolFx", Sounds.DEFAULT_FX) / (Sounds.DEFAULT_FX / 100)
				end
			end
		end
	end
	player:GetAttributeChangedSignal("VolMusic"):Connect(tune)
	player:GetAttributeChangedSignal("VolFx"):Connect(tune)
	player.CharacterAdded:Connect(function()
		task.wait(2)
		tune()
	end)
	tune()
	nextTrack()
end

return Sounds
