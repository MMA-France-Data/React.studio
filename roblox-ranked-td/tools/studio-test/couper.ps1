# Coupe des morceaux d'une vidéo MP4 avec le montage intégré à Windows (Windows.Media.Editing), sans rien installer.
#   couper.ps1 -Entree a.mp4 -Sortie b.mp4 -Garder "0-8,10-19,23-fin"
param(
	[Parameter(Mandatory = $true)][string]$Entree,
	[Parameter(Mandatory = $true)][string]$Sortie,
	[Parameter(Mandatory = $true)][string]$Garder,
	[int]$Images = 60,
	[int]$Debit = 20000000
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$methods = [System.WindowsRuntimeSystemExtensions].GetMethods()
$asTaskOperation = $methods | Where-Object { $_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
$asTaskProgress = $methods | Where-Object { $_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperationWithProgress`2' } | Select-Object -First 1
function Wait-Operation($operation, [Type]$type) {
	$task = $asTaskOperation.MakeGenericMethod($type).Invoke($null, @($operation))
	$task.Wait(-1) | Out-Null
	return $task.Result
}
[void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.Media.Editing.MediaComposition, Windows.Media.Editing, ContentType = WindowsRuntime]
[void][Windows.Media.Editing.MediaClip, Windows.Media.Editing, ContentType = WindowsRuntime]
[void][Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime]
[void][Windows.Media.Transcoding.TranscodeFailureReason, Windows.Media.Transcoding, ContentType = WindowsRuntime]

$source = Wait-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path $Entree).Path)) ([Windows.Storage.StorageFile])
$probe = Wait-Operation ([Windows.Media.Editing.MediaClip]::CreateFromFileAsync($source)) ([Windows.Media.Editing.MediaClip])
$total = $probe.OriginalDuration.TotalSeconds
Write-Host ("Vidéo d'origine : {0:N2} s" -f $total)

$composition = New-Object Windows.Media.Editing.MediaComposition
# La liste des morceaux (IList<MediaClip> de WinRT) : PowerShell 5.1 ne voit pas sa méthode Add sans passer par
# l'interface .NET.
$addClip = [System.Collections.Generic.ICollection[Windows.Media.Editing.MediaClip]].GetMethod("Add")
foreach ($part in $Garder.Split(",")) {
	$bounds = $part.Trim().Split("-")
	$from = [double]::Parse($bounds[0], [Globalization.CultureInfo]::InvariantCulture)
	$to = if ($bounds[1] -eq "fin") { $total } else { [Math]::Min($total, [double]::Parse($bounds[1], [Globalization.CultureInfo]::InvariantCulture)) }
	$clip = Wait-Operation ([Windows.Media.Editing.MediaClip]::CreateFromFileAsync($source)) ([Windows.Media.Editing.MediaClip])
	$clip.TrimTimeFromStart = [TimeSpan]::FromSeconds($from)
	$clip.TrimTimeFromEnd = [TimeSpan]::FromSeconds($total - $to)
	$addClip.Invoke($composition.Clips, @($clip)) | Out-Null
	Write-Host ("  garde {0:N2} s -> {1:N2} s" -f $from, $to)
}

$outPath = [IO.Path]::GetFullPath($Sortie)
$folder = Wait-Operation ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync([IO.Path]::GetDirectoryName($outPath))) ([Windows.Storage.StorageFolder])
$target = Wait-Operation ($folder.CreateFileAsync([IO.Path]::GetFileName($outPath), [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
$profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateMp4([Windows.Media.MediaProperties.VideoEncodingQuality]::HD1080p)
$profile.Video.Width = 1920
$profile.Video.Height = 1080
$profile.Video.FrameRate.Numerator = $Images
$profile.Video.FrameRate.Denominator = 1
$profile.Video.Bitrate = $Debit
$render = $composition.RenderToFileAsync($target, [Windows.Media.Editing.MediaTrimmingPreference]::Precise, $profile)
$task = $asTaskProgress.MakeGenericMethod([Windows.Media.Transcoding.TranscodeFailureReason], [double]).Invoke($null, @($render))
$task.Wait(-1) | Out-Null
Write-Host "Résultat : $($task.Result)"
$check = Wait-Operation ([Windows.Media.Editing.MediaClip]::CreateFromFileAsync($target)) ([Windows.Media.Editing.MediaClip])
Write-Host ("Nouvelle vidéo : {0} ({1:N2} s, {2:N1} Mo)" -f $outPath, $check.OriginalDuration.TotalSeconds, ((Get-Item $outPath).Length / 1MB))
