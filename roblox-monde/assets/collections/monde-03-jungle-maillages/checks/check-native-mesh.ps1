param([Parameter(Mandatory=$true)][string]$AssetDirectory)
$ErrorActionPreference = 'Stop'
$taskAsset = [System.IO.Path]::GetFullPath($AssetDirectory)
$taskSpec = Get-Content -LiteralPath (Join-Path $taskAsset 'native-rig-spec.json') -Raw | ConvertFrom-Json
[xml]$taskXml = Get-Content -LiteralPath (Join-Path $taskAsset ($taskSpec.id + '-rig-template.rbxmx')) -Raw
$taskItems = @($taskXml.SelectNodes('//Item'))
$taskParts = @($taskXml.SelectNodes('//Item[@class="Part"]'))
$taskMotors = @($taskXml.SelectNodes('//Item[@class="Motor6D"]'))
if ($taskParts.Count -ne $taskSpec.parts.Count + 1 -or $taskParts.Count -ge 20) { throw 'Part budget/anchors mismatch' }
if ($taskMotors.Count -ne $taskSpec.joints.Count) { throw 'Motor6D count mismatch' }
if ($taskXml.SelectNodes('//Item[@class="Bone"]').Count -ne 0) { throw 'Unexpected Bone rig' }
if ($taskXml.SelectNodes('//Item[@class="Script" or @class="LocalScript" or @class="ModuleScript"]').Count -ne 0) { throw 'Unexpected embedded script' }
$taskRefs = @{}
foreach ($taskItem in $taskItems) { $taskRefs[$taskItem.referent] = $taskItem }
foreach ($taskRef in $taskXml.SelectNodes('//Properties/Ref')) {
    if ($taskRef.InnerText -notin @('null','nil') -and -not $taskRefs.ContainsKey($taskRef.InnerText)) { throw "Broken reference $($taskRef.InnerText)" }
}
$taskSequences = @($taskXml.SelectNodes('//Item[@class="Folder" and Properties/string[@name="Name"]="Animations"]/Item[@class="KeyframeSequence"]'))
$taskExpected = @($taskSpec.animations.PSObject.Properties.Name)
if ($taskSequences.Count -ne $taskExpected.Count) { throw 'Clip count mismatch' }
foreach ($taskSequence in $taskSequences) {
    $taskName = $taskSequence.SelectSingleNode('Properties/string[@name="Name"]').InnerText
    if ($taskName -notin $taskExpected) { throw 'Wrong clip name' }
    foreach ($taskFrame in $taskSequence.SelectNodes('Item[@class="Keyframe"]')) {
        if ($taskFrame.SelectNodes('.//Item[@class="Pose"]').Count -ne $taskSpec.joints.Count + 1) { throw 'Pose hierarchy mismatch' }
        if (-not $taskFrame.SelectSingleNode('Item[@class="Pose" and Properties/string[@name="Name"]="RigRoot"]')) { throw 'Root Pose missing' }
    }
}
foreach ($taskFile in Get-ChildItem -LiteralPath $taskAsset -Filter '*.luau') {
    & luau-compile --null $taskFile.FullName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Syntax failed $($taskFile.FullName)" }
}
& node (Join-Path $PSScriptRoot 'verify-native-mesh.cjs') $taskAsset
if ($LASTEXITCODE -ne 0) { throw 'Pose checks failed' }
Write-Output "NATIVE_STRUCTURE_OK: $($taskSpec.id), $($taskParts.Count) anchors, $($taskMotors.Count) Motor6D, $($taskSequences.Count) KeyframeSequence. Studio import still required."
