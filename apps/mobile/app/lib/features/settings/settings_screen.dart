import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_sync/najath_sync.dart';

import '../../flavors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final policy = ref.watch(accessNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: CircleAvatar(child: Text(user.initials)),
              title: Text(user.name),
              subtitle: Text(
                '${user.displayIdentifier} · ${policy.activeRole.wire}',
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Appearance'),
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
            title: const Text('Your access'),
            subtitle: Text(
              '${policy.screens.length} section'
              '${policy.screens.length == 1 ? '' : 's'} · '
              '${policy.permissions.wires.length} permissions'
              '${policy.isFallback ? ' (defaults)' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAccessSheet(context, policy),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh access'),
            subtitle: const Text('Pick up changes made by the academy office'),
            onTap: () async {
              await ref.read(accessNotifierProvider.notifier).refresh();
              if (context.mounted) context.showSnack('Access refreshed');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear cached data'),
            subtitle: const Text('Keeps anything not yet sent'),
            onTap: () async {
              await ref.read(cacheStoreProvider).clearDataCaches();
              await ref.read(syncStateStoreProvider).resetAll();
              if (context.mounted) context.showSnack('Cached data cleared');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
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
  void _showAccessSheet(BuildContext context, AccessPolicy policy) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Text('Sections', style: context.text.titleMedium),
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
                title: Text(screen.label),
                subtitle: Text(screen.requires.wire),
              ),
          ],
        ),
      ),
    );
  }
}
