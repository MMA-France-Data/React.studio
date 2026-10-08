-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Bear"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,0.22500000000000003,0.445,1,0,0,0,1,0,0,0,1},["size"]={1.4475058415752884,1.65,2.25}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={-0.004755282581475784,0.5225,-1.007,1,0,0,0,1,0,0,0,1},["size"]={1.0606882607837207,0.975,1.394}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.135,-1.38,1,0,0,0,1,0,0,0,1},["size"]={0.6467184310807045,0.33000000000000007,0.6199999999999999}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.405,0.855,-0.5620002693091417,1,0,0,0,1,0,0,0,1},["size"]={0.3400000000000001,0.3599999999999999,0.2640005386182834}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.53,-0.43,-0.363,1,0,0,0,1,0,0,0,1},["size"]={0.54,1.06,0.6000000000000001}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.5295142416730858,-0.43,1.137,1,0,0,0,1,0,0,0,1},["size"]={0.5409715166538285,1.06,0.6000000000000001}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.405,0.855,-0.5620002693091417,1,0,0,0,1,0,0,0,1},["size"]={0.3400000000000001,0.3599999999999999,0.2640005386182834}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.53,-0.43,-0.363,1,0,0,0,1,0,0,0,1},["size"]={0.54,1.06,0.6000000000000001}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.5295142416730858,-0.43,1.137,1,0,0,0,1,0,0,0,1},["size"]={0.5409715166538285,1.06,0.6000000000000001}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,0.13969015076386782,1.5765587550248266,1,0,0,0,1,0,0,0,1},["size"]={0.24727469423673995,0.2960277257421078,0.40176665810105194}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.3400000037483468,0.5899999737739563,-1.2539990535706187,1,0,0,0,1,0,0,0,1},["size"]={0.17000000034413615,0.13000000000000012,0.01400006295189149}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.3400000037483468,0.5899999737739563,-1.2539990535706187,1,0,0,0,1,0,0,0,1},["size"]={0.17000000034413615,0.13000000000000012,0.01400006295189149}},{["name"]="LegFLFoot",["fbxName"]="Import3D_LegFLFoot",["cf"]={-0.53,-0.9025,-0.6349756097560976,1,0,0,0,1,0,0,0,1},["size"]={0.5516127794511889,0.365,0.7239512195121951}},{["name"]="LegFRFoot",["fbxName"]="Import3D_LegFRFoot",["cf"]={0.53,-0.9025,-0.6349756097560976,1,0,0,0,1,0,0,0,1},["size"]={0.5516127794511889,0.365,0.7239512195121951}},{["name"]="LegBLFoot",["fbxName"]="Import3D_LegBLFoot",["cf"]={-0.53,-0.9025,0.8650243902439025,1,0,0,0,1,0,0,0,1},["size"]={0.5516127794511889,0.365,0.7239512195121952}},{["name"]="LegBRFoot",["fbxName"]="Import3D_LegBRFoot",["cf"]={0.53,-0.9025,0.8650243902439025,1,0,0,0,1,0,0,0,1},["size"]={0.5516127794511889,0.365,0.7239512195121952}}}
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
