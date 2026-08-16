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
/// Its navigation is built entirely from the access policy, so a screen the
/// admin console revokes disappears from the rail and the bottom bar rather
/// than leading somewhere the user is bounced out of.
class HomeShell extends ConsumerWidget {
  const HomeShell({this.tabIndex = 0, super.key});

  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched once here so background sync stays triggered for the whole
    // session — connectivity returning and writes queuing both re-run a pass.
    ref
      ..watch(syncKeepAliveProvider)
      ..watch(authHooksProvider);

    final destinations = ref.watch(visibleDestinationsProvider);
    final user = ref.watch(currentUserProvider);
    final isFallback = ref.watch(isPolicyFallbackProvider);

    if (destinations.isEmpty) {
      return const _NoDestinationsView();
    }

    final index = tabIndex.clamp(0, destinations.length - 1);
    final isWide = context.screenType == ScreenType.desktop;

    final body = Column(
      children: [
        const OfflineBanner(),
        if (isFallback) const FallbackPolicyNotice(),
        const SyncProgressBanner(),
        Expanded(child: _Landing(destination: destinations[index])),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[index].label),
        actions: [
          const _PendingWritesButton(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RoutePath.settings()),
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
                  selectedIndex: index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => _open(context, destinations[i].id, i),
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: Icon(_iconFor(destination.id)),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => _open(context, destinations[i].id, i),
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(_iconFor(destination.id)),
                    label: destination.label,
                  ),
              ],
            ),
    );
  }

  /// The tab index lives in the URL, so a refresh or a restored deep link comes
  /// back to the same tab.
  void _open(BuildContext context, String screenId, int index) {
    if (screenId == ScreenId.dashboard) {
      context.go(RoutePath.home(tabIndex: index));
      return;
    }
    context.go('${RoutePath.forScreen(screenId)}?t=$index');
  }
}

/// Placeholder landing for a destination, until each module ships its own.
class _Landing extends StatelessWidget {
  const _Landing({required this.destination});

  final ScreenDefinition destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(destination.id),
              size: 48,
              color: context.colors.primary,
            ),
            const SizedBox(height: 12),
            Text(destination.label, style: context.text.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Needs ${destination.requires.wire}',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a principal sees when the matrix grants them nothing at all — better
/// than an empty shell with no explanation.
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
      onPressed: () => context.push(RoutePath.unsynced()),
      icon: Badge.count(
        count: pending.length,
        child: const Icon(Icons.cloud_upload_outlined),
      ),
    );
  }
}

IconData _iconFor(String screenId) => switch (screenId) {
  ScreenId.dashboard => Icons.home_outlined,
  ScreenId.attendance => Icons.fact_check_outlined,
  ScreenId.hifz => Icons.menu_book_outlined,
  ScreenId.academics => Icons.groups_outlined,
  ScreenId.exams => Icons.assignment_outlined,
  ScreenId.progress => Icons.trending_up,
  ScreenId.leave => Icons.event_busy_outlined,
  ScreenId.hostel => Icons.bed_outlined,
  ScreenId.canteen => Icons.restaurant_outlined,
  ScreenId.activities => Icons.emoji_events_outlined,
  ScreenId.announcements => Icons.campaign_outlined,
  ScreenId.profile => Icons.person_outline,
  _ => Icons.circle_outlined,
};
