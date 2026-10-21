import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language.dart';
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
    final l = context.l10n;
    final location = switch (_location) {
      LocatorPermission.granted => l.permissionAllowed,
      LocatorPermission.deniedForever => l.permissionNotAllowed,
      LocatorPermission.denied => l.permissionNotAskedOrNotAllowed,
      null => _known ? l.permissionUnknown : '…',
    };
    final notifications = switch (_notifications) { true => l.permissionAllowed, false => l.permissionNotAllowed, null => _known ? l.permissionUnknown : '…' };
    return AppPage(title: l.mePermissions, subtitle: l.permissionsSubtitle, children: [
      GroupCard(children: [
        GroupRow(key: const Key('permission-location'), icon: Icons.location_on_outlined, title: l.permissionLocation, value: location,
            subtitle: l.permissionLocationExplanation),
        GroupRow(key: const Key('permission-camera'), icon: Icons.photo_camera_outlined, title: l.permissionCamera,
            subtitle: l.permissionCameraExplanation),
        GroupRow(key: const Key('permission-notifications'), icon: Icons.notifications_none, title: l.permissionNotifications, value: notifications,
            subtitle: l.permissionNotificationsExplanation),
      ]),
      const SizedBox(height: 14),
      Text(l.permissionsFootnote, style: context.caption),
      const SizedBox(height: 14),
      SecondaryButton(l.permissionsOpenSettings, key: const Key('permission-open-settings'), onPressed: locator.openAppSettings),
    ]);
  }
}
