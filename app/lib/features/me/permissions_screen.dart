import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../weather/weather.dart';
import 'reminders.dart';

/// What the phone currently allows GoHard, read from the platform each time the page opens (and again on return from
/// Settings), never assumed. Only access an implemented feature uses is listed. Nothing here asks: each feature asks
/// when it is turned on or used, and a refusal is changed in the phone's Settings.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  late final AppLifecycleListener _life = AppLifecycleListener(onResume: _read);
  LocatorPermission? _location;
  bool? _notifications;
  bool _known = false;

  @override
  void initState() {
    super.initState();
    _life;
    _read();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final location = await ref.read(weatherLocatorProvider).check();
    bool? notifications;
    try {
      notifications = await ref.read(reminderSchedulerProvider).notificationsAllowed();
    } on Object {
      notifications = null; // the platform could not say
    }
    if (mounted) {
      setState(() {
        _location = location;
        _notifications = notifications;
        _known = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locator = ref.read(weatherLocatorProvider);
    final location = switch (_location) {
      LocatorPermission.granted => 'Allowed',
      LocatorPermission.deniedForever => 'Not allowed',
      LocatorPermission.denied => 'Not asked yet, or not allowed',
      null => _known ? 'Unknown' : '…',
    };
    final notifications = switch (_notifications) { true => 'Allowed', false => 'Not allowed', null => _known ? 'Unknown' : '…' };
    return AppPage(title: 'Phone permissions', subtitle: 'Controlled by the phone, not by GoHard\'s own settings.', children: [
      GroupCard(children: [
        GroupRow(key: const Key('permission-location'), icon: Icons.location_on_outlined, title: 'Location', value: location,
            subtitle: 'Approximate, while the app is open: automatic weather on Today and GPS runs. Asked when you use one of them.'),
        GroupRow(key: const Key('permission-camera'), icon: Icons.photo_camera_outlined, title: 'Camera',
            subtitle: 'Barcode scanning only. Asked the first time you scan; the scanner says so if it is not allowed.'),
        GroupRow(key: const Key('permission-notifications'), icon: Icons.notifications_none, title: 'Notifications', value: notifications,
            subtitle: 'Workout reminders only. Asked when you turn them on in Me.'),
      ]),
      const SizedBox(height: 14),
      Text('GoHard asks for each one only when you use the feature that needs it. To allow or stop something you refused or allowed earlier, use the phone\'s Settings. App preferences such as Units, Appearance and Today background are in Me.',
          style: context.caption),
      const SizedBox(height: 14),
      SecondaryButton('Open phone Settings', key: const Key('permission-open-settings'), onPressed: locator.openAppSettings),
    ]);
  }
}
