-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Crocodile"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.044534445653223426,0.005296097094754648,-0.21000000000000002,1,0,0,0,1,0,0,0,1},["size"]={0.9200000000000002,0.6305921941895093,1.1800000000000002}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={-0.04453444565322341,0.020500000000000004,-1.28,1,0,0,0,1,0,0,0,1},["size"]={0.556,0.391,1.1999999999999997}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={-0.044534445653223426,-0.15025933726496152,-1.3375,1,0,0,0,1,0,0,0,1},["size"]={0.4242087113059642,0.14748132547007697,1.075}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.45413859902825576,-0.12377072453754442,-0.5272028961139912,1,0,0,0,1,0,0,0,1},["size"]={0.4281504965186925,0.33068669976404713,0.3635880290983988}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.4541385990282558,-0.1238241600421748,0.1727971038860088,1,0,0,0,1,0,0,0,1},["size"]={0.42815049651869264,0.3305798287547864,0.3635880290983989}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.3650697077218089,-0.12377072453754442,-0.5272028961139912,1,0,0,0,1,0,0,0,1},["size"]={0.4281504965186926,0.33068669976404713,0.3635880290983988}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.365069707721809,-0.1238241600421748,0.1727971038860088,1,0,0,0,1,0,0,0,1},["size"]={0.4281504965186927,0.3305798287547864,0.3635880290983989}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={-0.04959882160249511,-0.028625380323547445,0.44496488782822174,1,0,0,0,1,0,0,0,1},["size"]={0.48437255851289873,0.4160485242156137,0.5445306109316737}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={-0.0032444760630856023,-0.05672068732125541,0.8849726234632354,1,0,0,0,1,0,0,0,1},["size"]={0.44330368481929194,0.3492903469633398,0.5615824720473257}},{["name"]="Tail2",["fbxName"]="Import3D_Tail2",["cf"]={0.18904247892585904,-0.11800649122719392,1.2714652974699812,1,0,0,0,1,0,0,0,1},["size"]={0.4358760368176386,0.24631852428863898,0.5300221911599594}},{["name"]="Tail3",["fbxName"]="Import3D_Tail3",["cf"]={0.47505965445335985,-0.17941091043841412,1.6432589428459214,1,0,0,0,1,0,0,0,1},["size"]={0.4121528589110188,0.14416825989842305,0.46041206689122305}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.31075334548950195,0.1299394965171814,-1.0752599239349365,1,0,0,0,1,0,0,0,1},["size"]={0.04263529181480408,0.08322672545909882,0.10592341423034668}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.22168444097042084,0.1299394965171814,-1.0752599239349365,1,0,0,0,1,0,0,0,1},["size"]={0.04263529181480408,0.08322672545909882,0.10592341423034668}},{["name"]="FootF-1",["fbxName"]="Import3D_FootF-1",["cf"]={-0.6045344456532235,-0.26,-0.7051572923981857,1,0,0,0,1,0,0,0,1},["size"]={0.28531695488854614,0.15800000000000003,0.39031458479637127}},{["name"]="FootF1",["fbxName"]="Import3D_FootF1",["cf"]={0.5154655543467767,-0.26,-0.7051572923981857,1,0,0,0,1,0,0,0,1},["size"]={0.28531695488854614,0.15800000000000003,0.39031458479637127}},{["name"]="FootB-1",["fbxName"]="Import3D_FootB-1",["cf"]={-0.6045344456532235,-0.26,-0.0051572923981855895,1,0,0,0,1,0,0,0,1},["size"]={0.28531695488854614,0.15800000000000003,0.39031458479637116}},{["name"]="FootB1",["fbxName"]="Import3D_FootB1",["cf"]={0.5154655543467767,-0.26,-0.0051572923981855895,1,0,0,0,1,0,0,0,1},["size"]={0.28531695488854614,0.15800000000000003,0.39031458479637116}}}
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
    assert(count == #members + 1 and joints == 11, "Structure inattendue")
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
