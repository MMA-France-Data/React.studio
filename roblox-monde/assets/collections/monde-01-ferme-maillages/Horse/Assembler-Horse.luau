-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Horse"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,-0.10843269526958466,0.35436612367630005,1,0,0,0,1,0,0,0,1},["size"]={1.235975980758667,1.2065252363681793,2.1975995302200317}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0,0.45500000566244125,-0.42500002682209015,1,0,0,0,1,0,0,0,1},["size"]={0.8199999928474426,1.0700000077486038,1.2900000512599945}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.8621982634067535,-1.0284107327461243,1,0,0,0,1,0,0,0,1},["size"]={0.5515163540840149,0.9505440592765808,1.1321064233779907}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.1626002937555313,1.2129784226417542,-0.6325368285179138,1,0,0,0,1,0,0,0,1},["size"]={0.20313730835914612,0.2534877061843872,0.20356130599975586}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.1626002937555313,1.2129784226417542,-0.6325368285179138,1,0,0,0,1,0,0,0,1},["size"]={0.20313730835914612,0.2534877061843872,0.20356130599975586}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.45562857389450073,-0.5903269201517105,-0.33905385434627533,1,0,0,0,1,0,0,0,1},["size"]={0.3212181329727173,0.6383123099803925,0.3510155975818634}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.45562857389450073,-1.1937131881713867,-0.3693137988448143,1,0,0,0,1,0,0,0,1},["size"]={0.3819239139556885,0.7175121307373047,0.45130570232868195}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.45562857389450073,-0.5903269201517105,-0.33905385434627533,1,0,0,0,1,0,0,0,1},["size"]={0.3212181329727173,0.6383123099803925,0.3510155975818634}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.45562857389450073,-1.1937131881713867,-0.3693137988448143,1,0,0,0,1,0,0,0,1},["size"]={0.3819239139556885,0.7175121307373047,0.45130570232868195}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.45562857389450073,-0.5903269201517105,0.9318645298480988,1,0,0,0,1,0,0,0,1},["size"]={0.3212181329727173,0.6383123099803925,0.35101550817489624}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.45562857389450073,-1.1937131881713867,0.9016045928001404,1,0,0,0,1,0,0,0,1},["size"]={0.3819239139556885,0.7175121307373047,0.4513057470321655}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.45562857389450073,-0.5903269201517105,0.9318645298480988,1,0,0,0,1,0,0,0,1},["size"]={0.3212181329727173,0.6383123099803925,0.35101550817489624}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.45562857389450073,-1.1937131881713867,0.9016045928001404,1,0,0,0,1,0,0,0,1},["size"]={0.3819239139556885,0.7175121307373047,0.4513057470321655}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.3803464708905646,1.2458477217545445,1,0,0,0,1,0,0,0,1},["size"]={0.34,0.7441719230837356,0.49749374568009963}},{["name"]="TailTip",["fbxName"]="Import3D_TailTip",["cf"]={0,-1.02954024096638,1.4570259036239253,1,0,0,0,1,0,0,0,1},["size"]={0.34,0.68091951806724,0.3459481927521495}},{["name"]="HorseEyeL",["fbxName"]="Import3D_HorseEyeL",["cf"]={-0.2453292845748365,0.9939686432480812,-0.9110645926557481,1,0,0,0,1,0,0,0,1},["size"]={0.05709115412134691,0.12216536468574068,0.14688587851139112}},{["name"]="HorseEyeR",["fbxName"]="Import3D_HorseEyeR",["cf"]={0.2453292845748365,0.9939686432480812,-0.9110645926557481,1,0,0,0,1,0,0,0,1},["size"]={0.05709115412134691,0.12216536468574068,0.14688587851139112}}}
local template, imported
for _, model in Selection:Get() do
    if model:IsA("Model") then
        if model:FindFirstChild("RigRoot") and model:FindFirstChild("Animations") then
            assert(not template, "Sélectionner un seul rig template")
            template = model
        else
            assert(not imported, "Sélectionner un seul modèle FBX")
            imported = model
        end
    end
end
assert(template and imported, "Sélectionner le FBX importé et le rig template")
assert(template.Name == id, "Le template ne correspond pas à cet animal")
local sources = {}
for _, member in members do
    local found
    for _, instance in imported:GetDescendants() do
        if instance:IsA("MeshPart") and (instance.Name == member.fbxName or instance.Name == member.name) then
            assert(not found, "Maillage en double : " .. member.name)
            assert(not instance:FindFirstChildWhichIsA("Bone", true), "Utiliser le FBX Import3D-Motor6D, pas le FBX à os")
            found = instance
        end
    end
    assert(found, "Maillage manquant : " .. member.fbxName .. "; désactiver Merge Meshes")
    sources[member.name] = found
end
local rig = template:Clone()
local ok, message = pcall(function()
    for _, member in members do
        local old = rig:FindFirstChild(member.name)
        assert(old and old:IsA("BasePart"), "Ancrage manquant : " .. member.name)
        local mesh = sources[member.name]:Clone()
        mesh.Name = member.name
        mesh.Size = Vector3.new(table.unpack(member.size))
        mesh.CFrame = CFrame.new(table.unpack(member.cf))
        mesh.Color = Color3.new(1, 1, 1)
        mesh.Transparency = 0
        mesh.Anchored, mesh.CanCollide, mesh.CanTouch, mesh.CanQuery, mesh.Massless = true, false, false, false, true
        mesh.CastShadow = false
        for _, child in mesh:GetDescendants() do
            if child:IsA("LuaSourceContainer") or child:IsA("JointInstance") or child:IsA("WeldConstraint") then child:Destroy() end
        end
        mesh.Parent = rig
        for _, joint in rig:GetDescendants() do
            if joint:IsA("Motor6D") or joint:IsA("Weld") then
                if joint.Part0 == old then joint.Part0 = mesh end
                if joint.Part1 == old then joint.Part1 = mesh end
            end
        end
        old:Destroy()
    end
    local root = rig:FindFirstChild("RigRoot")
    rig.PrimaryPart = root
    root.CFrame = CFrame.identity
    local count, joints = 0, 0
    for _, instance in rig:GetDescendants() do
        if instance:IsA("BasePart") then count += 1 end
        if instance:IsA("Motor6D") then
            joints += 1
            assert(instance.Part0 and instance.Part1, "Articulation non liée")
        end
        assert(not instance:IsA("Bone"), "Ce modèle doit conserver la structure Motor6D")
    end
    assert(count == #members + 1 and joints == 15, "Structure inattendue")
    for _, clipName in {"Idle","Walk","Attack"} do
        local clip = rig.Animations:FindFirstChild(clipName)
        assert(clip and clip:IsA("KeyframeSequence"), "Clip absent : " .. clipName)
    end
    local originalRoot = template:FindFirstChild("RigRoot")
    rig:PivotTo(originalRoot.CFrame)
end)
if not ok then rig:Destroy(); error(message) end
History:SetWaypoint("Avant assemblage " .. id)
rig.Name = id
rig.Parent = workspace
Selection:Set({rig})
History:SetWaypoint("Assemblage " .. id)
print(id .. " : maillages reliés aux Motor6D, clips locaux conservés. Originaux inchangés.")
