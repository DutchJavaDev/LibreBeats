import 'package:flutter/material.dart';
import 'package:librebeats/data/models.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/library_provider.dart';
import '../widgets/shared_widgets.dart';
import '../theme/app_theme.dart';

const _uuid = Uuid();

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: LibreBeatsTheme.background,
              title: Text('Settings'),
            ),

            // ── Servers ──────────────────────────────────────────────────
            const SliverToBoxAdapter(child: SectionHeader(title: 'Music Servers')),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ...library.servers.map((s) => _ServerCard(
                          server: s,
                          onRemove: () => _confirmRemoveServer(context, library, s),
                          onTest: () async {
                            await library.checkAllServers();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${s.name}: ${s.status.name}'),
                                  backgroundColor: LibreBeatsTheme.surface,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        )),
                    const SizedBox(height: 10),
                    _AddButton(
                      label: 'Add Server',
                      icon: Icons.add,
                      onTap: () => _showAddServerSheet(context, library),
                    ),
                  ],
                ),
              ),
            ),

            // ── Local Storage ─────────────────────────────────────────────
            const SliverToBoxAdapter(child: SectionHeader(title: 'Local Storage')),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _StorageCard(library: library),
                  ],
                ),
              ),
            ),

            // ── App ───────────────────────────────────────────────────────
            const SliverToBoxAdapter(child: SectionHeader(title: 'App')),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'About LibreBeats',
                      subtitle: 'Version 1.0.0',
                      onTap: () => _showAbout(context),
                    ),
                    _SettingsTile(
                      icon: Icons.code,
                      title: 'Open Source Licenses',
                      onTap: () => showLicensePage(context: context),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  void _confirmRemoveServer(BuildContext context, LibraryProvider library, MusicServer s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LibreBeatsTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Server', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
        content: Text('Remove "${s.name}"? Server playlists will also be removed.',
            style: const TextStyle(color: LibreBeatsTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: LibreBeatsTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              library.removeServer(s.id);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddServerSheet(BuildContext context, LibraryProvider library) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LibreBeatsTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddServerForm(library: library),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LibreBeatsTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: LibreBeatsTheme.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('LibreBeats', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
          ],
        ),
        content: const Text(
          'A free, open-source music player for Subsonic-compatible servers and local libraries.\n\nVersion 1.0.0',
          style: TextStyle(color: LibreBeatsTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: LibreBeatsTheme.accent)),
          ),
        ],
      ),
    );
  }
}

// ── Server Card ────────────────────────────────────────────────────────────
class _ServerCard extends StatelessWidget {
  final MusicServer server;
  final VoidCallback onRemove;
  final VoidCallback onTest;

  const _ServerCard({required this.server, required this.onRemove, required this.onTest});

  @override
  Widget build(BuildContext context) {
    final isOnline = server.status == ServerStatus.online;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LibreBeatsTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LibreBeatsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dns_rounded, color: Color(0xFF4A9FD4), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.name,
                        style: const TextStyle(
                            color: LibreBeatsTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(server.url,
                        style: const TextStyle(
                            color: LibreBeatsTheme.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? LibreBeatsTheme.online : LibreBeatsTheme.offline,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                    color: isOnline ? LibreBeatsTheme.online : LibreBeatsTheme.offline,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (server.songCount != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ChipTag(label: server.typeLabel, color: const Color(0xFF4A9FD4)),
                const SizedBox(width: 8),
                Text('${server.songCount} songs',
                    style: const TextStyle(
                        color: LibreBeatsTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.wifi_find_rounded, size: 15),
                  label: const Text('Test', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: LibreBeatsTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Remove', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Storage Card ───────────────────────────────────────────────────────────
class _StorageCard extends StatelessWidget {
  final LibraryProvider library;
  const _StorageCard({required this.library});

  @override
  Widget build(BuildContext context) {
    final used = library.localStorageUsedMb;
    final total = 512;
    final ratio = (used / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LibreBeatsTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LibreBeatsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cached Audio',
                  style: TextStyle(
                      color: LibreBeatsTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text('${used}MB / ${total}MB',
                  style: const TextStyle(
                      color: LibreBeatsTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: LibreBeatsTheme.border,
              valueColor: AlwaysStoppedAnimation(
                ratio > 0.8 ? Colors.orange : LibreBeatsTheme.accent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: library.isLoading
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: LibreBeatsTheme.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Clear Cache',
                              style: TextStyle(color: LibreBeatsTheme.textPrimary)),
                          content: const Text(
                              'This will delete all cached audio. You will need an internet connection to stream again.',
                              style: TextStyle(color: LibreBeatsTheme.textSecondary)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel',
                                  style: TextStyle(color: LibreBeatsTheme.textSecondary)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Clear',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) await library.clearLocalStorage();
                    },
              icon: library.isLoading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_sweep_rounded, size: 16),
              label: Text(library.isLoading ? 'Clearing...' : 'Clear Cache'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A1A1A),
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Server Form ────────────────────────────────────────────────────────
class _AddServerForm extends StatefulWidget {
  final LibraryProvider library;
  const _AddServerForm({required this.library});

  @override
  State<_AddServerForm> createState() => _AddServerFormState();
}

class _AddServerFormState extends State<_AddServerForm> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  ServerType _type = ServerType.librebeats;
  bool _obscure = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Server',
              style: TextStyle(
                  color: LibreBeatsTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Type selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ServerType.values.map((t) {
                final sel = t == _type;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? LibreBeatsTheme.accent : LibreBeatsTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t.name[0].toUpperCase() + t.name.substring(1),
                      style: TextStyle(
                          color: sel ? Colors.white : LibreBeatsTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          TextField(controller: _name, style: const TextStyle(color: LibreBeatsTheme.textPrimary),
              decoration: const InputDecoration(hintText: 'Server name')),
          const SizedBox(height: 10),
          TextField(controller: _url, style: const TextStyle(color: LibreBeatsTheme.textPrimary),
              decoration: const InputDecoration(hintText: 'URL (http://...)'),
              keyboardType: TextInputType.url),
          const SizedBox(height: 10),
          TextField(controller: _user, style: const TextStyle(color: LibreBeatsTheme.textPrimary),
              decoration: const InputDecoration(hintText: 'Username')),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            style: const TextStyle(color: LibreBeatsTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: LibreBeatsTheme.textSecondary, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: LibreBeatsTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Connect', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.isEmpty || _url.text.isEmpty) return;
    setState(() => _saving = true);
    final server = MusicServer(
      id: _uuid.v4(),
      name: _name.text,
      url: _url.text,
      username: _user.text,
      password: _pass.text,
      type: _type,
    );
    await widget.library.addServer(server);
    if (mounted) Navigator.pop(context);
  }
}

// ── Shared Small Widgets ───────────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: LibreBeatsTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LibreBeatsTheme.border, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: LibreBeatsTheme.accent, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: LibreBeatsTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: LibreBeatsTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LibreBeatsTheme.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: LibreBeatsTheme.textSecondary, size: 20),
        title: Text(title,
            style: const TextStyle(
                color: LibreBeatsTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle!, style: const TextStyle(color: LibreBeatsTheme.textSecondary, fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right, color: LibreBeatsTheme.textDim, size: 18),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}