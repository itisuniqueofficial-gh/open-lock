import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/onboarding/providers/permissions_providers.dart';

/// Guided protection setup. The displayed states come from Android every time
/// the app resumes; a saved Flutter preference is never treated as permission.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
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
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionsControllerProvider.notifier).refresh();
    }
  }

  Future<void> _selectMethod(EnforcementMethod? method) async {
    if (method == null) return;
    try {
      await ref.read(configControllerProvider.notifier).setEnforcementMethod(method);
      await ref.read(permissionsControllerProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the enforcement method.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(permissionsControllerProvider);
    final controller = ref.read(permissionsControllerProvider.notifier);
    final config =
        ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final states = async.valueOrNull ?? const PermissionStates.unknown();
    final method = config.enforcementMethod;
    final nativeMethod = enforcementMethodFromStorage(states.enforcementMethod);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protection setup'),
        actions: [
          IconButton(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _StatusBanner(states: states, method: nativeMethod),
            const SizedBox(height: AppSpacing.lg),
            Text('1. Choose enforcement method', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<EnforcementMethod>(
              value: method,
              decoration: const InputDecoration(
                labelText: 'Enforcement method',
                helperText: 'Only the selected method is used for protection.',
              ),
              items: EnforcementMethod.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.displayName),
                    ),
                  )
                  .toList(),
              onChanged: _selectMethod,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('2. Enable the selected permission', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.sm),
            if (method == EnforcementMethod.accessibility) ...[
              _PermissionTile(
                icon: Icons.accessibility_new_rounded,
                title: 'Accessibility Service',
                subtitle:
                    'Allows Open Lock to detect when a protected application is opened. It does not read window content.',
                granted: states.accessibilityService,
                required: true,
                onFix: controller.requestAccessibility,
              ),
              _MethodNote(
                text:
                    'Accessibility is event-driven and does not need a persistent Open Lock notification. Android still lets you disable it at any time.',
              ),
            ] else ...[
              _PermissionTile(
                icon: Icons.query_stats_rounded,
                title: 'Usage access',
                subtitle:
                    'Lets Open Lock notice which application is in the foreground.',
                granted: states.usageAccess,
                required: true,
                onFix: controller.requestUsageAccess,
              ),
              _PermissionTile(
                icon: Icons.layers_rounded,
                title: 'Display over other apps',
                subtitle:
                    'Lets the native lock activity appear over a protected app.',
                granted: states.overlay,
                required: true,
                onFix: controller.requestOverlay,
              ),
              _MethodNote(
                text:
                    'Usage Access uses a lightweight foreground service while selected, so Android requires an ongoing service notification.',
              ),
            ],
            _PermissionTile(
              icon: Icons.battery_saver_rounded,
              title: 'Battery optimization',
              subtitle:
                  'Optional. Some manufacturers restrict background work when the phone is idle.',
              granted: states.batteryExempt,
              required: false,
              onFix: controller.requestBattery,
            ),
            if (method == EnforcementMethod.usageAccess)
              _PermissionTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                subtitle:
                    'Allows Android to show the required Usage Access service notification.',
                granted: states.notifications,
                required: false,
                onFix: controller.requestNotifications,
              ),
            const SizedBox(height: AppSpacing.lg),
            Text('3. Select apps to lock', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose protected apps and configure authentication in the app list and settings.',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (states.canEnforce &&
                !states.serviceRunning &&
                method == EnforcementMethod.usageAccess)
              VaultButton(
                label: 'Turn on protection',
                onPressed: controller.startService,
              )
            else if (states.protectionActive)
              VaultButton(
                label: 'Continue',
                onPressed: () => context.go(AppRoutes.apps),
              )
            else
              VaultButton(
                label: 'Continue to app selection',
                variant: VaultButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.apps),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.states, required this.method});

  final PermissionStates states;
  final EnforcementMethod method;

  @override
  Widget build(BuildContext context) {
    final active = states.protectionActive;
    final scheme = Theme.of(context).colorScheme;
    final color = active ? AppColors.successLight : AppColors.warningLight;
    final unavailable = method == EnforcementMethod.accessibility
        ? 'Enable Accessibility Service to resume protection.'
        : 'Enable Usage Access and overlay access to resume protection.';
    return VaultCard(
      child: Row(
        children: [
          Icon(
            active ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
            color: color,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Protection active' : 'Protection not active yet',
                  style: AppTextStyles.h4,
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? '${method.displayName} is enabled and enforcing the native lock policy.'
                      : unavailable,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodNote extends StatelessWidget {
  const _MethodNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.required,
    required this.onFix,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final bool required;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: VaultCard(
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: AppTextStyles.h4)),
                      if (required) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Required',
                          style: AppTextStyles.overline.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (granted)
              const Icon(Icons.check_circle, color: AppColors.successLight)
            else
              TextButton(onPressed: onFix, child: const Text('Grant')),
          ],
        ),
      ),
    );
  }
}
