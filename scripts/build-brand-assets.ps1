# Builds every app icon, launch image and in-app brand image from the masters in design/brand/ (docs/BRANDING.md).
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-brand-assets.ps1 [-Check <dir>]
# Masters (never edited):
#   original-ios-app-icon-1024.png  GoHardAPP's original iOS icon: the metallic GH/lightning on a black rounded badge,
#                                   with outer black padding. Opaque RGB.
#   gh-mark-mono.png                the rebuild's transparent one-colour GH mark (same shape), on a wide empty canvas.
# Exports:
#   App icons (iOS catalog, Android legacy + adaptive): the whole master, uncropped, as the original app shipped it.
#     iOS 1024 is a byte copy of the master; the rest are bicubic downscales, saved without alpha.
#     Android adaptive foreground: the master at 72 of 108 dp (the visible viewport) over a black background, so every
#     launcher mask (circle, squircle, square) shows the whole badge and never cuts the GH.
#   Badge (launch screens, sign-in): the badge alone. Uniform crop to its outer frame, BadgeBox below, and the corners
#     outside its own rounded frame made transparent (anti-aliased rounded rectangle, BadgeRadius), so it sits on the
#     warm-light or dark launch colour without a black square around it. Nothing inside the frame changes.
#   Mono mark: the mono master cropped to its visible pixels (lossless), so a height sizes the glyph itself.
# -Check writes the badge and icon on light and dark backgrounds for a visual review (not committed).
param([string]$Check)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'design\brand'
$app = Join-Path $root 'app'
$master = Join-Path $src 'original-ios-app-icon-1024.png'

Add-Type -AssemblyName System.Drawing
# Measured on the 1024 px master: the frame's grey stroke spans x 192-832, y 196-808; its corners are ~78 px arcs.
$BadgeBox = [Drawing.Rectangle]::new(192, 196, 640, 612)
$BadgeRadius = 80

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Drawing2D; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class BrandArt {
  static Graphics Hq(Bitmap o) {
    var g = Graphics.FromImage(o);
    g.CompositingQuality = CompositingQuality.HighQuality;
    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
    g.SmoothingMode = SmoothingMode.AntiAlias;
    return g;
  }
  static void Draw(Graphics g, Image b, Rectangle crop, Rectangle to) {
    using (var a = new ImageAttributes()) {
      a.SetWrapMode(WrapMode.TileFlipXY); // no seam sampled from outside the crop
      g.DrawImage(b, to, crop.X, crop.Y, crop.Width, crop.Height, GraphicsUnit.Pixel, a);
    }
  }
  // The whole image, opaque, no alpha channel (iOS rejects icons with one).
  public static void Opaque(Image b, int size, string path) {
    using (var o = new Bitmap(size, size, PixelFormat.Format24bppRgb))
    using (var g = Hq(o)) { Draw(g, b, new Rectangle(0, 0, b.Width, b.Height), new Rectangle(0, 0, size, size)); o.Save(path, ImageFormat.Png); }
  }
  // The whole image at [inner] px, centred on a transparent [size] px canvas.
  public static void Inset(Image b, int size, int inner, string path) {
    using (var o = new Bitmap(size, size, PixelFormat.Format32bppArgb))
    using (var g = Hq(o)) { int p = (size - inner) / 2; Draw(g, b, new Rectangle(0, 0, b.Width, b.Height), new Rectangle(p, p, inner, inner)); o.Save(path, ImageFormat.Png); }
  }
  // [crop] scaled to [w] x [h], kept only inside a rounded rectangle of [radius] (in source pixels).
  public static void Rounded(Image b, Rectangle crop, double radius, int w, int h, string path) {
    using (var full = new Bitmap(w, h, PixelFormat.Format32bppArgb))
    using (var o = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
      using (var g = Hq(full)) Draw(g, b, crop, new Rectangle(0, 0, w, h));
      using (var g = Hq(o))
      using (var brush = new TextureBrush(full))
      using (var path2 = new GraphicsPath()) {
        float d = (float)(2 * radius * w / crop.Width);
        path2.AddArc(0, 0, d, d, 180, 90); path2.AddArc(w - d, 0, d, d, 270, 90);
        path2.AddArc(w - d, h - d, d, d, 0, 90); path2.AddArc(0, h - d, d, d, 90, 90); path2.CloseFigure();
        g.FillPath(brush, path2);
      }
      o.Save(path, ImageFormat.Png);
    }
  }
  // Bounds of the pixels with any alpha.
  public static Rectangle Visible(Bitmap b) {
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var px = new byte[d.Stride * b.Height]; Marshal.Copy(d.Scan0, px, 0, px.Length); b.UnlockBits(d);
    int x0 = b.Width, y0 = b.Height, x1 = -1, y1 = -1;
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++)
      if (px[y * d.Stride + x * 4 + 3] != 0) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    return Rectangle.FromLTRB(x0, y0, x1 + 1, y1 + 1);
  }
  public static void Crop(Bitmap b, Rectangle r, string path) { using (var o = b.Clone(r, PixelFormat.Format32bppArgb)) o.Save(path, ImageFormat.Png); }
  // The images side by side on the app's light and dark launch colours.
  public static void Sheet(string[] paths, string path) {
    var bgs = new[] { Color.FromArgb(0xF6, 0xF6, 0xF4), Color.FromArgb(0x10, 0x11, 0x14) };
    var imgs = Array.ConvertAll(paths, p => Image.FromFile(p));
    int w = 0, h = 0; foreach (var i in imgs) { w += i.Width + 16; h = Math.Max(h, i.Height); }
    using (var o = new Bitmap(w + 16, (h + 32) * bgs.Length))
    using (var g = Graphics.FromImage(o)) {
      for (int r = 0; r < bgs.Length; r++) {
        using (var br = new SolidBrush(bgs[r])) g.FillRectangle(br, 0, r * (h + 32), o.Width, h + 32);
        int x = 16; foreach (var i in imgs) { g.DrawImage(i, x, r * (h + 32) + 16, i.Width, i.Height); x += i.Width + 16; }
      }
      o.Save(path, ImageFormat.Png);
    }
    foreach (var i in imgs) i.Dispose();
  }
}
'@

