import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'food_item.dart';

/// Builds the live camera view. It reports every code it sees through `onCode`, and through `onUnavailable`
/// that there will be none (permission refused, no camera). Replaced in tests, where there is no camera.
typedef ScannerCamera = Widget Function({required ValueChanged<String> onCode, required ValueChanged<bool> onUnavailable});

final scannerCameraProvider = Provider<ScannerCamera>((_) => ({required onCode, required onUnavailable}) => _CameraView(onCode: onCode, onUnavailable: onUnavailable));

/// Scans one product barcode and pops with it, as digits. It only reads the code: looking the product up and
/// logging anything are separate, later steps. The picture never leaves the phone; only the digits are used.
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});
  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final _typed = TextEditingController();
  bool _done = false;

  /// Null while the camera may still work; then whether the reason is a refused permission.
  bool? _permissionRefused;
  String? _typedError;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// The camera reports the same code many times a second. Only the first valid product code counts, once;
  /// anything else it can read (a web link in a QR code, a parcel label) is ignored and never opened.
  void _onCode(String raw) {
    final code = normalizeBarcode(raw);
    if (_done || code == null || !mounted) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, code);
  }

  void _submitTyped() {
    if (normalizeBarcode(_typed.text) == null) {
      setState(() => _typedError = 'A barcode is 6 to 14 digits, as printed under the bars.');
      return;
    }
    _onCode(_typed.text);
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = _permissionRefused != null;
    return AppPage(
      title: 'Scan a barcode',
      subtitle: unavailable ? null : 'Hold the barcode on the packet inside the frame.',
      // The actions are pinned, which also makes this a page that keeps every field built: the keyboard opening
      // under a tall camera view must never drop the field that was just tapped.
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        SecondaryButton('Look up this barcode', key: const Key('barcode-typed-submit'), onPressed: _submitTyped),
        TextButton(key: const Key('barcode-cancel'), onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ]),
      children: [
        if (unavailable)
          Panel(
            child: StatusLine(
                Icons.no_photography_outlined,
                _permissionRefused!
                    ? 'GoHard is not allowed to use the camera, so it cannot scan. You can allow it in the phone\'s settings, or type the barcode below.'
                    : 'The camera cannot be used on this phone right now. You can type the barcode below.',
                tone: Tone.warning),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.panel),
            child: AspectRatio(
              aspectRatio: 1,
              child: ref.watch(scannerCameraProvider)(onCode: _onCode, onUnavailable: (refused) => setState(() => _permissionRefused = refused)),
            ),
          ),
        const SizedBox(height: 22),
        const SectionLabel('Or type the barcode'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('barcode-typed'), controller: _typed, keyboardType: TextInputType.number, textInputAction: TextInputAction.search,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
          onSubmitted: (_) => _submitTyped(),
          decoration: InputDecoration(labelText: 'Barcode digits', errorText: _typedError),
        ),
      ],
    );
  }
}

/// The camera itself: product barcode formats only, a quiet frame, and a torch where the phone has one.
/// It runs only while it is on screen and the app is in front, and lets go of the camera otherwise.
class _CameraView extends StatefulWidget {
  const _CameraView({required this.onCode, required this.onUnavailable});
  final ValueChanged<String> onCode;
  final ValueChanged<bool> onUnavailable;
  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> with WidgetsBindingObserver {
  final _controller = MobileScannerController(
      autoStart: false, formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.itf14],
      detectionSpeed: DetectionSpeed.noDuplicates);
  StreamSubscription<BarcodeCapture>? _codes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
    unawaited(_start());
  }

  void _listen() => _codes = _controller.barcodes.listen((capture) {
        for (final b in capture.barcodes) {
          if (b.rawValue != null) widget.onCode(b.rawValue!);
        }
      }, onError: (Object _) {}); // an unreadable frame is not an event; the next frame is tried

  Future<void> _start() async {
    try {
      await _controller.start();
    } on MobileScannerException catch (e) {
      if (mounted) widget.onUnavailable(e.errorCode == MobileScannerErrorCode.permissionDenied);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The permission prompt itself sends the app inactive and back; until it is answered there is nothing to stop.
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      _listen();
      unawaited(_start());
    } else if (state != AppLifecycleState.detached) {
      unawaited(_codes?.cancel());
      _codes = null;
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_codes?.cancel());
    super.dispose();
    unawaited(_controller.dispose()); // releases the camera
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: _controller,
          placeholderBuilder: (context) => ColoredBox(color: context.c.sunken, child: const Center(child: CircularProgressIndicator(semanticsLabel: 'Starting the camera'))),
          errorBuilder: (context, error) => ColoredBox(color: context.c.sunken),
        ),
        // A plain frame in the app's own shapes, so this never looks like another app's scanner.
        IgnorePointer(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.78, heightFactor: 0.42,
              child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.tile), border: Border.all(color: Colors.white, width: 2.5))),
            ),
          ),
        ),
        Positioned(
          right: 10, bottom: 10,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) => state.torchState == TorchState.unavailable
                ? const SizedBox.shrink()
                : IconButton.filled(
                    key: const Key('barcode-torch'),
                    tooltip: state.torchState == TorchState.on ? 'Turn the light off' : 'Turn the light on',
                    style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                    icon: Icon(state.torchState == TorchState.on ? Icons.flashlight_on : Icons.flashlight_off),
                    onPressed: _controller.toggleTorch,
                  ),
          ),
        ),
      ]);
}
