-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Spinosaurus"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.003727774653560223,-0.14674529039759315,-0.45499999999999996,1,0,0,0,1,0,0,0,1},["size"]={1.5674555493071205,1.5265094192048134,3.0700000000000003}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={-5.551115123125783e-17,0.23222137583352254,-1.9912194295262808,1,0,0,0,1,0,0,0,1},["size"]={0.7604437715018225,1.045921302095179,1.0438646041082629}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.6848669272112982,-3.17,1,0,0,0,1,0,0,0,1},["size"]={0.8408583998680115,0.719733854422596,1.9600000000000004}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.43000000000000016,-3.1799999999999997,1,0,0,0,1,0,0,0,1},["size"]={0.62,0.40000000000000036,1.98}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={5.551115123125783e-17,-0.2699999999999998,1.7732843778221425,1,0,0,0,1,0,0,0,1},["size"]={0.6629509802836402,0.71915860517904,1.9413667526690772}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0,-0.24621605903717814,3.628725650777775,1,0,0,0,1,0,0,0,1},["size"]={0.40839566882774514,0.7821793959737107,2.109405887305241}},{["name"]="Sail",["fbxName"]="Import3D_Sail",["cf"]={0,1.1300000000000003,-0.46499999999999997,1,0,0,0,1,0,0,0,1},["size"]={0.146,2.04,2.5700000000000003}},{["name"]="ArmL",["fbxName"]="Import3D_ArmL",["cf"]={-0.7079337745751774,-0.1355529341325955,-1.5870827669552714,1,0,0,0,1,0,0,0,1},["size"]={0.49734034691109974,0.5822589221436616,0.4879670303635113}},{["name"]="ForearmL",["fbxName"]="Import3D_ForearmL",["cf"]={-0.84,-0.4927537028745831,-2.175777092229103,1,0,0,0,1,0,0,0,1},["size"]={0.30800000000000005,0.6921008954007035,1.1291150384162423}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.7515000000000001,-0.7350299713916036,-0.49397049898991685,1,0,0,0,1,0,0,0,1},["size"]={0.5814219847840669,1.3601601879980316,1.0328367209234035}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.78615,-1.541753443423377,-0.638784456915215,1,0,0,0,1,0,0,0,1},["size"]={0.2921653050199502,0.7447500271576921,0.6414369033466796}},{["name"]="FootBL",["fbxName"]="Import3D_FootBL",["cf"]={-0.79,-1.8828435041313991,-0.6700029631913915,1,0,0,0,1,0,0,0,1},["size"]={0.45499999999999996,0.3189004561303064,0.7154233876785977}},{["name"]="ArmR",["fbxName"]="Import3D_ArmR",["cf"]={0.7079337745751774,-0.1355529341325955,-1.5870827669552714,1,0,0,0,1,0,0,0,1},["size"]={0.49734034691109974,0.5822589221436616,0.4879670303635113}},{["name"]="ForearmR",["fbxName"]="Import3D_ForearmR",["cf"]={0.84,-0.4927537028745831,-2.175777092229103,1,0,0,0,1,0,0,0,1},["size"]={0.30800000000000005,0.6921008954007035,1.1291150384162423}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.7515000000000001,-0.7350299713916036,-0.49397049898991685,1,0,0,0,1,0,0,0,1},["size"]={0.5814219847840669,1.3601601879980316,1.0328367209234035}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.78615,-1.541753443423377,-0.638784456915215,1,0,0,0,1,0,0,0,1},["size"]={0.2921653050199502,0.7447500271576921,0.6414369033466796}},{["name"]="FootBR",["fbxName"]="Import3D_FootBR",["cf"]={0.79,-1.8828435041313991,-0.6700029631913915,1,0,0,0,1,0,0,0,1},["size"]={0.45499999999999996,0.3189004561303064,0.7154233876785977}}}
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
