-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Duck"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.00010203451470428004,-0.08474999666213989,0.07613202929496765,1,0,0,0,1,0,0,0,1},["size"]={0.8894040411821185,0.8985999822616577,1.5239999890327454}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0.0005825997663826965,0.4144251562697655,-0.7453680336475372,1,0,0,0,1,0,0,0,1},["size"]={0.5072209799300548,0.4537502959455979,0.6690000891685486}},{["name"]="WingL",["fbxName"]="Import3D_WingL",["cf"]={-0.45260994047922587,-0.12344998121261597,0.20413202047348022,1,0,0,0,1,0,0,0,1},["size"]={0.1977471428910355,0.38999998569488525,0.7799999713897705}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.23000000417232513,-0.5612499713897705,-0.3123679831624031,1,0,0,0,1,0,0,0,1},["size"]={0.11219999194145203,0.2200000286102295,0.3830000013113022}},{["name"]="WingR",["fbxName"]="Import3D_WingR",["cf"]={0.45260994047922587,-0.12344998121261597,0.20413202047348022,1,0,0,0,1,0,0,0,1},["size"]={0.1977471428910355,0.38999998569488525,0.7799999713897705}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.23000000417232513,-0.5612499713897705,-0.3123679831624031,1,0,0,0,1,0,0,0,1},["size"]={0.11219999194145203,0.2200000286102295,0.3830000013113022}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.09914790838956833,0.7545021623373032,1,0,0,0,1,0,0,0,1},["size"]={0.36000001430511475,0.3701603561639786,0.650852233171463}},{["name"]="WhiteCollar",["fbxName"]="Import3D_WhiteCollar",["cf"]={0,0.1505500078201294,-0.4658679962158203,1,0,0,0,1,0,0,0,1},["size"]={0.4050000011920929,0.09000000357627869,0.41499996185302734}},{["name"]="BillUpper",["fbxName"]="Import3D_BillUpper",["cf"]={0,0.34565000236034393,-0.9988679587841034,1,0,0,0,1,0,0,0,1},["size"]={0.4399999976158142,0.0949999988079071,0.3399999737739563}},{["name"]="BillLower",["fbxName"]="Import3D_BillLower",["cf"]={0,0.2696300074458122,-1.0048680305480957,1,0,0,0,1,0,0,0,1},["size"]={0.3799999952316284,0.04399998486042023,0.309999942779541}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.22172129712998867,0.4700060023460537,-0.736959936839412,1,0,0,0,1,0,0,0,1},["size"]={0.056918922286900875,0.10491925975705008,0.09331487791171056}},{["name"]="WingBluePatch-1",["fbxName"]="Import3D_WingBluePatch-1",["cf"]={-0.5360000133514404,-0.11334999650716782,0.14413202553987503,1,0,0,0,1,0,0,0,1},["size"]={0.022516608238220215,0.14499999582767487,0.33000002801418304}},{["name"]="WebFoot-1",["fbxName"]="Import3D_WebFoot-1",["cf"]={-0.23000000417232513,-0.6796499788761139,-0.3058679774403572,1,0,0,0,1,0,0,0,1},["size"]={0.27000001072883606,0.07999998331069946,0.3400000184774399}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.22172129712998867,0.4700060023460537,-0.736959936839412,1,0,0,0,1,0,0,0,1},["size"]={0.056918922286900875,0.10491925975705008,0.09331487791171056}},{["name"]="WingBluePatch1",["fbxName"]="Import3D_WingBluePatch1",["cf"]={0.5360000133514404,-0.11334999650716782,0.14413202553987503,1,0,0,0,1,0,0,0,1},["size"]={0.022516608238220215,0.14499999582767487,0.33000002801418304}},{["name"]="WebFoot1",["fbxName"]="Import3D_WebFoot1",["cf"]={0.23000000417232513,-0.6796499788761139,-0.3058679774403572,1,0,0,0,1,0,0,0,1},["size"]={0.27000001072883606,0.07999998331069946,0.3400000184774399}}}
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
