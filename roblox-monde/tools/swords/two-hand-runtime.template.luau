-- Full matrix/quaternion doubles. Runs the REAL production path + IK + grip.
-- This checks FK numerically, not the Roblox physics/render engine.
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local Vector3, V = {}, {}
V.__index = function(v,k)
	if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
	if k == "Unit" then return v/v.Magnitude end
	return V[k]
end
function Vector3.new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0}, V) end
function V.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function V.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function V.__unm(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
function V.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
function V.__div(a,b) return a*(1/b) end
function V:Cross(b) return Vector3.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
function V:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
Vector3.zero,Vector3.xAxis,Vector3.yAxis,Vector3.zAxis=Vector3.new(),Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1)
local CFrame, CF = {}, {}
local I={0,0,0,1,0,0,0,1,0,0,0,1}
function CFrame.new(...)
	local values={...}
	if #values==1 and type(values[1])=="table" then values={values[1].X,values[1].Y,values[1].Z} end
	for i=1,12 do if values[i]==nil then values[i]=I[i] end end
	return setmetatable({v=values},CF)
end
CF.__index=function(c,k)
	local v=c.v
	if k=="Position" then return Vector3.new(v[1],v[2],v[3]) end
	if k=="XVector" then return Vector3.new(v[4],v[7],v[10]) end
	if k=="YVector" then return Vector3.new(v[5],v[8],v[11]) end
	if k=="ZVector" then return Vector3.new(v[6],v[9],v[12]) end
	if k=="LookVector" then return -c.ZVector end
	if k=="Rotation" then return CFrame.new(0,0,0,table.unpack(v,4)) end
	return CF[k]
end
function CF:VectorToWorldSpace(v)
	local a=self.v;return Vector3.new(a[4]*v.X+a[5]*v.Y+a[6]*v.Z,a[7]*v.X+a[8]*v.Y+a[9]*v.Z,a[10]*v.X+a[11]*v.Y+a[12]*v.Z)
end
function CF:PointToWorldSpace(v) return self.Position+self:VectorToWorldSpace(v) end
function CF:VectorToObjectSpace(v) return self:Inverse():VectorToWorldSpace(v) end
function CF.__mul(a,b)
	local x,y,c=a.v,b.v,table.clone(I)
	for i=0,2 do
		c[i+1]=x[i+1]
		for k=0,2 do c[i+1]+=x[4+i*3+k]*y[k+1] end
		for j=0,2 do
			c[4+i*3+j]=0
			for k=0,2 do c[4+i*3+j]+=x[4+i*3+k]*y[4+k*3+j] end
		end
	end
	return CFrame.new(table.unpack(c))
end
function CF:Inverse()
	local a,c=self.v,table.clone(I)
	for i=0,2 do for j=0,2 do c[4+i*3+j]=a[4+j*3+i] end end
	for i=0,2 do c[i+1]=0;for k=0,2 do c[i+1]-=c[4+i*3+k]*a[k+1] end end
	return CFrame.new(table.unpack(c))
end
function CF:ToObjectSpace(b) if self == b then return CFrame.identity end;return self:Inverse()*b end
function CF:GetComponents() return table.unpack(self.v) end
function CFrame.fromMatrix(p,x,y,z)
	return CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)
end
function CFrame.Angles(x,y,z)
	local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
	return CFrame.new(0,0,0,cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy)
end
local function quaternion(c)
	local a=c.v;local tr=a[4]+a[8]+a[12];local q
	if tr>0 then local s=math.sqrt(tr+1)*2;q={(a[11]-a[9])/s,(a[6]-a[10])/s,(a[7]-a[5])/s,s/4}
	elseif a[4]>a[8] and a[4]>a[12] then local s=math.sqrt(1+a[4]-a[8]-a[12])*2;q={s/4,(a[5]+a[7])/s,(a[6]+a[10])/s,(a[11]-a[9])/s}
	elseif a[8]>a[12] then local s=math.sqrt(1+a[8]-a[4]-a[12])*2;q={(a[5]+a[7])/s,s/4,(a[9]+a[11])/s,(a[6]-a[10])/s}
	else local s=math.sqrt(1+a[12]-a[4]-a[8])*2;q={(a[6]+a[10])/s,(a[9]+a[11])/s,s/4,(a[7]-a[5])/s} end
	local length=math.sqrt(q[1]^2+q[2]^2+q[3]^2+q[4]^2)
	for i=1,4 do q[i]/=length end;return q
end
function CF:Lerp(b,t)
	local qa,qb=quaternion(self),quaternion(b);local dot=0
	for i=1,4 do dot+=qa[i]*qb[i] end
	if dot<0 then dot=-dot;for i=1,4 do qb[i]=-qb[i] end end
	local q={}
	if dot>.9995 then
		local len=0;for i=1,4 do q[i]=qa[i]+(qb[i]-qa[i])*t;len+=q[i]^2 end
		for i=1,4 do q[i]/=math.sqrt(len) end
	else
		local angle,s=math.acos(math.min(1,dot)),math.sqrt(1-dot*dot)
		for i=1,4 do q[i]=(qa[i]*math.sin((1-t)*angle)+qb[i]*math.sin(t*angle))/s end
	end
	local x,y,z,w=table.unpack(q);local p=self.Position+(b.Position-self.Position)*t
	return CFrame.new(p.X,p.Y,p.Z,1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y))
