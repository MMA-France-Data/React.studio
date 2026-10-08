-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Velociraptor"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,0.06000000000000005,-0.37,1,0,0,0,1,0,0,0,1},["size"]={0.92,0.8999999999999999,1.82}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0.00007348226898817867,0.4155109577668399,-1.3511748501451253,1,0,0,0,1,0,0,0,1},["size"]={0.6099975948579507,1.1204064428739202,0.9569325989294641}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={-0.000020503997802734375,0.925997235658665,-2.06,1,0,0,0,1,0,0,0,1},["size"]={0.6835926175117493,0.6959944713173298,1.2199999999999998}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.627,-2.175,1,0,0,0,1,0,0,0,1},["size"]={0.5325916491252861,0.2959999999999998,1.0099999999999996}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,0.020000000000000018,1.0078147421640964,1,0,0,0,1,0,0,0,1},["size"]={0.46,0.4388268383802889,1.187738765185287}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0,0.171966334145069,2.1381897316673557,1,0,0,0,1,0,0,0,1},["size"]={0.21493877268270473,0.3237250231282509,1.305935652675499}},{["name"]="ArmL",["fbxName"]="Import3D_ArmL",["cf"]={-0.3858943714123956,0.07261037832734107,-0.9942304036537807,1,0,0,0,1,0,0,0,1},["size"]={0.3612236363575107,0.49126762298587145,0.31097838955382184}},{["name"]="ForearmL",["fbxName"]="Import3D_ForearmL",["cf"]={-0.45999999999999996,-0.21072579655646956,-1.3509848443027532,1,0,0,0,1,0,0,0,1},["size"]={0.21399423297454584,0.43838706386097936,0.7596303113944933}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.44180439656399373,-0.16554496834861926,-0.3142351699185947,1,0,0,0,1,0,0,0,1},["size"]={0.5908333080952992,0.9601617078725667,0.8329578885780473}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.51,-0.749999044152525,-0.4698426252463709,1,0,0,0,1,0,0,0,1},["size"]={0.24727469423673992,0.6430978021059088,0.5692742915886322}},{["name"]="FootBL",["fbxName"]="Import3D_FootBL",["cf"]={-0.484,-1.0056962645386567,-0.5411833959335548,1,0,0,0,1,0,0,0,1},["size"]={0.38200000000000006,0.36349245972915223,0.7502988483683607}},{["name"]="ArmR",["fbxName"]="Import3D_ArmR",["cf"]={0.3858943714123956,0.07261037832734107,-0.9942304036537807,1,0,0,0,1,0,0,0,1},["size"]={0.3612236363575107,0.49126762298587145,0.31097838955382184}},{["name"]="ForearmR",["fbxName"]="Import3D_ForearmR",["cf"]={0.45999999999999996,-0.21072579655646956,-1.3509848443027532,1,0,0,0,1,0,0,0,1},["size"]={0.21399423297454584,0.43838706386097936,0.7596303113944933}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.44180439656399373,-0.16554496834861926,-0.3142351699185947,1,0,0,0,1,0,0,0,1},["size"]={0.5908333080952992,0.9601617078725667,0.8329578885780473}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.51,-0.749999044152525,-0.4698426252463709,1,0,0,0,1,0,0,0,1},["size"]={0.24727469423673992,0.6430978021059088,0.5692742915886322}},{["name"]="FootBR",["fbxName"]="Import3D_FootBR",["cf"]={0.484,-1.0056962645386567,-0.5411833959335548,1,0,0,0,1,0,0,0,1},["size"]={0.38200000000000006,0.36349245972915223,0.7502988483683607}}}
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
    assert(count == #members + 1 and joints == 16, "Structure inattendue")
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
