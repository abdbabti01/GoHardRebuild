import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/format.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'exercise_media.dart';

/// The demonstration area of the exercise sheet (docs/EXERCISE_DEMOS.md): a poster with an explicit Play, then a
/// muted, repeating clip with Play/Pause, Replay, 0.5× / 1× and full screen. Nothing loads until Play; one player per
/// sheet; it pauses when covered, when the app goes to the background and when the sheet closes, and is disposed then.

/// Makes the player for a clip: from the saved file when there is one, otherwise streamed from its reviewed URL.
/// Muted and mixing with other audio, so music and the app's spoken cues carry on. Tests replace it.
typedef DemoPlayerFactory = VideoPlayerController Function(DemoVideo video, File? saved);

final demoPlayerFactoryProvider = Provider<DemoPlayerFactory>((_) => (video, saved) {
      final options = VideoPlayerOptions(mixWithOthers: true);
      return saved != null ? VideoPlayerController.file(saved, videoPlayerOptions: options) : VideoPlayerController.networkUrl(video.url, videoPlayerOptions: options);
    });

/// How long a clip may take to start before the sheet says it is unavailable.
const demoStartTimeout = Duration(seconds: 20);

String _mb(AppLocalizations l, int bytes) => l.demoMegabytes(formatGrouped(bytes / 1000000));

/// The one wording for the way into the sheet, everywhere: a clip is "Watch demo", pictures only are "View guide",
/// and a movement with neither is the written guide. Never a play icon without a clip.
IconData demoIcon(ExerciseMedia? m) => m == null ? Icons.info_outline_rounded : m.isVideo ? Icons.play_circle_outline_rounded : Icons.photo_library_outlined;
String demoActionLabel(AppLocalizations l, ExerciseMedia? m) => m == null ? l.demoHowTo : m.isVideo ? l.demoWatch : l.demoViewGuide;
String demoActionFor(AppLocalizations l, ExerciseMedia? m, String name) => m == null ? l.workoutAboutSemantic(name) : m.isVideo ? l.demoWatchFor(name) : l.demoGuideFor(name);

String demoFailureText(AppLocalizations l, DemoFailure f) => switch (f) {
      DemoFailure.network => l.demoFailNetwork,
      DemoFailure.notFound => l.demoFailNotFound,
      DemoFailure.invalid => l.demoFailInvalid,
      DemoFailure.storage => l.demoFailStorage,
    };

/// A small static picture of a reviewed demonstration (its bundled poster, decoded at its own size), with a play mark
/// for a clip. With [onTap] it is a button that says what it opens; without, it is decoration beside a row's name.
class DemoThumb extends StatelessWidget {
  const DemoThumb(this.media, {super.key, this.onTap, this.semanticLabel, this.width = 56, this.height = 40});
  final ExerciseMedia media;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(alignment: Alignment.center, children: [
        Image.asset(media.poster, width: width, height: height, fit: BoxFit.cover,
            cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).ceil(), errorBuilder: (_, _, _) => SizedBox(width: width, height: height)),
        if (media.isVideo)
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
            child: Padding(padding: EdgeInsets.all(2), child: Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white)),
          ),
      ]),
    );
    if (onTap == null) return ExcludeSemantics(child: picture);
    // At least 48 x 48 to tap, whatever the picture's size.
    return Semantics(
      container: true, button: true, label: semanticLabel, onTap: onTap, excludeSemantics: true,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), child: Center(child: picture)),
      ),
    );
  }
}

/// The media area for [media]: the player for a clip, the illustration for a still, or the plain "no demonstration"
/// panel. Never implies a clip that does not exist.
class ExerciseDemoMedia extends StatelessWidget {
  const ExerciseDemoMedia({super.key, required this.media});
  final ExerciseMedia? media;

