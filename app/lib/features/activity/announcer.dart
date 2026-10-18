/// The one announcement system (docs/RUN_WALK.md › Voice and alerts): structured local events (an interval phase, a
/// distance or time update, a personal best) go through one policy to the coach's words on screen, the phone's own
/// speech and, for phase changes, a vibration. Nothing here calls the AI, a cloud voice or the network: the words are
/// fixed and filled from the recorder's own numbers, and the voice is one installed on the phone.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../app/providers.dart' show ownerProvider, clockProvider;
import '../../core/device_prefs.dart';
import '../../core/format.dart' show clockText;
import '../../core/units.dart';
import '../coach/coach_avatar.dart';
import '../coach/coach_prefs.dart';
import 'intervals.dart';
import 'move_prefs.dart';
import 'steps.dart';

/// One thing to say. [key] makes it unique (an activity's phase 4, its 3rd km): the same key is never said twice,
/// whatever rebuilds, GPS batches, sync or restarts happen. Higher [priority] wins: interval prompts (3) over a
/// personal best (2) over routine updates (1).
@immutable
class Cue {
  const Cue(this.text, {required this.key, required this.priority, this.spoken, this.vibrate = false});
  final String text, key;
  final String? spoken;
  final int priority;
  final bool vibrate;

  static const phase = 3, record = 2, update = 1;
}

/// A voice installed on the phone.
typedef VoiceOption = ({String name, String locale});

/// The phone's speech. Tests replace it.
abstract class VoiceOut {
  Future<void> speak(String text, {VoiceOption? voice, required double pitch});
  Future<void> stop();
  Future<List<VoiceOption>> voices();
}

/// flutter_tts: AVSpeechSynthesizer on iOS, TextToSpeech on Android. Other audio is lowered (ducked) while speaking
/// and restored after: on iOS the shared session is deactivated with notify-others when an utterance ends, on Android
/// transient may-duck audio focus is requested and abandoned. Music is never stopped for it.
class TtsVoiceOut implements VoiceOut {
  FlutterTts? _tts;

  Future<FlutterTts> _ready() async {
    if (_tts != null) return _tts!;
    final t = FlutterTts();
    await t.awaitSpeakCompletion(true);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await t.setSharedInstance(true);
      await t.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers, IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers], IosTextToSpeechAudioMode.voicePrompt);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await t.setAudioAttributesForNavigation();
    }
    await t.setSpeechRate(0.5);
    return _tts = t;
  }

  @override
  Future<void> speak(String text, {VoiceOption? voice, required double pitch}) async {
    final t = await _ready();
    if (voice != null) {
      await t.setVoice({'name': voice.name, 'locale': voice.locale});
    } else {
      await t.clearVoice();
    }
    await t.setPitch(pitch);
    await t.speak(text, focus: true);
  }

  @override
  Future<void> stop() async {
    await _tts?.stop();
  }

  @override
  Future<List<VoiceOption>> voices() async => offlineVoices(await (await _ready()).getVoices);
}

/// The installed voices that speak without a connection. Android marks a voice that needs the network
/// (`network_required: "1"`); those are never offered, so an update is never silent for want of signal. iOS voices are
/// on the phone and carry no such flag.
List<VoiceOption> offlineVoices(Object? raw) => [
      for (final v in (raw as List? ?? const []))
        if (v is Map && v['name'] is String && v['locale'] is String && '${v['network_required']}' != '1') (name: v['name'] as String, locale: v['locale'] as String),
    ];

final voiceOutProvider = Provider<VoiceOut>((ref) => TtsVoiceOut());

/// Leon a little lower, Leona a little higher, in whichever voice is chosen: the same coach every time.
double coachPitch(CoachGuide g) => g == CoachGuide.leon ? 0.92 : 1.08;

/// What the coach is saying now, for the screen (the bubble or the recording's coach line), plus the speech queue.
class Announcer extends Notifier<Cue?> {
  final _said = <String>{};
  Cue? _speaking, _queued;
  DateTime? _queuedAt;
  Timer? _hide;
  int _epoch = 0;

  /// The offline-capable voices, read once.
  List<VoiceOption>? _offline;

  /// How long words stay on screen.
  static const showFor = Duration(seconds: 10);

  /// A queued cue older than this is dropped instead of spoken late.
  static const staleAfter = Duration(seconds: 8);

