import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:najath_auth/najath_auth.dart';
import 'package:najath_core/najath_core.dart';
import 'package:najath_design_system/najath_design_system.dart';
import 'package:najath_local_db/najath_local_db.dart';
import 'package:najath_sync/najath_sync.dart';

import '../../app/router/route_path.dart';

/// The post-sign-in shell.
///
/// Navigation is built entirely from the access policy for the **active
/// shell**, so a screen the admin console revokes disappears from the bar
/// rather than leading somewhere the user is bounced out of. One binary, three
/// experiences — teacher, parent, warden — resolved by role at runtime.
class HomeShell extends ConsumerWidget {
  const HomeShell({required this.screenId, required this.child, super.key});

  /// Which registry screen this route renders, so the shell can highlight it.
  final String screenId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched once here so background sync stays triggered for the whole
    // session — connectivity returning and writes queuing both re-run a pass.
    ref
      ..watch(syncKeepAliveProvider)
      ..watch(authHooksProvider);

    final policy = ref.watch(accessNotifierProvider);
    final destinations = policy.visibleDestinations;
    final user = ref.watch(currentUserProvider);

    if (destinations.isEmpty) return const _NoDestinationsView();

    final index = destinations.indexWhere((d) => d.id == screenId);
    final selected = index < 0 ? 0 : index;
    final isWide = context.screenType == ScreenType.desktop;

    final body = Column(
      children: [
        const OfflineBanner(),
        if (policy.isFallback) const FallbackPolicyNotice(),
        const SyncProgressBanner(),
        Expanded(child: child),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(ScreenRegistry.byId(screenId)?.label ?? 'Najath'),
        actions: [
          const _PendingWritesButton(),
          if (policy.hasMultipleRoles)
            IconButton(
              tooltip: 'Switch role',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => _showRoleSwitcher(context, ref, policy),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RoutePath.settings),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: CircleAvatar(
                radius: 16,
                child: Text(user.initials, style: context.text.labelMedium),
              ),
            ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: selected,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => _open(context, ref, destinations[i].id),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(_iconFor(d.id)),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isWide || destinations.length < 2
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => _open(context, ref, destinations[i].id),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(_iconFor(d.id)), label: d.label),
              ],
            ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, String id) {
    // Ward-scoped destinations need the selected ward; the provider persists it
    // so switching tabs never loses which child is being viewed.
    final wardId = ref.read(selectedWardProvider);
    context.go(RoutePath.forScreen(id, wardId: wardId));
  }

  /// Switching role rebuilds the router and re-scopes every provider — without
  /// re-authenticating. A teacher who is also a parent uses this daily.
  void _showRoleSwitcher(BuildContext context, WidgetRef ref, AccessPolicy policy) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final role in policy.roles)
                ListTile(
                  leading: Icon(
                    role == policy.activeRole
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(_roleLabel(role)),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(accessNotifierProvider.notifier).switchRole(role);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleLabel(AppRole role) => switch (role) {
  AppRole.superAdmin => 'System administrator',
  AppRole.admin => 'Office admin',
  AppRole.deptHead => 'Department head',
  AppRole.teacher => 'Teacher',
  AppRole.hostelWarden => 'Hostel warden',
  AppRole.canteenManager => 'Canteen manager',
  AppRole.accountant => 'Accountant',
  AppRole.parent => 'Parent',
};

/// What a principal sees when the matrix grants them nothing — better than an
/// empty shell with no explanation.
class _NoDestinationsView extends StatelessWidget {
  const _NoDestinationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Najath')),
      body: const EmptyView(
        message:
            'Your account has no sections enabled yet.\n'
            'The academy office can turn them on for your role.',
        icon: Icons.lock_outline,
      ),
    );
  }
}

class _PendingWritesButton extends ConsumerWidget {
  const _PendingWritesButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWritesProvider).value ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Unsynced work',
      onPressed: () => context.push(RoutePath.unsynced),
      icon: Badge.count(
        count: pending.length,
        child: const Icon(Icons.cloud_upload_outlined),
      ),
    );
  }
}

IconData _iconFor(String screenId) => switch (screenId) {
  ScreenId.today => Icons.today_outlined,
  ScreenId.batches => Icons.groups_outlined,
  ScreenId.batchHifz => Icons.menu_book_outlined,
  ScreenId.teacherReports => Icons.insights_outlined,
  ScreenId.wards => Icons.family_restroom_outlined,
  ScreenId.wardHifz => Icons.menu_book_outlined,
  ScreenId.wardAcademics => Icons.school_outlined,
  ScreenId.wardLeave => Icons.event_busy_outlined,
  ScreenId.notices => Icons.campaign_outlined,
  ScreenId.rollcall => Icons.checklist_outlined,
  ScreenId.gatePass => Icons.qr_code_scanner_outlined,
  ScreenId.occupancy => Icons.bed_outlined,
  _ => Icons.circle_outlined,
};
