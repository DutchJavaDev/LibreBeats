import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/providers/theme_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:provider/provider.dart';

import '../widgets/servers_section.dart';

// same trick as the search screen, keeps the title pinned while scrolling
class _SettingsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _SettingsHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _SettingsHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

/// Only holds settings that actually do something: appearance, server
/// management, offline storage and about. The remaining prototype cards
/// (audio, notifications, ...) come back once their features exist.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // mb below 1gb, gb above
  static String formatBytes(int bytes) {
    const gb = 1024 * 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _iconBox(BuildContext context, IconData icon,
      {Color? background, Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: background ?? scheme.surfaceContainerHighest,
          shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: color ?? scheme.onSurfaceVariant),
    );
  }

  // wraps a settings block in the outlined card, 16px gutters
  Widget _card(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(clipBehavior: Clip.antiAlias, child: child),
      );

  Future<void> _confirmClearDownloads(BuildContext context) async {
    // grab everything before the dialog await, no context across the gap
    final likedProvider = context.read<LikedProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final error = Theme.of(context).colorScheme.error;
    final size = formatBytes(likedProvider.offlineBytes);
    final beats = likedProvider.count;
    final mixes = likedProvider.mixCount;
    final what = [
      if (beats > 0) '$beats liked ${beats == 1 ? 'beat' : 'beats'}',
      if (mixes > 0) '$mixes ${mixes == 1 ? 'playlist' : 'playlists'}',
    ].join(' and ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $size?'),
        content: Text('Removes $what and their downloads from this device. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: error),
            child: const Text('Delete downloads'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await likedProvider.clearAll();
    messenger.showSnackBar(SnackBar(
      content: Text('Cleared $what, freed $size'),
    ));
  }

  // "12 of 13 on disk · 2 playlists · 1 downloading", colored where it matters
  Widget _storageStatus(BuildContext context, LikedProvider likedProvider) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final pending = likedProvider.pendingTrackCount;
    final failed = likedProvider.failedTrackCount;

    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall,
        children: [
          TextSpan(
              text: '${likedProvider.totalDownloadedCount} of '
                  '${likedProvider.totalTrackCount} on disk'),
          if (likedProvider.mixCount > 0)
            TextSpan(text: ' · ${likedProvider.mixCount} playlists'),
          if (pending > 0)
            TextSpan(
                text: ' · $pending downloading',
                style: TextStyle(color: tokens.warning)),
          if (failed > 0)
            TextSpan(
                text: ' · $failed failed',
                style: TextStyle(color: theme.colorScheme.error)),
        ],
      ),
    );
  }

  // one appearance choice: icon, label, check when active
  Widget _themeModeRow(BuildContext context, ThemeController controller,
      ThemeMode value, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = controller.mode == value;
    return ListTile(
      onTap: () => controller.setMode(value),
      leading: _iconBox(context, icon, color: selected ? scheme.primary : null),
      title: Text(label),
      trailing: selected
          ? Container(
              width: 20,
              height: 20,
              decoration:
                  BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              child: Icon(Icons.check, size: 13, color: scheme.onPrimary),
            )
          : Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outline),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likedProvider = context.watch<LikedProvider>();
    final themeController = context.watch<ThemeController>();
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final total = likedProvider.totalTrackCount;

    // topInset + top padding (20) + title line (~30) + rule gap (6+3) + bottom (8)
    final headerHeight = topInset + 20 + 30 + 9 + 8;

    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _SettingsHeaderDelegate(
            height: headerHeight,
            child: Container(
              color: theme.colorScheme.surface,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  const BrandRule(),
                ],
              ),
            ),
          ),
        ),
        // Appearance: dark is the default, light and follow-the-system opt in.
        const SliverToBoxAdapter(child: SectionHeader('Appearance')),
        SliverToBoxAdapter(
          child: _card(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _themeModeRow(context, themeController, ThemeMode.dark,
                    Icons.dark_mode_outlined, 'Dark'),
                const Divider(indent: 70),
                _themeModeRow(context, themeController, ThemeMode.light,
                    Icons.light_mode_outlined, 'Light'),
                const Divider(indent: 70),
                _themeModeRow(context, themeController, ThemeMode.system,
                    Icons.smartphone_outlined, 'System'),
              ],
            ),
          ),
        ),
        // Servers.
        const SliverToBoxAdapter(child: SectionHeader('Servers')),
        const SliverToBoxAdapter(child: ServersSection()),
        // Storage.
        const SliverToBoxAdapter(child: SectionHeader('Storage')),
        SliverToBoxAdapter(
          child: _card(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // info only, downloads cover both liked beats and mixes
                // so there is no single place to navigate to
                ListTile(
                  leading: _iconBox(context, Icons.favorite_border,
                      color: theme.colorScheme.primary),
                  title: Row(
                    children: [
                      const Expanded(child: Text('Liked downloads')),
                      Text(formatBytes(likedProvider.offlineBytes),
                          style: theme.textTheme.titleSmall!
                              .copyWith(fontSize: 13)),
                    ],
                  ),
                  // bookmarks-only platforms get told why instead of a
                  // progress bar that never moves
                  subtitle: !likedProvider.supportsDownloads
                      ? const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child:
                              Text("downloads need AAC audio, the servers ship "
                                  "opus which iOS can't decode, likes stay "
                                  "streaming bookmarks here"),
                        )
                      : total == 0
                          ? const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text('Nothing downloaded yet'),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: likedProvider.totalDownloadedCount /
                                        total,
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _storageStatus(context, likedProvider),
                              ],
                            ),
                ),
                if (total > 0) ...[
                  const Divider(indent: 70),
                  ListTile(
                    onTap: () => _confirmClearDownloads(context),
                    leading: _iconBox(context, Icons.delete_outline,
                        background:
                            theme.extension<LbTokens>()!.dangerContainer,
                        color: theme.colorScheme.error),
                    title: Text('Clear liked downloads',
                        style: theme.textTheme.titleSmall!
                            .copyWith(color: theme.colorScheme.error)),
                  ),
                ],
              ],
            ),
          ),
        ),
        // About.
        const SliverToBoxAdapter(child: SectionHeader('About')),
        SliverToBoxAdapter(
          child: _card(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // app identity, tapping copies the version for bug reports
                ListTile(
                  onTap: () {
                    Clipboard.setData(
                        const ClipboardData(text: 'Liberated Beats 0.1.0'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Version copied'),
                    ));
                  },
                  leading: const LbEmblem(size: 38),
                  title: const Text('Liberated Beats'),
                  subtitle: const Text('0.1.0 · open source'),
                  trailing: Icon(Icons.copy,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
                const Divider(indent: 70),
                ListTile(
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Liberated Beats',
                    applicationVersion: '0.1.0',
                  ),
                  leading: _iconBox(context, Icons.description),
                  title: const Text('Licenses'),
                  subtitle: const Text('Third-party open source licenses'),
                  trailing: Icon(Icons.chevron_right,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
