-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Rooster"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,-0.11827768384820059,-0.21513664722442627,1,0,0,0,1,0,0,0,1},["size"]={0.7900000214576721,1.129044622194651,1.284000039100647}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.4659000188112259,-0.8906367123126984,1,0,0,0,1,0,0,0,1},["size"]={0.47940000891685486,0.6478000581264496,0.8170000910758972}},{["name"]="WingL",["fbxName"]="Import3D_WingL",["cf"]={-0.41405783348198477,-0.1994580700993538,-0.10213664174079895,1,0,0,0,1,0,0,0,1},["size"]={0.24958609342453192,0.5270966142416,0.6700000166893005}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.20999999344348907,-0.821800023317337,-0.36724376305937767,1,0,0,0,1,0,0,0,1},["size"]={0.29008862376213074,0.5735999941825867,0.6302142217755318}},{["name"]="WingR",["fbxName"]="Import3D_WingR",["cf"]={0.41405783348198477,-0.1994580700993538,-0.10213664174079895,1,0,0,0,1,0,0,0,1},["size"]={0.24958609342453192,0.5270966142416,0.6700000166893005}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.20999999344348907,-0.821800023317337,-0.36724376305937767,1,0,0,0,1,0,0,0,1},["size"]={0.29008862376213074,0.5735999941825867,0.6302142217755318}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,0.4112296386108195,0.6924471562295106,1,0,0,0,1,0,0,0,1},["size"]={0.46817175976009695,1.078715529748876,1.025836766797095}},{["name"]="Comb0",["fbxName"]="Import3D_Comb0",["cf"]={0,0.8395999670028687,-0.9021366238594055,1,0,0,0,1,0,0,0,1},["size"]={0.0949999988079071,0.23000001907348633,0.13499999046325684}},{["name"]="Comb1",["fbxName"]="Import3D_Comb1",["cf"]={0,0.9166000485420227,-0.7871366739273071,1,0,0,0,1,0,0,0,1},["size"]={0.0949999988079071,0.33000004291534424,0.13499999046325684}},{["name"]="Comb2",["fbxName"]="Import3D_Comb2",["cf"]={0,0.8395999670028687,-0.672136664390564,1,0,0,0,1,0,0,0,1},["size"]={0.0949999988079071,0.23000001907348633,0.13499999046325684}},{["name"]="Comb3",["fbxName"]="Import3D_Comb3",["cf"]={0,0.9166000485420227,-0.5571366548538208,1,0,0,0,1,0,0,0,1},["size"]={0.0949999988079071,0.33000004291534424,0.13499999046325684}},{["name"]="Wattle",["fbxName"]="Import3D_Wattle",["cf"]={0,0.32499998807907104,-0.9881366789340973,1,0,0,0,1,0,0,0,1},["size"]={0.14000000059604645,0.25,0.14000004529953003}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.21667567128315568,0.6112133061978966,-0.8182273040729342,1,0,0,0,1,0,0,0,1},["size"]={0.0635164960136625,0.1237469425433706,0.10530539849334453}},{["name"]="WingFeather-10",["fbxName"]="Import3D_WingFeather-10",["cf"]={-0.44848607683791863,-0.32523150742053986,-0.3121366426348686,1,0,0,0,1,0,0,0,1},["size"]={0.19849949687609042,0.30090370774269104,0.15999998152256012}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.21667567128315568,0.6112133061978966,-0.8182273040729342,1,0,0,0,1,0,0,0,1},["size"]={0.0635164960136625,0.1237469425433706,0.10530539849334453}},{["name"]="WingFeather10",["fbxName"]="Import3D_WingFeather10",["cf"]={0.4524808302996488,-0.32523150742053986,-0.3121366426348686,1,0,0,0,1,0,0,0,1},["size"]={0.19050998995263013,0.30090370774269104,0.15999998152256012}}}
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
    assert(count == #members + 1 and joints == 7, "Structure inattendue")
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