  @override
  Widget build(BuildContext context) {
    final m = media;
    if (m == null) {
      // Words only, so it takes the height they need at any text size.
      return DecoratedBox(
        key: const Key('demo-none'),
        decoration: BoxDecoration(color: context.c.sunken, borderRadius: BorderRadius.circular(Radii.field), border: Border.all(color: context.c.divider)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.videocam_off_outlined, size: 30, color: context.c.secondary),
            const SizedBox(height: 8),
            Text(context.l10n.demoNoneTitle, textAlign: TextAlign.center, style: context.sansStyle(15, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(context.l10n.demoNoneBody, textAlign: TextAlign.center, style: context.caption),
          ]),
        ),
      );
    }
    if (!m.isVideo) {
      final l = context.l10n;
      final pos = m.positions;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Frame(
          key: const Key('demo-still'),
          aspectRatio: 2,
          color: Colors.white,
          child: Semantics(
            image: true,
            label: pos == null ? l.demoPicturesOf(m.variant) : l.demoPicturesPositions(m.variant, _position(l, pos.$1), _position(l, pos.$2)),
            child: Image.asset(m.poster, fit: BoxFit.contain),
          ),
        ),
        // The two pictures sit side by side inside the one image (start on the left), so their labels stay left to
        // right in every language, each under its own picture.
        if (pos != null)
          ExcludeSemantics(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  for (final p in [pos.$1, pos.$2])
                    Expanded(child: Text(_position(l, p), key: Key('demo-position-$p'), textAlign: TextAlign.center, style: context.sansStyle(13.5, weight: FontWeight.w600))),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(l.demoPicturesOnly, style: context.caption),
      ]);
    }
    return _DemoPlayer(media: m);
  }
}

String _position(AppLocalizations l, String p) => switch (p) { 'start' => l.demoPositionStart, 'bottom' => l.demoPositionBottom, _ => l.demoPositionEnd };

/// A bounded, rounded box for the media: the movement keeps its shape (contain, never cropped), and the box never
/// takes more than about 40 % of the screen so the guide and controls stay reachable.
class _Frame extends StatelessWidget {
  const _Frame({super.key, required this.child, this.aspectRatio = 16 / 9, this.color});
  final Widget child;
  final double aspectRatio;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final maxH = (MediaQuery.sizeOf(context).height * 0.4).clamp(160.0, 360.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color ?? context.c.sunken, borderRadius: BorderRadius.circular(Radii.field), border: Border.all(color: context.c.divider)),
          child: ClipRRect(borderRadius: BorderRadius.circular(Radii.field - 1), child: Center(child: child)),
        ),
      ),
    );
  }
}

enum _Phase { poster, loading, ready, failed }

class _DemoPlayer extends ConsumerStatefulWidget {
  const _DemoPlayer({required this.media});
  final ExerciseMedia media;
  @override
  ConsumerState<_DemoPlayer> createState() => _DemoPlayerState();
}

class _DemoPlayerState extends ConsumerState<_DemoPlayer> {
  late final DemoStore _store = ref.read(demoStoreProvider);
  late final DemoPlayerFactory _make = ref.read(demoPlayerFactoryProvider);
  late final AppLifecycleListener _life = AppLifecycleListener(onHide: _pause, onPause: _pause);
  DemoVideo get _video => widget.media.video!;

