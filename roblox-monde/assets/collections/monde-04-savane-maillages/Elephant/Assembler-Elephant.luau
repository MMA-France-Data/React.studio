-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Elephant"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,0.19749999999999995,0.56,1,0,0,0,1,0,0,0,1},["size"]={2.3,2.0749999999999997,3.04}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.8574999999999999,-1.2603797583695129,1,0,0,0,1,0,0,0,1},["size"]={1.42,1.6150000000000002,1.970759516739026}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-1.09,0.74,-0.68,1,0,0,0,1,0,0,0,1},["size"]={1.32,1.62,0.24}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={1.09,0.74,-0.68,1,0,0,0,1,0,0,0,1},["size"]={1.32,1.62,0.24}},{["name"]="Trunk",["fbxName"]="Import3D_Trunk",["cf"]={0,0.5345026215498037,-1.4829504144636823,1,0,0,0,1,0,0,0,1},["size"]={0.5627300000000001,0.9178634841042878,0.804824567408488}},{["name"]="Trunk1",["fbxName"]="Import3D_Trunk1",["cf"]={0,-0.12550888294062942,-1.7672009480801765,1,0,0,0,1,0,0,0,1},["size"]={0.47705999999999993,0.9019986630353256,0.6357307135857742}},{["name"]="Trunk2",["fbxName"]="Import3D_Trunk2",["cf"]={0,-0.7334438683357062,-2.0111994706649257,1,0,0,0,1,0,0,0,1},["size"]={0.38439999999999996,0.7147875119756708,0.5654360348614922}},{["name"]="Trunk3",["fbxName"]="Import3D_Trunk3",["cf"]={0,-0.9285527728081219,-2.364992898635414,1,0,0,0,1,0,0,0,1},["size"]={0.30637999999999993,0.43135796270784366,0.5879766707123251}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.6839999999999999,-0.5125,-0.495,1,0,0,0,1,0,0,0,1},["size"]={0.75,1.105,0.8600000000000001}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.72,-1.3199999999999998,-0.5365738546568125,1,0,0,0,1,0,0,0,1},["size"]={0.6600000000000001,0.74,0.7031477093136251}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.6839999999999999,-0.5125,-0.495,1,0,0,0,1,0,0,0,1},["size"]={0.75,1.105,0.8600000000000001}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.72,-1.3199999999999998,-0.5365738546568125,1,0,0,0,1,0,0,0,1},["size"]={0.6600000000000001,0.74,0.7031477093136251}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.6839999999999999,-0.5125,1.475,1,0,0,0,1,0,0,0,1},["size"]={0.75,1.105,0.8599999999999999}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.72,-1.3199999999999998,1.4334261453431876,1,0,0,0,1,0,0,0,1},["size"]={0.6600000000000001,0.74,0.7031477093136251}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.6839999999999999,-0.5125,1.475,1,0,0,0,1,0,0,0,1},["size"]={0.75,1.105,0.8599999999999999}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.72,-1.3199999999999998,1.4334261453431876,1,0,0,0,1,0,0,0,1},["size"]={0.6600000000000001,0.74,0.7031477093136251}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.07422520880333461,2.208831365220898,1,0,0,0,1,0,0,0,1},["size"]={0.14265847744427304,0.7896181118858256,0.5292683100756357}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0.05774881998032702,-0.847026488204531,2.4741789064948945,1,0,0,0,1,0,0,0,1},["size"]={0.24650990002247114,0.9670061267838739,0.27907429788491056}}}
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
