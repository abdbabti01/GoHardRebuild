# Builds the runtime Leon and Leona images (app/assets/coach/) from the source artwork in design/coach/assets/.
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-coach-art.ps1 [-Check <dir>]
# Avatars: the full square, 192 px (48 px at 3.0x with room to spare; drawn clipped to a circle, which keeps the whole
# head, ears and mane). Full body: both cropped to the same box (the union of their opaque areas, so the two keep the
# scale they were drawn at), 420 px high. Alpha below 16 is cleared first: the sources carry a faint coloured fringe
# and a hidden glow in fully transparent pixels, which bicubic sampling would otherwise drag onto the edges.
# -Check writes light and dark composites of the outputs for a visual review (not committed).
param([string]$Check)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'design\coach\assets'
$out = Join-Path $root 'app\assets\coach'
New-Item -ItemType Directory -Force $out | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Drawing2D; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class CoachArt {
  // Loads as 32bpp ARGB with alpha < min cleared to fully transparent black.
  public static Bitmap Load(string path, int min) {
    using (var raw = (Bitmap)Image.FromFile(path)) {
      var b = raw.Clone(new Rectangle(0, 0, raw.Width, raw.Height), PixelFormat.Format32bppArgb);
      var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
      var px = new byte[d.Stride * b.Height]; Marshal.Copy(d.Scan0, px, 0, px.Length);
      for (int i = 0; i < px.Length; i += 4) if (px[i + 3] < min) { px[i] = px[i + 1] = px[i + 2] = px[i + 3] = 0; }
      Marshal.Copy(px, 0, d.Scan0, px.Length); b.UnlockBits(d);
      return b;
    }
  }
  // Bounds of the pixels with any alpha left.
  public static Rectangle Opaque(Bitmap b) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var px = new byte[d.Stride * b.Height]; Marshal.Copy(d.Scan0, px, 0, px.Length); b.UnlockBits(d);
    int x0 = b.Width, y0 = b.Height, x1 = -1, y1 = -1;
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++)
      if (px[y * d.Stride + x * 4 + 3] != 0) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    return Rectangle.FromLTRB(x0, y0, x1 + 1, y1 + 1);
  }
  public static void Resize(Bitmap b, Rectangle crop, int w, int h, string path) {
    using (var o = new Bitmap(w, h, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(o))
    using (var a = new ImageAttributes()) {
      g.CompositingMode = CompositingMode.SourceCopy;
      g.CompositingQuality = CompositingQuality.HighQuality;
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      g.PixelOffsetMode = PixelOffsetMode.HighQuality;
      g.SmoothingMode = SmoothingMode.HighQuality;
      a.SetWrapMode(WrapMode.TileFlipXY); // no dark seam sampled from outside the crop
      g.DrawImage(b, new Rectangle(0, 0, w, h), crop.X, crop.Y, crop.Width, crop.Height, GraphicsUnit.Pixel, a);
      o.Save(path, ImageFormat.Png);
    }
  }
  // The outputs side by side on the app's light and dark page and sunken colours.
  public static void Sheet(string[] paths, string path) {
    var bgs = new[] { Color.FromArgb(0xF5, 0xF2, 0xEE), Color.FromArgb(0xEA, 0xE5, 0xDF), Color.FromArgb(0x16, 0x14, 0x1A), Color.FromArgb(0x2C, 0x28, 0x32) };
    var imgs = Array.ConvertAll(paths, p => Image.FromFile(p));
    int w = 0, h = 0; foreach (var i in imgs) { w += i.Width + 16; h = Math.Max(h, i.Height); }
    using (var o = new Bitmap(w + 16, (h + 16) * bgs.Length + 16))
    using (var g = Graphics.FromImage(o)) {
      for (int r = 0; r < bgs.Length; r++) {
        using (var br = new SolidBrush(bgs[r])) g.FillRectangle(br, 0, r * (h + 16), o.Width, h + 32);
        int x = 16; foreach (var i in imgs) { g.DrawImage(i, x, r * (h + 16) + 16, i.Width, i.Height); x += i.Width + 16; }
      }
      o.Save(path, ImageFormat.Png);
    }
    foreach (var i in imgs) i.Dispose();
  }
}
'@

foreach ($n in 'leon', 'leona') {
  $b = [CoachArt]::Load((Join-Path $src "$n-avatar.png"), 16)
  [CoachArt]::Resize($b, [Drawing.Rectangle]::new(0, 0, $b.Width, $b.Height), 192, 192, (Join-Path $out "$n-avatar.png"))
  $b.Dispose()
}

$full = @{}; $box = $null
foreach ($n in 'leon', 'leona') {
  $full[$n] = [CoachArt]::Load((Join-Path $src "$n-full.png"), 16)
  $r = [CoachArt]::Opaque($full[$n])
  $box = if ($box) { [Drawing.Rectangle]::Union($box, $r) } else { $r }
}
$box.Inflate(8, 8)
$box = [Drawing.Rectangle]::Intersect($box, [Drawing.Rectangle]::new(0, 0, $full['leon'].Width, $full['leon'].Height))
$h = 420; $w = [int][Math]::Round($box.Width * $h / $box.Height)
foreach ($n in 'leon', 'leona') {
  [CoachArt]::Resize($full[$n], $box, $w, $h, (Join-Path $out "$n-full.png"))
  $full[$n].Dispose()
}

Get-ChildItem $out -Filter *.png | ForEach-Object { '{0}  {1} bytes' -f $_.Name, $_.Length }
"full-body crop $box -> ${w}x$h"
if ($Check) {
  New-Item -ItemType Directory -Force $Check | Out-Null
  $names = 'leon-avatar', 'leona-avatar', 'leon-full', 'leona-full' | ForEach-Object { Join-Path $out "$_.png" }
  [CoachArt]::Sheet($names, (Join-Path $Check 'coach-check.png'))
}
