-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Wolf"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.0004961525866247762,0.012499999999999983,0.22999999999999998,1,0,0,0,1,0,0,0,1},["size"]={0.6946230240579068,0.825,1.48}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0,0.16326536309541695,-0.46092377372172894,1,0,0,0,1,0,0,0,1},["size"]={0.7772452485095056,0.7862000335482786,0.8825191109971063}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.3482868660130645,-1.0607502341270447,1,0,0,0,1,0,0,0,1},["size"]={0.55,0.579426267973871,0.9215004682540894}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.121,-1.1335,1,0,0,0,1,0,0,0,1},["size"]={0.33286978070330375,0.184,0.793}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.18506226230353623,0.6646221419342015,-0.73,1,0,0,0,1,0,0,0,1},["size"]={0.2352647212381388,0.3742497487748707,0.19519303625343865}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.2188278798936231,-0.19499999999999998,-0.342,1,0,0,0,1,0,0,0,1},["size"]={0.25552411492621524,0.5499999999999999,0.38}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.223,-0.6335,-0.41731296138719537,1,0,0,0,1,0,0,0,1},["size"]={0.24347046817155932,0.417,0.35262592277439075}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.22916089438718745,-0.19499999999999998,0.68,1,0,0,0,1,0,0,0,1},["size"]={0.29470150521194216,0.5499999999999999,0.38000000000000006}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.231,-0.6335,0.6046870386128047,1,0,0,0,1,0,0,0,1},["size"]={0.24347046817155932,0.417,0.3526259227743907}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.18506226230353623,0.6646221419342015,-0.73,1,0,0,0,1,0,0,0,1},["size"]={0.2352647212381388,0.3742497487748707,0.19519303625343865}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.2188278798936231,-0.19499999999999998,-0.342,1,0,0,0,1,0,0,0,1},["size"]={0.25552411492621524,0.5499999999999999,0.38}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.223,-0.6335,-0.41731296138719537,1,0,0,0,1,0,0,0,1},["size"]={0.24347046817155932,0.417,0.35262592277439075}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.22916089438718745,-0.19499999999999998,0.68,1,0,0,0,1,0,0,0,1},["size"]={0.29470150521194216,0.5499999999999999,0.38000000000000006}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.231,-0.6335,0.6046870386128047,1,0,0,0,1,0,0,0,1},["size"]={0.24347046817155932,0.417,0.3526259227743907}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0.0018487698149973752,-0.07237526812839983,0.9348405894939542,1,0,0,0,1,0,0,0,1},["size"]={0.3068194152585513,0.4830916952240779,0.5510524701168499}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={-0.004671288122135464,-0.30447304576935325,1.202802046127131,1,0,0,0,1,0,0,0,1},["size"]={0.36774833478493585,0.49552806356222673,0.4937515058131362}},{["name"]="Tail2",["fbxName"]="Import3D_Tail2",["cf"]={0.003597599763363782,-0.5209454902083381,1.3789117842054917,1,0,0,0,1,0,0,0,1},["size"]={0.2785942859381445,0.37661133647711376,0.3755714154840142}},{["name"]="TailPoint",["fbxName"]="Import3D_TailPoint",["cf"]={0,-0.5983386024883864,1.4130827845658929,1,0,0,0,1,0,0,0,1},["size"]={0.24156835513896902,0.29816276534331615,0.2770121404740642}}}
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
    assert(count == #members + 1 and joints == 17, "Structure inattendue")
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
