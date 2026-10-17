import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme.dart';
import 'track_math.dart';

/// Whether this build has a Google Maps key (native channel `gohard/maps`). Without one, or in tests, the route is
/// drawn without a basemap. Map trouble never touches recording (docs/RUN_WALK.md › Map).
final mapsAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return await const MethodChannel('gohard/maps').invokeMethod<bool>('configured') ?? false;
  } on Object {
    return false;
  }
});

/// The current position: the dot and its accuracy circle.
typedef Here = ({double lat, double lon, double acc});

/// The route, the current position and the camera. Presentation only: it never starts location, and it draws only
/// recorded points (the live line ends at the newest accepted fix).
///
/// Camera: [live] starts in Follow. Any pinch, pan, double-tap or zoom button switches to Free, which new fixes leave
/// alone, until Recenter (Follow again) or Fit route (the whole route once, then Free). Gestures are claimed by the
/// map, so they never scroll the page or drag a sheet.
class RouteMap extends ConsumerStatefulWidget {
  const RouteMap({super.key, required this.segments, this.here, this.live = false, this.controls = false, this.zoomButtons = false,
      this.highlight, this.overlayPadding = EdgeInsets.zero, this.onExpand, this.semanticLabel = 'Route map'});
  final List<List<TrackPoint>> segments;
  final Here? here;
  final bool live, controls, zoomButtons;

  /// A distance range (metres) drawn over the route: the selected split.
  final (double, double)? highlight;

  /// Space covered by the page's own overlays, kept clear of Google's logo and notices.
  final EdgeInsets overlayPadding;
  final VoidCallback? onExpand;
  final String semanticLabel;

  @override
  ConsumerState<RouteMap> createState() => _RouteMapState();
}

enum _Camera { follow, free }

class _RouteMapState extends ConsumerState<RouteMap> {
  late _Camera _camera = widget.live ? _Camera.follow : _Camera.free;
  GoogleMapController? _google;
  final _sketch = TransformationController();
  bool _touching = false;
  Size _size = Size.zero;

