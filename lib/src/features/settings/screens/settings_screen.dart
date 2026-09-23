import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/settings/providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-read the live device-admin state after returning from the system
    // "activate device admin" dialog.
    if (state == AppLifecycleState.resumed) {
      ref.read(preventUninstallControllerProvider.notifier).refresh();
    }
  }

  String _relockLabel(RelockPolicy policy) {
    switch (policy.mode) {
      case RelockMode.immediately:
        return 'When you leave the app';
      case RelockMode.onScreenOff:
        return 'When the screen turns off';
      case RelockMode.afterTimeout:
        return 'After ${policy.timeout.inMinutes} min';
    }
  }

  /// In-app re-auth required before device admin can be deactivated. Tries
  /// biometrics first (if enabled), then falls back to a PIN prompt. Returns
  /// true only on a successful check.
  Future<bool> _authenticateForDisable() async {
    final biometric = ref.read(biometricServiceProvider);
    if (await biometric.isEnabled() && await biometric.authenticate()) {
      return true;
    }
    if (!mounted) return false;
    return _promptPin();
  }

  Future<bool> _promptPin() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var error = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Confirm your PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your PIN to turn off uninstall protection.',
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    errorText: error ? 'Wrong PIN' : null,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await ref
                      .read(pinAuthServiceProvider)
                      .verifyPin(controller.text);
                  if (ok) {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  } else {
                    setDialogState(() => error = true);
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final config =
        ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final controller = ref.read(configControllerProvider.notifier);
    final biometricSupported =
        ref.watch(biometricSupportedProvider).valueOrNull ?? false;
    final biometricEnabled =
        ref.watch(biometricEnabledProvider).valueOrNull ?? false;
    final preventUninstall =
        ref.watch(preventUninstallControllerProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            _section(context, 'Protection'),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Permissions & status'),
              subtitle: const Text('Usage access, overlay, monitor service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.permissions),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Relock behavior'),
              subtitle: Text(_relockLabel(config.relock)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.relock),
            ),
            _section(context, 'Security'),
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.changePin),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Fingerprint unlock'),
              subtitle: Text(
                biometricSupported
                    ? 'Use your fingerprint to open OpenLock'
                    : 'Not available on this device',
              ),
              value: biometricEnabled,
              onChanged: biometricSupported
                  ? (value) async {
                      final service = ref.read(biometricServiceProvider);
                      if (value) {
                        await service.enable();
                      } else {
                        await service.disable();
                      }
                      ref.invalidate(biometricEnabledProvider);
                      // Keep the native lock screen in sync with the choice.
                      await controller.pushToNative();
                    }
                  : null,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.app_blocking_outlined),
              title: const Text('Prevent uninstall'),
              subtitle: Text(
                preventUninstall
                    ? 'OpenLock is a device admin — it can\'t be uninstalled '
                        'until you turn this off with your PIN.'
                    : 'Block OpenLock from being uninstalled without your PIN '
                        '(uses device administrator).',
              ),
              value: preventUninstall,
              onChanged: (value) async {
                final security =
                    ref.read(preventUninstallControllerProvider.notifier);
                if (value) {
                  await security.requestEnable();
                } else {
                  final messenger = ScaffoldMessenger.of(context);
                  final lifted =
                      await security.disableWithAuth(_authenticateForDisable);
                  if (!lifted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'PIN or fingerprint required to turn off uninstall '
                          'protection.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.shuffle),
              title: const Text('Randomize keypad'),
              subtitle: const Text('Shuffle digits to foil shoulder-surfers'),
              value: config.randomizeKeypad,
              onChanged: controller.setRandomizeKeypad,
            ),
            _section(context, 'Intruder detection'),
            SwitchListTile(
              secondary: const Icon(Icons.photo_camera_outlined),
              title: const Text('Capture intruder photos'),
              subtitle: Text(
                'After ${config.intruderThreshold} failed attempts, take a '
                'silent front-camera photo',
              ),
              value: config.intruderCaptureEnabled,
              onChanged: (value) =>
                  controller.setIntruderCapture(enabled: value),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('View intruder log'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.intruder),
            ),
            _section(context, 'Advanced'),
            SwitchListTile(
              secondary: const Icon(Icons.warning_amber_outlined),
              title: const Text('Decoy cover'),
              subtitle: const Text(
                'Show a fake "app has stopped" dialog; long-press to unlock',
              ),
              value: config.fakeCoverEnabled,
              onChanged: controller.setFakeCover,
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup & restore'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.backup),
            ),
            _section(context, 'Updates'),
            const _UpdateSection(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.about),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Text(
          title.toUpperCase(),
          style: AppTextStyles.overline.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

/// "Check for updates on open" toggle + a manual "Check now", backed by
/// core_update. On by default; the only network call the app makes.
class _UpdateSection extends ConsumerStatefulWidget {
  const _UpdateSection();

  @override
  ConsumerState<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends ConsumerState<_UpdateSection> {
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final info = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() => _checking = false);
    final messenger = ScaffoldMessenger.of(context);
    if (info == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("You're on the latest version.")),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update available · v${info.version}'),
          action: SnackBarAction(
            label: 'Update',
            onPressed: () => ref.read(updateServiceProvider).openDownload(info),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoCheck = ref.watch(updateAutoCheckProvider).valueOrNull ?? true;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.system_update_alt),
          title: const Text('Check for updates on open'),
          subtitle: const Text(
            'Looks for a new release on GitHub. Nothing is uploaded.',
          ),
          value: autoCheck,
          onChanged: (v) async {
            await ref.read(secureStorageProvider).write(
                  key: updateAutoCheckKey,
                  value: v ? 'true' : 'false',
                );
            ref.invalidate(updateAutoCheckProvider);
            ref.invalidate(updateCheckProvider);
          },
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Check now'),
          trailing: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _checking ? null : _checkNow,
        ),
      ],
    );
  }
}
