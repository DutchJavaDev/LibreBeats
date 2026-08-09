import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
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

/// Only holds settings that actually do something: server management,
/// offline storage and about. The remaining prototype cards (audio,
/// notifications, ...) come back once their features exist.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // mb below 1gb, gb above
  static String formatBytes(int bytes) {
    const gb = 1024 * 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Color(0xFF1ED760),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon,
      {Color background = const Color(0xFF282828),
      Color color = const Color(0xFFA7A7A7)}) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Future<void> _confirmClearDownloads(BuildContext context) async {
    // grab everything before the dialog await, no context across the gap
    final likedProvider = context.read<LikedProvider>();
    final messenger = ScaffoldMessenger.of(context);
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
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $size?',
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
            'Removes $what and their downloads from this device. '
            'This cannot be undone.',
            style: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete downloads',
                style: TextStyle(color: Color(0xFFE8453C))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await likedProvider.clearAll();
    messenger.showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF282828),
      content: Text('Cleared $what, freed $size',
          style: const TextStyle(color: Colors.white)),
    ));
  }

  // "12 of 13 on disk · 2 playlists · 1 downloading", colored where it matters
  Widget _storageStatus(LikedProvider likedProvider) {
    final pending = likedProvider.pendingTrackCount;
    final failed = likedProvider.failedTrackCount;

    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
        children: [
          TextSpan(
              text: '${likedProvider.totalDownloadedCount} of '
                  '${likedProvider.totalTrackCount} on disk'),
          if (likedProvider.mixCount > 0)
            TextSpan(text: ' · ${likedProvider.mixCount} playlists'),
          if (pending > 0)
            TextSpan(
                text: ' · $pending downloading',
                style: const TextStyle(color: Color(0xFFE8C32E))),
          if (failed > 0)
            TextSpan(
                text: ' · $failed failed',
                style: const TextStyle(color: Color(0xFFE8453C))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final likedProvider = context.watch<LikedProvider>();
    final topInset = MediaQuery.of(context).padding.top;
    final total = likedProvider.totalTrackCount;

    // topInset + top padding (16) + title line (~30) + bottom padding (8)
    final headerHeight = topInset + 16 + 30 + 8;

    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _SettingsHeaderDelegate(
            height: headerHeight,
            child: Container(
              color: const Color(0xFF121212),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 8),
              child: const Text(
                'Settings',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
        ),
        // SERVERS.
        SliverToBoxAdapter(child: _sectionHeader('Servers')),
        const SliverToBoxAdapter(child: ServersSection()),
        // STORAGE.
        SliverToBoxAdapter(child: _sectionHeader('Storage')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // info only, downloads cover both liked beats and mixes
                  // so there is no single place to navigate to
                  ListTile(
                    leading: _iconBox(Icons.favorite_border,
                        color: const Color(0xFF1ED760)),
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text('Liked downloads',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white)),
                        ),
                        Text(formatBytes(likedProvider.offlineBytes),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
                    subtitle: total == 0
                        ? const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text('Nothing downloaded yet',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFFA7A7A7))),
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
                                  backgroundColor: const Color(0xFF282828),
                                  color: const Color(0xFF1ED760),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _storageStatus(likedProvider),
                            ],
                          ),
                  ),
                  if (total > 0) ...[
                    const Divider(
                        indent: 70, height: 1, color: Color(0x1AFFFFFF)),
                    ListTile(
                      onTap: () => _confirmClearDownloads(context),
                      leading: _iconBox(Icons.delete_outline,
                          background: const Color(0xFF2A1215),
                          color: const Color(0xFFE8453C)),
                      title: const Text('Clear liked downloads',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFE8453C))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // ABOUT.
        SliverToBoxAdapter(child: _sectionHeader('About')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // app identity, tapping copies the version for bug reports
                  ListTile(
                    onTap: () {
                      Clipboard.setData(
                          const ClipboardData(text: 'Liberated Beats 0.1.0'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        backgroundColor: Color(0xFF282828),
                        content: Text('Version copied',
                            style: TextStyle(color: Colors.white)),
                      ));
                    },
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/librebeats-icon-1024.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _iconBox(Icons.music_note),
                      ),
                    ),
                    title: const Text('Liberated Beats',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                    subtitle: const Text('0.1.0 · open source',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFA7A7A7))),
                    trailing: const Icon(Icons.copy,
                        size: 14, color: Color(0xFFA7A7A7)),
                  ),
                  const Divider(
                      indent: 70, height: 1, color: Color(0x1AFFFFFF)),
                  ListTile(
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Liberated Beats',
                      applicationVersion: '0.1.0',
                    ),
                    leading: _iconBox(Icons.description),
                    title: const Text('Licenses',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                    subtitle: const Text('Third-party open source licenses',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFA7A7A7))),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFA7A7A7)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
