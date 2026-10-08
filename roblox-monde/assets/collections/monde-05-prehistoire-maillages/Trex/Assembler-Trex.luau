-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Trex"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,-0.023636965805287957,-0.49,1,0,0,0,1,0,0,0,1},["size"]={2.464181264697708,2.3827260683894242,3.5799999999999996}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0.0001204403603219939,0.6628282806737114,-2.2710972879376996,1,0,0,0,1,0,0,0,1},["size"]={1.5290956596067142,1.854171200800756,1.832349981121113}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,1.3518558690144238,-3.83,1,0,0,0,1,0,0,0,1},["size"]={1.9398052704529678,1.6039967262287997,3}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.5449999999999999,-3.83,1,0,0,0,1,0,0,0,1},["size"]={1.46,1.0099999999999998,3}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.26000000000000023,2.2509049827729575,1,0,0,0,1,0,0,0,1},["size"]={1.027141037598766,1.0952399653045362,2.4240323623076714}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0,-0.3500000000000001,4.6037454970138585,1,0,0,0,1,0,0,0,1},["size"]={0.5325916491252861,0.5599583627643572,2.6143197545492325}},{["name"]="ArmL",["fbxName"]="Import3D_ArmL",["cf"]={-0.9098010135062093,-0.1146735992938086,-1.911973936505506,1,0,0,0,1,0,0,0,1},["size"]={0.5246888484018638,0.7276130499922964,0.6973018841296148}},{["name"]="ForearmL",["fbxName"]="Import3D_ForearmL",["cf"]={-1.07,-0.45317471749162697,-2.5325891932244415,1,0,0,0,1,0,0,0,1},["size"]={0.28200000000000003,0.4898015320066196,0.8764333156585091}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.9622046858136353,-0.8473069033712517,-0.46650575658746335,1,0,0,0,1,0,0,0,1},["size"]={1.2395203320411783,2.0509117778460615,1.7647478852823841}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-1.0145,-2.005528404532628,-0.7214449210221996,1,0,0,0,1,0,0,0,1},["size"]={0.6127614772968806,1.2059621461478396,1.106585249281848}},{["name"]="FootBL",["fbxName"]="Import3D_FootBL",["cf"]={-1.02,-2.520403823503492,-0.8922954778093574,1,0,0,0,1,0,0,0,1},["size"]={0.9548000000000001,0.46175331744283277,1.507217372850061}},{["name"]="ArmR",["fbxName"]="Import3D_ArmR",["cf"]={0.9098010135062093,-0.1146735992938086,-1.911973936505506,1,0,0,0,1,0,0,0,1},["size"]={0.5246888484018638,0.7276130499922964,0.6973018841296148}},{["name"]="ForearmR",["fbxName"]="Import3D_ForearmR",["cf"]={1.07,-0.45317471749162697,-2.5325891932244415,1,0,0,0,1,0,0,0,1},["size"]={0.28200000000000003,0.4898015320066196,0.8764333156585091}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.9622046858136353,-0.8473069033712517,-0.46650575658746335,1,0,0,0,1,0,0,0,1},["size"]={1.2395203320411783,2.0509117778460615,1.7647478852823841}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={1.0145,-2.005528404532628,-0.7214449210221996,1,0,0,0,1,0,0,0,1},["size"]={0.6127614772968806,1.2059621461478396,1.106585249281848}},{["name"]="FootBR",["fbxName"]="Import3D_FootBR",["cf"]={1.02,-2.520403823503492,-0.8922954778093574,1,0,0,0,1,0,0,0,1},["size"]={0.9548000000000001,0.46175331744283277,1.507217372850061}}}
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
