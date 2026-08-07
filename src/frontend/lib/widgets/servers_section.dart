import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/server_registry.dart';
import 'add_server_scan.dart';

/// Server management, lives inside the settings page. Collapsed its a one
/// line summary, expanded it shows the fleet grouped by status (problems on
/// top) with add / share / retry actions and a filter for long lists.
class ServersSection extends StatefulWidget {
  const ServersSection({super.key});

  @override
  State<ServersSection> createState() => _ServersSectionState();
}

class _ServersSectionState extends State<ServersSection> {
  bool _expanded = false;
  final _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

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

  // one dot summing up the whole fleet, worst status wins
  Color _fleetColor(ServerRegistry registry) {
    if (registry.servers.any((s) => s.status == ServerStatus.failed)) {
      return const Color(0xFFE8453C);
    }
    if (registry.servers.any((s) => s.status == ServerStatus.connecting)) {
      return const Color(0xFFE8C32E);
    }
    return const Color(0xFF1ED760);
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<ServerRegistry>();
    final total = registry.servers.length;
    final connected = registry.healthy.length;

    final visible = registry.servers
        .where((s) =>
            _filter.isEmpty ||
            s.host.toLowerCase().contains(_filter.toLowerCase()))
        .toList()
      ..sort((a, b) => a.host.compareTo(b.host));

    final failed =
        visible.where((s) => s.status == ServerStatus.failed).toList();
    final connecting =
        visible.where((s) => s.status == ServerStatus.connecting).toList();
    final healthy =
        visible.where((s) => s.status == ServerStatus.healthy).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // collapsed summary, always visible
            ListTile(
              onTap: () => setState(() => _expanded = !_expanded),
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Color(0xFF282828), shape: BoxShape.circle),
                child:
                    const Icon(Icons.dns, size: 18, color: Color(0xFFA7A7A7)),
              ),
              title: const Text('Servers',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
              subtitle: Text(
                  total == 0
                      ? 'None added yet'
                      : !registry.hasDefaultLogin &&
                              registry.servers.any((s) => s.email == null)
                          ? 'No default login set'
                          : '$connected of $total connected',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (total > 0)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _fleetColor(registry),
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFFA7A7A7)),
                ],
              ),
            ),
            if (_expanded) ...[
              const Divider(indent: 70, height: 1, color: Color(0x1AFFFFFF)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _addServers,
                      icon: const Icon(Icons.qr_code_scanner,
                          size: 16, color: Color(0xFFA7A7A7)),
                      label: const Text('Add',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFFA7A7A7))),
                    ),
                    TextButton.icon(
                      onPressed:
                          total == 0 ? null : () => _showShareQr(registry),
                      icon: const Icon(Icons.qr_code,
                          size: 16, color: Color(0xFFA7A7A7)),
                      label: const Text('Share',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFFA7A7A7))),
                    ),
                    const Spacer(),
                    if (failed.isNotEmpty)
                      TextButton(
                        onPressed: registry.reconnectFailed,
                        child: const Text('Retry all',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF1ED760))),
                      ),
                  ],
                ),
              ),
              ListTile(
                dense: true,
                onTap: () => _editDefaultLogin(registry),
                leading: Icon(Icons.person_outline,
                    size: 18,
                    color: registry.hasDefaultLogin
                        ? const Color(0xFFA7A7A7)
                        : const Color(0xFFE8C32E)),
                title: const Text('Default login',
                    style: TextStyle(fontSize: 13, color: Colors.white)),
                subtitle: Text(
                    registry.hasDefaultLogin
                        ? registry.defaultEmail
                        : 'Not set, servers need this to sign in',
                    style: TextStyle(
                        fontSize: 11,
                        color: registry.hasDefaultLogin
                            ? const Color(0xFFA7A7A7)
                            : const Color(0xFFE8C32E))),
              ),
              // filter only matters once the list gets long
              if (total > 8)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _filterController,
                      onChanged: (v) => setState(() => _filter = v),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Filter servers',
                        hintStyle: const TextStyle(color: Color(0xFFA7A7A7)),
                        prefixIcon: const Icon(Icons.search,
                            color: Color(0xFFA7A7A7), size: 18),
                        filled: true,
                        fillColor: const Color(0xFF282828),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              if (failed.isNotEmpty) ..._group('Unreachable', failed, registry),
              if (connecting.isNotEmpty)
                ..._group('Connecting', connecting, registry),
              if (healthy.isNotEmpty)
                ..._group('Connected', healthy, registry),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _group(
      String title, List<ServerConnection> servers, ServerRegistry registry) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${title.toUpperCase()} (${servers.length})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF1ED760),
            ),
          ),
        ),
      ),
      for (final server in servers)
        ListTile(
          dense: true,
          onTap: () => _showDetail(server, registry),
          leading: const Icon(Icons.dns, size: 18, color: Color(0xFFA7A7A7)),
          title: Text(server.host,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          subtitle: Text(_statusLabel(server.status),
              style: const TextStyle(fontSize: 11, color: Color(0xFFA7A7A7))),
          trailing: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _statusColor(server.status),
              shape: BoxShape.circle,
            ),
          ),
        ),
    ];
  }

  void _showDetail(ServerConnection server, ServerRegistry registry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor(server.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(server.host,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_statusLabel(server.status),
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFFA7A7A7))),
            if (server.status == ServerStatus.failed &&
                server.lastError != null) ...[
              const SizedBox(height: 4),
              Text(server.lastError!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFE8453C))),
            ],
            const SizedBox(height: 16),
            const Text('URL',
                style: TextStyle(fontSize: 11, color: Color(0xFFA7A7A7))),
            Text(server.url,
                style: const TextStyle(fontSize: 13, color: Colors.white)),
            const SizedBox(height: 12),
            const Text('Publishable key',
                style: TextStyle(fontSize: 11, color: Color(0xFFA7A7A7))),
            Text(_maskedKey(server.key),
                style: const TextStyle(fontSize: 13, color: Colors.white)),
            const SizedBox(height: 12),
            const Text('Login',
                style: TextStyle(fontSize: 11, color: Color(0xFFA7A7A7))),
            Text(server.email ?? 'Default (${registry.defaultEmail})',
                style: const TextStyle(fontSize: 13, color: Colors.white)),
            const SizedBox(height: 20),
            Row(
              children: [
                if (server.status == ServerStatus.failed)
                  OutlinedButton.icon(
                    onPressed: () {
                      registry.reconnect(server);
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.refresh,
                        size: 16, color: Colors.white),
                    label: const Text('Retry',
                        style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x4DFFFFFF))),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _editServerLogin(sheetContext, server, registry),
                  icon: const Icon(Icons.person_outline,
                      size: 16, color: Color(0xFFA7A7A7)),
                  label: const Text('Login',
                      style: TextStyle(color: Color(0xFFA7A7A7))),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      _confirmRemove(sheetContext, server, registry),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFE8453C)),
                  label: const Text('Remove',
                      style: TextStyle(color: Color(0xFFE8453C))),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext sheetContext,
      ServerConnection server, ServerRegistry registry) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: Text('Remove ${server.host}?',
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'Its playlists disappear from search until you add it again.',
          style: TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFA7A7A7))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFE8453C))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await registry.removeServer(server);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  String _maskedKey(String key) =>
      key.length <= 18 ? key : '${key.substring(0, 18)}…';

  Future<void> _editDefaultLogin(ServerRegistry registry) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _CredentialsDialog(
        title: 'Default login',
        initialEmail: registry.defaultEmail,
        initialPassword: registry.defaultPassword,
      ),
    );
    if (result == null) return;
    final (email, password) = result;
    await registry.setDefaultCredentials(email, password);
  }

  Future<void> _editServerLogin(BuildContext sheetContext,
      ServerConnection server, ServerRegistry registry) async {
    final result = await showDialog<(String, String)>(
      context: sheetContext,
      builder: (_) => _CredentialsDialog(
        title: 'Login for ${server.host}',
        initialEmail: server.email ?? '',
        initialPassword: server.password ?? '',
        allowUseDefault: true,
      ),
    );
    if (result == null) return;

    // ('', '') comes from the "Use default" button and clears the override
    final (email, password) = result;
    await registry.setServerCredentials(server, email: email, password: password);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  Future<void> _addServers() async {
    final registry = context.read<ServerRegistry>();

    final results = await Navigator.push<List<(String, String, String?, String?)>>(
      context,
      MaterialPageRoute(builder: (_) => const AddServerScanScreen()),
    );
    if (results == null || !mounted) return;

    var added = 0;
    var duplicates = 0;
    var failed = 0;
    for (final (url, key, email, password) in results) {
      switch (
          await registry.addServer(url, key, email: email, password: password)) {
        case AddServerResult.added:
          added++;
        case AddServerResult.duplicate:
          duplicates++;
        case AddServerResult.signInFailed:
          failed++;
      }
    }

    if (!mounted) return;
    final parts = [
      if (added > 0) 'added $added',
      if (duplicates > 0) '$duplicates already added',
      if (failed > 0) '$failed could not sign in, check the login',
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(parts.join(', ')),
    ));
  }

  void _showShareQr(ServerRegistry registry) {
    showDialog(
      context: context,
      builder: (_) => _ShareQrDialog(registry: registry),
    );
  }
}

