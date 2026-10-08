-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Anaconda"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0.1152388663432466,-0.06752513232219039,-0.6607573126368019,1,0,0,0,1,0,0,0,1},["size"]={0.5037167312957742,0.3936216764241831,0.5438941683881666}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0.10507709342086455,-0.015323449349815652,-1.061402052041682,1,0,0,0,1,0,0,0,1},["size"]={0.4421936648330413,0.4558864829746567,0.5789564988474464}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0.10398026100434393,0.07796843237236036,-1.5107502341270447,1,0,0,0,1,0,0,0,1},["size"]={0.494,0.3250580570181938,0.5215004682540894}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0.1039802610043439,-0.037500000000000006,-1.52,1,0,0,0,1,0,0,0,1},["size"]={0.3975416238113742,0.11499999999999999,0.56}},{["name"]="Body1",["fbxName"]="Import3D_Body1",["cf"]={0.2509338696446758,-0.07961254528206477,-0.21702184261500795,1,0,0,0,1,0,0,0,1},["size"]={0.6874821272366767,0.36874617558800954,0.7042085839017035}},{["name"]="Body2",["fbxName"]="Import3D_Body2",["cf"]={0.4933778313940621,-0.07547202837336964,0.18003454631090554,1,0,0,0,1,0,0,0,1},["size"]={0.6459951297360342,0.37141572870061645,0.6573167980380126}},{["name"]="Body3",["fbxName"]="Import3D_Body3",["cf"]={0.6162540652092265,-0.0746922616521685,0.5895309362053641,1,0,0,0,1,0,0,0,1},["size"]={0.44708333399209327,0.3571692657660768,0.47741560259723737}},{["name"]="Body4",["fbxName"]="Import3D_Body4",["cf"]={0.4909749285952384,-0.07953067603614057,0.9887655065893357,1,0,0,0,1,0,0,0,1},["size"]={0.5870451366501606,0.32311687839177383,0.6239785753660546}},{["name"]="Body5",["fbxName"]="Import3D_Body5",["cf"]={0.17470678338668985,-0.08367632641718234,1.293212968488192,1,0,0,0,1,0,0,0,1},["size"]={0.593629558797917,0.2952062344099519,0.5328795588615869}},{["name"]="Tail6",["fbxName"]="Import3D_Tail6",["cf"]={-0.2087987406623713,-0.08891635834686029,1.5288955429556275,1,0,0,0,1,0,0,0,1},["size"]={0.512793274164163,0.2301054575864781,0.42027790469289283}},{["name"]="Tail7",["fbxName"]="Import3D_Tail7",["cf"]={-0.5910095084884863,-0.11541482670626055,1.6734083463631855,1,0,0,0,1,0,0,0,1},["size"]={0.4332192090408948,0.15421464937252033,0.19450898263381622}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.10249774158000946,0.14455245435237885,-1.572265863418579,1,0,0,0,1,0,0,0,1},["size"]={0.08476340770721436,0.10159767419099808,0.08286166191101074}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.310458242893219,0.14455245435237885,-1.572265863418579,1,0,0,0,1,0,0,0,1},["size"]={0.08476340770721436,0.10159767419099808,0.08286166191101074}},{["name"]="TailPoint",["fbxName"]="Import3D_TailPoint",["cf"]={-0.8343910855951358,-0.129,1.7369511242106839,1,0,0,0,1,0,0,0,1},["size"]={0.21168778825462542,0.07597395426688926,0.09478278024387676}}}
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
    assert(count == #members + 1 and joints == 11, "Structure inattendue")
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
