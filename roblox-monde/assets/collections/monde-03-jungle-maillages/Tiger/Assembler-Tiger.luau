-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Tiger"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,-0.018660008907318115,-0.13524192571640015,1,0,0,0,1,0,0,0,1},["size"]={1.2809808254241943,1.2304158210754395,2.3934115171432495}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0,0.2847301959991455,-1.4415053129196167,1,0,0,0,1,0,0,0,1},["size"]={0.7921855449676514,1.0113006830215454,0.45508527755737305}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.47224220633506775,-2.085366725921631,1,0,0,0,1,0,0,0,1},["size"]={1.1583173274993896,0.8553918227553368,1.0180425643920898}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.13935571908950806,-2.261080265045166,1,0,0,0,1,0,0,0,1},["size"]={0.6404904127120972,0.25703890435397625,0.5772840976715088}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.3665964901447296,0.748242974281311,-1.7314114570617676,1,0,0,0,1,0,0,0,1},["size"]={0.26125265657901764,0.3202452063560486,0.14158213138580322}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.41294777393341064,-0.34733274579048157,-1.062267541885376,1,0,0,0,1,0,0,0,1},["size"]={0.4298027753829956,0.7416205052286386,0.5225052833557129}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.41294777393341064,-0.9414718151092529,-1.2969735860824585,1,0,0,0,1,0,0,0,1},["size"]={0.49722281098365784,0.5140778422355652,0.7390922904014587}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.4171615242958069,-0.326263964176178,0.5979510545730591,1,0,0,0,1,0,0,0,1},["size"]={0.5140778124332428,0.8006130382418633,0.7416204810142517}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.41294777393341064,-0.9414718151092529,0.43909257650375366,1,0,0,0,1,0,0,0,1},["size"]={0.49722281098365784,0.5140778422355652,0.7390922605991364}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.3665964901447296,0.748242974281311,-1.7314114570617676,1,0,0,0,1,0,0,0,1},["size"]={0.26125265657901764,0.3202452063560486,0.14158213138580322}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.41294777393341064,-0.34733274579048157,-1.062267541885376,1,0,0,0,1,0,0,0,1},["size"]={0.4298027753829956,0.7416205052286386,0.5225052833557129}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.41294777393341064,-0.9414718151092529,-1.2969735860824585,1,0,0,0,1,0,0,0,1},["size"]={0.49722281098365784,0.5140778422355652,0.7390922904014587}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.4171615242958069,-0.326263964176178,0.5979510545730591,1,0,0,0,1,0,0,0,1},["size"]={0.5140778124332428,0.8006130382418633,0.7416204810142517}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.41294777393341064,-0.9414718151092529,0.43909257650375366,1,0,0,0,1,0,0,0,1},["size"]={0.49722281098365784,0.5140778422355652,0.7390922605991364}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.16491204500198364,1.333083152770996,1,0,0,0,1,0,0,0,1},["size"]={0.2359701544046402,0.4428063668310642,0.651081919670105}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0.07942420989274979,-0.23858711123466492,1.8559379577636719,1,0,0,0,1,0,0,0,1},["size"]={0.35288195312023163,0.3005347326397896,0.5535246133804321}},{["name"]="Tail2",["fbxName"]="Import3D_Tail2",["cf"]={0.210771381855011,-0.021528147161006927,2.225429058074951,1,0,0,0,1,0,0,0,1},["size"]={0.24964271485805511,0.4292342811822891,0.3845348358154297}}}
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
