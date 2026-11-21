# Encodes the mannequin bodyweight-squat pilot (technique review pending) from rendered frames.
#   powershell -File design\leon-3d\mannequin\export_squat.ps1 -Squat C:\dev\GoHard-leon-prototype\mannequin\squat
# Frames come from animate_squat.py (--render 3q / --render side). Same encoding as the Leon v1 pilot (export_leon.ps1).
param(
    [Parameter(Mandatory = $true)][string]$Squat,
    [string]$Ffmpeg = 'C:\dev\tools\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe',
    [int]$Crf = 18
)
$ErrorActionPreference = 'Stop'
$ffprobe = Join-Path (Split-Path $Ffmpeg) 'ffprobe.exe'
$Out = Join-Path $Squat 'export'; New-Item -ItemType Directory -Force $Out | Out-Null
$label = Join-Path $Out 'label.txt'
[IO.File]::WriteAllText($label, "Squat pilot $([char]0x2014) technique review pending", (New-Object Text.UTF8Encoding $false))
$font = 'C\:/Windows/Fonts/segoeui.ttf'; $lab = $label.Replace('\', '/').Replace(':', '\:')
$draw = "drawtext=fontfile='$font':textfile='$lab':x=20:y=h-42:fontsize=22:fontcolor=0x2B2F33:box=1:boxcolor=0xFFFFFF@0.7:boxborderw=8"
$h264 = @('-c:v', 'libx264', '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p', '-preset', 'slow', '-g', '60',
          '-an', '-map_metadata', '-1', '-fflags', '+bitexact', '-flags:v', '+bitexact', '-movflags', '+faststart')
$name = 'mannequin_bodyweight-squat'
# Main clip is clean (the review label belongs in the app's preview UI); poster = its first frame, so play starts seamlessly.
& $Ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$Squat\3q\f_%04d.png" -crf $Crf @h264 "$Out\${name}_3q_720.mp4"
& $Ffmpeg -hide_banner -loglevel error -y -i "$Squat\3q\f_0001.png" -q:v 3 "$Out\${name}_3q_720_poster.jpg"
# Review copies carry the label.
& $Ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$Squat\3q\f_%04d.png" -vf $draw -crf $Crf @h264 "$Out\${name}_3q_720_review.mp4"
& $Ffmpeg -hide_banner -loglevel error -y -framerate 30 -i "$Squat\side\f_%04d.png" -vf $draw -crf ($Crf + 2) @h264 "$Out\${name}_side_480_review.mp4"
foreach ($f in Get-ChildItem "$Out\*.mp4") {
    $j = & $ffprobe -v error -show_streams -show_format -of json $f.FullName | ConvertFrom-Json
    $v = $j.streams | Where-Object codec_type -eq 'video'; $a = @($j.streams | Where-Object codec_type -eq 'audio').Count
    '{0}: {1} {2} {3} {4}x{5} {6} fps {7:N2} s, audio streams {8}, {9:N2} MB' -f $f.Name, $v.codec_name, $v.profile, $v.pix_fmt, $v.width, $v.height, $v.r_frame_rate, [double]$j.format.duration, $a, ($f.Length / 1MB)
    & $Ffmpeg -v error -i $f.FullName -f null - ; if ($LASTEXITCODE) { throw "decode errors in $($f.Name)" }
}
# Loop seam: the last decoded frame must match the first.
$ErrorActionPreference = 'Continue'
$main = "$Out\${name}_3q_720.mp4"
& $Ffmpeg -hide_banner -loglevel error -y -i $main -vf 'select=eq(n\,0)' -frames:v 1 "$Out\seam_first.png"
& $Ffmpeg -hide_banner -loglevel error -y -sseof -0.1 -i $main -update 1 "$Out\seam_last.png"
& $Ffmpeg -hide_banner -i "$Out\seam_first.png" -i "$Out\seam_last.png" -lavfi psnr -f null - 2>&1 | Select-String 'PSNR'
