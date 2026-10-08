-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Goat"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.0004225409083932763,-0.16322886902269823,0.24843838810920715,1,0,0,0,1,0,0,0,1},["size"]={0.7600450587378681,0.8196573265755752,1.7136000990867615}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0.0005684012236513436,0.48646900057792664,-0.6631616353988647,1,0,0,0,1,0,0,0,1},["size"]={0.6105919718983444,0.7136049866676331,0.6995999813079834}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.430377796292305,0.6269194185733795,-0.43941161036491394,1,0,0,0,1,0,0,0,1},["size"]={0.4478256404399872,0.1538446545600891,0.2524999976158142}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.430377796292305,0.6269194185733795,-0.43941161036491394,1,0,0,0,1,0,0,0,1},["size"]={0.4478256404399872,0.1538446545600891,0.2524999976158142}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.30000001192092896,-0.7544574588537216,-0.41441164910793304,1,0,0,0,1,0,0,0,1},["size"]={0.23000001907348633,0.7565999329090118,0.3225000202655792}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.30000001192092896,-0.7544574588537216,-0.41441164910793304,1,0,0,0,1,0,0,0,1},["size"]={0.23000001907348633,0.7565999329090118,0.3225000202655792}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.30000001192092896,-0.7544574588537216,0.7755883634090424,1,0,0,0,1,0,0,0,1},["size"]={0.23000001907348633,0.7565999329090118,0.3225000500679016}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.30000001192092896,-0.7544574588537216,0.7755883634090424,1,0,0,0,1,0,0,0,1},["size"]={0.23000001907348633,0.7565999329090118,0.3225000500679016}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,0.12303081154823303,1.0892589092254639,1,0,0,0,1,0,0,0,1},["size"]={0.1899999976158142,0.46487605571746826,0.35065197944641113}},{["name"]="LongFace",["fbxName"]="Import3D_LongFace",["cf"]={1.7720291900502616e-10,0.25243676518333896,-1.0531615912914276,1,0,0,0,1,0,0,0,1},["size"]={0.43284933808422843,0.30518849323060004,0.32999998331069946}},{["name"]="Nose",["fbxName"]="Import3D_Nose",["cf"]={0,0.2966425269842148,-1.2451616525650024,1,0,0,0,1,0,0,0,1},["size"]={0.27000001072883606,0.14000001549720764,0.06200003623962402}},{["name"]="Beard",["fbxName"]="Import3D_Beard",["cf"]={0,-0.011157482862472534,-0.9931615889072418,1,0,0,0,1,0,0,0,1},["size"]={0.16783572733402252,0.3199999928474426,0.22999995946884155}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.2712465291842818,0.5598358002025634,-0.8072422541299602,1,0,0,0,1,0,0,0,1},["size"]={0.052688709441793824,0.12192281651017112,0.14526362637993384}},{["name"]="HornBaseL",["fbxName"]="Import3D_HornBaseL",["cf"]={-0.20602035522460938,0.8648425340652466,-0.41723665595054626,1,0,0,0,1,0,0,0,1},["size"]={0.10760921239852905,0.43000006675720215,0.3397499918937683}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.2712465291842818,0.5598358002025634,-0.8072422541299602,1,0,0,0,1,0,0,0,1},["size"]={0.052688709441793824,0.12192281651017112,0.14526362637993384}},{["name"]="HornBaseR",["fbxName"]="Import3D_HornBaseR",["cf"]={0.20602035522460938,0.8648425340652466,-0.41723665595054626,1,0,0,0,1,0,0,0,1},["size"]={0.10760921239852905,0.43000006675720215,0.3397499918937683}}}
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
