-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Lion"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,0,-0.12,1,0,0,0,1,0,0,0,1},["size"]={1.331479122813215,1.44,2.4000000000000004}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0,0.255,-1.38,1,0,0,0,1,0,0,0,1},["size"]={1.12,1.25,0.6599999999999999}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={-1.1102230246251565e-16,0.3548799774129516,-1.9725000000000001,1,0,0,0,1,0,0,0,1},["size"]={2.065214314723878,2.287857913127174,1.305}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.08499999999999999,-2.29,1,0,0,0,1,0,0,0,1},["size"]={0.68,0.35000000000000003,0.5800000000000001}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.52,1.24,-1.9464997118838174,1,0,0,0,1,0,0,0,1},["size"]={0.3804226065180614,0.56,0.3129994237676348}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.52,1.24,-1.9464997118838174,1,0,0,0,1,0,0,0,1},["size"]={0.3804226065180614,0.56,0.3129994237676348}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.5,-0.55,-1.015,1,0,0,0,1,0,0,0,1},["size"]={0.56,1.06,0.7200000000000001}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.49,-1.295,-1.1651879360111432,1,0,0,0,1,0,0,0,1},["size"]={0.55,0.5499999999999998,0.6603758720222863}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.5,-0.55,-1.015,1,0,0,0,1,0,0,0,1},["size"]={0.56,1.06,0.7200000000000001}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.49,-1.295,-1.1651879360111432,1,0,0,0,1,0,0,0,1},["size"]={0.55,0.5499999999999998,0.6603758720222863}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.51,-0.55,0.74,1,0,0,0,1,0,0,0,1},["size"]={0.5800000000000001,1.06,0.7200000000000001}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.49,-1.295,0.5898120639888569,1,0,0,0,1,0,0,0,1},["size"]={0.55,0.5499999999999998,0.6603758720222862}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.51,-0.55,0.74,1,0,0,0,1,0,0,0,1},["size"]={0.5800000000000001,1.06,0.7200000000000001}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.49,-1.295,0.5898120639888569,1,0,0,0,1,0,0,0,1},["size"]={0.55,0.5499999999999998,0.6603758720222862}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.3305,1.3295,1,0,0,0,1,0,0,0,1},["size"]={0.23,0.5014898157740095,0.726118467443219}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0.07549999999999998,-0.3495,1.9365,1,0,0,0,1,0,0,0,1},["size"]={0.3446528808298845,0.4392603596160757,0.6735914343785792}},{["name"]="Tail2",["fbxName"]="Import3D_Tail2",["cf"]={0.23500000000000001,-0.02599999999999998,2.3245,1,0,0,0,1,0,0,0,1},["size"]={0.324859195044131,0.4845384774062039,0.3461077741247429}},{["name"]="TailTuft",["fbxName"]="Import3D_TailTuft",["cf"]={0.32189071824209503,0.14207970735314032,2.423899340570409,1,0,0,0,1,0,0,0,1},["size"]={0.3948925475953011,0.41757964858050506,0.3989097922519287}}}
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
