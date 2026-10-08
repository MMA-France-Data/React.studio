-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Pteranodon"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,0.1032653042873215,-0.009999999999999953,1,0,0,0,1,0,0,0,1},["size"]={0.6560159542928043,0.7605306085746428,1.1800000000000002}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0,0.43588388899221286,-0.5832752751147856,1,0,0,0,1,0,0,0,1},["size"]={0.37,0.5936478564745176,0.5793706679647086}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={-0.00000476837158203125,1.0150000000000001,-0.8899999999999999,1,0,0,0,1,0,0,0,1},["size"]={0.4850495159626007,1.09,2.52}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.5379999999999998,-1.415,1,0,0,0,1,0,0,0,1},["size"]={0.3100444243122201,0.2400000000000002,1.47}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.034691394039274126,0.6798770747801323,1,0,0,0,1,0,0,0,1},["size"]={0.2092324335849338,0.2254242064142904,0.6213005761632919}},{["name"]="WingL",["fbxName"]="Import3D_WingL",["cf"]={-0.7353019557763731,0.1024978193208167,0.10854230502629075,1,0,0,0,1,0,0,0,1},["size"]={1.147423484969289,0.41499563864163336,1.1629153899474187}},{["name"]="WingElbowL",["fbxName"]="Import3D_WingElbowL",["cf"]={-1.6347227548200487,0.16894296376409534,0.1784020453387305,1,0,0,0,1,0,0,0,1},["size"]={1.1094455096400972,0.26788592752819085,1.0231959093225391}},{["name"]="WingTipL",["fbxName"]="Import3D_WingTipL",["cf"]={-2.7480617081518837,0.1949636294973428,0.09746365237648219,1,0,0,0,1,0,0,0,1},["size"]={1.604959709480581,0.21992725899468568,0.8650726952470357}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.2342075946851952,-0.28781366093164684,0.2834946471437804,1,0,0,0,1,0,0,0,1},["size"]={0.20152780085015343,0.4129387995920353,0.2234170351635624}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.3001692637709159,-0.5926494343800257,0.293427750171733,1,0,0,0,1,0,0,0,1},["size"]={0.11735121176466873,0.31866862309235156,0.18614751937431687}},{["name"]="FootBL",["fbxName"]="Import3D_FootBL",["cf"]={-0.33,-0.787863302662908,0.13473857505374998,1,0,0,0,1,0,0,0,1},["size"]={0.133,0.26211816419765743,0.2438971362378677}},{["name"]="WingR",["fbxName"]="Import3D_WingR",["cf"]={0.7353019557763731,0.1024978193208167,0.10854230502629075,1,0,0,0,1,0,0,0,1},["size"]={1.147423484969289,0.41499563864163336,1.1629153899474187}},{["name"]="WingElbowR",["fbxName"]="Import3D_WingElbowR",["cf"]={1.6347227548200487,0.16894296376409534,0.1784020453387305,1,0,0,0,1,0,0,0,1},["size"]={1.1094455096400972,0.26788592752819085,1.0231959093225391}},{["name"]="WingTipR",["fbxName"]="Import3D_WingTipR",["cf"]={2.7480617081518837,0.1949636294973428,0.09746365237648219,1,0,0,0,1,0,0,0,1},["size"]={1.604959709480581,0.21992725899468568,0.8650726952470357}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.2342075946851952,-0.28781366093164684,0.2834946471437804,1,0,0,0,1,0,0,0,1},["size"]={0.20152780085015343,0.4129387995920353,0.2234170351635624}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.3001692637709159,-0.5926494343800257,0.293427750171733,1,0,0,0,1,0,0,0,1},["size"]={0.11735121176466873,0.31866862309235156,0.18614751937431687}},{["name"]="FootBR",["fbxName"]="Import3D_FootBR",["cf"]={0.33,-0.787863302662908,0.13473857505374998,1,0,0,0,1,0,0,0,1},["size"]={0.133,0.26211816419765743,0.2438971362378677}}}
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
