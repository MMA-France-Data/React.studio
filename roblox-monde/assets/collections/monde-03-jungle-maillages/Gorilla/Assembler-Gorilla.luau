-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Gorilla"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,-0.04378300905227661,0.45099999010562897,1,0,0,0,1,0,0,0,1},["size"]={2.6697888374328613,2.3472341299057007,1.3849999606609344}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0,0.9595999717712402,-0.0065000057220458984,1,0,0,0,1,0,0,0,1},["size"]={1.0399999618530273,0.7300000190734863,0.9599999785423279}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,1.3481820506375644,-0.5690000057220459,1,0,0,0,1,0,0,0,1},["size"]={1.1016000509262085,0.930364068850202,1.3550000190734863}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.5092764347791672,1.2851715087890625,-0.24124999716877937,1,0,0,0,1,0,0,0,1},["size"]={0.22029617428779602,0.2585756778717041,0.2594999894499779}},{["name"]="ArmL",["fbxName"]="Import3D_ArmL",["cf"]={-1.1781413853168488,0.007542073726654053,0.2084999978542328,1,0,0,0,1,0,0,0,1},["size"]={0.7259311079978943,1.4825551509857178,0.8299999833106995}},{["name"]="ElbowL",["fbxName"]="Import3D_ElbowL",["cf"]={-1.3632451528734641,-1.0147454738616943,0.03384903073310852,1,0,0,0,1,0,0,0,1},["size"]={0.6989032756434523,1.0688068866729736,0.8676701784133911}},{["name"]="WristL",["fbxName"]="Import3D_WristL",["cf"]={-1.355638176202774,-1.680137058995291,-0.2514999955892563,1,0,0,0,1,0,0,0,1},["size"]={0.8745235800743103,0.49132605214491565,1.0599999725818634}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.5471232011914253,-1.1737614870071411,0.717263475060463,1,0,0,0,1,0,0,0,1},["size"]={0.6057708114385605,0.8158855438232422,0.7278213202953339}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.5700000077486038,-1.6762464046478271,0.22350242733955383,1,0,0,0,1,0,0,0,1},["size"]={0.5400000512599945,0.5487072467803955,1.1000048518180847}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.5092764347791672,1.2851715087890625,-0.24124999716877937,1,0,0,0,1,0,0,0,1},["size"]={0.22029617428779602,0.2585756778717041,0.2594999894499779}},{["name"]="ArmR",["fbxName"]="Import3D_ArmR",["cf"]={1.1781413853168488,0.007542073726654053,0.2084999978542328,1,0,0,0,1,0,0,0,1},["size"]={0.7259311079978943,1.4825551509857178,0.8299999833106995}},{["name"]="ElbowR",["fbxName"]="Import3D_ElbowR",["cf"]={1.3632451528734641,-1.0147454738616943,0.03384903073310852,1,0,0,0,1,0,0,0,1},["size"]={0.6989032756434523,1.0688068866729736,0.8676701784133911}},{["name"]="WristR",["fbxName"]="Import3D_WristR",["cf"]={1.355638176202774,-1.680137058995291,-0.2514999955892563,1,0,0,0,1,0,0,0,1},["size"]={0.8745235800743103,0.49132605214491565,1.0599999725818634}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.5471232011914253,-1.1737614870071411,0.717263475060463,1,0,0,0,1,0,0,0,1},["size"]={0.6057708114385605,0.8158855438232422,0.7278213202953339}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.5700000077486038,-1.6762464046478271,0.22350242733955383,1,0,0,0,1,0,0,0,1},["size"]={0.5400000512599945,0.5487072467803955,1.1000048518180847}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.8309000134468079,-0.8865000307559967,1,0,0,0,1,0,0,0,1},["size"]={0.6399999856948853,0.21420001983642578,0.42000001668930054}}}
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
