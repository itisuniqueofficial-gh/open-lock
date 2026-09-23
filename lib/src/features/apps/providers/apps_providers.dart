import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';

/// The launchable apps installed on the device, loaded once from native.
final installedAppsProvider = FutureProvider<List<InstalledApp>>((ref) {
  return ref.watch(enforcementBridgeProvider).getInstalledApps();
});

/// Packages the native monitor auto-locked (installed while "lock new apps"
/// was on). Merged with the user's manual selection in the picker.
final autoLockedPackagesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(enforcementBridgeProvider).getAutoLockedPackages();
});

/// The current search query in the app picker.
final appSearchQueryProvider = StateProvider<String>((_) => '');
