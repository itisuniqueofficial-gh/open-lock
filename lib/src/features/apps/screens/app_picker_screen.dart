import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_update/core_update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/core/di.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/apps/services/app_list_filter.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

class AppPickerScreen extends ConsumerWidget {
  const AppPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(installedAppsProvider);
    final configAsync = ref.watch(configControllerProvider);
    final query = ref.watch(appSearchQueryProvider);
    final config = configAsync.valueOrNull ?? LockConfig.empty;
    final autoLocked =
        ref.watch(autoLockedPackagesProvider).valueOrNull ?? const <String>[];
    // Apps are "locked" in the UI if the user picked them OR the monitor
    // auto-locked them as newly installed.
    final effectiveLocked = {...config.lockedPackages, ...autoLocked};

    return Scaffold(
      appBar: AppBar(title: const Text('Locked apps')),
      body: SafeArea(
        child: appsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const VaultEmptyState(
            icon: Icons.error_outline,
            message: 'Could not load installed apps.',
          ),
          data: (apps) {
            final visible = AppListFilter.apply(
              apps: apps,
              lockedPackages: effectiveLocked,
              query: query,
            );
            final lockedCount = AppListFilter.lockedCount(
              apps: apps,
              lockedPackages: effectiveLocked,
            );
            return Column(
              children: [
                const _UpdateBannerCard(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    onChanged: (value) =>
                        ref.read(appSearchQueryProvider.notifier).state = value,
                    decoration: const InputDecoration(
                      hintText: 'Search apps',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                _LockNewAppsTile(config: config),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$lockedCount locked',
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const VaultEmptyState(
                          icon: Icons.apps_outlined,
                          message: 'No apps match your search.',
                        )
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final app = visible[index];
                            final locked =
                                effectiveLocked.contains(app.packageName);
                            return _AppTile(
                              app: app,
                              locked: locked,
                              onToggle: () async {
                                final notifier = ref.read(
                                  configControllerProvider.notifier,
                                );
                                final inManual = config.lockedPackages
                                    .contains(app.packageName);
                                final inAuto =
                                    autoLocked.contains(app.packageName);
                                if (locked) {
                                  // Turn off: clear from both manual and auto.
                                  if (inManual) {
                                    await notifier.toggleApp(app.packageName);
                                  }
                                  if (inAuto) {
                                    await ref
                                        .read(enforcementBridgeProvider)
                                        .removeAutoLocked(app.packageName);
                                    ref.invalidate(autoLockedPackagesProvider);
                                  }
                                } else {
                                  await notifier.toggleApp(app.packageName);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LockNewAppsTile extends ConsumerWidget {
  const _LockNewAppsTile({required this.config});

  final LockConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      value: config.lockNewApps,
      onChanged: (value) =>
          ref.read(configControllerProvider.notifier).setLockNewApps(value),
      secondary: const Icon(Icons.new_releases_outlined),
      title: const Text('Lock newly installed apps'),
      subtitle: const Text('Automatically guard apps you install later'),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.locked,
    required this.onToggle,
  });

  final InstalledApp app;
  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      value: locked,
      onChanged: (_) => onToggle(),
      secondary: SizedBox(
        width: 40,
        height: 40,
        child: app.icon != null
            ? Image.memory(
                app.icon!,
                gaplessPlayback: true,
                // Icons arrive as 96px PNGs; decode at that size (not full
                // resolution) to keep the scrolling list light.
                cacheWidth: 96,
                cacheHeight: 96,
              )
            : Icon(Icons.android, color: scheme.onSurfaceVariant),
      ),
      title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        app.packageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// "Update available" card, shown when a newer GitHub release exists and the
/// user hasn't dismissed it this session.
class _UpdateBannerCard extends ConsumerWidget {
  const _UpdateBannerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateCheckProvider).valueOrNull;
    final dismissed = ref.watch(updateDismissedProvider);
    if (info == null || dismissed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: UpdateBanner(
        info: info,
        onUpdate: () => ref.read(updateServiceProvider).openDownload(info),
        onDismiss: () =>
            ref.read(updateDismissedProvider.notifier).state = true,
      ),
    );
  }
}
