import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../core/compatibility.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../workout/workout_flow.dart' show ExercisePicker;
import 'coach_bubble.dart';
import 'exercise_demo.dart';
import 'exercise_media.dart';

/// Owner-only management of shared exercise videos (docs/OWNER_EXERCISE_VIDEOS.md): choose an exercise, choose a video,
/// upload, preview the processed result, publish. Online only and separate from the workout sync queue; the server
/// decides who may manage, and nothing here publishes or retries a publish by itself.

const _uuid = Uuid();
const maxOriginalBytes = 200 * 1024 * 1024;
const maxOriginalSeconds = 120;

/// Whether this account may manage, and whether the server is set up. Null on an older server or signed out.
@immutable
class MediaAccess {
  const MediaAccess({required this.canManage, required this.ready, this.problem});
  final bool canManage, ready;
  final String? problem;
}

final mediaAccessProvider = FutureProvider<MediaAccess?>((ref) async {
  if (ref.watch(ownerProvider) == null) return null;
  final caps = ref.watch(compatibilityProvider).capabilities;
  if (caps == null || !caps.contains('exercises.media-catalog')) return null;
  try {
    final r = await ref.watch(apiProvider).send('GET', '/exercise-media/access');
    if (!r.ok || r.data is! Map) return null;
    final j = r.data as Json;
    return MediaAccess(canManage: j['canManage'] == true, ready: j['ready'] == true, problem: j['problem'] as String?);
  } on TransportFailure {
    return null;
  }
});

/// A command the server refused, with its short code (TOO_LARGE, REVISION_CONFLICT…).
class MediaCommandError implements Exception {
  const MediaCommandError(this.code);
  final String code;
  @override
  String toString() => 'MediaCommandError($code)';
}

/// Sends a file to a signed storage URL. A separate client: no GoHard token or header ever goes to storage.
typedef MediaUploader = Future<void> Function(String url, Map<String, String> headers, File file, int bytes,
    {required void Function(int sent) onProgress, required CancelToken cancel});

final mediaUploaderProvider = Provider<MediaUploader>((_) => (url, headers, file, bytes, {required onProgress, required cancel}) async {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), sendTimeout: const Duration(minutes: 10), receiveTimeout: const Duration(seconds: 60)));
      try {
        await dio.put<void>(url, data: file.openRead(), cancelToken: cancel, onSendProgress: (sent, _) => onProgress(sent),
            options: Options(headers: {...headers, Headers.contentLengthHeader: bytes}));
      } finally {
        dio.close(force: true);
      }
    });

/// The phone's video picker (the system photo picker: no camera, microphone or whole-library permission). In a debug
/// build GOHARD_TEST_PICK_FILE stands in for it, because a device test cannot tap the system picker; the journey says so.
final videoPickerProvider = Provider<Future<File?> Function()>((_) => () async {
      const simulated = String.fromEnvironment('GOHARD_TEST_PICK_FILE');
      if (kDebugMode && simulated.isNotEmpty) return File(simulated);
      final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
      return x == null ? null : File(x.path);
    });

/// The chosen video's length, read on the phone where it can be (the server checks it again regardless).
final videoDurationProvider = Provider<Future<Duration?> Function(File)>((_) => (file) async {
      final c = VideoPlayerController.file(file);
      try {
        await c.initialize().timeout(const Duration(seconds: 6));
        return c.value.duration;
      } on Object {
        return null;
      } finally {
        await c.dispose();
      }
    });

class OwnerMediaApi {
  OwnerMediaApi(this._api);
  final Api _api;

  Future<Json> list() async {
    final r = await _api.send('GET', '/exercise-media/manage');
    if (!r.ok) throw MediaCommandError(r.status == 404 ? 'NOT_OWNER' : 'UNAVAILABLE');
    return r.data as Json;
  }

