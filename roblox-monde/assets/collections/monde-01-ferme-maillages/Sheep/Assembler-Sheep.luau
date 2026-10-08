-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Sheep"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={-0.003016420512308715,0.11974027997929021,0.2856268882751465,1,0,0,0,1,0,0,0,1},["size"]={1.481640116987447,1.1406875897780688,1.642199993133545}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0.002747843163119018,0.18095649778842926,-0.9514231085777283,1,0,0,0,1,0,0,0,1},["size"]={0.525695700440618,0.6642000377178192,0.8463000059127808}},{["name"]="EarL",["fbxName"]="Import3D_EarL",["cf"]={-0.36062900722026825,0.34241926670074463,-0.6813230812549591,1,0,0,0,1,0,0,0,1},["size"]={0.36024823784828186,0.14896851778030396,0.2724999785423279}},{["name"]="EarR",["fbxName"]="Import3D_EarR",["cf"]={0.36062900722026825,0.34241926670074463,-0.6813230812549591,1,0,0,0,1,0,0,0,1},["size"]={0.36024823784828186,0.14896851778030396,0.2724999785423279}},{["name"]="LegFL",["fbxName"]="Import3D_LegFL",["cf"]={-0.38999998569488525,-0.5734035074710846,-0.44632309675216675,1,0,0,0,1,0,0,0,1},["size"]={0.2200000286102295,0.5366000533103943,0.3125}},{["name"]="LegFR",["fbxName"]="Import3D_LegFR",["cf"]={0.38999998569488525,-0.5734035074710846,-0.44632309675216675,1,0,0,0,1,0,0,0,1},["size"]={0.2200000286102295,0.5366000533103943,0.3125}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.38999998569488525,-0.5734035074710846,0.7536768913269043,1,0,0,0,1,0,0,0,1},["size"]={0.2200000286102295,0.5366000533103943,0.3125}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.38999998569488525,-0.5734035074710846,0.7536768913269043,1,0,0,0,1,0,0,0,1},["size"]={0.2200000286102295,0.5366000533103943,0.3125}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.0731787160038948,1.1536102890968323,1,0,0,0,1,0,0,0,1},["size"]={0.3700000047683716,0.45262281596660614,0.42496001720428467}},{["name"]="WoolTop00",["fbxName"]="Import3D_WoolTop00",["cf"]={-0.3096233159303665,0.45547698450425494,-0.16500259563326836,1,0,0,0,1,0,0,0,1},["size"]={0.3890499770641327,0.2811922135420487,0.4885047450661659}},{["name"]="WoolTop10",["fbxName"]="Import3D_WoolTop10",["cf"]={0.001194976270198822,0.5736293494701385,-0.1650184914469719,1,0,0,0,1,0,0,0,1},["size"]={0.3957483321428299,0.3049892783164978,0.49191291630268097}},{["name"]="WoolTop20",["fbxName"]="Import3D_WoolTop20",["cf"]={0.31001103669404984,0.4568773059395956,-0.16502788662910461,1,0,0,0,1,0,0,0,1},["size"]={0.40407024323940277,0.2813181575830791,0.49615269899368286}},{["name"]="Muzzle",["fbxName"]="Import3D_Muzzle",["cf"]={0,0.0010965019464492798,-1.1750730276107788,1,0,0,0,1,0,0,0,1},["size"]={0.3799999952316284,0.3100000023841858,0.2999999523162842}},{["name"]="WoolCap",["fbxName"]="Import3D_WoolCap",["cf"]={0,0.3598964810371399,-0.7950730919837952,1,0,0,0,1,0,0,0,1},["size"]={0.6399999856948853,0.25,0.5900000333786011}},{["name"]="EyeL",["fbxName"]="Import3D_EyeL",["cf"]={-0.23509471723809838,0.24582598719280213,-0.9781558141257847,1,0,0,0,1,0,0,0,1},["size"]={0.05631104286274827,0.1415828269973918,0.13027626214323496}},{["name"]="EyeR",["fbxName"]="Import3D_EyeR",["cf"]={0.23509471723809838,0.24582598719280213,-0.9781558141257847,1,0,0,0,1,0,0,0,1},["size"]={0.05631104286274827,0.1415828269973918,0.13027626214323496}}}
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
    assert(count == #members + 1 and joints == 9, "Structure inattendue")
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
