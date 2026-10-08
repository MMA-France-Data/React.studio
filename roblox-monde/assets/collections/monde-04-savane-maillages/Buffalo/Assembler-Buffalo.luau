-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Buffalo"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0.000032254556879385277,0.15349297718938554,0.39,1,0,0,0,1,0,0,0,1},["size"]={1.687581624521706,1.5569859543787712,2.3200000000000003}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0,0.22621864019273155,-0.7896874174439115,1,0,0,0,1,0,0,0,1},["size"]={1.3,1.326016868098307,0.9627116296750903}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.32548026756870846,-1.6407504415512086,1,0,0,0,1,0,0,0,1},["size"]={3.0413585895840107,1.3909605351374168,1.141500883102417}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.7096637694066256,0.42,-1.1955187522342954,1,0,0,0,1,0,0,0,1},["size"]={0.5763199171906095,0.319189102275916,0.21604486247476862}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.7096637694066256,0.42,-1.1955187522342954,1,0,0,0,1,0,0,0,1},["size"]={0.5763199171906095,0.319189102275916,0.21604486247476862}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.5208617633144829,-0.275,-0.474,1,0,0,0,1,0,0,0,1},["size"]={0.589702523610329,0.9299999999999999,0.6699999999999999}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.527,-0.899,-0.4845,1,0,0,0,1,0,0,0,1},["size"]={0.41856000000000004,0.5379999999999999,0.479}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.5208617633144829,-0.275,-0.474,1,0,0,0,1,0,0,0,1},["size"]={0.589702523610329,0.9299999999999999,0.6699999999999999}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.527,-0.899,-0.4845,1,0,0,0,1,0,0,0,1},["size"]={0.41856000000000004,0.5379999999999999,0.479}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.5276686002785022,-0.275,1.163,1,0,0,0,1,0,0,0,1},["size"]={0.5760888496822905,0.9299999999999999,0.6699999999999999}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.527,-0.899,1.1525,1,0,0,0,1,0,0,0,1},["size"]={0.41856000000000004,0.5379999999999999,0.4790000000000001}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.5276686002785022,-0.275,1.163,1,0,0,0,1,0,0,0,1},["size"]={0.5760888496822905,0.9299999999999999,0.6699999999999999}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.527,-0.899,1.1525,1,0,0,0,1,0,0,0,1},["size"]={0.41856000000000004,0.5379999999999999,0.4790000000000001}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.08126118776315916,1.697400990893541,1,0,0,0,1,0,0,0,1},["size"]={0.12173523408577967,0.5780512713457798,0.593860378327326}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0.05000000000000002,-0.6338554504397982,2.0196940680824342,1,0,0,0,1,0,0,0,1},["size"]={0.26970607726112944,0.7488574432939563,0.3289310024313197}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.34728774428367615,0.4107239842414856,-1.74375319480896,1,0,0,0,1,0,0,0,1},["size"]={0.1410796046257019,0.14107981324195862,0.14952516555786133}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.34728774428367615,0.4107239842414856,-1.74375319480896,1,0,0,0,1,0,0,0,1},["size"]={0.1410796046257019,0.14107981324195862,0.14952516555786133}}}
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