  Future<Json?> _command(String method, String path, Json body) async {
    final r = await _api.send(method, path, data: {'operationId': _uuid.v4(), ...body});
    final ack = r.ack;
    if (ack == null) throw MediaCommandError(r.status == 503 ? 'STORAGE_NOT_CONFIGURED' : r.status == 404 ? 'NOT_FOUND' : 'UNAVAILABLE');
    if (ack['status'] != 'accepted') throw MediaCommandError(ack['code'] as String? ?? 'REJECTED');
    return ack['data'] as Json?;
  }

  Future<Json> create(String key, String type, int bytes) async =>
      (await _command('POST', '/exercise-media/manage/drafts', {'draftId': _uuid.v4(), 'catalogKey': key, 'contentType': type, 'bytes': bytes}))!;
  Future<Json> details(Json draft, MediaDetailsForm f) async => (await _command('PUT', '/exercise-media/manage/drafts/${draft['id']}/details', {
        'revision': draft['revision'], 'variant': f.variant, 'title': f.title, 'creator': f.creator, 'rightsKind': f.licensed ? 'licensed' : 'original',
        'licenceName': f.licensed ? f.licence : null, 'licenceUrl': f.licensed && f.licenceUrl.isNotEmpty ? f.licenceUrl : null,
        'sourceUrl': f.licensed ? f.sourceUrl : null, 'rightsNotice': f.notice, 'rightsConfirmed': f.confirmed,
      }))!;
  Future<Json> uploadLink(String id) async {
    final r = await _api.send('POST', '/exercise-media/manage/drafts/$id/upload-url');
    if (!r.ok) throw MediaCommandError((r.data is Map ? (r.data as Map)['code'] as String? : null) ?? 'UNAVAILABLE');
    return r.data as Json;
  }

  Future<Json> complete(String id) async => (await _command('POST', '/exercise-media/manage/drafts/$id/complete', {}))!;
  Future<Json> retry(Json d) async => (await _command('POST', '/exercise-media/manage/drafts/${d['id']}/retry', {'revision': d['revision']}))!;
  Future<Json> publish(Json d) async => (await _command('POST', '/exercise-media/manage/drafts/${d['id']}/publish', {'revision': d['revision']}))!;
  Future<void> delete(Json d) => _command('POST', '/exercise-media/manage/drafts/${d['id']}/delete', {'revision': d['revision']});
  Future<void> unpublish(String key, String versionId) => _command('POST', '/exercise-media/manage/keys/$key/unpublish', {'versionId': versionId});
  Future<Json> preview(String id) async {
    final r = await _api.send('GET', '/exercise-media/manage/drafts/$id/preview');
    if (!r.ok) throw const MediaCommandError('NOT_READY');
    return r.data as Json;
  }
}

final ownerMediaApiProvider = Provider((ref) => OwnerMediaApi(ref.watch(apiProvider)));

/// The details the owner confirms before publishing: what the video shows, its title and credit, and the rights.
class MediaDetailsForm {
  String variant = '', title = '', creator = 'GoHard', licence = '', licenceUrl = '', sourceUrl = '', notice = 'Original footage, published by GoHard.';
  bool licensed = false, confirmed = false;

  MediaDetailsForm();
  MediaDetailsForm.from(Json d)
      : variant = d['variant'] as String? ?? '',
        title = d['title'] as String? ?? '',
        creator = d['creator'] as String? ?? 'GoHard',
        licence = d['licenceName'] as String? ?? '',
        licenceUrl = d['licenceUrl'] as String? ?? '',
        sourceUrl = d['sourceUrl'] as String? ?? '',
        notice = d['rightsNotice'] as String? ?? '',
        licensed = d['rightsKind'] == 'licensed',
        confirmed = d['rightsConfirmed'] == true;

  void copyFrom(MediaDetailsForm o) {
    variant = o.variant;
    title = o.title;
    creator = o.creator;
    licence = o.licence;
    licenceUrl = o.licenceUrl;
    sourceUrl = o.sourceUrl;
    notice = o.notice;
    licensed = o.licensed;
    confirmed = o.confirmed;
  }

