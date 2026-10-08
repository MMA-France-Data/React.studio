-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Deer"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,-0.2225,0.33000000000000007,1,0,0,0,1,0,0,0,1},["size"]={0.76,0.815,1.54}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0,0.21956050903487795,-0.4313421547575276,1,0,0,0,1,0,0,0,1},["size"]={0.52,1.014527610355136,0.8412007902285055}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,1.1052933190972296,-0.7744375063633606,1,0,0,0,1,0,0,0,1},["size"]={1.0276901074657159,1.4205866381944592,1.0241247030783325}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.35902074752997354,0.8254028266776423,-0.6302650612033809,1,0,0,0,1,0,0,0,1},["size"]={0.44064185456212546,0.2696627412098894,0.19150947701187848}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.23099010538259315,-0.6024999999999999,-0.1975,1,0,0,0,1,0,0,0,1},["size"]={0.25993490500192634,0.845,0.345}},{["name"]="KneeFL",["fbxName"]="Import3D_KneeFL",["cf"]={-0.239,-1.2610000000000001,-0.24,1,0,0,0,1,0,0,0,1},["size"]={0.17776,0.5820000000000001,0.28}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.22469707612778633,-0.6024999999999999,0.9226475669633387,1,0,0,0,1,0,0,0,1},["size"]={0.2473488464923127,0.845,0.34529513392667743}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.239,-1.2610000000000001,0.88,1,0,0,0,1,0,0,0,1},["size"]={0.17776,0.5820000000000001,0.28}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.35902074752997354,0.8254028266776423,-0.6302650612033809,1,0,0,0,1,0,0,0,1},["size"]={0.44064185456212546,0.2696627412098894,0.19150947701187848}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.23099010538259315,-0.6024999999999999,-0.1975,1,0,0,0,1,0,0,0,1},["size"]={0.25993490500192634,0.845,0.345}},{["name"]="KneeFR",["fbxName"]="Import3D_KneeFR",["cf"]={0.239,-1.2610000000000001,-0.24,1,0,0,0,1,0,0,0,1},["size"]={0.17776,0.5820000000000001,0.28}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.22469707612778633,-0.6024999999999999,0.9226475669633387,1,0,0,0,1,0,0,0,1},["size"]={0.2473488464923127,0.845,0.34529513392667743}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.239,-1.2610000000000001,0.88,1,0,0,0,1,0,0,0,1},["size"]={0.17776,0.5820000000000001,0.28}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.12583709563117867,1.1919792508623317,1,0,0,0,1,0,0,0,1},["size"]={0.19972186842198225,0.26832580873764267,0.387505828187082}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.17829060554504395,0.7669602632522583,-0.9247925281524658,1,0,0,0,1,0,0,0,1},["size"]={0.08502890169620514,0.11229950189590454,0.127718985080719}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.17829060554504395,0.7669602632522583,-0.9247925281524658,1,0,0,0,1,0,0,0,1},["size"]={0.08502890169620514,0.11229950189590454,0.127718985080719}}}
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
    assert(count == #members + 1 and joints == 14, "Structure inattendue")
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
