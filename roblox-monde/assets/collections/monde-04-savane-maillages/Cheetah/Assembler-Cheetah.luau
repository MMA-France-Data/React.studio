-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Cheetah"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,0.205,-0.24,1,0,0,0,1,0,0,0,1},["size"]={0.73,0.95,2.06}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0.0011999812027751883,0.4578885686531444,-1.3184892278127924,1,0,0,0,1,0,0,0,1},["size"]={0.4823999624055504,0.7259022849394867,0.7510003231327134}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.6799999999999999,-1.896,1,0,0,0,1,0,0,0,1},["size"]={0.606,0.594,0.8319999999999999}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.41800000000000004,-2.039,1,0,0,0,1,0,0,0,1},["size"]={0.3804226065180615,0.196,0.478}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.262,0.9789999999999999,-1.5485000195503233,1,0,0,0,1,0,0,0,1},["size"]={0.24,0.2819999999999999,0.22100003910064703}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.262,0.9789999999999999,-1.5485000195503233,1,0,0,0,1,0,0,0,1},["size"]={0.24,0.2819999999999999,0.22100003910064703}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.3002416139948426,-0.27,-0.987,1,0,0,0,1,0,0,0,1},["size"]={0.2473325658353414,0.8999999999999999,0.3979999999999999}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.304,-0.8835,-1.0594999999999999,1,0,0,0,1,0,0,0,1},["size"]={0.2796106157907752,0.5249999999999999,0.3749999999999999}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.3002416139948426,-0.27,-0.987,1,0,0,0,1,0,0,0,1},["size"]={0.2473325658353414,0.8999999999999999,0.3979999999999999}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.304,-0.8835,-1.0594999999999999,1,0,0,0,1,0,0,0,1},["size"]={0.2796106157907752,0.5249999999999999,0.3749999999999999}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.29754405494919317,-0.27,0.505,1,0,0,0,1,0,0,0,1},["size"]={0.28441242075976403,0.8999999999999999,0.39799999999999996}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.304,-0.8835,0.4325,1,0,0,0,1,0,0,0,1},["size"]={0.2796106157907752,0.5249999999999999,0.375}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.29754405494919317,-0.27,0.505,1,0,0,0,1,0,0,0,1},["size"]={0.28441242075976403,0.8999999999999999,0.39799999999999996}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.304,-0.8835,0.4325,1,0,0,0,1,0,0,0,1},["size"]={0.2796106157907752,0.5249999999999999,0.375}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,0.057499999999999996,1.0110000000000001,1,0,0,0,1,0,0,0,1},["size"]={0.17309228596571796,0.5128414993947973,0.8329346617457062}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0.07349999999999998,-0.10350000000000001,1.6465,1,0,0,0,1,0,0,0,1},["size"]={0.3091401420248459,0.16797263928213252,0.6908790641851641}},{["name"]="Tail2",["fbxName"]="Import3D_Tail2",["cf"]={0.22349999999999995,0.03599999999999999,2.1605000000000003,1,0,0,0,1,0,0,0,1},["size"]={0.29734893793952294,0.4335929228636166,0.5671217413841927}},{["name"]="TailRingTail20",["fbxName"]="Import3D_TailRingTail20",["cf"]={0.18983999999999998,-0.02736,2.06392,1,0,0,0,1,0,0,0,1},["size"]={0.14294691138801102,0.13980074593520703,0.11694753491879695}}}
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
