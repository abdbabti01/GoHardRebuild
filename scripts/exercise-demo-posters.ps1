param([string]$Cache, [string]$S = (Join-Path $env:TEMP "gohard-demo-posters"), [string]$Dest = (Join-Path $PSScriptRoot "..\app\assets\demos"))
# Run after build-exercise-demos.mjs has filled --cache (clips) and with the stills downloaded to $S\stills as
# <key>__<imageId>.png (the provider thumbnails named in exercise-media.json). Windows only (WinRT + System.Drawing).
# Bundled posters: one frame of each mapped clip (640 px wide, JPEG q80) and the start/finish pair of each mapped still,
# side by side on white (640 x 320). The transformations are recorded in exercise-media.json.
Add-Type -AssemblyName System.Drawing
$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 80L
New-Item -ItemType Directory -Force $Dest | Out-Null

$clips = @{ 'bench-press' = @('clip_22', 0.35); 'incline-dumbbell-press' = @('clip_24', 0.1); 'dumbbell-bench-press' = @('clip_20', 0.1); 'overhead-triceps-extension' = @('clip_57', 0.1); 'dip' = @('clip_65', 0.1) }
foreach ($k in $clips.Keys) {
  $one = Join-Path $S "p_$k"; New-Item -ItemType Directory -Force $one | Out-Null
  Copy-Item (Join-Path $Cache $clips[$k][0]) (Join-Path $one "$($clips[$k][0]).mov")
  & (Join-Path $PSScriptRoot 'exercise-demo-frames.ps1') -Dir $one -Out (Join-Path $S "pf_$k") -Fractions @($clips[$k][1]) -Width 640 | Out-Null
  $src = Get-ChildItem (Join-Path $S "pf_$k") -Filter '*_0.jpg' | Select-Object -First 1
  $img = [System.Drawing.Image]::FromFile($src.FullName)
  $img.Save((Join-Path $Dest "$k.jpg"), $jpeg, $ep); $img.Dispose()
}

$stills = @{ 'barbell-curl' = @(27, 28); 'biceps-curl' = @(23, 24); 'hammer-curl' = @(47, 48); 'lateral-raise' = @(177, 178); 'seated-cable-row' = @(143, 144); 'walking-lunge' = @(121, 122); 'dumbbell-shoulder-press' = @(173, 174) }
foreach ($k in $stills.Keys) {
  $bmp = New-Object System.Drawing.Bitmap 640, 320
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::White)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  for ($i = 0; $i -lt 2; $i++) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $S "stills\${k}__$($stills[$k][$i]).png"))
    $f = [Math]::Min(300 / $img.Width, 300 / $img.Height)
    $w = $img.Width * $f; $h = $img.Height * $f
    $g.DrawImage($img, [float](10 + $i * 320 + (300 - $w) / 2), [float](10 + (300 - $h) / 2), [float]$w, [float]$h); $img.Dispose()
  }
  $g.Dispose(); $bmp.Save((Join-Path $Dest "$k.jpg"), $jpeg, $ep); $bmp.Dispose()
}
Get-ChildItem $Dest | ForEach-Object { '{0} {1}' -f $_.Name, $_.Length }
