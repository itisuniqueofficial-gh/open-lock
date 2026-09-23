import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openlock/src/features/apps/providers/apps_providers.dart';
import 'package:openlock/src/features/enforcement/models/lock_config.dart';
import 'package:openlock/src/features/enforcement/providers/config_providers.dart';
import 'package:openlock/src/features/schedules/models/lock_schedule.dart';
import 'package:openlock/src/features/schedules/widgets/schedule_format.dart';

class ScheduleEditorScreen extends ConsumerStatefulWidget {
  const ScheduleEditorScreen({this.scheduleId, super.key});

  final String? scheduleId;

  @override
  ConsumerState<ScheduleEditorScreen> createState() =>
      _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen> {
  final _nameController = TextEditingController(text: 'Focus time');
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  int _start = 9 * 60;
  int _end = 17 * 60;
  Set<String> _packages = {};
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _hydrate(LockConfig config) {
    if (_initialized || widget.scheduleId == null) return;
    LockSchedule? existing;
    for (final s in config.schedules) {
      if (s.id == widget.scheduleId) {
        existing = s;
        break;
      }
    }
    if (existing != null) {
      _nameController.text = existing.name;
      _weekdays = Set.of(existing.weekdays);
      _start = existing.startMinutes;
      _end = existing.endMinutes;
      _packages = Set.of(existing.packages);
    }
    _initialized = true;
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (picked == null) return;
    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (isStart) {
        _start = minutes;
      } else {
        _end = minutes;
      }
    });
  }

  Future<void> _save() async {
    final schedule = LockSchedule(
      id: widget.scheduleId,
      name: _nameController.text.trim().isEmpty
          ? 'Schedule'
          : _nameController.text.trim(),
      packages: _packages,
      weekdays: _weekdays,
      startMinutes: _start,
      endMinutes: _end,
    );
    await ref.read(configControllerProvider.notifier).upsertSchedule(schedule);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    if (widget.scheduleId != null) {
      await ref
          .read(configControllerProvider.notifier)
          .deleteSchedule(widget.scheduleId!);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final config =
        ref.watch(configControllerProvider).valueOrNull ?? LockConfig.empty;
    _hydrate(config);
    final appsAsync = ref.watch(installedAppsProvider);
    final isEditing = widget.scheduleId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit schedule' : 'New schedule'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            VaultTextField(label: 'Name', controller: _nameController),
            const SizedBox(height: AppSpacing.lg),
            const Text('Active days', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(ScheduleFormat.weekdayLabels[day - 1]),
                    selected: _weekdays.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _weekdays.add(day);
                      } else {
                        _weekdays.remove(day);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Start',
                    value: ScheduleFormat.time(_start),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _TimeField(
                    label: 'End',
                    value: ScheduleFormat.time(_end),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            if (_end < _start)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Overnight window — ends the next morning.',
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Apps to lock', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            appsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Could not load apps.'),
              data: (apps) {
                final sorted = [...apps]..sort((a, b) =>
                    a.label.toLowerCase().compareTo(b.label.toLowerCase()));
                return Column(
                  children: [
                    for (final app in sorted)
                      CheckboxListTile(
                        value: _packages.contains(app.packageName),
                        onChanged: (checked) => setState(() {
                          if (checked ?? false) {
                            _packages.add(app.packageName);
                          } else {
                            _packages.remove(app.packageName);
                          }
                        }),
                        title: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            VaultButton(label: 'Save schedule', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onTap,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTextStyles.body),
          ),
        ),
      ],
    );
  }
}
