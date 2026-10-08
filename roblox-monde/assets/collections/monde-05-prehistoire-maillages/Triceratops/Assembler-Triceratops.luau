-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Triceratops"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0.0016509491614804528,0.02375062001859979,-0.3700000000000001,1,0,0,0,1,0,0,0,1},["size"]={2.032021723866,1.7375012400371994,2.92}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0.00287961335142245,0.14826744803805547,-2.0188823830745815,1,0,0,0,1,0,0,0,1},["size"]={1.2057029488907145,1.2563163810847096,0.9133991011507898}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0.011355046450260864,0.5677704914116131,-2.9200363900836885,1,0,0,0,1,0,0,0,1},["size"]={2.0711102191659148,1.9755409828232264,1.8817098074405878}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,-0.285,-3.1,1,0,0,0,1,0,0,0,1},["size"]={0.94,0.63,1.3999999999999995}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.1895994344856215,1.3979333382475545,1,0,0,0,1,0,0,0,1},["size"]={0.64,0.7287070656925544,1.231276512560683}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0,-0.38635692625721474,2.3939577233280795,1,0,0,0,1,0,0,0,1},["size"]={0.3423803458662553,0.386812213170167,1.192833479443044}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.7297402157278304,-0.5175098840342501,-1.3328879475368298,1,0,0,0,1,0,0,0,1},["size"]={0.5615448444200417,0.8792207620606425,0.6571922266705943}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.74835,-1.083905052213887,-1.2334516675095601,1,0,0,0,1,0,0,0,1},["size"]={0.27874965709126975,0.5642231297236353,0.42062645669883914}},{["name"]="FootFL",["fbxName"]="Import3D_FootFL",["cf"]={-0.75,-1.3755517319042507,-1.597232394063847,1,0,0,0,1,0,0,0,1},["size"]={0.43400000000000016,0.3334019151710359,0.6839842749254319}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.725892293112666,-0.51750988403425,0.6371120524631706,1,0,0,0,1,0,0,0,1},["size"]={0.5692406896503706,0.8792207620606427,0.6571922266705945}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.74835,-1.0839050522138869,0.7365483324904399,1,0,0,0,1,0,0,0,1},["size"]={0.27874965709126953,0.5642231297236354,0.4206264566988389}},{["name"]="FootBL",["fbxName"]="Import3D_FootBL",["cf"]={-0.75,-1.3755517319042507,0.37276760593615293,1,0,0,0,1,0,0,0,1},["size"]={0.43400000000000016,0.3334019151710359,0.6839842749254318}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.7297402157278304,-0.5175098840342501,-1.3328879475368298,1,0,0,0,1,0,0,0,1},["size"]={0.5615448444200417,0.8792207620606425,0.6571922266705943}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.74835,-1.083905052213887,-1.2334516675095601,1,0,0,0,1,0,0,0,1},["size"]={0.27874965709126975,0.5642231297236353,0.42062645669883914}},{["name"]="FootFR",["fbxName"]="Import3D_FootFR",["cf"]={0.75,-1.3755517319042507,-1.597232394063847,1,0,0,0,1,0,0,0,1},["size"]={0.43400000000000016,0.3334019151710359,0.6839842749254319}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.725892293112666,-0.51750988403425,0.6371120524631706,1,0,0,0,1,0,0,0,1},["size"]={0.5692406896503706,0.8792207620606427,0.6571922266705945}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.74835,-1.0839050522138869,0.7365483324904399,1,0,0,0,1,0,0,0,1},["size"]={0.27874965709126953,0.5642231297236354,0.4206264566988389}},{["name"]="FootBR",["fbxName"]="Import3D_FootBR",["cf"]={0.75,-1.3755517319042507,0.37276760593615293,1,0,0,0,1,0,0,0,1},["size"]={0.43400000000000016,0.3334019151710359,0.6839842749254318}}}
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
    assert(count == #members + 1 and joints == 18, "Structure inattendue")
    for _, clipName in {"Idle","Walk","Attack","Bite"} do
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