  List<TrackPoint> get _all => [for (final s in widget.segments) ...s];

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    final here = widget.here;
    if (_camera == _Camera.follow && here != null && (old.here?.lat != here.lat || old.here?.lon != here.lon)) _follow(here);
  }

  @override
  void dispose() {
    _sketch.dispose();
    super.dispose();
  }

  /// Whether the camera has been brought from the whole-world start to street level yet.
  bool _framed = false;

  void _follow(Here here) {
    // The map starts on the whole world when no position is known yet; the first position frames it at street level,
    // later ones only move it, keeping the zoom the person chose.
    _google?.animateCamera(_framed ? CameraUpdate.newLatLng(LatLng(here.lat, here.lon)) : CameraUpdate.newLatLngZoom(LatLng(here.lat, here.lon), 16)).ignore();
    if (_google != null) _framed = true;
    if (_google == null) _centerSketch(here.lat, here.lon);
  }

  void _release() {
    if (_camera != _Camera.free) setState(() => _camera = _Camera.free);
  }

  void _recenter() {
    setState(() => _camera = _Camera.follow);
    final here = widget.here ?? (_all.isEmpty ? null : (lat: _all.last.lat, lon: _all.last.lon, acc: 0.0));
    if (here != null) _follow(here);
  }

  void _fit() {
    _release();
    final pts = _all;
    if (_google != null && pts.isNotEmpty) {
      _google!.animateCamera(CameraUpdate.newLatLngBounds(_bounds(pts), 48)).ignore();
    } else {
      _sketch.value = Matrix4.identity();
    }
  }

  void _zoom(bool zoomIn) {
    _release();
    if (_google != null) {
      _google!.animateCamera(zoomIn ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut()).ignore();
    } else {
      final s = _sketch.value.getMaxScaleOnAxis();
      final next = (zoomIn ? s * 1.6 : s / 1.6).clamp(1.0, 40.0);
      final c = Offset(_size.width / 2, _size.height / 2);
      final scene = _sketch.toScene(c);
      _sketch.value = Matrix4.identity()
        ..translateByDouble(c.dx - scene.dx * next, c.dy - scene.dy * next, 0, 1)
        ..scaleByDouble(next, next, 1, 1);
    }
  }

  static LatLngBounds _bounds(List<TrackPoint> pts) {
    var (s, w, n, e) = (90.0, 180.0, -90.0, -180.0);
    for (final p in pts) {
      (s, w, n, e) = (min(s, p.lat), min(w, p.lon), max(n, p.lat), max(e, p.lon));
    }
    return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
  }

  // ------------------------------------------------------------------ the drawn route (no basemap)

  void _centerSketch(double lat, double lon) {
    final proj = _Projection.of(_all, widget.here, _size);
    if (proj == null) return;
    final p = proj.toOffset(lat, lon);
    final s = max(2.0, _sketch.value.getMaxScaleOnAxis());
    _sketch.value = Matrix4.identity()
      ..translateByDouble(_size.width / 2 - p.dx * s, _size.height / 2 - p.dy * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  Widget _drawn(BuildContext context) => LayoutBuilder(builder: (context, box) {
        _size = box.biggest;
        final painter = CustomPaint(
          size: box.biggest,
          painter: _RoutePainter(segments: widget.segments, here: widget.here, highlight: widget.highlight, line: context.c.accent, glow: context.c.tint,
              hereColor: const Color(0xFF2F7BF6), ground: context.c.sunken, grid: context.c.divider, size: box.biggest),
        );
        if (!widget.controls) return painter;
        return GestureDetector(
          onDoubleTapDown: (d) {
            _release();
            final s = (_sketch.value.getMaxScaleOnAxis() * 2).clamp(1.0, 40.0);
            final scene = _sketch.toScene(d.localPosition);
            _sketch.value = Matrix4.identity()
              ..translateByDouble(d.localPosition.dx - scene.dx * s, d.localPosition.dy - scene.dy * s, 0, 1)
              ..scaleByDouble(s, s, 1, 1);
          },
          onDoubleTap: () {},
          child: InteractiveViewer(
            transformationController: _sketch, minScale: 1, maxScale: 40, onInteractionStart: (_) => _release(),
            child: painter,
          ),
        );
      });

  // ------------------------------------------------------------------ Google Maps

  Widget _googleMap(BuildContext context) {
    final pts = _all;
    final here = widget.here;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hl = widget.highlight;
    final target = here != null ? LatLng(here.lat, here.lon) : pts.isNotEmpty ? LatLng(pts.last.lat, pts.last.lon) : const LatLng(0, 0);
    return Listener(
      onPointerDown: (_) => _touching = true,
      onPointerUp: (_) => _touching = false,
      onPointerCancel: (_) => _touching = false,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: target, zoom: here == null && pts.isEmpty ? 1 : 16),
        style: dark ? _darkStyle : null,
        padding: widget.overlayPadding,
        myLocationEnabled: false, myLocationButtonEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false,
        compassEnabled: widget.controls, rotateGesturesEnabled: widget.controls, tiltGesturesEnabled: false,
        scrollGesturesEnabled: widget.controls, zoomGesturesEnabled: widget.controls,
        gestureRecognizers: widget.controls ? {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)} : const {},
        onMapCreated: (c) {
          _google = c;
          _framed = here != null || pts.isNotEmpty; // created already at street level
          if (!_framed && widget.here != null) _follow(widget.here!);
          if (!widget.live && pts.length > 1) {
            // A saved route opens fitted; give the map a frame to know its size.
            Future<void>.delayed(const Duration(milliseconds: 200), () => mounted ? c.moveCamera(CameraUpdate.newLatLngBounds(_bounds(pts), 40)) : null).ignore();
          }
        },
        onCameraMoveStarted: () {
          if (_touching) _release();
        },
        polylines: {
          for (final (i, s) in widget.segments.indexed)
            if (s.length > 1)
              Polyline(polylineId: PolylineId('s$i'), points: [for (final p in s) LatLng(p.lat, p.lon)], width: 6, color: context.c.accent, jointType: JointType.round),
          if (hl != null)
            for (final (i, s) in widget.segments.indexed)
              if (s.where((p) => p.dist >= hl.$1 && p.dist <= hl.$2).length > 1)
                Polyline(polylineId: PolylineId('h$i'), zIndex: 2, width: 9, color: const Color(0xFFF2B33D),
                    points: [for (final p in s) if (p.dist >= hl.$1 && p.dist <= hl.$2) LatLng(p.lat, p.lon)]),
        },
        circles: {
          if (here != null) ...{
            Circle(circleId: const CircleId('acc'), center: LatLng(here.lat, here.lon), radius: here.acc, strokeWidth: 1,
                strokeColor: const Color(0x662F7BF6), fillColor: const Color(0x222F7BF6)),
            Circle(circleId: const CircleId('here'), center: LatLng(here.lat, here.lon), radius: 4, zIndex: 3, strokeWidth: 3,
                strokeColor: Colors.white, fillColor: const Color(0xFF2F7BF6)),
          },
          if (!widget.live && pts.isNotEmpty) ...{
            Circle(circleId: const CircleId('start'), center: LatLng(pts.first.lat, pts.first.lon), radius: 6, zIndex: 3, strokeWidth: 3, strokeColor: Colors.white, fillColor: context.c.accent),
            Circle(circleId: const CircleId('end'), center: LatLng(pts.last.lat, pts.last.lon), radius: 6, zIndex: 3, strokeWidth: 3, strokeColor: Colors.white, fillColor: const Color(0xFF222222)),
          },
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maps = ref.watch(mapsAvailableProvider).value ?? false;
    final buttons = <Widget>[
      if (widget.controls && widget.live) _MapButton(Icons.my_location, _camera == _Camera.follow ? 'Following your position' : 'Recenter', _recenter, key: const Key('map-recenter'), on: _camera == _Camera.follow),
      if (widget.controls && _all.length > 1) _MapButton(Icons.fit_screen_outlined, 'Fit route', _fit, key: const Key('map-fit')),
      if (widget.zoomButtons) ...[
        _MapButton(Icons.add, 'Zoom in', () => _zoom(true), key: const Key('map-zoom-in')),
        _MapButton(Icons.remove, 'Zoom out', () => _zoom(false), key: const Key('map-zoom-out')),
      ],
    ];
    return Semantics(
      label: widget.semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.panel),
        child: Stack(children: [
          Positioned.fill(child: maps ? _googleMap(context) : _drawn(context)),
          if (!maps)
            Positioned(
              left: 10, bottom: 8 + widget.overlayPadding.bottom,
              child: ExcludeSemantics(child: Text('Route drawn without a map', style: context.sansStyle(11.5, color: context.c.secondary))),
            ),
          if (widget.onExpand != null)
            Positioned(top: 8, right: 8, child: _MapButton(Icons.open_in_full, 'Expand map', widget.onExpand!, key: const Key('map-expand'), label: true)),
          if (buttons.isNotEmpty)
            Positioned(
              right: 8, bottom: 8 + widget.overlayPadding.bottom,
              child: Column(mainAxisSize: MainAxisSize.min, children: [for (final b in buttons) Padding(padding: const EdgeInsets.only(top: 8), child: b)]),
            ),
        ]),
      ),
    );
  }
}

