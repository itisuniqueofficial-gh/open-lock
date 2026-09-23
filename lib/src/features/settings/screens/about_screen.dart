import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:openlock/src/core/app_info.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.lock_rounded, size: 64, color: scheme.primary),
                  const SizedBox(height: AppSpacing.md),
                  const Text(AppInfo.name, style: AppTextStyles.h1),
                  Text(
                    'Version ${AppInfo.version}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            VaultCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          color: scheme.primary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Private by design', style: AppTextStyles.h4),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Open Lock runs entirely on your device. Your lock settings '
                    'and any intruder photos are encrypted and never leave '
                    'your phone. No account, no ads, no tracking.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const VaultCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.groups_outlined,
                    label: 'Maintained by',
                    value: AppInfo.maintainer,
                  ),
                  Divider(height: AppSpacing.lg),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Developed by',
                    value: AppInfo.developer,
                  ),
                  Divider(height: AppSpacing.lg),
                  _InfoRow(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: AppInfo.website,
                  ),
                  Divider(height: AppSpacing.lg),
                  _InfoRow(
                    icon: Icons.code_outlined,
                    label: 'Developer',
                    value: AppInfo.developerWebsite,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Open Lock is open-source software, released under the MIT '
              'License.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              SelectableText(value, style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
