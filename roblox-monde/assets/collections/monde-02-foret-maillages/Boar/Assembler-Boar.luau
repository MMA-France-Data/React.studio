-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Boar"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0.00009734156796137317,0.03899556583750624,0.43500000000000005,1,0,0,0,1,0,0,0,1},["size"]={1.1849574999684915,1.2279911316750125,1.77}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.16999999999999998,-0.9047501635551453,1,0,0,0,1,0,0,0,1},["size"]={0.86,0.82,1.3295003271102905}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.34448077771109037,0.5946560119834521,-0.45956683519012476,1,0,0,0,1,0,0,0,1},["size"]={0.29986049493803424,0.41972102516003845,0.27345284267761283}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.38613943483704843,-0.445,-0.169,1,0,0,0,1,0,0,0,1},["size"]={0.3710803458662554,0.7100000000000001,0.47200000000000003}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.39073642183475044,-0.445,0.9669999999999999,1,0,0,0,1,0,0,0,1},["size"]={0.3802743198616594,0.7100000000000001,0.47199999999999986}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.34448077771109037,0.5946560119834521,-0.45956683519012476,1,0,0,0,1,0,0,0,1},["size"]={0.29986049493803424,0.41972102516003845,0.27345284267761283}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.38613943483704843,-0.445,-0.169,1,0,0,0,1,0,0,0,1},["size"]={0.3710803458662554,0.7100000000000001,0.47200000000000003}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.39073642183475044,-0.445,0.9669999999999999,1,0,0,0,1,0,0,0,1},["size"]={0.3802743198616594,0.7100000000000001,0.47199999999999986}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0.005399685578191777,0.1950605480168482,1.3439341621051,1,0,0,0,1,0,0,0,1},["size"]={0.124926153111802,0.30003707337801866,0.3693736241253933}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.32851311564445496,0.2838161289691925,-0.8876825571060181,1,0,0,0,1,0,0,0,1},["size"]={0.05968296527862549,0.10421109199523926,0.14666962623596191}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.32851311564445496,0.2838161289691925,-0.8876825571060181,1,0,0,0,1,0,0,0,1},["size"]={0.05968296527862549,0.10421109199523926,0.14666962623596191}},{["name"]="LegFLFoot",["fbxName"]="Import3D_LegFLFoot",["cf"]={-0.41,-0.86,-0.21999999999999997,1,0,0,0,1,0,0,0,1},["size"]={0.30300000000000005,0.15800000000000014,0.28}},{["name"]="LegFRFoot",["fbxName"]="Import3D_LegFRFoot",["cf"]={0.41,-0.86,-0.21999999999999997,1,0,0,0,1,0,0,0,1},["size"]={0.30300000000000005,0.15800000000000014,0.28}},{["name"]="LegBLFoot",["fbxName"]="Import3D_LegBLFoot",["cf"]={-0.41,-0.86,0.916,1,0,0,0,1,0,0,0,1},["size"]={0.30300000000000005,0.15800000000000014,0.28}},{["name"]="LegBRFoot",["fbxName"]="Import3D_LegBRFoot",["cf"]={0.41,-0.86,0.916,1,0,0,0,1,0,0,0,1},["size"]={0.30300000000000005,0.15800000000000014,0.28}},{["name"]="TuskBase-1",["fbxName"]="Import3D_TuskBase-1",["cf"]={-0.30388060552146956,0.010178020752588626,-1.2088635306186317,1,0,0,0,1,0,0,0,1},["size"]={0.2799610010467007,0.3676806298322014,0.39393944955447324}},{["name"]="TuskBase1",["fbxName"]="Import3D_TuskBase1",["cf"]={0.30388060552146956,0.010178020752588626,-1.2088635306186317,1,0,0,0,1,0,0,0,1},["size"]={0.2799610010467007,0.3676806298322014,0.39393944955447324}}}
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
    assert(count == #members + 1 and joints == 9, "Structure inattendue")
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
