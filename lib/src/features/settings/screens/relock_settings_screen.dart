import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/models/relock_policy.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';

class RelockSettingsScreen extends ConsumerWidget {
  const RelockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config =
        ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    final controller = ref.read(configControllerProvider.notifier);
    final policy = config.relock;

    return Scaffold(
      appBar: AppBar(title: const Text('Relock behavior')),
      body: SafeArea(
        child: RadioGroup<RelockMode>(
          groupValue: policy.mode,
          onChanged: (mode) {
            if (mode != null) controller.setRelock(policy.copyWith(mode: mode));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'When should a locked app relock after you unlock it?',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const RadioListTile<RelockMode>(
                value: RelockMode.immediately,
                title: Text('When you leave the app'),
                subtitle: Text('Relocks the instant you switch away'),
              ),
              const RadioListTile<RelockMode>(
                value: RelockMode.afterTimeout,
                title: Text('After a timeout'),
                subtitle: Text('Stays open briefly if you come back'),
              ),
              if (policy.mode == RelockMode.afterTimeout)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final choice in RelockPolicy.timeoutChoices)
                        ChoiceChip(
                          label: Text('${choice.inMinutes} min'),
                          selected: policy.timeout == choice,
                          onSelected: (_) => controller
                              .setRelock(policy.copyWith(timeout: choice)),
                        ),
                    ],
                  ),
                ),
              const RadioListTile<RelockMode>(
                value: RelockMode.onScreenOff,
                title: Text('When the screen turns off'),
                subtitle: Text('Stays open across app switches'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
