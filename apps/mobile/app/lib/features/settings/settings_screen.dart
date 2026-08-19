import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';
import 'package:najath_local_db/najath_local_db.dart';

import '../../flavors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final policy = ref.watch(accessNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: CircleAvatar(child: Text(user.initials)),
              title: Text(user.name),
              subtitle: Text(
                '${user.displayIdentifier} · ${policy.activeRole.label(l10n)}',
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settingsAppearance),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {themeMode},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (selection) =>
                  ref.read(themeModeProvider.notifier).set(selection.first),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(l10n.settingsYourAccess),
            subtitle: Text(
              '${l10n.settingsAccessSummary(policy.screens.length, policy.permissions.wires.length)}'
              '${policy.isFallback ? ' (${l10n.settingsAccessDefaults})' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAccessSheet(context, l10n, policy),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(l10n.settingsRefreshAccess),
            subtitle: Text(l10n.settingsRefreshAccessHint),
            onTap: () async {
              await ref.read(accessNotifierProvider.notifier).refresh();
              if (context.mounted) context.showSnack(l10n.settingsAccessRefreshed);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(l10n.settingsClearCache),
            subtitle: Text(l10n.settingsClearCacheHint),
            onTap: () async {
              // The outbox is deliberately untouched: unsent work is the
              // teacher's, not ours to discard.
              await ref.read(appDatabaseProvider).clearCachedData();
              if (context.mounted) context.showSnack(l10n.settingsCacheCleared);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.actionSignOut),
            textColor: context.colors.error,
            iconColor: context.colors.error,
            onTap: () => unawaited(ref.read(authNotifierProvider.notifier).signOut()),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${F.title} · ${Env.current.env.name}',
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Shows exactly what the role matrix grants. Worth surfacing: when a teacher
  /// says "I can't see exams", this answers it without a support call.
  void _showAccessSheet(BuildContext context, L10n l10n, AccessPolicy policy) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Text(l10n.settingsSections, style: context.text.titleMedium),
            const SizedBox(height: 8),
            for (final screen in ScreenRegistry.all)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  policy.canOpen(screen.id)
                      ? Icons.check_circle_outline
                      : Icons.remove_circle_outline,
                  color: policy.canOpen(screen.id)
                      ? AppColors.success
                      : context.colors.onSurfaceVariant,
                ),
                title: Text(screenLabel(l10n, screen.id)),
                subtitle: Text(screen.requires.wire),
              ),
          ],
        ),
      ),
    );
  }
}
