const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process'),os=require('node:os');
const root=path.resolve(__dirname,'../..'),assets=path.join(root,'assets/swords-roblox');
const manifest=JSON.parse(fs.readFileSync(path.join(assets,'MONDES-MANIFEST.json'),'utf8'));
function hashFile(file){
 const bytes=fs.readFileSync(file);
 const canonical=/\.(json|md|lua|luau|cjs|py|ps1)$/.test(file)?bytes.toString('utf8').replace(/\r\n/g,'\n'):bytes;
 return crypto.createHash('sha256').update(canonical).digest('hex');
}
for(const [name,expected] of Object.entries(manifest.files)){
 const actual=hashFile(path.join(assets,name));
 if(actual!==expected)throw Error('Changed asset: '+name);
}
for(const [name,expected] of Object.entries({...manifest.clientFiles,...manifest.combatFiles})){
 if(hashFile(path.join(root,name))!==expected)throw Error('Changed delivery: '+name);
}
const literal=value=>Array.isArray(value)?'{'+value.map(literal).join(',')+'}':JSON.stringify(value);
let cases='';
for(const id of manifest.ids){
 const info=JSON.parse(fs.readFileSync(path.join(assets,id,'info.json'),'utf8'));
 if(info.triangles>19000||info.robloxImportCompleted)throw Error('Invalid import state: '+id);
 cases+=`do
 local source,mesh=model(${literal(id)},2)
 mesh.Size=Vector3.new(${info.size[0]},5.2,${info.size[1]})*2
 mesh.Position=Vector3.new(${-info.gripCrossOffset[0]},${2.6-info.gripFromPommel},${-info.gripCrossOffset[1]})*2
 local selected,calibration=imports.chooseSource(${literal(id)})
 check(selected==source,"Correct source selected: ${id}")
 local arranged=imports.arrange(${literal(id)},selected,calibration)
 check(arranged.Name==${literal(id)} and arranged.attr_Calibre==2,"Identity and calibration: ${id}")
 check(arranged.PrimaryPart.CFrame.Position.Magnitude<1e-6,"Handle centered: ${id}")
 check((arranged.PrimaryPart.CFrame.LookVector-y).Magnitude<1e-6,"Blade direction: ${id}")
 local attachments={}
 local count=0
 for _,part in arranged:GetDescendants() do
  check(not part:IsA("LuaSourceContainer"),"No executable in arranged ${id}")
  if part:IsA("BasePart") then count+=1; check(part.Massless and not part.CanCollide,"Safe flags: ${id}") end
  if part.ClassName=="Attachment" then attachments[part.Name]=part.Position end
 end
 check(count==2,"Exactly one visible mesh and one grip: ${id}")
 check((attachments.TrailBase-Vector3.new(${info.trailBase.join(',')})).Magnitude<1e-6,"Blade base: ${id}")
 check((attachments.TrailTip-Vector3.new(${info.trailTip.join(',')})).Magnitude<1e-6,"Blade tip: ${id}")
 ${id==='HyenaFang'?`check(arranged.attr_TwoHanded==true,"Hyena is one two-hand sword")
 check((attachments.RightHold-Vector3.new(0,0,-.16)).Magnitude<1e-6,"Right palm on upper wrapped shaft")
 check((attachments.LeftHold-Vector3.new(0,0,.16)).Magnitude<1e-6,"Left palm on lower wrapped shaft")`:`check(not arranged.attr_TwoHanded,"No two-hand override on ${id}")`}
 check(math.abs(mesh.Size.Y-10.4)<1e-6 and #source:GetDescendants()==2,"Original import preserved: ${id}")
 source:Destroy()
end
`;
}
cases+=`do
 local folder=Instance.new("Folder");folder.Name="SwordMeshes";folder.Parent=mockStorage
 local storedGold=Instance.new("Model");storedGold.Name="Gold";storedGold.Parent=folder
 local storedStand=Instance.new("Model");storedStand.Name="Stand";storedStand.Parent=folder
 local visibleGold=model("GoldV2",2)
`;
for(const id of manifest.ids){
 const info=JSON.parse(fs.readFileSync(path.join(assets,id,'info.json'),'utf8'));
 cases+=`do
  local source,mesh=model(${literal(id)},2)
  mesh.Size=Vector3.new(${info.size[0]},5.2,${info.size[1]})*2
  mesh.Position=Vector3.new(${-info.gripCrossOffset[0]},${2.6-info.gripFromPommel},${-info.gripCrossOffset[1]})*2
 end
`;
}
cases+=`check(callbacks["Ranger les nouvelles épées"]~=nil,"New-only import action exists")
 callbacks["Ranger les nouvelles épées"]()
 check(folder:FindFirstChild("Gold")==storedGold and not storedGold.destroyed,"Old Gold is not reranged even with a visible replacement source")
 check(folder:FindFirstChild("Stand")==storedStand and not storedStand.destroyed,"Existing stand preserved")
`;
for(const id of manifest.ids)cases+=`check(folder:FindFirstChild(${literal(id)})~=nil,"New-only action stored ${id}")\n`;
cases+=`check(#folder.children==6,"No duplicate or unrelated import")
 check(mockSelection.items[1]==folder and mockHistory.waypoint~=nil,"New folder selected and undo waypoint recorded")
 callbacks["Ranger les nouvelles épées"]()
 check(#folder.children==6 and folder:FindFirstChild("Gold")==storedGold,"Repeated new-only import remains scoped and idempotent")
end
`;
const plugin=fs.readFileSync(path.join(__dirname,'RangerLesEpees.lua'),'utf8');
const fixture=fs.readFileSync(path.join(__dirname,'gold-import.template.luau'),'utf8')
 .replace('--[[IMPORT_PLUGIN_SOURCE]]',plugin).replace('--[[NEW_SWORD_CASES]]',cases);
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'world-sword-import-'));
const file=path.join(temp,'contract.luau');fs.writeFileSync(file,fixture);
const syntax=cp.spawnSync('luau-compile',['--null',path.join(__dirname,'RangerLesEpees.lua')],{encoding:'utf8'});
if(syntax.status!==0)throw Error('Plugin syntax: '+syntax.stdout+syntax.stderr);
const run=cp.spawnSync('luau',[file],{encoding:'utf8'});
process.stdout.write(run.stdout);process.stderr.write(run.stderr);
if(run.status!==0)throw Error('Actual plugin import contract failed');
console.log('WORLD_SWORDS_IMPORT_CONTRACT_OK',manifest.ids.join(', '),'(mock objects; Studio still required)');
