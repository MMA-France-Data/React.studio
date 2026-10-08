-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Jaguar"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.006248285134085124,0.04250000000000004,-0.19,1,0,0,0,1,0,0,0,1},["size"]={0.9010698569365412,0.965,1.6800000000000002}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={-0.006783213602355731,0.33499999999999996,-1.4335,1,0,0,0,1,0,0,0,1},["size"]={0.78,0.71,0.9870000000000001}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={-0.006783213602355731,0.081,-1.6555,1,0,0,0,1,0,0,0,1},["size"]={0.5325916491252861,0.24800000000000003,0.4670000000000001}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.2917832136023557,0.6665000000000001,-1.2097505583763124,1,0,0,0,1,0,0,0,1},["size"]={0.27,0.31300000000000006,0.26350111675262444}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.3129608548930936,-0.35,-0.792,1,0,0,0,1,0,0,0,1},["size"]={0.35002506328477956,0.8400000000000001,0.5200000000000001}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.3107445777631731,-0.41100000000000003,0.3364401477793291,1,0,0,0,1,0,0,0,1},["size"]={0.39820621729419753,0.962,0.6171197044413418}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.2782167863976442,0.6665000000000001,-1.2097505583763124,1,0,0,0,1,0,0,0,1},["size"]={0.27,0.31300000000000006,0.26350111675262444}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.2993944276883821,-0.35,-0.792,1,0,0,0,1,0,0,0,1},["size"]={0.35002506328477956,0.8400000000000001,0.5200000000000001}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.2971781505584616,-0.41100000000000003,0.3364401477793291,1,0,0,0,1,0,0,0,1},["size"]={0.39820621729419753,0.962,0.6171197044413418}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={-0.006783213602355759,-0.05499999999999999,0.8200000000000001,1,0,0,0,1,0,0,0,1},["size"]={0.19401552932421134,0.3990565524368156,0.7312156875725009}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0.10510839319882215,-0.13749999999999998,1.37,1,0,0,0,1,0,0,0,1},["size"]={0.3919001310339548,0.180962046825271,0.6243579643020227}},{["name"]="Tail2",["fbxName"]="Import3D_Tail2",["cf"]={0.2835,-0.014499999999999971,1.7599999999999998,1,0,0,0,1,0,0,0,1},["size"]={0.26150196339891285,0.3529985952259931,0.3959692811602953}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.2764488458633423,0.46113473176956177,-1.5918192863464355,1,0,0,0,1,0,0,0,1},["size"]={0.1302955448627472,0.12480664253234863,0.1396561861038208}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.26288241147994995,0.46113473176956177,-1.5918192863464355,1,0,0,0,1,0,0,0,1},["size"]={0.1302955448627472,0.12480664253234863,0.1396561861038208}},{["name"]="LegFLFoot",["fbxName"]="Import3D_LegFLFoot",["cf"]={-0.31678321360235573,-0.749,-0.9205598522206708,1,0,0,0,1,0,0,0,1},["size"]={0.36900992832251966,0.28600000000000003,0.45711970444134176}},{["name"]="LegFRFoot",["fbxName"]="Import3D_LegFRFoot",["cf"]={0.30321678639764427,-0.749,-0.9205598522206708,1,0,0,0,1,0,0,0,1},["size"]={0.36900992832251966,0.28600000000000003,0.45711970444134176}}}
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
    assert(count == #members + 1 and joints == 12, "Structure inattendue")
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
