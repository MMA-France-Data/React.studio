-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Lynx"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0.00007208196587082938,-0.16,0.11499999999999999,1,0,0,0,1,0,0,0,1},["size"]={0.8895655696111904,0.9099999999999999,1.55}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.3987627234248801,-0.94,1,0,0,0,1,0,0,0,1},["size"]={1.1121320343559642,0.7775254468497602,0.8999999999999999}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.1525,-1.1685,1,0,0,0,1,0,0,0,1},["size"]={0.48123459724534773,0.203,0.40700000000000014}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.2889205328976916,0.9350331253191736,-0.64,1,0,0,0,1,0,0,0,1},["size"]={0.2346630344189899,0.5830841866962049,0.24953967711454372}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.3468251240443182,-0.6549999999999999,-0.441,1,0,0,0,1,0,0,0,1},["size"]={0.35363731798866066,0.9699999999999999,0.4700000000000001}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.3468251240443182,-0.6549999999999999,0.679,1,0,0,0,1,0,0,0,1},["size"]={0.35363731798866066,0.9699999999999999,0.47}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.2889205328976916,0.9350331253191736,-0.64,1,0,0,0,1,0,0,0,1},["size"]={0.2346630344189899,0.5830841866962049,0.24953967711454372}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.3468251240443182,-0.6549999999999999,-0.441,1,0,0,0,1,0,0,0,1},["size"]={0.35363731798866066,0.9699999999999999,0.4700000000000001}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.3468251240443182,-0.6549999999999999,0.679,1,0,0,0,1,0,0,0,1},["size"]={0.35363731798866066,0.9699999999999999,0.47}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.08119650553576407,1.0172764062066282,1,0,0,0,1,0,0,0,1},["size"]={0.30433808521444916,0.3558683401712759,0.5008014565178068}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.2704433798789978,0.49566978216171265,-1.1395795345306396,1,0,0,0,1,0,0,0,1},["size"]={0.15482106804847717,0.11966505646705627,0.12496685981750488}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.2704433798789978,0.49566978216171265,-1.1395795345306396,1,0,0,0,1,0,0,0,1},["size"]={0.15482106804847717,0.11966505646705627,0.12496685981750488}},{["name"]="LegFLFoot",["fbxName"]="Import3D_LegFLFoot",["cf"]={-0.35,-1.1355,-0.526,1,0,0,0,1,0,0,0,1},["size"]={0.41846486716986764,0.28900000000000015,0.43}},{["name"]="LegFRFoot",["fbxName"]="Import3D_LegFRFoot",["cf"]={0.35,-1.1355,-0.526,1,0,0,0,1,0,0,0,1},["size"]={0.41846486716986764,0.28900000000000015,0.43}},{["name"]="LegBLFoot",["fbxName"]="Import3D_LegBLFoot",["cf"]={-0.35,-1.1355,0.5940000000000001,1,0,0,0,1,0,0,0,1},["size"]={0.41846486716986764,0.28900000000000015,0.43}},{["name"]="LegBRFoot",["fbxName"]="Import3D_LegBRFoot",["cf"]={0.35,-1.1355,0.5940000000000001,1,0,0,0,1,0,0,0,1},["size"]={0.41846486716986764,0.28900000000000015,0.43}},{["name"]="BobtailTip",["fbxName"]="Import3D_BobtailTip",["cf"]={0,-0.12625606239527176,1.1792212754830889,1,0,0,0,1,0,0,0,1},["size"]={0.2510789203019206,0.269148695393448,0.21830793241656243}}}
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
    assert(count == #members + 1 and joints == 10, "Structure inattendue")
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
