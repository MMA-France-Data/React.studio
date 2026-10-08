-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Rhino"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.0011922647334691172,0.15385508967448153,0.45999999999999996,1,0,0,0,1,0,0,0,1},["size"]={2.1423845294669386,1.8577101793489632,2.98}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.4353490728415048,-1.7000000000000002,1,0,0,0,1,0,0,0,1},["size"]={1.36,1.6926981456830097,1.84}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.5067158581405915,0.6197346902584565,-1.1522018237315512,1,0,0,0,1,0,0,0,1},["size"]={0.3831487678966107,0.5290742572067946,0.2886828336312579}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.5067158581405915,0.6197346902584565,-1.1522018237315512,1,0,0,0,1,0,0,0,1},["size"]={0.3831487678966107,0.5290742572067946,0.2886828336312579}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.6659999999999999,-0.4275,-0.6995408204659017,1,0,0,0,1,0,0,0,1},["size"]={0.7160000000000001,0.9550000000000001,0.8016690314789588}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.7,-1.0735000000000001,-0.7547780558527604,1,0,0,0,1,0,0,0,1},["size"]={0.6000000000000001,0.5810000000000001,0.6715561117055208}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.6659999999999999,-0.4275,-0.6995408204659017,1,0,0,0,1,0,0,0,1},["size"]={0.7160000000000001,0.9550000000000001,0.8016690314789588}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.7,-1.0735000000000001,-0.7547780558527604,1,0,0,0,1,0,0,0,1},["size"]={0.6000000000000001,0.5810000000000001,0.6715561117055208}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.6659999999999999,-0.4275,1.5104591795340983,1,0,0,0,1,0,0,0,1},["size"]={0.7160000000000001,0.9550000000000001,0.801669031478959}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.7,-1.0735000000000001,1.4552219441472394,1,0,0,0,1,0,0,0,1},["size"]={0.6000000000000001,0.5810000000000001,0.6715561117055209}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.6659999999999999,-0.4275,1.5104591795340983,1,0,0,0,1,0,0,0,1},["size"]={0.7160000000000001,0.9550000000000001,0.801669031478959}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.7,-1.0735000000000001,1.4552219441472394,1,0,0,0,1,0,0,0,1},["size"]={0.6000000000000001,0.5810000000000001,0.6715561117055209}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.23111309056474405,2.080612371297847,1,0,0,0,1,0,0,0,1},["size"]={0.14265847744427304,0.5993565025459426,0.6149289997288578}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0.05274434162545497,-0.7209856457236995,2.422021600173946,1,0,0,0,1,0,0,0,1},["size"]={0.24814569906169787,0.6230586677182737,0.3498162302489969}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.49793994426727295,0.29920080304145813,-1.709730863571167,1,0,0,0,1,0,0,0,1},["size"]={0.14409685134887695,0.1314682513475418,0.19297754764556885}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.49793994426727295,0.29920080304145813,-1.709730863571167,1,0,0,0,1,0,0,0,1},["size"]={0.14409685134887695,0.1314682513475418,0.19297754764556885}}}
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
    assert(count == #members + 1 and joints == 14, "Structure inattendue")
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
