param([string]$Dir, [string]$Out, [double[]]$Fractions = @(0.1, 0.35, 0.6, 0.85), [int]$Width = 480)
# Extracts frames from every clip in $Dir as JPEGs (WinRT MediaComposition; no ffmpeg on this machine).
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Editing.MediaComposition, Windows.Media.Editing, ContentType = WindowsRuntime]
$null = [Windows.Media.Editing.MediaClip, Windows.Media.Editing, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$t) { $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
New-Item -ItemType Directory -Force $Out | Out-Null
foreach ($f in Get-ChildItem $Dir -File) {
  try {
    $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($f.FullName)) ([Windows.Storage.StorageFile])
    $clip = Await ([Windows.Media.Editing.MediaClip]::CreateFromFileAsync($file)) ([Windows.Media.Editing.MediaClip])
    $comp = New-Object Windows.Media.Editing.MediaComposition
    $list = $comp.Clips
    [System.Collections.Generic.ICollection[Windows.Media.Editing.MediaClip]].GetMethod('Add').Invoke($list, @($clip))
    $dur = $clip.OriginalDuration
    $i = 0
    foreach ($fr in $Fractions) {
      $at = [TimeSpan]::FromTicks([long]($dur.Ticks * $fr))
      $stream = Await ($comp.GetThumbnailAsync($at, $Width, 0, [Windows.Media.Editing.VideoFramePrecision]::NearestFrame)) ([Windows.Graphics.Imaging.ImageStream])
      $net = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
      $fs = [System.IO.File]::Create((Join-Path $Out ("{0}_{1}.jpg" -f $f.BaseName, $i)))
      $net.CopyTo($fs); $fs.Close(); $i++
    }
    "{0}: {1:N2}s ok" -f $f.Name, $dur.TotalSeconds
  } catch { "{0}: FAILED {1}" -f $f.Name, ($_.Exception.ToString()) }
}
