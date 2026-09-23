import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/core/router/app_router.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';
import 'package:openlock/src/features/schedules/widgets/schedule_format.dart';

class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config =
        ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final schedules = config.schedules;

    return Scaffold(
      appBar: AppBar(title: const Text('Focus schedules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newSchedule),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: SafeArea(
        child: schedules.isEmpty
            ? const VaultEmptyState(
                icon: Icons.schedule_rounded,
                message:
                    'No schedules yet.\nLock chosen apps during set hours — '
                    'like social apps 9-5 on weekdays.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: schedules.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  return _ScheduleCard(
                    schedule: schedule,
                    onTap: () => context.push(
                      '${AppRoutes.editSchedule}/${schedule.id}',
                    ),
                    onToggle: (value) => ref
                        .read(configControllerProvider.notifier)
                        .upsertSchedule(schedule.copyWith(enabled: value)),
                  );
                },
              ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onTap,
    required this.onToggle,
  });

  final LockSchedule schedule;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VaultCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule.name, style: AppTextStyles.h4),
                const SizedBox(height: 2),
                Text(
                  ScheduleFormat.summary(schedule),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  '${schedule.packages.length} apps',
                  style: AppTextStyles.caption
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: schedule.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
