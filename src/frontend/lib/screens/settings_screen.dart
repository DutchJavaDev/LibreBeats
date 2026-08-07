import 'package:flutter/material.dart';

import '../widgets/servers_section.dart';

/// Only holds settings that actually do something: server management and
/// about. The prototype cards (audio, downloads, notifications, ...) come
/// back once their features exist.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
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

  Widget _iconBox(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: Color(0xFF282828), shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: const Color(0xFFA7A7A7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 8),
            child: const Text(
              'Settings',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
        // SERVERS.
        SliverToBoxAdapter(child: _sectionHeader('Servers')),
        const SliverToBoxAdapter(child: ServersSection()),
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
                  ListTile(
                    leading: _iconBox(Icons.info_outline),
                    title: const Text('Version',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                    subtitle: const Text('Liberated Beats 0.1.0 (open source)',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFA7A7A7))),
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
