import 'dart:io';

import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:openlock/src/core/interfaces/enforcement_bridge.dart';
import 'package:openlock/src/features/intruder/providers/intruder_providers.dart';

class IntruderLogScreen extends ConsumerWidget {
  const IntruderLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(intruderControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intruder log'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(intruderControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          if ((async.valueOrNull ?? const []).isNotEmpty)
            IconButton(
              onPressed: () =>
                  ref.read(intruderControllerProvider.notifier).clearAll(),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const VaultEmptyState(
            icon: Icons.error_outline,
            message: 'Could not load the intruder log.',
          ),
          data: (records) {
            if (records.isEmpty) {
              return const VaultEmptyState(
                icon: Icons.verified_user_outlined,
                message:
                    'No intruder events.\nIf someone fails your PIN too many '
                    'times, a snapshot appears here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: records.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _IntruderCard(
                record: records[index],
                onDelete: () => ref
                    .read(intruderControllerProvider.notifier)
                    .delete(records[index].id),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IntruderCard extends StatelessWidget {
  const _IntruderCard({required this.record, required this.onDelete});

  final IntruderRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = DateFormat.yMMMd().add_jm().format(record.timestamp);
    final photo = record.photoPath;
    final hasPhoto = photo != null && File(photo).existsSync();
    return VaultCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: SizedBox(
              width: 56,
              height: 56,
              child: hasPhoto
                  ? Image.file(File(photo), fit: BoxFit.cover)
                  : ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.no_photography_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.packageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4,
                ),
                const SizedBox(height: 2),
                Text(
                  when,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
