-- Panneau « 🎁 DONNER » du propriétaire du jeu (client/AdminUI.luau) : offrir (ou reprendre) un pass à un joueur de
-- son serveur (demande du propriétaire, 30/09/2026 : « donner le x2 »). Le serveur vérifie TOUT : seul le
-- propriétaire du jeu (le compte qui a créé l'expérience) peut le faire, le joueur doit être dans ce serveur et le
-- pass doit exister. Le pass offert est sauvegardé chez le joueur (données giftedPasses, Monetization.setGiftedPass)
-- et compte comme acheté. Mode solo seulement, comme tous les passes : rien ne change en classé.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Monetization = require(script.Parent.Parent.Monetization)

local AdminGifts = {}

-- Tests Studio : attribut de ReplicatedStorage qui fait comme si le joueur n'était PAS le propriétaire.
AdminGifts.STUDIO_NOT_OWNER = "StudioNotOwner"

-- Vrai si ce joueur est le propriétaire du jeu (jeu publié sur son compte personnel). Dans Studio (place de test sans
-- propriétaire), oui, sauf si un test dit le contraire.
function AdminGifts.isOwner(player: Player): boolean
	if RunService:IsStudio() then
		return ReplicatedStorage:GetAttribute(AdminGifts.STUDIO_NOT_OWNER) ~= true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- Offre (give = true) ou reprend (false) le pass `passName` au joueur `targetUserId`. Renvoie (réussi, raison du refus).
function AdminGifts.handle(sender: Player, targetUserId: any, passName: any, give: any): (boolean, string?)
	if not AdminGifts.isOwner(sender) then
		return false, "réservé au propriétaire du jeu"
	end
	if typeof(targetUserId) ~= "number" or typeof(passName) ~= "string" or typeof(give) ~= "boolean" then
		return false, "demande invalide"
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	local displayName = Monetization.passDisplayName(passName)
	if not target or not displayName then
		return false, "joueur ou pass introuvable"
	end
	if not Monetization.setGiftedPass(target, passName, give) then
		return false, "données du joueur pas encore chargées"
	end
	local notify = Remotes.get("Notify")
	if give then
		notify:FireClient(sender, `Pass {displayName} offert à {target.DisplayName}`, "Success")
		if target ~= sender then
			notify:FireClient(target, `🎁 {sender.DisplayName} t'offre le pass {displayName} !`, "Success")
		end
	else
		notify:FireClient(sender, `Pass {displayName} repris à {target.DisplayName} (un pass acheté reste)`, "Info")
	end
	return true, nil
end

function AdminGifts.start()
	Remotes.get("AdminAction").OnServerEvent:Connect(function(player, action, targetUserId, passName, give)
		if action ~= "GivePass" then
			return
		end
		local ok, reason = AdminGifts.handle(player, targetUserId, passName, give)
		-- Seul le propriétaire reçoit la raison d'un refus (les autres n'ont pas le panneau).
		if not ok and AdminGifts.isOwner(player) then
			Remotes.get("Notify"):FireClient(player, `Impossible : {reason}`, "Error")
		end
	end)
end

return AdminGifts