  String? get problem {
    if (variant.trim().isEmpty) return 'Say what the video shows (equipment, grip, angle).';
    if (title.trim().isEmpty || creator.trim().isEmpty) return 'Give it a title and a credit.';
    if (licensed && (licence.trim().isEmpty || !sourceUrl.startsWith('https://'))) return 'Licensed footage needs its licence and an https:// source link.';
    if (!confirmed) return 'Confirm you own this footage or may publish it.';
    return null;
  }
}

/// What the owner is told about a status or an error. Plain words; no codes, codecs or URLs.
String mediaStatusLabel(String? status, {required bool published}) => switch (status) {
      'awaiting_upload' => 'Draft',
      'queued' || 'processing' => 'Processing',
      'ready' => 'Ready to preview',
      'failed' => 'Failed',
      'published' => 'Published',
      _ => published ? 'Published' : 'No owner video',
    };

String mediaErrorText(String? code) => switch (code) {
      'TOO_LARGE' => 'The file is larger than 200 MB. Choose a shorter clip.',
      'TOO_LONG' => 'The video is longer than 2 minutes. Choose a shorter clip.',
      'NOT_A_VIDEO' || 'PROCESSING_REJECTED' || 'BAD_DIMENSIONS' || 'OUTPUT_INVALID' => 'This file could not be read as a video. Export it again from your photos and try that.',
      'UNSUPPORTED_HDR' => 'This HDR format cannot be converted with correct colours. Record in standard video, or export it as "Most Compatible".',
      'OUTPUT_TOO_LARGE' => 'The phone-friendly version came out over 20 MB. Choose a shorter clip.',
      'SIZE_MISMATCH' || 'EMPTY' || 'UPLOAD_MISSING' || 'UPLOAD_EXPIRED' => 'The upload did not arrive complete. Upload the video again.',
      'STORAGE_NOT_CONFIGURED' => 'Video storage is not set up on the server yet (docs/OWNER_EXERCISE_VIDEOS.md › Setup).',
      'REVISION_CONFLICT' => 'This changed elsewhere. It has been reloaded; check it and try again.',
      'DETAILS_REQUIRED' => 'Fill in what it shows and confirm the rights before publishing.',
      'NOT_OWNER' => 'This account cannot manage exercise videos.',
      _ => 'Processing did not finish on the server. Try again; if it keeps failing, the server\'s video worker needs a look.',
    };

String _mb(num bytes) => '${(bytes / 1000000).toStringAsFixed(bytes < 10000000 ? 1 : 0)} MB';
String _clock(Duration d) => d.inMinutes > 0 ? '${d.inMinutes} min ${d.inSeconds % 60} s' : '${d.inSeconds} s';

/// The latest unfinished or published draft for a key, and its active published version, from one manage listing.
({Json? draft, Json? active}) _stateFor(Json? listing, String key) {
  final drafts = [for (final d in (listing?['drafts'] as List? ?? const []).cast<Json>()) if (d['catalogKey'] == key && d['status'] != 'withdrawn') d];
  final active = (listing?['active'] as List? ?? const []).cast<Json>().where((v) => v['catalogKey'] == key).firstOrNull;
  return (draft: drafts.firstOrNull, active: active);
}

// ------------------------------------------------------------------ Me › Manage exercise videos

class ManageExerciseVideosScreen extends ConsumerStatefulWidget {
  const ManageExerciseVideosScreen({super.key});
  @override
  ConsumerState<ManageExerciseVideosScreen> createState() => _ManageExerciseVideosScreenState();
}

