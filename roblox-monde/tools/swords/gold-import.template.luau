-- Exercises the real import plugin with small object/math doubles.
-- Not an Import 3D or Studio render test. FBX round-trip is checked separately.
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local V = {}; V.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
	return V[key]
end
local Vector3 = {new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V) end}
function V.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function V.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function V.__unm(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
function V.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function V.__div(a,b) return a*(1/b) end
function V:Cross(b) return Vector3.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
local zero, x, y, z = Vector3.new(),Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1)
local CFrame = {}
function CFrame.lookAt(at, to, up)
	local forward = to-at; forward = forward/forward.Magnitude
	local right = forward:Cross(up); right = right/right.Magnitude
	return {Position=at,XVector=right,YVector=right:Cross(forward),ZVector=-forward,LookVector=forward}
end
local Obj = {}
Obj.__index = function(o,k) return Obj[k] or o.props[k] end
Obj.__newindex = function(o,k,v)
	if k=="Parent" then
		local previous=o.props.Parent
		if previous then local at=table.find(previous.children,o); if at then table.remove(previous.children,at) end end
		if v then table.insert(v.children,o) end
	end
	o.props[k]=v
end
local Instance = {new=function(class) return setmetatable({props={ClassName=class},children={}},Obj) end}
function Obj:IsA(class)
	return self.ClassName==class or (class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart"))
		or (class=="LuaSourceContainer" and self.ClassName=="Script")
end
function Obj:IsDescendantOf(other)
	local p=self.Parent
	while p do if p==other then return true end; p=p.Parent end
	return false
end
function Obj:GetDescendants()
	local out={}
	local function visit(item) for _,c in item.children do table.insert(out,c); visit(c) end end
	visit(self); return out
end
function Obj:Clone()
	local copy=Instance.new(self.ClassName)
	for k,v in self.props do if k~="Parent" then copy[k]=v end end
	for _,c in self.children do local child=c:Clone(); child.Parent=copy end
	return copy
end
function Obj:Destroy() self.Parent=nil; self.destroyed=true end
function Obj:SetAttribute(k,v) self.props["attr_"..k]=v end
function Obj:ScaleTo(factor)
	for _,item in self:GetDescendants() do if item:IsA("BasePart") then
		item.Size=item.Size*factor; item.Position=item.Position*factor
	end end
end
local workspace=Instance.new("Workspace")
local game={GetService=function() return {} end}
local plugin={CreateToolbar=function() return {CreateButton=function()
	return {Click={Connect=function() end}}
end} end}
local imports=(function()
--[[IMPORT_PLUGIN_SOURCE]]
	return {chooseSource=chooseSource,arrange=arrange}
end)()
local function model(name,scale)
	local source=Instance.new("Model"); source.Name="Sword_"..name; source.Parent=workspace
	local mesh=Instance.new("MeshPart"); mesh.Name=source.Name
	mesh.Size=Vector3.new(0.5084,5.2,1.4532)*scale
	-- Bounding-box centre measured relative to the actual handle in GoldV2 FBX.
	mesh.Position=Vector3.new(0.0005,1.56,-0.0421)*scale
	mesh.CFrame={XVector=x,YVector=y,ZVector=z}; mesh.Parent=source
	local forbidden=Instance.new("Script"); forbidden.Parent=source
	return source,mesh
end
local old=model("Gold",1)
local selected,info=imports.chooseSource("Gold")
check(selected==old and info.grip==0.585,"Legacy Gold must keep its own calibration")
local other=model("Fusion",1)
local selectedOther,otherInfo=imports.chooseSource("Fusion")
check(selectedOther==other and otherInfo.grip==0.910,"Other sword import unchanged")
local new,mesh=model("GoldV2",2)
selected,info=imports.chooseSource("Gold")
check(selected==new and info.grip==1.040,"Replacement preferred when both versions are present")
local arranged=imports.arrange("Gold",selected,info)
check(arranged.Name=="Gold" and arranged.attr_Calibre==2,"Replacement uses existing gameplay identity")
check(arranged.PrimaryPart.Name=="Grip","Real hand pivot remains the primary part")
check(arranged.PrimaryPart.CFrame.Position.Magnitude<1e-6,"Pivot on actual central shaft, not guard bbox")
check((arranged.PrimaryPart.CFrame.LookVector-y).Magnitude<1e-6,"Grip faces the blade")
local count,trail=0,{}
for _,item in arranged:GetDescendants() do
	check(not item:IsA("LuaSourceContainer"),"Imported executable stripped from copy")
	if item:IsA("BasePart") then
		count+=1
		check(item.Anchored and item.Massless and not item.CanCollide and not item.CanTouch and not item.CanQuery,"Safe visual part flags")
		if item.ClassName=="MeshPart" then check(math.abs(item.Size.Y-5.2)<1e-6,"Replacement size normalized") end
	elseif item.ClassName=="Attachment" then trail[item.Name]=item.Position end
end
check(count==2 and trail.TrailBase and trail.TrailTip,"One visible mesh, one grip, two trail endpoints")
check((trail.TrailBase-Vector3.new(-.0413,.0814,-.858)).Magnitude<1e-6,"Trail starts on gold blade")
check((trail.TrailTip-Vector3.new(-.0023,.6570,-4.160)).Magnitude<1e-6,"Trail follows curved tip rather than old blade axis")
check(mesh.Size.Y==10.4 and #new:GetDescendants()==2,"Imported original remains intact")
new:Destroy(); old:Destroy()
local absent=imports.chooseSource("Gold")
check(absent==nil,"No source must not fabricate or replace an existing stored sword")
print("GOLD_IMPORT_CONTRACT_OK",checks,"(mock objects, not Studio Import 3D)")