  @override
  Cue? build() {
    ref.watch(ownerProvider); // another account: nothing carries over, speech stops
    final voice = ref.read(voiceOutProvider);
    ref.onDispose(() {
      _hide?.cancel();
      _epoch++;
      voice.stop().ignore();
    });
    return null;
  }

  VoiceOut get _voice => ref.read(voiceOutProvider);

  /// Whether [key] was already said.
  bool said(String key) => _said.contains(key);

  /// Marks keys as said without saying them: what was due before a restart, or before this recorder took the activity
  /// over, is never poured out on resume.
  void prime(Iterable<String> keys) => _said.addAll(keys);

  void say(Cue c) {
    if (!_said.add(c.key)) return;
    state = c;
    _hide?.cancel();
    _hide = Timer(showFor, () {
      if (ref.mounted && state == c) state = null;
    });
    if (c.vibrate && ref.read(movePrefsProvider).vibrate && ref.read(devicePrefsProvider).haptics == HapticsPref.device) {
      HapticFeedback.heavyImpact();
      ref.read(stepSourceProvider).vibrate().ignore();
    }
    if (!ref.read(movePrefsProvider).voice) return;
    final now = ref.read(clockProvider).utcNow();
    final cur = _speaking;
    if (cur != null) {
      if (c.priority > cur.priority) {
        _cut();
      } else {
        _queued = c;
        _queuedAt = now;
        return;
      }
    }
    _speak(c).ignore();
  }

  /// A short countdown tick before a phase change (no words).
  void tick() {
    if (ref.read(movePrefsProvider).vibrate) Haptics.selection();
  }

  void _cut() {
    _epoch++;
    _speaking = null;
    _voice.stop().ignore();
  }

  Future<void> _speak(Cue c) async {
    final epoch = ++_epoch;
    _speaking = c;
    final p = ref.read(movePrefsProvider);
    var voice = p.voiceName == null || p.voiceLocale == null ? null : (name: p.voiceName!, locale: p.voiceLocale!);
    // Only a voice that speaks offline; one chosen earlier that is gone or needs a connection gives way to the phone's own.
    if (voice != null) {
      try {
        _offline ??= await _voice.voices();
      } on Object {
        _offline = const [];
      }
      if (!_offline!.contains(voice)) voice = null;
    }
    try {
      await _voice.speak(c.spoken ?? c.text, voice: voice, pitch: coachPitch(ref.read(coachPrefsProvider).guide));
    } on Object {
      // No speech engine, or it failed: the words are on screen.
    }
    if (!ref.mounted || epoch != _epoch) return;
    _speaking = null;
    final q = _queued, at = _queuedAt;
    _queued = null;
    if (q != null && at != null && ref.read(clockProvider).utcNow().difference(at) < staleAfter) _speak(q).ignore();
  }

  /// Pause, finish, discard, an interruption: whatever is queued is obsolete and speech stops now.
  void cancel() {
    _queued = null;
    _hide?.cancel();
    if (state != null) state = null;
    _cut();
  }

  /// Voice preview, from Voice and alerts. Not an announcement: never deduplicated or queued.
  Future<void> preview(CoachGuide guide, VoiceOption? voice) async {
    _cut();
    try {
      await _voice.speak('Hi, I\'m ${guide.label}. I\'ll tell you when to run, when to walk, and how far you\'ve gone.', voice: voice, pitch: coachPitch(guide));
    } on Object {
      // Nothing to preview with on this phone.
    }
  }
}

final announcerProvider = NotifierProvider<Announcer, Cue?>(Announcer.new);

// ---------------------------------------------------------------------------- cues from a recording

/// What a recording has reached, for deciding what to say: the current phase, the last whole distance and time marks.
class CueMarks {
  int? phase, dist, time;
  bool done = false;
  int? countdown;
}

/// The recording's cues at one moment, from its own numbers (pure; the recorder calls it every second while
/// recording). The first call for a recording ([marks] empty) only notes where it stands, so nothing that was due
/// earlier is said. A phase change and a distance or time update due together are said as one message, phase first.
/// A countdown second (3, 2, 1 before a phase change) is returned in [CueStep.tick].
typedef CueStep = ({Cue? cue, bool tick});

