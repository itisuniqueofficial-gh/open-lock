import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

/// Whether the device can offer biometric unlock at all.
final biometricSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricServiceProvider).isSupported(),
);

/// Whether biometric unlock is currently enabled. Invalidate after toggling.
final biometricEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricServiceProvider).isEnabled(),
);

/// Owns the "Prevent uninstall" (device-admin) protection state.
///
/// The truth is whether OpenLock is an active device administrator, read from
/// the native layer. Enabling launches the system activation dialog; disabling
/// is **auth-gated** — device admin is never deactivated from within the app
/// without a successful PIN/biometric check first.
final class PreventUninstallController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(enforcementBridgeProvider).isDeviceAdminActive();

  /// Re-reads the live device-admin state (call after returning from the system
  /// activation dialog) and keeps the pushed config flag in sync with it.
  Future<void> refresh() async {
    final active =
        await ref.read(enforcementBridgeProvider).isDeviceAdminActive();
    state = AsyncData(active);
    await ref.read(configControllerProvider.notifier).setPreventUninstall(
          active,
        );
  }

  /// Requests device-admin activation via the system dialog. The effective
  /// state is confirmed by a later [refresh] (on screen resume).
  Future<void> requestEnable() async {
    await ref.read(configControllerProvider.notifier).setPreventUninstall(true);
    await ref.read(enforcementBridgeProvider).requestDeviceAdmin();
  }

  /// Auth-gated deactivation. [authenticate] must perform an in-app
  /// PIN/biometric check and return true only on success. Device admin is
  /// deactivated **only** after that succeeds; otherwise nothing changes.
  /// Returns true if protection was lifted.
  Future<bool> disableWithAuth(Future<bool> Function() authenticate) async {
    final ok = await authenticate();
    if (!ok) return false;
    await ref.read(enforcementBridgeProvider).deactivateDeviceAdmin();
    await ref
        .read(configControllerProvider.notifier)
        .setPreventUninstall(false);
    state = const AsyncData(false);
    return true;
  }
}

final preventUninstallControllerProvider =
    AsyncNotifierProvider<PreventUninstallController, bool>(
  PreventUninstallController.new,
);
