# Rebuilds and exports the Leon squat prototype (technique review pending).
#   powershell -File design\leon-3d\export_leon.ps1 -Out C:\dev\GoHard-leon-prototype [-SkipBuild] [-SkipRender]
# Needs Blender 4.5 LTS and ffmpeg (portable copies are fine); paths below are the defaults used on 19 Nov 2026.
param(
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Blender = 'C:\dev\tools\blender-4.5.16-windows-x64\blender.exe',
    [string]$Ffmpeg = 'C:\dev\tools\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe',
    [int]$Crf = 18,
    [switch]$SkipBuild,
    [switch]$SkipRender
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ffprobe = Join-Path (Split-Path $Ffmpeg) 'ffprobe.exe'
$blend = Join-Path $Out 'leon_squat_prototype.blend'
New-Item -ItemType Directory -Force $Out, "$Out\stills", "$Out\frames-3q", "$Out\frames-side" | Out-Null

if (-not $SkipBuild) {
    & $Blender -b --factory-startup --python "$here\build_leon.py" -- --out $blend --report "$Out\checks.json"
    if ($LASTEXITCODE) { throw 'build failed' }
}
if (-not $SkipRender) {
    & $Blender -b $blend --python "$here\render_leon.py" -- --stills "$Out\stills" --res 720 --samples 48
    & $Blender -b $blend --python "$here\render_leon.py" -- --anim "$Out\frames-3q" --cam 'Cam 3q' --res 720 --samples 24
    & $Blender -b $blend --python "$here\render_leon.py" -- --anim "$Out\frames-side" --cam 'Cam side' --res 720 --samples 16
}

# The label lives in a UTF-8 text file so the em dash survives the command line.
$label = Join-Path $Out 'label.txt'
[IO.File]::WriteAllText($label, "Leon squat prototype $([char]0x2014) technique review pending", (New-Object Text.UTF8Encoding $false))
$font = 'C\:/Windows/Fonts/segoeui.ttf'
$lab = $label.Replace('\', '/').Replace(':', '\:')
$draw = "drawtext=fontfile='$font':textfile='$lab':x=24:y=h-46:fontsize=24:fontcolor=0x2B2F33:box=1:boxcolor=0xFFFFFF@0.7:boxborderw=8"
$h264 = @('-c:v', 'libx264', '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-preset', 'slow', '-g', '60',
          '-an', '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:v', '+bitexact', '-movflags', '+faststart')

# Main clip (clean: the review label belongs in the app's preview UI), poster = its first frame.
& $Ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$Out\frames-3q\f_%04d.png" -crf $Crf @h264 "$Out\leon_bodyweight-squat_3q_720.mp4"
& $Ffmpeg -hide_banner -loglevel error -y -i "$Out\frames-3q\f_0001.png" -q:v 3 "$Out\leon_bodyweight-squat_3q_720.jpg"
# Review copies carry the label.
& $Ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$Out\frames-side\f_%04d.png" -vf $draw -crf ($Crf + 2) @h264 "$Out\leon_bodyweight-squat_side_720_review.mp4"
& $Ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$Out\frames-3q\f_%04d.png" -vf $draw -crf $Crf @h264 "$Out\leon_bodyweight-squat_3q_720_review.mp4"
Get-ChildItem "$Out\stills\*.png" | ForEach-Object {
    & $Ffmpeg -hide_banner -loglevel error -y -i $_.FullName -vf $draw -q:v 2 ($_.FullName -replace '\.png$', '_labelled.jpg')
}

# Verify what was actually written.
foreach ($f in Get-ChildItem "$Out\*.mp4") {
    $j = & $ffprobe -v error -show_streams -show_format -of json $f.FullName | ConvertFrom-Json
    $v = $j.streams | Where-Object codec_type -eq 'video'
    $a = @($j.streams | Where-Object codec_type -eq 'audio').Count
    '{0}: {1} {2} level {3} {4} {5}x{6} {7} fps {8:N2} s, audio streams {9}, {10:N2} MB' -f $f.Name, $v.codec_name, $v.profile, $v.level, $v.pix_fmt, $v.width, $v.height, $v.r_frame_rate, [double]$j.format.duration, $a, ($f.Length / 1MB)
    & $Ffmpeg -v error -i $f.FullName -f null - ; if ($LASTEXITCODE) { throw "decode errors in $($f.Name)" }
}
# Loop seam: the last decoded frame must match the first (ffmpeg reports on stderr, which is not an error here).
$ErrorActionPreference = 'Continue'
$main = "$Out\leon_bodyweight-squat_3q_720.mp4"
& $Ffmpeg -hide_banner -loglevel error -y -i $main -vf 'select=eq(n\,0)' -frames:v 1 "$Out\seam_first.png"
& $Ffmpeg -hide_banner -loglevel error -y -sseof -0.1 -i $main -update 1 "$Out\seam_last.png"
& $Ffmpeg -hide_banner -i "$Out\seam_first.png" -i "$Out\seam_last.png" -lavfi psnr -f null - 2>&1 | Select-String 'PSNR'
