# Images pour la page Roblox du jeu, à partir des captures du scénario « page » :
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test page     (environ 2 minutes : les captures)
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\page.ps1              (le recadrage)
# Chaque capture out\page_<nom>.png montre toute la fenêtre de Studio. Ce script y découpe l'image du jeu (trouvée
# grâce à la capture « page_calibrage », un écran rose plein cadre), la recadre au format de Roblox et l'enregistre
# dans assets\page :
#   miniature_<nom>.jpg : 1920 x 1080 (miniatures de la page du jeu)
#   icone.jpg           : 512 x 512 (icône du jeu, tirée de la capture « zoom »)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$out = Join-Path $root "out"
$repo = (Resolve-Path (Join-Path $root "..\..")).Path
$page = Join-Path $repo "assets\page"
New-Item -ItemType Directory -Force $page | Out-Null

$calibration = Join-Path $out "page_calibrage.png"
if (-not (Test-Path $calibration)) {
	Write-Host "Capture de calibrage introuvable : lance d'abord tools\studio-test\run.ps1 -Test page"
	exit 1
}
# Rectangle de l'image du jeu : la boîte des pixels roses de la capture de calibrage.
$bitmap = New-Object System.Drawing.Bitmap $calibration
$minX = $bitmap.Width; $minY = $bitmap.Height; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $bitmap.Height; $y += 1) {
	for ($x = 0; $x -lt $bitmap.Width; $x += 1) {
		$pixel = $bitmap.GetPixel($x, $y)
		if ($pixel.R -gt 240 -and $pixel.G -lt 20 -and $pixel.B -gt 240) {
			if ($x -lt $minX) { $minX = $x }
			if ($x -gt $maxX) { $maxX = $x }
			if ($y -lt $minY) { $minY = $y }
			if ($y -gt $maxY) { $maxY = $y }
		}
	}
}
$bitmap.Dispose()
if ($maxX -lt 0) {
	Write-Host "Aucun pixel rose dans la capture de calibrage : image du jeu introuvable"
	exit 1
}
$view = New-Object System.Drawing.Rectangle $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1)
Write-Host "Image du jeu dans la fenêtre de Studio : $($view.Width) x $($view.Height) px, à partir de ($($view.X), $($view.Y))"

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$quality = New-Object System.Drawing.Imaging.EncoderParameters 1
$quality.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]92)

# Découpe `source` (rectangle de la capture) et l'enregistre à la taille voulue.
function Save-Crop([string]$capture, [System.Drawing.Rectangle]$source, [int]$width, [int]$height, [string]$file) {
	$image = New-Object System.Drawing.Bitmap $capture
	$target = New-Object System.Drawing.Bitmap $width, $height
	$graphics = [System.Drawing.Graphics]::FromImage($target)
	$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$graphics.DrawImage($image, (New-Object System.Drawing.Rectangle 0, 0, $width, $height), $source, [System.Drawing.GraphicsUnit]::Pixel)
	$graphics.Dispose()
	$target.Save($file, $codec, $quality)
	$target.Dispose()
	$image.Dispose()
	Write-Host "  $file"
}

# Miniatures : la plus grande zone 16:9 au milieu de l'image du jeu.
$names = "combat", "zoom", "boss", "victoire", "camp", "oeufs", "niveaux", "boutique", "couveuses", "place"
foreach ($name in $names) {
	$capture = Join-Path $out "page_$name.png"
	if (-not (Test-Path $capture)) { Write-Host "  (capture page_$name.png absente)"; continue }
	$cropWidth = [Math]::Min($view.Width, [int]($view.Height * 16 / 9))
	$cropHeight = [int]($cropWidth * 9 / 16)
	$source = New-Object System.Drawing.Rectangle ($view.X + [int](($view.Width - $cropWidth) / 2)), ($view.Y + [int](($view.Height - $cropHeight) / 2)), $cropWidth, $cropHeight
	Save-Crop $capture $source 1920 1080 (Join-Path $page "miniature_$name.jpg")
}
# Icône : un carré au milieu de la capture « zoom » (sans interface).
$zoom = Join-Path $out "page_zoom.png"
if (Test-Path $zoom) {
	$side = [Math]::Min($view.Width, $view.Height)
	$source = New-Object System.Drawing.Rectangle ($view.X + [int](($view.Width - $side) / 2)), ($view.Y + [int](($view.Height - $side) / 2)), $side, $side
	Save-Crop $zoom $source 512 512 (Join-Path $page "icone.jpg")
}
Write-Host "Images prêtes dans $page"
