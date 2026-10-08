-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Capybara"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,0.020072612841409265,0.49,1,0,0,0,1,0,0,0,1},["size"]={1.26,1.0701452256828186,1.88}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.245,-0.8357501482963562,1,0,0,0,1,0,0,0,1},["size"]={0.9,0.75,1.2315002965927124}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.32,0.5925,-0.4357501006126404,1,0,0,0,1,0,0,0,1},["size"]={0.27,0.28500000000000003,0.23150020122528076}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.4297175604561693,-0.35,-0.23,1,0,0,0,1,0,0,0,1},["size"]={0.42936072311500595,0.7,0.46}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.42737953366032433,-0.35,1.015,1,0,0,0,1,0,0,0,1},["size"]={0.42468466952331596,0.7,0.45999999999999996}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.32,0.5925,-0.4357501006126404,1,0,0,0,1,0,0,0,1},["size"]={0.27,0.28500000000000003,0.23150020122528076}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.4297175604561693,-0.35,-0.23,1,0,0,0,1,0,0,0,1},["size"]={0.42936072311500595,0.7,0.46}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.42737953366032433,-0.35,1.015,1,0,0,0,1,0,0,0,1},["size"]={0.42468466952331596,0.7,0.45999999999999996}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.37642258405685425,0.34412962198257446,-1.0029232501983643,1,0,0,0,1,0,0,0,1},["size"]={0.092071533203125,0.15521499514579773,0.1776067018508911}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.37642258405685425,0.34412962198257446,-1.0029232501983643,1,0,0,0,1,0,0,0,1},["size"]={0.092071533203125,0.15521499514579773,0.1776067018508911}},{["name"]="LegFLFoot",["fbxName"]="Import3D_LegFLFoot",["cf"]={-0.44000000000000006,-0.6725,-0.32065668591574537,1,0,0,0,1,0,0,0,1},["size"]={0.3423803458662554,0.2549999999999999,0.42131337183149076}},{["name"]="LegFRFoot",["fbxName"]="Import3D_LegFRFoot",["cf"]={0.44000000000000006,-0.6725,-0.32065668591574537,1,0,0,0,1,0,0,0,1},["size"]={0.3423803458662554,0.2549999999999999,0.42131337183149076}},{["name"]="LegBLFoot",["fbxName"]="Import3D_LegBLFoot",["cf"]={-0.44000000000000006,-0.6725,0.9243433140842545,1,0,0,0,1,0,0,0,1},["size"]={0.3423803458662554,0.2549999999999999,0.42131337183149065}},{["name"]="LegBRFoot",["fbxName"]="Import3D_LegBRFoot",["cf"]={0.44000000000000006,-0.6725,0.9243433140842545,1,0,0,0,1,0,0,0,1},["size"]={0.3423803458662554,0.2549999999999999,0.42131337183149065}}}
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
    assert(count == #members + 1 and joints == 8, "Structure inattendue")
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