end
CFrame.identity=CFrame.new()
local Path=(function()
--[[PATH_SOURCE]]
end)()
local Motion=(function()
--[[MOTION_SOURCE]]
end)()
local Combat=(function()
--[[COMBAT_SOURCE]]
end)()
local Grip=(function()
--[[GRIP_SOURCE]]
end)()
local RIG = --[[RIG_DATA]]
local function object(class, name)
	local o={ClassName=class,Name=name,children={}}
	function o:IsA(c) return c==self.ClassName or c=="BasePart" and self.ClassName=="Part" end
	function o:FindFirstChild(n) return self.children[n] end
	return o
end
local maxError,measured=0,0
for _, bodyScale in {0.75,1,1.3} do
	for _, armScale in {0.85,1,1.2} do
		for _, constraint in {false,true} do
			local character=object("Model","R15Preview");local links={}
			local rootPart=object("Part","HumanoidRootPart");rootPart.CFrame=CFrame.new(12,4,-7)*CFrame.Angles(0,.61,0);character.children[rootPart.Name]=rootPart
			local function scaled(values, factor)
				local c=table.clone(values);for i=1,3 do c[i]*=factor end;return CFrame.new(table.unpack(c))
			end
			for _, data in RIG do
				local parent=character:FindFirstChild(data.parent)
				local child=object("Part",data.child);character.children[data.child]=child
				local factor=bodyScale*(if string.find(data.name,"Elbow") or string.find(data.name,"Wrist") then armScale else 1)
				local link=object(if constraint then "AnimationConstraint" else "Motor6D",data.name)
				link.Part0,link.Part1=parent,child
				link.C0,link.C1=scaled(data.c0,factor),scaled(data.c1,factor)
				link.Transform=CFrame.identity;links[data.name]=link
				if constraint then
					for _, item in {{parent,link.C0},{child,link.C1}} do
						local a=object("Attachment",data.name.."RigAttachment");a.CFrame=item[2];item[1].children[a.Name]=a
					end
				end
				if data.child=="RightHand" or data.child=="LeftHand" then
					local socket=object("Attachment",data.child=="RightHand" and "RightGripAttachment" or "LeftGripAttachment")
					socket.Position=Vector3.new(0,-.25*bodyScale,0);child.children[socket.Name]=socket
				end
			end
			local function findJoint(_c,_p,n) return links[n] end
			check(Motion.supported(character,findJoint),"R15 bind frames available for both joint types")
			local sword=object("Model","HyenaFang");local primary=object("Part","Grip");primary.CFrame=CFrame.identity;sword.PrimaryPart=primary
			function sword:GetAttribute(n) return n=="TwoHanded" and true or nil end
			function sword:GetPivot() return primary.CFrame end
			function sword:PivotTo(c) primary.CFrame=c end
			for _,side in {"Right","Left"} do
				local hold=object("Attachment",side.."Hold")
				hold.CFrame=CFrame.new(0,0,if side=="Right" then -.256 else .256)*CFrame.Angles(0,0,if side=="Left" then math.pi else 0)
				primary.children[hold.Name]=hold
			end
			for _, variant in {"SlashRight","SlashLeft"} do
				local firstX,lastX
				for i=-1,145 do
					local elapsed=i/144*Combat.duration
					for _,link in links do link.Transform=CFrame.identity end
					local body=Combat.sample(variant,elapsed)
					if body then for name,c in body do
						if not string.find(name,"Shoulder") and not string.find(name,"Elbow") and not string.find(name,"Wrist") then
							links[name].Transform=CFrame.identity:Lerp(c,Combat.weight(elapsed))
						end
					end end
					local pose=Motion.pose(character,findJoint,sword,variant,elapsed)
					check(pose~=nil,"Shared handle remains reachable")
					for name,c in pose do
						check(c.Position.Magnitude<1e-9,"No stretched limb translations");links[name].Transform=c
					end
					for _,data in RIG do
						local link=links[data.name];link.Part1.CFrame=link.Part0.CFrame*link.C0*link.Transform*link.C1:Inverse()
					end
					for _,side in {"Right","Left"} do
						local hand=character:FindFirstChild(side.."Hand");local a=hand:FindFirstChild(side.."GripAttachment")
						a.WorldPosition=hand.CFrame:PointToWorldSpace(a.Position)
					end
					Grip.place(sword,character:FindFirstChild("RightHand"))
					local actual=Grip.frame(character:FindFirstChild("LeftHand"))
					local target=primary.CFrame*primary:FindFirstChild("LeftHold").CFrame
					local relative=target:ToObjectSpace(actual)
					local error=relative.Position.Magnitude;maxError=math.max(maxError,error)
					check(error<0.0001,"Left fist remains on the same handle as the right fist")
					check(relative.XVector:Dot(Vector3.xAxis)>.9999 and relative.YVector:Dot(Vector3.yAxis)>.9999,"Both palms keep their grip orientation")
					if Combat.trail(elapsed) then
						check(math.abs(primary.CFrame.LookVector.Y)<.035,"Horizontal circular cut, not upright chop")
						check(math.abs(primary.CFrame.XVector.Y)>.99,"The cutting plane is horizontal")
						local weaponLocal=rootPart.CFrame:ToObjectSpace(primary.CFrame)
						if not firstX then firstX=weaponLocal.LookVector.X end;lastX=weaponLocal.LookVector.X
					end
					measured+=1
				end
				check(if variant=="SlashRight" then firstX<-.7 and lastX>.7 else firstX>.7 and lastX<-.7,"Opposite directions for the two circular cuts")
			end
		end
	end
end
check(Path.duration==Combat.duration,"No combat clock change")
print("HYENA_TWO_HAND_RUNTIME_FK_OK",checks,"checks",measured,"poses",maxError,"stud max grip error (not Studio)")
