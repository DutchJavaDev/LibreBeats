import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/server_registry.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _normalizeVolume = true;
  bool _gaplessPlayback = true;
  bool _wifiOnly = true;
  bool _newReleases = true;
  bool _playlistUpdates = false;
  bool _darkMode = true;
  bool _mobileData = true;
  bool _privateSession = false;

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

  Widget _settingToggle({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: _iconBox(icon),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)))
          : null,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _settingNav({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      onTap: () {},
      leading: _iconBox(icon),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
      subtitle: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFA7A7A7)),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Color(0xFF282828), shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: const Color(0xFFA7A7A7)),
    );
  }

  Widget _card(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: _withDividers(children).toList()),
      ),
    );
  }

  // Interleaves a divider between every child except after the last.
  Iterable<Widget> _withDividers(List<Widget> children) sync* {
    for (var i = 0; i < children.length; i++) {
      yield children[i];
      if (i != children.length - 1) {
        yield const Divider(indent: 70, height: 1, color: Color(0x1AFFFFFF));
      }
    }
  }

  // --- Servers section ------------------------------------------------------

  Color _statusColor(ServerStatus status) => switch (status) {
        ServerStatus.healthy => const Color(0xFF1ED760),
        ServerStatus.connecting => const Color(0xFFE8C32E),
        ServerStatus.failed => const Color(0xFFE8453C),
      };

  String _statusLabel(ServerStatus status) => switch (status) {
        ServerStatus.healthy => 'Connected',
        ServerStatus.connecting => 'Connecting…',
        ServerStatus.failed => 'Unreachable',
      };

  Widget _serversCard(ServerRegistry registry) {
    return _card([
      for (final server in registry.servers)
        ListTile(
          leading: _iconBox(Icons.dns),
          title: Text(server.host,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          subtitle: Text(_statusLabel(server.status),
              style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7))),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _statusColor(server.status),
                  shape: BoxShape.circle,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Color(0xFFA7A7A7)),
                onPressed: () => registry.removeServer(server),
              ),
            ],
          ),
        ),
      ListTile(
        onTap: _showAddServerDialog,
        leading: _iconBox(Icons.add),
        title: const Text('Add server',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        subtitle: const Text('Connect another LibreBeats backend',
            style: TextStyle(fontSize: 12, color: Color(0xFFA7A7A7))),
      ),
    ]);
  }

  Future<void> _showAddServerDialog() async {
    final urlController = TextEditingController();
    final keyController = TextEditingController();
    final registry = context.read<ServerRegistry>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Add server',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://your-server.example.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Publishable key',
                hintText: 'sb_publishable_…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFA7A7A7))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add',
                style: TextStyle(color: Color(0xFF1ED760))),
          ),
        ],
      ),
    );

    final url = urlController.text.trim();
    final key = keyController.text.trim();
    urlController.dispose();
    keyController.dispose();

    if (submitted != true || url.isEmpty || key.isEmpty || !mounted) return;

    // Validates by signing in — the server is only kept when that succeeds.
    final added = await registry.addServer(url, key);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added
          ? 'Connected to ${Uri.tryParse(url)?.host ?? url}'
          : 'Could not connect to server'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // watch: status dots update live as servers connect, fail, or get removed.
    final registry = context.watch<ServerRegistry>();
    final topInset = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        // Profile header.
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF121212)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1DB954), Color(0xFF158A3E)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('L', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('libre_user', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Free plan · local library', style: TextStyle(fontSize: 13, color: Color(0xFFA7A7A7))),
                  ],
                ),
              ],
            ),
          ),
        ),
        // SERVERS.
        SliverToBoxAdapter(child: _sectionHeader('Servers')),
        SliverToBoxAdapter(child: _serversCard(registry)),
        // AUDIO.
        SliverToBoxAdapter(child: _sectionHeader('Audio')),
        SliverToBoxAdapter(
          child: _card([
            _settingToggle(
              icon: Icons.graphic_eq,
              label: 'Normalize volume',
              subtitle: 'Keep volume consistent across tracks',
              value: _normalizeVolume,
              onChanged: (v) => setState(() => _normalizeVolume = v),
            ),
            _settingNav(icon: Icons.high_quality, label: 'Audio quality', value: 'Very high (320 kbps)'),
            _settingToggle(
              icon: Icons.music_note,
              label: 'Gapless playback',
              subtitle: 'Play tracks without silence',
              value: _gaplessPlayback,
              onChanged: (v) => setState(() => _gaplessPlayback = v),
            ),
            _settingNav(icon: Icons.equalizer, label: 'Equalizer', value: 'Flat (default)'),
          ]),
        ),
        // DOWNLOADS.
        SliverToBoxAdapter(child: _sectionHeader('Downloads')),
        SliverToBoxAdapter(
          child: _card([
            _settingToggle(
              icon: Icons.wifi,
              label: 'Download over Wi-Fi only',
              value: _wifiOnly,
              onChanged: (v) => setState(() => _wifiOnly = v),
            ),
            _settingNav(icon: Icons.download, label: 'Download quality', value: 'High (160 kbps)'),
            _settingNav(icon: Icons.folder, label: 'Storage location', value: '/sdcard/Music/LiberatedBeats'),
          ]),
        ),
        // NOTIFICATIONS.
        SliverToBoxAdapter(child: _sectionHeader('Notifications')),
        SliverToBoxAdapter(
          child: _card([
            _settingToggle(
              icon: Icons.new_releases,
              label: 'New releases',
              subtitle: 'Artists you follow',
              value: _newReleases,
              onChanged: (v) => setState(() => _newReleases = v),
            ),
            _settingToggle(
              icon: Icons.playlist_add_check,
              label: 'Playlist updates',
              subtitle: 'Collaborative playlists',
              value: _playlistUpdates,
              onChanged: (v) => setState(() => _playlistUpdates = v),
            ),
          ]),
        ),
        // DISPLAY.
        SliverToBoxAdapter(child: _sectionHeader('Display')),
        SliverToBoxAdapter(
          child: _card([
            _settingToggle(
              icon: Icons.dark_mode,
              label: 'Dark mode',
              value: _darkMode,
              onChanged: (v) => setState(() => _darkMode = v),
            ),
            _settingNav(icon: Icons.language, label: 'Language', value: 'English (US)'),
          ]),
        ),
        // PRIVACY & NETWORK.
        SliverToBoxAdapter(child: _sectionHeader('Privacy & Network')),
        SliverToBoxAdapter(
          child: _card([
            _settingToggle(
              icon: Icons.signal_cellular_alt,
              label: 'Stream over mobile data',
              value: _mobileData,
              onChanged: (v) => setState(() => _mobileData = v),
            ),
            _settingToggle(
              icon: Icons.visibility_off,
              label: 'Private session',
              subtitle: "Your listening won't update history",
              value: _privateSession,
              onChanged: (v) => setState(() => _privateSession = v),
            ),
            _settingNav(icon: Icons.privacy_tip, label: 'Privacy policy', value: 'View our data practices'),
          ]),
        ),
        // ABOUT.
        SliverToBoxAdapter(child: _sectionHeader('About')),
        SliverToBoxAdapter(
          child: _card([
            _settingNav(icon: Icons.info_outline, label: 'Version', value: 'Liberated Beats 0.1.0 (open source)'),
            _settingNav(icon: Icons.description, label: 'Licenses', value: 'Third-party open source licenses'),
          ]),
        ),
        // Log out.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
            child: Material(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () {},
                leading: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0x26E8453C), shape: BoxShape.circle),
                  child: const Icon(Icons.logout, size: 18, color: Color(0xFFE8453C)),
                ),
                title: const Text(
                  'Log out',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFE8453C)),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
