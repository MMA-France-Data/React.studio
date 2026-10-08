-- Command Bar, EDIT mode only. Select imported FBX model and rig template.
-- Creates a new assembled model; never removes either selected original.
local Selection = game:GetService("Selection")
local History = game:GetService("ChangeHistoryService")
assert(not game:GetService("RunService"):IsRunning(), "Arrêter le test avant l'assemblage")
local id = "Dilophosaurus"
local members = {{["name"]="Core",["fbxName"]="Import3D_Core",["cf"]={0,-0.09999999999999987,-0.455,1,0,0,0,1,0,0,0,1},["size"]={1.06,1.06,2.07}},{["name"]="Neck",["fbxName"]="Import3D_Neck",["cf"]={0.00004539857532012692,0.36350796585337,-1.5101416668137495,1,0,0,0,1,0,0,0,1},["size"]={0.6179385658393839,1.296938207616746,0.9759438865705681}},{["name"]="Head",["fbxName"]="Import3D_Head",["cf"]={0,1.2000000000000002,-2.295,1,0,0,0,1,0,0,0,1},["size"]={0.72,1,1.3899999999999997}},{["name"]="Jaw",["fbxName"]="Import3D_Jaw",["cf"]={0,0.7675000000000001,-2.4,1,0,0,0,1,0,0,0,1},["size"]={0.5706339097770922,0.29499999999999993,1.2000000000000002}},{["name"]="Tail",["fbxName"]="Import3D_Tail",["cf"]={0,-0.20999999999999996,1.1614778315780132,1,0,0,0,1,0,0,0,1},["size"]={0.54,0.4998915283640559,1.4333700699969443}},{["name"]="Tail1",["fbxName"]="Import3D_Tail1",["cf"]={0,-0.10738215500895032,2.560324555289346,1,0,0,0,1,0,0,0,1},["size"]={0.26629582456264306,0.44433758712576776,1.6622409353406642}},{["name"]="FrillL",["fbxName"]="Import3D_FrillL",["cf"]={-0.39797553094914245,0.795,-1.2645571388290409,1,0,0,0,1,0,0,0,1},["size"]={0.5039275069962342,1.57,1.206225084507739}},{["name"]="ArmL",["fbxName"]="Import3D_ArmL",["cf"]={-0.45365125243421267,-0.09218133338322643,-1.1630153186943235,1,0,0,0,1,0,0,0,1},["size"]={0.43071660035646103,0.5742487642408771,0.35200484106564633}},{["name"]="ForearmL",["fbxName"]="Import3D_ForearmL",["cf"]={-0.55,-0.43356569353891083,-1.5976825861163269,1,0,0,0,1,0,0,0,1},["size"]={0.24969336792072772,0.5004236655576426,0.9053370746505236}},{["name"]="LegBL",["fbxName"]="Import3D_LegBL",["cf"]={-0.5200719021655629,-0.5092037990777982,-0.47408902755385623,1,0,0,0,1,0,0,0,1},["size"]={0.6709668163884317,1.1398486075501797,0.8812056778624454}},{["name"]="KneeBL",["fbxName"]="Import3D_KneeBL",["cf"]={-0.6,-1.1853754785585464,-0.6092021209054641,1,0,0,0,1,0,0,0,1},["size"]={0.2948275200514976,0.6960161661705784,0.6351165705780516}},{["name"]="FootBL",["fbxName"]="Import3D_FootBL",["cf"]={-0.6,-1.500010335622036,-0.6715241183438587,1,0,0,0,1,0,0,0,1},["size"]={0.37200000000000005,0.27455060686393584,0.7974670886134033}},{["name"]="FrillR",["fbxName"]="Import3D_FrillR",["cf"]={0.39797553094914245,0.795,-1.2645571388290409,1,0,0,0,1,0,0,0,1},["size"]={0.5039275069962342,1.57,1.206225084507739}},{["name"]="ArmR",["fbxName"]="Import3D_ArmR",["cf"]={0.45365125243421267,-0.09218133338322643,-1.1630153186943235,1,0,0,0,1,0,0,0,1},["size"]={0.43071660035646103,0.5742487642408771,0.35200484106564633}},{["name"]="ForearmR",["fbxName"]="Import3D_ForearmR",["cf"]={0.55,-0.43356569353891083,-1.5976825861163269,1,0,0,0,1,0,0,0,1},["size"]={0.24969336792072772,0.5004236655576426,0.9053370746505236}},{["name"]="LegBR",["fbxName"]="Import3D_LegBR",["cf"]={0.5200719021655629,-0.5092037990777982,-0.47408902755385623,1,0,0,0,1,0,0,0,1},["size"]={0.6709668163884317,1.1398486075501797,0.8812056778624454}},{["name"]="KneeBR",["fbxName"]="Import3D_KneeBR",["cf"]={0.6,-1.1853754785585464,-0.6092021209054641,1,0,0,0,1,0,0,0,1},["size"]={0.2948275200514976,0.6960161661705784,0.6351165705780516}},{["name"]="FootBR",["fbxName"]="Import3D_FootBR",["cf"]={0.6,-1.500010335622036,-0.6715241183438587,1,0,0,0,1,0,0,0,1},["size"]={0.37200000000000005,0.27455060686393584,0.7974670886134033}}}
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
    assert(count == #members + 1 and joints == 18, "Structure inattendue")
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
