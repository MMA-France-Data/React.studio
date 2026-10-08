-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Ram"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,0.05249999999999999,0.2,1,0,0,0,1,0,0,0,1},["size"]={1.28,1.145,1.62}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0.0018547669239573072,0.39,-1.0007501292228698,1,0,0,0,1,0,0,0,1},["size"]={0.5837095338479146,0.9199999999999999,0.9815002584457397}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.44059060472874,0.45499999999999996,-0.6305253080357038,1,0,0,0,1,0,0,0,1},["size"]={0.42813116534168905,0.22851584755835547,0.19143005771857025}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.384219027101402,-0.565,-0.437,1,0,0,0,1,0,0,0,1},["size"]={0.33590003101164506,0.7899999999999999,0.44000000000000006}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.388,-0.565,0.8030000000000002,1,0,0,0,1,0,0,0,1},["size"]={0.3283380852144491,0.7899999999999999,0.44000000000000006}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.44059060472874,0.45499999999999996,-0.6305253080357038,1,0,0,0,1,0,0,0,1},["size"]={0.42813116534168905,0.22851584755835547,0.19143005771857025}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.384219027101402,-0.565,-0.437,1,0,0,0,1,0,0,0,1},["size"]={0.33590003101164506,0.7899999999999999,0.44000000000000006}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.388,-0.565,0.8030000000000002,1,0,0,0,1,0,0,0,1},["size"]={0.3283380852144491,0.7899999999999999,0.44000000000000006}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,0.010554074874807973,1.0621276836718008,1,0,0,0,1,0,0,0,1},["size"]={0.24727469423673995,0.3652496335062285,0.4300726126645368}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.2164941430091858,0.5533166527748108,-1.0643575191497803,1,0,0,0,1,0,0,0,1},["size"]={0.08842307329177856,0.10279476642608643,0.14788955450057983}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.2164941430091858,0.5533166527748108,-1.0643575191497803,1,0,0,0,1,0,0,0,1},["size"]={0.08842307329177856,0.10279476642608643,0.14788955450057983}},{["name"]="LegFLFoot",["fbxName"]="Import3D_LegFLFoot",["cf"]={-0.4,-1.033,-0.477,1,0,0,0,1,0,0,0,1},["size"]={0.2424,0.15799999999999992,0.28}},{["name"]="LegFRFoot",["fbxName"]="Import3D_LegFRFoot",["cf"]={0.4,-1.033,-0.477,1,0,0,0,1,0,0,0,1},["size"]={0.2424,0.15799999999999992,0.28}},{["name"]="LegBLFoot",["fbxName"]="Import3D_LegBLFoot",["cf"]={-0.4,-1.033,0.763,1,0,0,0,1,0,0,0,1},["size"]={0.2424,0.15799999999999992,0.28}},{["name"]="LegBRFoot",["fbxName"]="Import3D_LegBRFoot",["cf"]={0.4,-1.033,0.763,1,0,0,0,1,0,0,0,1},["size"]={0.2424,0.15799999999999992,0.28}},{["name"]="Horn-1_0",["fbxName"]="Import3D_Horn-1_0",["cf"]={-0.36497281166382717,0.524814344437069,-0.7935961672987881,1,0,0,0,1,0,0,0,1},["size"]={0.4420605466341053,0.803966787521256,0.6572935280112024}},{["name"]="Horn1_0",["fbxName"]="Import3D_Horn1_0",["cf"]={0.3649728116638271,0.524814344437069,-0.7935961672987881,1,0,0,0,1,0,0,0,1},["size"]={0.4420605466341052,0.803966787521256,0.6572935280112024}}}
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