$m = [Drawing.Image]::FromFile($master)
try {
  # iOS: every image the catalog lists, at its pixel size.
  $set = Join-Path $app 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
  foreach ($i in (Get-Content -Raw (Join-Path $set 'Contents.json') | ConvertFrom-Json).images) {
    $px = [int]([double]($i.size -split 'x')[0] * [double]($i.scale -replace 'x', ''))
    $to = Join-Path $set $i.filename
    if ($px -eq 1024) { Copy-Item $master $to -Force } else { [BrandArt]::Opaque($m, $px, $to) }
  }

  # Android: legacy icons (48 dp) and the adaptive foreground (108 dp, badge in the central 72 dp).
  $res = Join-Path $app 'android\app\src\main\res'
  $dens = [ordered]@{ mdpi = 1.0; hdpi = 1.5; xhdpi = 2.0; xxhdpi = 3.0; xxxhdpi = 4.0 }
  foreach ($d in $dens.Keys) {
    $s = $dens[$d]
    [BrandArt]::Opaque($m, [int](48 * $s), (Join-Path $res "mipmap-$d\ic_launcher.png"))
    [BrandArt]::Inset($m, [int](108 * $s), [int](72 * $s), (Join-Path $res "mipmap-$d\ic_launcher_foreground.png"))
  }

  # The badge: 112 pt wide on the launch screens, up to 64 dp in the app.
  $w = 112; $h = [int][Math]::Round($w * $BadgeBox.Height / $BadgeBox.Width)
  $launch = Join-Path $app 'ios\Runner\Assets.xcassets\LaunchImage.imageset'
  [BrandArt]::Rounded($m, $BadgeBox, $BadgeRadius, $w, $h, (Join-Path $launch 'LaunchImage.png'))
  [BrandArt]::Rounded($m, $BadgeBox, $BadgeRadius, 2 * $w, 2 * $h, (Join-Path $launch 'LaunchImage@2x.png'))
  [BrandArt]::Rounded($m, $BadgeBox, $BadgeRadius, 3 * $w, 3 * $h, (Join-Path $launch 'LaunchImage@3x.png'))
  foreach ($d in $dens.Keys) {
    $s = $dens[$d]; $dir = Join-Path $res "drawable-$d"
    New-Item -ItemType Directory -Force $dir | Out-Null
    [BrandArt]::Rounded($m, $BadgeBox, $BadgeRadius, [int]($w * $s), [int][Math]::Round($h * $s), (Join-Path $dir 'launch_badge.png'))
  }
  [BrandArt]::Rounded($m, $BadgeBox, $BadgeRadius, 192, [int][Math]::Round(192 * $BadgeBox.Height / $BadgeBox.Width), (Join-Path $app 'assets\images\gohard-badge.png'))
} finally { $m.Dispose() }

$mono = [Drawing.Bitmap]::FromFile((Join-Path $src 'gh-mark-mono.png'))
try {
  $v = [BrandArt]::Visible($mono)
  [BrandArt]::Crop($mono, $v, (Join-Path $app 'assets\images\evening-gh-mark.png'))
  "mono mark crop $v"
} finally { $mono.Dispose() }

"badge crop $BadgeBox radius $BadgeRadius -> ${w}x$h pt"
if ($Check) {
  New-Item -ItemType Directory -Force $Check | Out-Null
  [BrandArt]::Sheet(@((Join-Path $app 'assets\images\gohard-badge.png'), (Join-Path $launch 'LaunchImage@2x.png'), (Join-Path $res 'mipmap-xxxhdpi\ic_launcher.png'), (Join-Path $app 'assets\images\evening-gh-mark.png')), (Join-Path $Check 'brand-check.png'))
}