class _ManageExerciseVideosScreenState extends ConsumerState<ManageExerciseVideosScreen> {
  Json? _listing;
  String? _error, _query;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await ref.read(ownerMediaApiProvider).list();
      if (!mounted) return;
      setState(() { _listing = l; _error = null; });
      // While something is processing, the page checks again; never invents progress.
      final busy = (l['drafts'] as List).cast<Json>().any((d) => d['status'] == 'queued' || d['status'] == 'processing');
      _poll?.cancel();
      if (busy) _poll = Timer(const Duration(seconds: 4), _load);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e is MediaCommandError ? mediaErrorText(e.code) : 'The server could not be reached. Check your connection and try again.');
    }
  }

  Future<void> _open(String key) async {
    await push(context, ManageExerciseVideoScreen(catalogKey: key));
    if (mounted) await _load();
  }

  Future<void> _uploadNew() async {
    final e = await push<CatalogExercise>(context, const ExercisePicker(title: 'Which exercise does the video show?'));
    if (e == null || !mounted) return;
    if (e.isCustom || e.key == null) return toast(context, 'Shared videos are for built-in exercises only.');
    await push(context, ManageExerciseVideoScreen(catalogKey: e.key!, startUpload: true));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(mediaAccessProvider).value;
    final bundled = ref.watch(bundledMediaProvider).value;
    final exercises = [for (final e in ref.watch(exerciseChoicesProvider)) if (!e.isCustom) e];
    final q = (_query ?? '').trim().toLowerCase();
    final shown = [for (final e in exercises) if (q.isEmpty || e.name.toLowerCase().contains(q)) e];
    return AppPage(title: 'Exercise videos', children: [
      Text('Demonstrations you publish here are shown to everyone using GoHard, on the exercise they serve.', style: context.caption),
      const CoachSpot(id: 'owner.videos', introduce: true, say: CoachSay('Choose an exercise, upload a short clear clip, check the preview, then publish. Nothing reaches anyone until you press Publish.')),
      const SizedBox(height: 12),
      if (access != null && !access.ready) ...[
        StatusLine(Icons.cloud_off, mediaErrorText(access.problem), tone: Tone.warning),
        const SizedBox(height: 12),
      ],
      PrimaryButton('Upload video', key: const Key('videos-upload'), icon: Icons.upload_rounded, onPressed: access?.ready == true ? _uploadNew : null),
      const SizedBox(height: 14),
      TextField(key: const Key('videos-search'), decoration: const InputDecoration(labelText: 'Search exercises', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: StatusLine(Icons.error_outline, _error!, tone: Tone.error)),
      const SizedBox(height: 6),
      for (final e in shown)
        Builder(builder: (context) {
          final s = _stateFor(_listing, e.key!);
          final label = mediaStatusLabel(s.draft?['status'] as String?, published: s.active != null);
          final fallback = s.active == null && bundled?.forKey(e.key) != null ? ' · bundled demonstration shown' : '';
          return ListRow(key: Key('videos-${e.key}'), title: e.name, subtitle: '$label$fallback', onTap: () => _open(e.key!));
        }),
    ]);
  }
}

// ------------------------------------------------------------------ one exercise

class ManageExerciseVideoScreen extends ConsumerStatefulWidget {
  const ManageExerciseVideoScreen({super.key, required this.catalogKey, this.startUpload = false});
  final String catalogKey;
  final bool startUpload;
  @override
  ConsumerState<ManageExerciseVideoScreen> createState() => _ManageExerciseVideoScreenState();
}

enum _Local { idle, picked, uploading, uploadFailed }

class _ManageExerciseVideoScreenState extends ConsumerState<ManageExerciseVideoScreen> {
  Json? _listing, _preview;
  String? _message;
  Timer? _poll;
  bool _busy = false;

  // The video chosen on this phone, before and during its upload. Never sent anywhere but the signed upload URL.
  _Local _local = _Local.idle;
  File? _file;
  int _bytes = 0, _sent = 0;
  Duration? _duration;
  CancelToken? _cancel;
  final _form = MediaDetailsForm();

