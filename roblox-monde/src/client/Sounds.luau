-- LES SONS DU JEU (demande du créateur, 09/10). Pour en changer un : remplacer son `id` ci-dessous par celui d'un son
-- de la boutique des créateurs de Roblox (« rbxassetid://NUMÉRO »).
-- Ceux d'ici sont tous des sons fournis par Roblox, sans rien à importer : les trois sons de l'épée classique de
-- Roblox, et les fichiers livrés avec le jeu lui-même (« rbxasset://sounds/... »). Le choix est donc petit : ce
-- sont des sons de départ, à remplacer par de plus beaux quand le créateur en aura choisi.
--   volume : de 0 à 1 ; pitch : la hauteur (1 = normal), tirée au hasard entre les deux nombres à chaque fois ;
--   gap : pas plus d'une fois toutes les `gap` secondes (les pièces tombent par dizaines).
local SoundService = game:GetService("SoundService")

local Sounds = {}

Sounds.LIST = {
	swing = { id = "rbxassetid://12222216", volume = 0.45, pitch = { 0.9, 1.15 }, gap = 0.05 }, -- un coup d'épée
	swingBig = { id = "rbxassetid://12222208", volume = 0.5, pitch = { 0.85, 1 }, gap = 0.05 }, -- un coup sur trois
	sword = { id = "rbxassetid://12222225", volume = 0.6, pitch = { 1, 1 } }, -- une nouvelle épée
	coin = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.5, pitch = { 1.5, 1.9 }, gap = 0.08 }, -- des pièces
	boss = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.6, pitch = { 0.9, 1 } }, -- un boss battu
	level = { id = "rbxasset://sounds/action_get_up.mp3", volume = 0.6, pitch = { 1.25, 1.25 } }, -- un niveau gagné
	hatch = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.6, pitch = { 1.3, 1.5 } }, -- un œuf qui éclot
	click = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.4, pitch = { 1, 1 }, gap = 0.05 }, -- un bouton
}

local made, last = {}, {}
local random = Random.new()

function Sounds.play(name: string)
	local info = Sounds.LIST[name]
	if not info then
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
		sound.Volume = info.volume
		sound.Parent = SoundService
		made[name] = sound
	end
	sound.PlaybackSpeed = random:NextNumber(info.pitch[1], info.pitch[2])
	-- (PlayLocalSound : le même son peut se superposer à lui-même, et seul ce joueur l'entend.)
	SoundService:PlayLocalSound(sound)
end

return Sounds
