-- Lightweight object/math doubles: exercise actual creation/update/disposal.
-- This checks the code contract, NOT Roblox's renderer or texture appearance.
for _, mobile in {false, true} do
	local made, checks = {}, 0
	local function check(ok, why) assert(ok, why); checks += 1 end
	local V = {}; V.__index = function(v, key)
		if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
		if key == "Unit" then return v / v.Magnitude end
		return V[key]
	end
	local Vector3 = {}
	function Vector3.new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, V) end
	function V.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
	function V.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
	function V.__unm(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
	function V.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
	function V.__div(a,b) return a * (1/b) end
	function V:Dot(b) return self.X*b.X + self.Y*b.Y + self.Z*b.Z end
	function V:Lerp(b,t) return self + (b-self)*t end
	Vector3.zero, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis = Vector3.new(), Vector3.new(1,0,0), Vector3.new(0,1,0), Vector3.new(0,0,1)
	local CF = {}; CF.__index = CF
	local CFrame = {}
	function CFrame.new(position) return setmetatable({Position=position or Vector3.zero,RightVector=Vector3.xAxis,UpVector=Vector3.yAxis,LookVector=-Vector3.zAxis}, CF) end
	function CF:PointToObjectSpace(p) return p-self.Position end
	function CF:VectorToWorldSpace(v) return v end
	function CF:ToObjectSpace(c) return CFrame.new(c.Position-self.Position) end
	local Color = {}; Color.__index = Color
	local Color3 = {}
	function Color3.new(r,g,b) return setmetatable({R=r,G=g,B=b},Color) end
	function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
	function Color:Lerp(b,t) return Color3.new(self.R+(b.R-self.R)*t,self.G+(b.G-self.G)*t,self.B+(b.B-self.B)*t) end
	local NumberSequenceKeypoint = {new=function(time,value) return {Time=time,Value=value} end}
	local NumberSequence = {new=function(v) return {Keypoints=if type(v)=="table" then v else {{Time=0,Value=v},{Time=1,Value=v}}} end}
	local NumberRange = {new=function(a,b) return {Min=a,Max=b or a} end}
	local ColorSequenceKeypoint = {new=function(t,v) return {Time=t,Value=v} end}
	local ColorSequence = {new=function(a,b) return {a,b} end}
	local Vector2 = {new=function(x,y) return {X=x,Y=y} end}
	local Enum = {TextureMode={Wrap="Wrap",Stretch="Stretch"},NormalId={Top="Top"}}
	local Random = {new=function() return {NextNumber=function(_,a,b) return (a+b)/2 end} end}
	local Obj = {}; Obj.__index = Obj
	function Obj:IsA(class) return self.ClassName==class end
	function Obj:Destroy() self.destroyed=true end
	function Obj:Clear() self.clearCount=(self.clearCount or 0)+1 end
	function Obj:SetTextureOffset(offset) self.offset=offset end
	local Instance = {new=function(class)
		local item=setmetatable({ClassName=class,WorldPosition=Vector3.zero,WorldCFrame=CFrame.new()},Obj)
		table.insert(made,item); return item
	end}
	local game = {GetService=function() return {TouchEnabled=mobile} end}
	local script = {Parent={SwordWispProfile="Wisp",VoidAuraProfile="Profile",VoidBladeAura="Void"}}
	local modules={}
	local require=function(name) assert(modules[name],"Missing dependency"); return modules[name] end
	modules.Wisp = (function()
--[[WISP_SOURCE]]
	end)()
	modules.Profile = (function()
--[[PROFILE_SOURCE]]
	end)()
	modules.Void = (function()
--[[VOID_SOURCE]]
	end)()
	local Aura = (function()
--[[AURA_SOURCE]]
	end)()
	local function model()
		return {PrimaryPart={CFrame=CFrame.new()},FindFirstChild=function() return nil end}
	end
	local function endpoints()
		local a,b=Instance.new("Attachment"),Instance.new("Attachment")
		a.WorldPosition,b.WorldPosition=Vector3.zero,Vector3.new(0,5.3,0)
		return a,b
	end
	local a,b=endpoints()
	local state=Aura.create(model(),"Void",a,b)
	check(state.kind=="VoidShroud","Void must not use old small wisps")
	check(#state.beams==(if mobile then 10 else 14),"Bounded connected smoke layers")
	check(#state.emitters==1,"Only one detached upper smoke source per blade")
	local born=#made
	Aura.update(state,1/60,true,false,false)
	check(state.nodes[#state.nodes].at.WorldPosition.Y>b.WorldPosition.Y,"Smoke rises beyond the tip")
	local emitter=state.emitters[1].item
	check(emitter.Enabled and not emitter.LockedToPart and emitter.VelocityInheritance==0,"Upper smoke escapes freely")
	for frame=1,240 do
		if frame==60 then b.WorldPosition=Vector3.new(5.3,0,0) end
		Aura.update(state,1/60,true,frame>100,false)
		for _, segment in state.segments do
			check(segment.ray.Enabled and segment.ray.Width0>=0 and segment.ray.Width1>=0,"Live finite smoke widths")
			check(segment.ray.offset>=0 and segment.ray.offset<1,"Continuous normalized texture flow")
		end
	end
	check(#made==born,"No per-frame object creation")
	check(state.nodes[#state.nodes].at.WorldPosition.Y>0,"Horizontal swings still shed upward smoke")
	for _, layer in modules.Profile.layers do
		local segments={}
		for _, s in state.segments do if s.layer==layer then table.insert(segments,s) end end
		for i=2,#segments do
			check(math.abs(segments[i-1].ray.Width1-segments[i].ray.Width0)<1e-8,"No geometric gap between smoke sections")
		end
		check(segments[#segments].ray.Width1<1e-8,"Smoke upper end thins completely")
		local keys=segments[#segments].ray.Transparency.Keypoints
		check(keys[#keys].Value>1-1e-8,"Smoke upper end fully fades")
	end
	local before=emitter.clearCount or 0
	Aura.update(state,1/60,true,false,true)
	check(emitter.clearCount==before+1,"Teleport clears detached smoke")
	Aura.update(state,1/60,false,false,false)
	check(not emitter.Enabled and emitter.clearCount==before+2,"Distance culling clears and disables smoke")
	for _, ray in state.beams do check(not ray.Enabled,"Culled shroud has no visible ribbons") end
	Aura.update(state,1/60,true,false,false)
	check(emitter.Enabled,"Shroud resumes when near the camera")
	Aura.dispose(state); Aura.dispose(state)
	check(state.folder.destroyed,"Shroud folder is disposed idempotently")
	for _, at in state.owned do check(at.destroyed,"Owned smoke anchors disposed") end
	for _, id in {"Fusion","Flame","Frost"} do
		local old=Aura.create(model(),id,a,b)
		check(old~=nil,"Other elemental sword still supported")
		Aura.update(old,1/60,true,false,false)
		local found=false
		for _, entry in old.emitters do
			local item=entry.item
			if item.Name==(if id=="Flame" then "BladeFlames" elseif id=="Frost" then "ColdBladeMist" else "FusionHotWisp") then
				found=true
				check(item.Enabled and not item.LockedToPart,"Bold aura remains living, detached smoke/flame")
				local maximum=0
				for _, key in item.Size.Keypoints do maximum=math.max(maximum,key.Value) end
				check(maximum>=(if id=="Fusion" then .85 else 2),"More visible fire and ice")
			end
		end
		check(found,"Actually found the changed elemental effect")
		Aura.dispose(old)
	end
	local allocated={}
	for _=1,(if mobile then 6 else 16) do
		local next=Aura.create(model(),"Void",a,b)
		check(next~=nil,"Released aura capacity is reusable")
		table.insert(allocated,next)
	end
	check(Aura.create(model(),"Void",a,b)==nil,"Global aura cap applies to the shroud")
	for _, next in allocated do Aura.dispose(next) end
	print("AURA_OBJECT_CONTRACT_OK",if mobile then "mobile" else "desktop",checks,"(not a render test)")
end