  VideoPlayerController? _c;
  _Phase _phase = _Phase.poster;
  bool _fromFile = false, _fullscreen = false, _held = false;
  double _speed = 1;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _life;
    unawaited(_store.ready());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Another sheet or page over this one (Ask GoHard, Replace…): stop, unless it is our own full screen.
    if (!(ModalRoute.of(context)?.isCurrent ?? true) && !_fullscreen) _pause();
  }

  @override
  void dispose() {
    _life.dispose();
    _drop();
    super.dispose();
  }

  void _pause() {
    final c = _c;
    if (c != null && c.value.isInitialized && c.value.isPlaying) c.pause();
  }

  /// Ends the current session completely: no callback from it can reach this state afterwards.
  void _drop() {
    _timeout?.cancel();
    final c = _c;
    _c = null;
    if (c != null) {
      c.removeListener(_changed);
      c.dispose();
    }
    if (_held) _store.release(_video);
    _held = false;
  }

  void _changed() {
    final c = _c;
    if (c == null || !mounted) return;
    if (c.value.hasError && _phase != _Phase.failed) {
      _drop();
      setState(() => _phase = _Phase.failed);
      return;
    }
    setState(() {});
  }

  Future<void> _play() async {
    _drop();
    setState(() => _phase = _Phase.loading);
    final File? saved;
    try {
      saved = await _store.fileFor(_video);
    } on Object {
      if (mounted) setState(() => _phase = _Phase.failed);
      return;
    }
    if (!mounted) return;
    final c = _make(_video, saved);
    _c = c;
    _fromFile = saved != null;
    _store.hold(_video);
    _held = true;
    _timeout = Timer(demoStartTimeout, () {
      if (_c != c || !mounted || c.value.isInitialized) return;
      _drop();
      setState(() => _phase = _Phase.failed);
    });
    try {
      await c.initialize();
      if (_c != c || !mounted) return; // closed or restarted meanwhile; _drop() already disposed it
      _timeout?.cancel();
      await c.setVolume(0);
      await c.setLooping(true);
      await c.setPlaybackSpeed(_speed);
      c.addListener(_changed);
      if (_c != c || !mounted) return;
      // Covered while it loaded (or the app went away): ready, but it waits for Play.
      final visible = (ModalRoute.of(context)?.isCurrent ?? true) && WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
      if (visible) await c.play();
      if (mounted && _c == c) setState(() => _phase = _Phase.ready);
    } on Object {
      if (_c != c || !mounted) return;
      _drop();
      setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _replay() async {
    final c = _c;
    if (c == null) return;
    await c.seekTo(Duration.zero);
    await c.play();
  }

  Future<void> _setSpeed(double s) async {
    setState(() => _speed = s);
    await _c?.setPlaybackSpeed(s);
  }

  Future<void> _openFullscreen() async {
    final c = _c;
    if (c == null) return;
    setState(() => _fullscreen = true);
    await Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: context.motion(Motion.quick),
      reverseTransitionDuration: context.motion(Motion.quick),
      pageBuilder: (_, _, _) => _Fullscreen(controller: c, controls: (ctx) => _controls(ctx, onDark: true)),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
    if (mounted) setState(() => _fullscreen = false);
  }

  Future<void> _removeDownload() async {
    if (_fromFile) {
      _drop();
      setState(() => _phase = _Phase.poster);
    }
    await _store.remove(_video);
  }

  Widget _controls(BuildContext context, {bool onDark = false}) {
    final c = _c;
    final playing = c?.value.isPlaying ?? false;
    final ink = context.c.text;
    return Wrap(
      alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            key: const Key('demo-toggle'), tooltip: playing ? context.l10n.demoPause : context.l10n.demoPlay, color: ink,
            icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
            onPressed: c == null ? null : () async {
              // The player's state now, not when this was built: a background pause may have happened since.
              c.value.isPlaying ? await c.pause() : await c.play();
              if (mounted) setState(() {});
            },
          ),
          IconButton(key: const Key('demo-replay'), tooltip: context.l10n.demoReplay, color: ink, icon: const Icon(Icons.replay_rounded), onPressed: c == null ? null : _replay),
          if (!_fullscreen || onDark)
            IconButton(
              key: Key(onDark ? 'demo-exit-fullscreen' : 'demo-fullscreen'), tooltip: onDark ? context.l10n.demoExitFullscreen : context.l10n.demoFullscreen, color: ink,
              icon: Icon(onDark ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
              onPressed: c == null ? null : onDark ? () => Navigator.of(context).pop() : _openFullscreen,
            ),
        ]),
        SizedBox(
          width: 150,
          child: Segmented<double>(keyPrefix: 'demo-speed', values: const [0.5, 1], selected: _speed, label: (v) => v == 1 ? context.l10n.demoSpeedNormal : context.l10n.demoSpeedHalf, onChanged: _setSpeed),
        ),
      ],
    );
  }

  Widget _downloadLine(BuildContext context) => ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final l = context.l10n;
          final size = _mb(l, _video.bytes);
          final (IconData icon, String text, Widget? action) = switch (_store.state(_video)) {
            DemoSaved.downloaded => (Icons.download_done_rounded, l.demoDownloaded(size),
                TextButton(key: const Key('demo-remove'), onPressed: _removeDownload, child: Text(l.demoRemoveDownload))),
            DemoSaved.downloading => (Icons.downloading_rounded, l.demoDownloading(size), null),
            DemoSaved.failed => (Icons.error_outline, demoFailureText(l, _store.failure(_video)!),
                TextButton(key: const Key('demo-download'), onPressed: () => _store.download(_video).catchError((_) {}), child: Text(l.demoTryAgain))),
            DemoSaved.none => (Icons.cloud_outlined, l.demoStreams(size),
                TextButton.icon(key: const Key('demo-download'), icon: const Icon(Icons.download_rounded, size: 18),
                    onPressed: () => _store.download(_video).catchError((_) {}), label: Text(l.demoDownload))),
          };
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: context.c.secondary),
                const SizedBox(width: 6),
                Flexible(child: Text(text, key: const Key('demo-saved-state'), style: context.caption)),
              ]),
              ?action,
            ]),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final m = widget.media;
    final l = context.l10n;
    final poster = Image.asset(m.poster, fit: BoxFit.contain, semanticLabel: l.demoPosterSemantic);
    final Widget area = switch (_phase) {
      _Phase.ready when c != null && c.value.isInitialized =>
        Semantics(label: l.demoVideoSemantic, child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
      _Phase.loading => SizedBox.expand(child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(child: Opacity(opacity: 0.55, child: poster)),
          Semantics(liveRegion: true, child: _Badge(text: l.demoLoading, icon: Icons.hourglass_top_rounded)),
        ])),
      _Phase.failed => SizedBox.expand(child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(child: Opacity(opacity: 0.35, child: poster)),
          _Badge(key: const Key('demo-unavailable'), text: l.demoUnavailable, icon: Icons.videocam_off_outlined),
        ])),
      _ => SizedBox.expand(child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(child: poster),
          Semantics(
            button: true, label: l.demoPlay,
            child: Material(
              color: Colors.black.withValues(alpha: 0.6), shape: const CircleBorder(),
              child: InkWell(
                key: const Key('demo-play'), customBorder: const CircleBorder(), onTap: _play,
                child: const SizedBox(width: 64, height: 64, child: Icon(Icons.play_arrow_rounded, size: 40, color: Colors.white)),
              ),
            ),
          ),
        ])),
    };
    return Column(key: const Key('demo-player'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Frame(aspectRatio: _video.aspectRatio, color: Colors.black, child: area),
      if (_phase == _Phase.ready) Padding(padding: const EdgeInsets.only(top: 4), child: _controls(context)),
      if (_phase == _Phase.failed) ...[
        const SizedBox(height: 8),
        Text(
          _fromFile ? l.demoSavedFailed : l.demoStreamFailed,
          style: context.caption,
        ),
        Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(key: const Key('demo-retry'), onPressed: _play, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(l.demoRetry))),
      ],
      if (_phase == _Phase.ready) Text(l.demoMuted, style: context.caption),
      _downloadLine(context),
    ]);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: context.sansStyle(14, weight: FontWeight.w600, color: Colors.white))),
        ]),
      );
}

/// Full screen shows the SAME player (one session, same position). System bars and orientation are left as they are,
/// so returning needs no restoring.
class _Fullscreen extends StatefulWidget {
  const _Fullscreen({required this.controller, required this.controls});
  final VideoPlayerController controller;
  final WidgetBuilder controls;
  @override
  State<_Fullscreen> createState() => _FullscreenState();
}

class _FullscreenState extends State<_Fullscreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_tick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: const Key('demo-fullscreen-page'),
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(tooltip: context.l10n.demoCloseFullscreen, color: Colors.white, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
            ),
            Expanded(
              child: Center(
                child: widget.controller.value.isInitialized
                    ? AspectRatio(aspectRatio: widget.controller.value.aspectRatio, child: VideoPlayer(widget.controller))
                    : const SizedBox.shrink(),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(Radii.field)),
              child: widget.controls(context),
            ),
          ]),
        ),
      );
}
