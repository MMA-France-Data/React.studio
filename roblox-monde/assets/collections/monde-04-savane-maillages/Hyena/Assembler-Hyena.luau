-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Hyena"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.000501229841010864,0.03498705779881245,0.19500000000000006,1,0,0,0,1,0,0,0,1},["size"]={1.0010024596820217,1.2099741155976251,1.83}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={-0.0015721080390257713,0.2637451190502359,-0.7443706411388459,1,0,0,0,1,0,0,0,1},["size"]={0.8331442160780516,0.9295515938659742,0.9155449685725061}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,0.49249999999999994,-1.3857503962516784,1,0,0,0,1,0,0,0,1},["size"]={0.83,0.7050000000000001,1.091500792503357}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.22050000000000003,-1.5945,1,0,0,0,1,0,0,0,1},["size"]={0.4755282581475768,0.247,0.6909999999999998}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.335,0.84,-0.9420003533363343,1,0,0,0,1,0,0,0,1},["size"]={0.34199999999999997,0.44999999999999996,0.2840007066726684}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.335,0.84,-0.9420003533363343,1,0,0,0,1,0,0,0,1},["size"]={0.34199999999999997,0.44999999999999996,0.2840007066726684}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.33056186735591847,-0.2975,-0.517,1,0,0,0,1,0,0,0,1},["size"]={0.40602634122989845,0.825,0.54}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.331,-0.8815,-0.6124588577219878,1,0,0,0,1,0,0,0,1},["size"]={0.3823247195506517,0.5129999999999999,0.48891771544397566}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.33056186735591847,-0.2975,-0.517,1,0,0,0,1,0,0,0,1},["size"]={0.40602634122989845,0.825,0.54}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.331,-0.8815,-0.6124588577219878,1,0,0,0,1,0,0,0,1},["size"]={0.3823247195506517,0.5129999999999999,0.48891771544397566}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.32961081083962335,-0.39499999999999996,0.79,1,0,0,0,1,0,0,0,1},["size"]={0.3280397068936959,0.63,0.54}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.331,-0.8815,0.6945411422780122,1,0,0,0,1,0,0,0,1},["size"]={0.3823247195506517,0.5129999999999999,0.48891771544397566}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.32961081083962335,-0.39499999999999996,0.79,1,0,0,0,1,0,0,0,1},["size"]={0.3280397068936959,0.63,0.54}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.331,-0.8815,0.6945411422780122,1,0,0,0,1,0,0,0,1},["size"]={0.3823247195506517,0.5129999999999999,0.48891771544397566}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.2530126363041725,1.2663517841956229,1,0,0,0,1,0,0,0,1},["size"]={0.19972186842198225,0.3888045818976856,0.5472979978152991}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0.034999999999999996,-0.4397734199486253,1.545810224113091,1,0,0,0,1,0,0,0,1},["size"]={0.27180531950810954,0.38804470082990705,0.3907757214309624}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.24362434446811676,0.5942790508270264,-1.463259220123291,1,0,0,0,1,0,0,0,1},["size"]={0.1237575113773346,0.11818546056747437,0.136816143989563}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.24362434446811676,0.5942790508270264,-1.463259220123291,1,0,0,0,1,0,0,0,1},["size"]={0.1237575113773346,0.11818546056747437,0.136816143989563}}}
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
