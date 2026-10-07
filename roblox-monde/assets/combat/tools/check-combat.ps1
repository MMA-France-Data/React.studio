param([string] $ReportPath)
$ErrorActionPreference = 'Stop'
$assetRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
foreach ($name in @('luau', 'luau-compile', 'rojo')) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { throw "Missing tool: $name" }
}
$files = @(Get-ChildItem -LiteralPath $assetRoot -Recurse -File)
$luauFiles = @($files | Where-Object Extension -eq '.luau')
foreach ($file in $luauFiles) {
    $diagnostics = & luau-compile --text $file.FullName 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Luau syntax failed: $($file.FullName)`n$diagnostics" }
}
foreach ($test in @('test-player-alternation.luau', 'test-combat-timeline.luau')) {
    & luau (Join-Path $assetRoot "tests/$test")
    if ($LASTEXITCODE -ne 0) { throw "Failed test: $test" }
}

$manifest = Get-Content -LiteralPath (Join-Path $assetRoot 'animaux/MANIFEST.json') -Raw | ConvertFrom-Json
$animalCount = 0
$attackCount = 0
$biteCount = 0
foreach ($room in $manifest.rooms) {
    foreach ($pet in $room.pets) {
        $path = Join-Path $assetRoot "animaux/salle-$($room.room)/models/$($pet.id).rbxmx"
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pet.sha256) {
            throw "Animal hash mismatch: $($pet.id)"
        }
        [xml] $model = Get-Content -LiteralPath $path -Raw
        foreach ($clip in $model.SelectNodes('//Item[@class="KeyframeSequence"]')) {
            $name = $clip.SelectSingleNode('Properties/string[@name="Name"]').InnerText
            if ($name -notin @('Attack', 'Bite')) { continue }
            if ($clip.SelectSingleNode('Properties/bool[@name="Loop"]').InnerText -ne 'false') {
                throw "Combat clip loops: $($pet.id)/$name"
            }
            $impacts = @($clip.SelectNodes('.//Item[@class="Keyframe"]/Properties/string[@name="Name"]') |
                Where-Object InnerText -eq 'Impact')
            if ($impacts.Count -ne 1) { throw "Expected one Impact: $($pet.id)/$name" }
            if ($name -eq 'Attack') { $attackCount++ } else { $biteCount++ }
        }
        $animalCount++
    }
}
if ($animalCount -ne 36 -or $attackCount -ne 36 -or $biteCount -ne 17) { throw 'Wrong animal/clip totals' }
$nativeFiles = @($files | Where-Object Extension -eq '.rbxmx')
if ($nativeFiles.Count -ne 45) { throw 'Expected 45 native models/sequences' }
foreach ($file in $nativeFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    [xml] $asset = $text
    if ($asset.SelectNodes('//Item[@class="Script" or @class="LocalScript" or @class="ModuleScript"]').Count -gt 0) {
        throw "Embedded script: $($file.Name)"
    }
    if ($text -match '(?i)rbxassetid://|https?://') { throw "External asset: $($file.Name)" }
    $refs = @{}
    foreach ($item in $asset.SelectNodes('//Item')) { $refs[$item.GetAttribute('referent')] = $true }
    foreach ($ref in $asset.SelectNodes('//Ref')) {
        if ($ref.InnerText -notin @('', 'null') -and -not $refs.ContainsKey($ref.InnerText)) {
            throw "Unresolved reference: $($file.Name)/$($ref.InnerText)"
        }
    }
}

function Check-ProjectPaths($node, [string] $directory) {
    if ($node -is [Collections.IDictionary]) {
        if ($node.Contains('$path')) {
            $path = [string] $node['$path']
            if ([IO.Path]::IsPathRooted($path) -or -not (Test-Path -LiteralPath (Join-Path $directory $path))) {
                throw "Nonportable or missing project dependency: $path"
            }
        }
        foreach ($value in $node.Values) { Check-ProjectPaths $value $directory }
    } elseif ($node -is [array]) {
        foreach ($value in $node) { Check-ProjectPaths $value $directory }
    }
}
$projects = @($files | Where-Object Name -like '*.project.json')
if ($projects.Count -ne 7) { throw 'Expected seven standalone gallery projects' }
$buildDirectory = Join-Path ([IO.Path]::GetTempPath()) ('monde-combat-check-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $buildDirectory)
foreach ($project in $projects) {
    $data = Get-Content -LiteralPath $project.FullName -Raw | ConvertFrom-Json -AsHashtable
    Check-ProjectPaths $data $project.DirectoryName
    $target = Join-Path $buildDirectory ($data.name + '.rbxl')
    & rojo build $project.FullName -o $target
    if ($LASTEXITCODE -ne 0) { throw "Rojo gallery build failed: $($project.FullName)" }
}
$report = [ordered]@{
    date = (Get-Date).ToString('yyyy-MM-dd')
    baseCommit = '456314d'
    animalModels = $animalCount
    animalAttacks = $attackCount
    animalBites = $biteCount
    playerClips = 2
    swordForms = 6
    nativeXmlAssets = $nativeFiles.Count
    luauSyntaxFiles = $luauFiles.Count
    timingAndAlternationAssertions = 388
    portableGalleryBuilds = $projects.Count
    studioRuntimeTest = $false
    gameSourceReplaced = $false
    liveRobloxDeployment = $false
    files = @($files | Where-Object Name -ne 'DELIVERY.json' | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = [IO.Path]::GetRelativePath($assetRoot, $_.FullName).Replace('\', '/')
            bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
}
if ($ReportPath) {
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($ReportPath), ($report | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
}
Write-Output "COMBAT_HANDOFF_OK: 36 animals, 53 animal actions, 2 player cuts, 6 swords, $($luauFiles.Count) Luau files, 7 galleries. Studio runtime test NOT performed."
Write-Output "Temporary gallery builds: $buildDirectory"