  OwnerMediaApi get _api => ref.read(ownerMediaApiProvider);
  ({Json? draft, Json? active}) get _state => _stateFor(_listing, widget.catalogKey);

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.startUpload && mounted) _pick();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await _api.list();
      if (!mounted) return;
      final before = _state.draft;
      setState(() => _listing = l);
      final d = _state.draft;
      if (d != null && _form.variant.isEmpty && _local == _Local.idle) {
        _form.copyFrom(MediaDetailsForm.from(d));
      }
      if (d?['status'] == 'ready' && (before?['status'] != 'ready' || _preview == null)) await _loadPreview(d!);
      _poll?.cancel();
      if (d != null && (d['status'] == 'queued' || d['status'] == 'processing')) _poll = Timer(const Duration(seconds: 3), _load);
    } on Object catch (e) {
      if (mounted) setState(() => _message = e is MediaCommandError ? mediaErrorText(e.code) : 'The server could not be reached. Check your connection and try again.');
    }
  }

  Future<void> _loadPreview(Json d) async {
    try {
      final p = await _api.preview(d['id'] as String);
      if (mounted) setState(() => _preview = p);
    } on Object {
      if (mounted) setState(() => _preview = null);
    }
  }

  static String _typeOf(String path) => switch (path.toLowerCase().split('.').last) {
        'mov' || 'qt' => 'video/quicktime',
        'm4v' => 'video/x-m4v',
        '3gp' => 'video/3gpp',
        'webm' => 'video/webm',
        'mkv' => 'video/x-matroska',
        _ => 'video/mp4',
      };

  Future<void> _pick() async {
    final file = await ref.read(videoPickerProvider)();
    if (file == null || !mounted) return;
    final bytes = await file.length();
    final duration = await ref.read(videoDurationProvider)(file);
    if (!mounted) return;
    final name = ref.read(exerciseChoicesProvider).where((e) => e.key == widget.catalogKey).firstOrNull?.name ?? widget.catalogKey;
    setState(() {
      _file = file;
      _bytes = bytes;
      _duration = duration;
      _local = _Local.picked;
      _message = null;
      if (_form.title.isEmpty) _form.title = name;
    });
  }

  Future<void> _upload() async {
    final file = _file!;
    setState(() { _local = _Local.uploading; _sent = 0; _message = null; });
    _cancel = CancelToken();
    try {
      // A draft from before (an upload that did not finish) is reused; otherwise a new one.
      var d = _state.draft;
      if (d == null || d['status'] != 'awaiting_upload' || d['declaredBytes'] != _bytes) d = await _api.create(widget.catalogKey, _typeOf(file.path), _bytes);
      d = await _api.details(d, _form);
      final link = await _api.uploadLink(d['id'] as String);
      await ref.read(mediaUploaderProvider)(link['url'] as String, (link['headers'] as Map).cast<String, String>(), file, _bytes,
          onProgress: (sent) { if (mounted) setState(() => _sent = sent); }, cancel: _cancel!);
      await _api.complete(d['id'] as String);
      if (!mounted) return;
      setState(() { _local = _Local.idle; _file = null; });
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _local = e.type == DioExceptionType.cancel ? _Local.picked : _Local.uploadFailed;
        _message = e.type == DioExceptionType.cancel ? 'Upload cancelled. Nothing was published.' : 'The upload did not finish. Check your connection and upload again.';
      });
    } on MediaCommandError catch (e) {
      if (mounted) setState(() { _local = _Local.uploadFailed; _message = mediaErrorText(e.code); });
    } on TransportFailure {
      if (mounted) setState(() { _local = _Local.uploadFailed; _message = 'The server could not be reached. Check your connection and upload again.'; });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _message = null; });
    try {
      await action();
    } on MediaCommandError catch (e) {
      if (mounted) setState(() => _message = mediaErrorText(e.code));
    } on TransportFailure {
      if (mounted) setState(() => _message = 'The server could not be reached. Nothing changed.');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _publish(Json d) async {
    final ok = await confirm(context, title: 'Publish to everyone?', action: 'Publish',
        body: 'Publishing makes this demonstration available to everyone using GoHard, on ${d['title']}. You can unpublish it later.');
    if (!ok) return;
    await _run(() async {
      var draft = d;
      if (_form.problem == null) draft = await _api.details(d, _form);
      await _api.publish(draft);
      // Seen here at once; everyone else on their next quiet refresh.
      await ref.read(remoteMediaProvider.notifier).refresh(force: true);
      if (mounted) toast(context, 'Published. Everyone sees it after their app next refreshes.');
    });
  }

  Future<void> _editDetails(Json d) async {
    final saved = await showGoSheet<bool>(context, title: 'Details', builder: (_) => _DetailsForm(form: _form, action: 'Save details'));
    if (saved == true) await _run(() => _api.details(d, _form));
  }

  @override
  Widget build(BuildContext context) {
    final exercise = ref.watch(exerciseChoicesProvider).where((e) => e.key == widget.catalogKey).firstOrNull;
    final bundled = ref.watch(bundledMediaProvider).value?.forKey(widget.catalogKey);
    final (:draft, :active) = _state;
    final status = draft?['status'] as String?;
    return AppPage(
      title: exercise?.name ?? widget.catalogKey,
      subtitle: exercise == null ? null : '${exercise.category} · ${exercise.equipment}',
      children: [
        // What everyone sees now, apart from any replacement in progress.
        const SectionLabel('What everyone sees now'),
        const SizedBox(height: 6),
        Panel(
          key: const Key('video-current'),
          child: active != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Published owner video', style: context.sansStyle(16, weight: FontWeight.w600)),
                  Text('${active['title']} · ${active['variant']}', style: context.caption),
                  Text(active['rightsKind'] == 'original' ? 'Original footage by ${active['creator']}' : 'Video by ${active['creator']}, ${active['licenceName']}', style: context.caption),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('video-unpublish'), icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: const Text('Unpublish'), onPressed: _busy ? null : () async {
                        final ok = await confirm(context, title: 'Unpublish this video?', action: 'Unpublish', destructive: true,
                            body: 'Everyone sees ${bundled == null ? 'no demonstration' : 'the bundled demonstration'} again after their app next refreshes. Phones that saved it for offline use may keep it until then.');
                        if (!ok) return;
                        await _run(() async {
                          await _api.unpublish(widget.catalogKey, active['id'] as String);
                          await ref.read(remoteMediaProvider.notifier).refresh(force: true);
                        });
                      })),
                ])
              : Text(bundled != null ? 'The bundled demonstration: ${bundled.credit.attribution}.' : 'No demonstration yet: the written guide only.', style: context.body),
        ),
        const SizedBox(height: 18),
        SectionLabel(active != null ? 'Replacement' : 'Owner video'),
        const SizedBox(height: 6),
        if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: StatusLine(Icons.error_outline, _message!, tone: Tone.warning)),
        ..._draftSection(draft, status, active != null),
      ],
    );
  }

  List<Widget> _draftSection(Json? draft, String? status, bool hasActive) {
    switch (_local) {
      case _Local.picked || _Local.uploadFailed:
        return [
          StatusLine(Icons.movie_outlined, '${_mb(_bytes)}${_duration == null ? ' · length checked after upload' : ' · ${_clock(_duration!)}'}'),
          if (_bytes > maxOriginalBytes) const StatusLine(Icons.error_outline, 'Larger than 200 MB: choose a shorter clip.', tone: Tone.error),
          if ((_duration?.inSeconds ?? 0) > maxOriginalSeconds) const StatusLine(Icons.error_outline, 'Longer than 2 minutes: choose a shorter clip.', tone: Tone.error),
          const SizedBox(height: 10),
          _DetailsForm(form: _form, action: null),
          const SizedBox(height: 12),
          PrimaryButton(_local == _Local.uploadFailed ? 'Upload again' : 'Upload', key: const Key('video-start-upload'), icon: Icons.upload_rounded,
              onPressed: _bytes > maxOriginalBytes || (_duration?.inSeconds ?? 0) > maxOriginalSeconds ? null : () {
                final problem = _form.problem;
                if (problem != null) return setState(() => _message = problem);
                _upload();
              }),
          TextButton(onPressed: () => setState(() { _local = _Local.idle; _file = null; _message = null; }), child: const Text('Choose a different video')),
        ];
      case _Local.uploading:
        return [
          Text('Uploading ${_mb(_sent)} of ${_mb(_bytes)}', key: const Key('video-uploading'), style: context.body),
          const SizedBox(height: 8),
          ProgressRail(_bytes == 0 ? 0 : _sent / _bytes, label: 'Upload progress'),
          const SizedBox(height: 8),
          Text('Keep GoHard open until it finishes. If it stops, you can upload again.', style: context.caption),
          TextButton(key: const Key('video-cancel-upload'), onPressed: () => _cancel?.cancel(), child: const Text('Cancel upload')),
        ];
      case _Local.idle:
        break;
    }
    final limits = Text('A short, clear clip of the whole movement works best: up to 2 minutes and 200 MB. GoHard makes a phone-friendly, muted copy.', style: context.caption);
    final pick = SecondaryButton(hasActive ? 'Upload a replacement' : 'Upload video', key: const Key('video-pick'), icon: Icons.video_library_outlined, onPressed: _busy ? null : _pick);
    Widget delete(Json d) => TextButton(key: const Key('video-delete-draft'), onPressed: _busy ? null : () => _run(() => _api.delete(d)), child: const Text('Delete draft'));
    switch (status) {
      case 'awaiting_upload':
        return [StatusLine(Icons.info_outline, 'The upload did not finish. Choose the video again to upload it.'), const SizedBox(height: 10), pick, delete(draft!)];
      case 'queued' || 'processing':
        return [
          Row(key: const Key('video-processing'), children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text('Processing: making the phone-friendly clip and its poster. You can leave this page.', style: context.body)),
          ]),
        ];
      case 'failed':
        return [
          StatusLine(Icons.error_outline, mediaErrorText(draft!['error'] as String?), tone: Tone.error),
          const SizedBox(height: 10),
          if (hasActive) Text('The published video is unchanged.', style: context.caption),
          // Only a processing failure is worth retrying; content the server refuses needs another video.
          if (const {'PROCESSING_FAILED', 'PROCESSING_GAVE_UP', 'PROCESSING_TIMEOUT', 'NO_WORKER_DISK'}.contains(draft['error'])) ...[
            SecondaryButton('Try again', key: const Key('video-retry'), icon: Icons.refresh_rounded, onPressed: _busy ? null : () => _run(() => _api.retry(draft))),
            const SizedBox(height: 8),
          ],
          pick,
          delete(draft),
        ];
      case 'ready':
        final p = _preview;
        final m = p == null
            ? null
            : ExerciseMedia(
                catalogKey: widget.catalogKey, poster: p['posterUrl'] as String, variant: draft!['variant'] as String? ?? '', changes: '', providerName: 'GoHard',
                allowDownload: false, credit: DemoCredit(creator: draft['creator'] as String? ?? '', attribution: '', original: true),
                video: DemoVideo(url: Uri.parse(p['clipUrl'] as String), bytes: draft['bytes'] as int, sha256: draft['id'] as String,
                    durationSeconds: (draft['durationSeconds'] as num).toDouble(), width: draft['width'] as int, height: draft['height'] as int));
        return [
          Text('Ready to preview: this is exactly what everyone will see.', key: const Key('video-ready'), style: context.body),
          const SizedBox(height: 8),
          if (m == null) const StatusLine(Icons.hourglass_top_rounded, 'Loading the preview…') else ExerciseDemoMedia(key: const Key('video-preview'), media: m),
          const SizedBox(height: 10),
          Text('${draft!['width']} × ${draft['height']} · ${(draft['durationSeconds'] as num).toStringAsFixed(1)} s · ${_mb(draft['bytes'] as int)}', style: context.caption),
          Text('Shows: ${draft['variant']} · ${draft['rightsKind'] == 'original' ? 'Original footage by ${draft['creator']}' : 'Video by ${draft['creator']}, ${draft['licenceName']}'}', style: context.caption),
          TextButton(key: const Key('video-edit-details'), onPressed: () => _editDetails(draft), child: const Text('Edit details')),
          const SizedBox(height: 6),
          Text('Publishing makes this demonstration available to everyone using GoHard.', style: context.caption),
          const SizedBox(height: 8),
          PrimaryButton(hasActive ? 'Publish replacement' : 'Publish', key: const Key('video-publish'), busy: _busy, onPressed: () => _publish(draft)),
          delete(draft),
        ];
      default:
        return [limits, const SizedBox(height: 10), pick];
    }
  }
}