CueStep recordingCues({
  required CueMarks marks,
  required String activityId,
  required IntervalPlan? plan,
  required List<int> skips,
  required int activeMs,
  required double? distanceMeters,
  required double? paceSecondsPerUnit,
  required DistanceUnit unit,
  required MovePrefs prefs,
}) {
  final first = marks.phase == null && marks.dist == null && marks.time == null && !marks.done;
  final pos = plan == null ? null : IntervalClock.at(plan, skips, activeMs);
  final everyM = prefs.everyDistance * unit.meters, everyS = prefs.everyMinutes * 60;
  final dist = distanceMeters == null ? 0 : (distanceMeters / everyM).floor();
  final time = activeMs ~/ 1000 ~/ everyS;
  if (first) {
    marks
      ..phase = pos?.index ?? -1
      ..dist = dist
      ..time = time
      ..done = pos?.done ?? false;
    return (cue: null, tick: false);
  }

  String? phaseText;
  var key = '';
  if (pos != null && pos.index != marks.phase) {
    marks.phase = pos.index;
    if (pos.done && !marks.done) {
      marks.done = true;
      phaseText = 'Intervals finished. Continue freely, or finish and review.';
      key = '$activityId:intervals:done';
    } else if (!pos.done) {
      phaseText = phaseCue(pos);
      key = '$activityId:phase:${pos.index}';
    }
  }

  // A short countdown: the last three whole seconds of a phase that has a next phase.
  var tick = false;
  if (pos != null && !pos.done && prefs.countdown) {
    final s = (pos.remainingMs / 1000).ceil();
    if (s <= 3 && s >= 1 && marks.countdown != s) {
      marks.countdown = s;
      tick = true;
    } else if (s > 3) {
      marks.countdown = null;
    }
  }

  String? update, updateSaid, updateShort;
  if (prefs.updates == UpdateMode.distance && distanceMeters != null && dist > (marks.dist ?? 0)) {
    marks.dist = dist;
    final d = dist * prefs.everyDistance;
    final name = unit == DistanceUnit.km ? (d == 1 ? 'kilometre' : 'kilometres') : (d == 1 ? 'mile' : 'miles');
    final n = d == d.roundToDouble() ? d.round().toString() : d.toString();
    final active = activeMs ~/ 1000;
    updateShort = '$n ${unit.label} completed.';
    update = '$n ${unit.label} completed. Active time ${clockText(active)}.${paceSecondsPerUnit == null ? '' : ' Avg. moving pace ${unit.paceNumber(paceSecondsPerUnit)} /${unit.label}.'}';
    updateSaid = '$n $name. Active time ${spokenDuration(active)}.${paceSecondsPerUnit == null ? '' : ' Average moving pace ${spokenDuration(paceSecondsPerUnit.round())} per ${unit == DistanceUnit.km ? 'kilometre' : 'mile'}.'}';
    key = key.isEmpty ? '$activityId:dist:$dist:${prefs.everyDistance}${unit.name}' : key;
  } else if (prefs.updates == UpdateMode.time && time > (marks.time ?? 0)) {
    marks.time = time;
    final m = time * prefs.everyMinutes;
    final d = distanceMeters == null ? null : unit.distance(distanceMeters);
    updateShort = '$m min active.';
    update = '$m min active.${d == null ? '' : ' $d.'}${paceSecondsPerUnit == null ? '' : ' Avg. moving pace ${unit.paceNumber(paceSecondsPerUnit)} /${unit.label}.'}';
    updateSaid = '$m minutes active.${distanceMeters == null ? '' : ' ${_spokenDistance(distanceMeters, unit)}.'}${paceSecondsPerUnit == null ? '' : ' Average moving pace ${spokenDuration(paceSecondsPerUnit.round())} per ${unit == DistanceUnit.km ? 'kilometre' : 'mile'}.'}';
    key = key.isEmpty ? '$activityId:time:$time:${prefs.everyMinutes}' : key;
  } else {
    // Keep the marks current when updates are off, so turning them on mid-way never pours out old ones.
    if (dist > (marks.dist ?? 0)) marks.dist = dist;
    if (time > (marks.time ?? 0)) marks.time = time;
  }

  if (phaseText != null) {
    // Coalesced: the phase prompt, then only the distance or time itself.
    final short = updateShort == null ? '' : ' $updateShort';
    return (cue: Cue('$phaseText$short', key: key, priority: Cue.phase, vibrate: true), tick: tick);
  }
  if (update != null) return (cue: Cue(update, spoken: updateSaid, key: key, priority: Cue.update), tick: tick);
  return (cue: null, tick: tick);
}

String _spokenDistance(double m, DistanceUnit unit) {
  final v = m / unit.meters;
  final n = v.toStringAsFixed(v < 10 ? 2 : 1);
  return '$n ${unit == DistanceUnit.km ? 'kilometres' : 'miles'}';
}