/// A round map control, 48 px, labelled for screen readers.
class _MapButton extends StatelessWidget {
  const _MapButton(this.icon, this.tooltip, this.onPressed, {super.key, this.label = false, this.on = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool label, on;

  @override
  Widget build(BuildContext context) {
    final fg = on ? GoColors.panelOf(context.c).text : context.c.text;
    final child = label
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: fg), const SizedBox(width: 8), Text(tooltip, style: context.sansStyle(14, weight: FontWeight.w600, color: fg))]),
          )
        : Icon(icon, size: 22, color: fg);
    return Semantics(
      button: true, label: tooltip, toggled: on ? true : null,
      child: ExcludeSemantics(
        child: Material(
          color: on ? context.c.tint : context.c.surface.withValues(alpha: 0.94), shape: StadiumBorder(side: BorderSide(color: context.c.divider)),
          child: InkWell(
            customBorder: const StadiumBorder(), onTap: onPressed,
            child: ConstrainedBox(constraints: const BoxConstraints(minWidth: Targets.minimum, minHeight: Targets.minimum), child: Center(widthFactor: 1, child: child)),
          ),
        ),
      ),
    );
  }
}

/// Equirectangular projection of a small area into a box, fitted with a margin. Enough for a run or a walk.
class _Projection {
  _Projection(this._k, this.scale, this.offset);
  final double _k, scale;
  final Offset offset;
  static const _m = 111320.0;

