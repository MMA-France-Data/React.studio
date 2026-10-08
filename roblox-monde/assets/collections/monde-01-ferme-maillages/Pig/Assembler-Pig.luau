-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Pig"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,-0.021323466545354663,0.3149000406265259,1,0,0,0,1,0,0,0,1},["size"]={1.2583999633789062,0.991277646529652,1.8564000129699707}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0.0002353098359802741,0.1944427637624968,-0.7975000441074371,1,0,0,0,1,0,0,0,1},["size"]={0.928670626156946,0.693210154447601,1.0080000758171082}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.4376250058412552,0.3533821851015091,-0.5647455155849457,1,0,0,0,1,0,0,0,1},["size"]={0.33500000834465027,0.3582991063594818,0.22996801137924194}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.4376250058412552,0.3533821851015091,-0.5647455155849457,1,0,0,0,1,0,0,0,1},["size"]={0.33500000834465027,0.3582991063594818,0.22996801137924194}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.46000000834465027,-0.5015703439712524,-0.4672500044107437,1,0,0,0,1,0,0,0,1},["size"]={0.2651999592781067,0.44201600551605225,0.39750000834465027}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.46000000834465027,-0.5015703439712524,-0.4672500044107437,1,0,0,0,1,0,0,0,1},["size"]={0.2651999592781067,0.44201600551605225,0.39750000834465027}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.46000000834465027,-0.5161623358726501,0.8427499830722809,1,0,0,0,1,0,0,0,1},["size"]={0.2800000309944153,0.47119998931884766,0.3974999785423279}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.46000000834465027,-0.5161623358726501,0.8427499830722809,1,0,0,0,1,0,0,0,1},["size"]={0.2800000309944153,0.47119998931884766,0.3974999785423279}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0.22003994246820996,0.32245408022116306,1.2015679842079408,1,0,0,0,1,0,0,0,1},["size"]={0.35533120879046864,0.3309171194673892,0.09228965742632256}},{["name"]="TailTip",["fbxName"]="Import3D_TailTip",["cf"]={0.1899200418086792,0.3662438722706173,1.22,1,0,0,0,1,0,0,0,1},["size"]={0.23293292675971516,0.29194184711151183,0.055425625842203896}},{["name"]="BigSnout",["fbxName"]="Import3D_BigSnout",["cf"]={0,0.0406225362865891,-1.1071968939460846,1,0,0,0,1,0,0,0,1},["size"]={0.6600000262260437,0.3967697102723054,0.2726062006637392}},{["name"]="SnoutFace",["fbxName"]="Import3D_SnoutFace",["cf"]={0,0.03563767671585083,-1.256500005722046,1,0,0,0,1,0,0,0,1},["size"]={0.5699999928474426,0.3100000023841858,0.04800009727478027}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.40242090448737144,0.2859077013563365,-0.8456070587853901,1,0,0,0,1,0,0,0,1},["size"]={0.07899534611728032,0.12792064842576856,0.1303193128518565}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.40242090448737144,0.2859077013563365,-0.8456070587853901,1,0,0,0,1,0,0,0,1},["size"]={0.07899534611728032,0.12792064842576856,0.1303193128518565}},{["name"]="LegFLFoot",["fbxName"]="Import3D_LegFLFoot",["cf"]={-0.46000000834465027,-0.6567623317241669,-0.4584999829530716,1,0,0,0,1,0,0,0,1},["size"]={0.2800000309944153,0.1899999976158142,0.3699999749660492}},{["name"]="LegFRFoot",["fbxName"]="Import3D_LegFRFoot",["cf"]={0.46000000834465027,-0.6567623317241669,-0.4584999829530716,1,0,0,0,1,0,0,0,1},["size"]={0.2800000309944153,0.1899999976158142,0.3699999749660492}}}
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