// The payload is the same format the scanner reads, so another device can
// pick up this whole server list with one scan. Logins are only included
// when the toggle is on, they end up in the QR in plain text.
class _ShareQrDialog extends StatefulWidget {
  const _ShareQrDialog({required this.registry});

  final ServerRegistry registry;

  @override
  State<_ShareQrDialog> createState() => _ShareQrDialogState();
}

class _ShareQrDialogState extends State<_ShareQrDialog> {
  bool _includeLogins = false;

  String get _payload {
    final entries = <Map<String, String>>[];
    for (final s in widget.registry.servers) {
      final entry = {'url': s.url, 'key': s.key};
      if (_includeLogins) {
        final (email, password) = widget.registry.credentialsFor(s);
        if (email.isNotEmpty && password.isNotEmpty) {
          entry['email'] = email;
          entry['password'] = password;
        }
      }
      entries.add(entry);
    }
    return jsonEncode(entries);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF181818),
      title: const Text('Scan to add these servers',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 240,
              height: 240,
              child: QrImageView(data: _payload),
            ),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _includeLogins,
            onChanged: (v) => setState(() => _includeLogins = v ?? false),
            activeColor: const Color(0xFF1ED760),
            title: const Text('Include logins',
                style: TextStyle(fontSize: 13, color: Colors.white)),
            subtitle: const Text('Passwords end up in the QR in plain text',
                style: TextStyle(fontSize: 11, color: Color(0xFFE8C32E))),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Close', style: TextStyle(color: Color(0xFFA7A7A7))),
        ),
      ],
    );
  }
}

// Email + password dialog for the default login and per server overrides.
// Pops with (email, password), ('', '') from "Use default", or null on cancel.
// NOTE: controllers live in the state, see AddServerDialog.
class _CredentialsDialog extends StatefulWidget {
  const _CredentialsDialog({
    required this.title,
    required this.initialEmail,
    required this.initialPassword,
    this.allowUseDefault = false,
  });

  final String title;
  final String initialEmail;
  final String initialPassword;
  final bool allowUseDefault;

  @override
  State<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<_CredentialsDialog> {
  late final _emailController = TextEditingController(text: widget.initialEmail);
  late final _passwordController =
      TextEditingController(text: widget.initialPassword);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    Navigator.pop(context, (email, password));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF181818),
      title: Text(widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFFA7A7A7))),
        ),
        if (widget.allowUseDefault)
          TextButton(
            onPressed: () => Navigator.pop(context, ('', '')),
            child: const Text('Use default',
                style: TextStyle(color: Color(0xFFA7A7A7))),
          ),
        TextButton(
          onPressed: _save,
          child: const Text('Save', style: TextStyle(color: Color(0xFF1ED760))),
        ),
      ],
    );
  }
}