  static _Projection? of(List<TrackPoint> pts, Here? here, Size size) {
    final lats = [for (final p in pts) p.lat, if (here != null) here.lat], lons = [for (final p in pts) p.lon, if (here != null) here.lon];
    if (lats.isEmpty || size.isEmpty) return null;
    final lat0 = lats.reduce((a, b) => a + b) / lats.length;
    final k = cos(lat0 * pi / 180);
    var (minX, maxX, minY, maxY) = (double.infinity, -double.infinity, double.infinity, -double.infinity);
    for (var i = 0; i < lats.length; i++) {
      final x = lons[i] * k * _m, y = -lats[i] * _m;
      (minX, maxX, minY, maxY) = (min(minX, x), max(maxX, x), min(minY, y), max(maxY, y));
    }
    // At least 250 m across, so a lone position or a short route is not blown up.
    final w = max(250.0, maxX - minX), h = max(250.0, maxY - minY);
    final scale = min((size.width - 48) / w, (size.height - 48) / h);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    return _Projection(k, scale, Offset(size.width / 2 - cx * scale, size.height / 2 - cy * scale));
  }

  Offset toOffset(double lat, double lon) => Offset(lon * _k * _m * scale, -lat * _m * scale) + offset;
  double meters(double m) => m * scale;
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.segments, required this.here, required this.highlight, required this.line, required this.glow,
      required this.hereColor, required this.ground, required this.grid, required this.size});
  final List<List<TrackPoint>> segments;
  final Here? here;
  final (double, double)? highlight;
  final Color line, glow, hereColor, ground, grid;
  final Size size;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final proj = _Projection.of([for (final s in segments) ...s], here, size);
    if (proj == null) return;
    Path path(Iterable<TrackPoint> pts) {
      final p = Path();
      for (final (i, t) in pts.indexed) {
        final o = proj.toOffset(t.lat, t.lon);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in segments) {
      if (s.length < 2) continue;
      canvas.drawPath(path(s), stroke(glow, 9));
      canvas.drawPath(path(s), stroke(line, 4.5));
    }
    final hl = highlight;
    if (hl != null) {
      for (final s in segments) {
        final part = s.where((p) => p.dist >= hl.$1 && p.dist <= hl.$2);
        if (part.length > 1) canvas.drawPath(path(part), stroke(const Color(0xFFF2B33D), 6));
      }
    }
    final h = here;
    if (h != null) {
      final o = proj.toOffset(h.lat, h.lon);
      canvas.drawCircle(o, max(8, proj.meters(h.acc)), Paint()..color = hereColor.withValues(alpha: 0.16));
      canvas.drawCircle(o, 8, Paint()..color = Colors.white);
      canvas.drawCircle(o, 5.5, Paint()..color = hereColor);
    } else if (segments.isNotEmpty && segments.first.isNotEmpty) {
      final a = segments.first.first, b = segments.last.last;
      canvas.drawCircle(proj.toOffset(a.lat, a.lon), 6, Paint()..color = line);
      canvas.drawCircle(proj.toOffset(b.lat, b.lon), 6, Paint()..color = const Color(0xFF222222));
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => true;
}

/// A small, non-interactive route drawing for history rows: no map, no gestures, no location.
class RouteThumb extends StatelessWidget {
  const RouteThumb({super.key, required this.segments, this.size = 56});
  final List<List<TrackPoint>> segments;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            size: Size.square(size),
            painter: _RoutePainter(segments: segments, here: null, highlight: null, line: context.c.accent, glow: context.c.tint,
                hereColor: context.c.accent, ground: context.c.sunken, grid: Colors.transparent, size: Size.square(size)),
          ),
        ),
      );
}

/// A muted dark map style, so the route reads in the Dark looks.
const _darkStyle = '[{"elementType":"geometry","stylers":[{"color":"#1f2124"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#9aa0a6"}]},'
    '{"elementType":"labels.text.stroke","stylers":[{"color":"#1f2124"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#33363b"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1d3324"}]}]';