/// Variant, title, credit and rights. Original footage needs no outside licence; someone else's keeps its own.
class _DetailsForm extends StatefulWidget {
  const _DetailsForm({required this.form, required this.action});
  final MediaDetailsForm form;
  final String? action;
  @override
  State<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<_DetailsForm> {
  MediaDetailsForm get f => widget.form;
  late final _variant = TextEditingController(text: f.variant), _title = TextEditingController(text: f.title), _creator = TextEditingController(text: f.creator),
      _licence = TextEditingController(text: f.licence), _licenceUrl = TextEditingController(text: f.licenceUrl), _source = TextEditingController(text: f.sourceUrl),
      _notice = TextEditingController(text: f.notice);

  @override
  void dispose() {
    for (final c in [_variant, _title, _creator, _licence, _licenceUrl, _source, _notice]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, TextEditingController c, void Function(String) set, {String? helper, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(key: Key(key), controller: c, minLines: 1, maxLines: lines, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3), onChanged: (v) => setState(() => set(v))),
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _field('video-variant', 'What it shows', _variant, (v) => f.variant = v, helper: 'Equipment, grip and angle, e.g. "Barbell on a flat bench, side view".', lines: 2),
        _field('video-title', 'Title', _title, (v) => f.title = v),
        _field('video-creator', 'Credit shown to everyone', _creator, (v) => f.creator = v, helper: 'A name everyone may see. Your email or profile is never shown.'),
        SwitchListTile(key: const Key('video-licensed'), contentPadding: EdgeInsets.zero, value: f.licensed, onChanged: (v) => setState(() => f.licensed = v),
            title: const Text('Someone else made this footage'), subtitle: const Text('Licensed footage keeps its creator, licence and source.')),
        if (f.licensed) ...[
          _field('video-licence', 'Licence (exact, e.g. CC BY-SA 4.0)', _licence, (v) => f.licence = v),
          _field('video-licence-url', 'Licence link (https://), optional', _licenceUrl, (v) => f.licenceUrl = v),
          _field('video-source', 'Where it came from (https://)', _source, (v) => f.sourceUrl = v),
        ],
        _field('video-notice', 'Rights notice', _notice, (v) => f.notice = v, lines: 2),
        CheckboxListTile(key: const Key('video-rights'), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: f.confirmed,
            onChanged: (v) => setState(() => f.confirmed = v ?? false),
            title: Text(f.licensed ? 'I have permission to publish this footage under its licence' : 'I own this footage and may publish it')),
        if (widget.action != null) ...[
          const SizedBox(height: 8),
          PrimaryButton(widget.action!, key: const Key('video-details-save'), onPressed: f.problem == null ? () => Navigator.pop(context, true) : null),
        ],
      ]);
}
