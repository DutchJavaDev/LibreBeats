import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/server_registry.dart';
import 'add_server_scan.dart';

/// The whole add-servers flow: push the QR scanner, feed whatever it returns
/// into the registry and sum it up in a snackbar. Shared between the settings
/// card and the first-run screen.
Future<void> addServersFlow(
    BuildContext context, ServerRegistry registry) async {
  final results = await Navigator.push<List<(String, String, String?, String?)>>(
    context,
    MaterialPageRoute(builder: (_) => const AddServerScanScreen()),
  );
  if (results == null || !context.mounted) return;

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

  if (!context.mounted) return;
  final parts = [
    if (added > 0) 'added $added',
    if (duplicates > 0) '$duplicates already added',
    if (failed > 0) '$failed could not sign in, check the login',
  ];
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(parts.join(', ')),
  ));
}

/// The default-login dialog, saves on confirm. Shared between the settings
/// card and the first-run screen.
Future<void> showDefaultLoginDialog(
    BuildContext context, ServerRegistry registry) async {
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
  void initState() {
    super.initState();
    // first run should not hide the add button behind a tap
    _expanded = context.read<ServerRegistry>().servers.isEmpty;
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Color _statusColor(ServerStatus status) {
    final tokens = Theme.of(context).extension<LbTokens>()!;
    return switch (status) {
      ServerStatus.healthy => tokens.success,
      ServerStatus.connecting => tokens.warning,
      ServerStatus.failed => Theme.of(context).colorScheme.error,
    };
  }

  String _statusLabel(ServerStatus status) => switch (status) {
        ServerStatus.healthy => 'Connected',
        ServerStatus.connecting => 'Connecting…',
        ServerStatus.failed => 'Unreachable',
      };

  // problems first and colored, "1 unreachable · 11 connected"
  Widget _fleetSummary(ServerRegistry registry) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final servers = registry.servers;
    if (servers.isEmpty) {
      return Text('None added yet', style: theme.textTheme.bodySmall);
    }
    if (!registry.hasDefaultLogin && servers.any((s) => s.email == null)) {
      return Text('No default login set',
          style: theme.textTheme.bodySmall?.copyWith(color: tokens.warning));
    }

    final failed =
        servers.where((s) => s.status == ServerStatus.failed).length;
    final connecting =
        servers.where((s) => s.status == ServerStatus.connecting).length;
    final connected = registry.healthy.length;

    final parts = <TextSpan>[];
    void add(String text, [Color? color]) {
      if (parts.isNotEmpty) parts.add(const TextSpan(text: ' · '));
      parts.add(TextSpan(
          text: text, style: color == null ? null : TextStyle(color: color)));
    }

    if (failed > 0) add('$failed unreachable', theme.colorScheme.error);
    if (connecting > 0) add('$connecting connecting', tokens.warning);
    if (connected > 0 || parts.isEmpty) add('$connected connected');

    return Text.rich(TextSpan(
      style: theme.textTheme.bodySmall,
      children: parts,
    ));
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<LbTokens>()!;
    final registry = context.watch<ServerRegistry>();
    final total = registry.servers.length;

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
        color: cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LbRadius.hero),
          side: BorderSide(color: cs.outlineVariant),
        ),
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
                decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                child: const Icon(Icons.dns, size: 18),
              ),
              title: const Text('Servers'),
              subtitle: _fleetSummary(registry),
              trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ),
            if (_expanded) ...[
              const Divider(indent: 70, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    // adding is the main thing to do here, it gets the accent
                    OutlinedButton.icon(
                      onPressed: _addServers,
                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                      label: const Text('Add'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                        side: BorderSide(color: cs.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (total > 0)
                      OutlinedButton.icon(
                        onPressed: () => _showShareQr(registry),
                        icon: const Icon(Icons.qr_code, size: 16),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const Spacer(),
                    // amber, retrying is a something-went-wrong action
                    if (failed.isNotEmpty)
                      TextButton(
                        onPressed: registry.reconnectFailed,
                        style: TextButton.styleFrom(
                            foregroundColor: tokens.warning),
                        child: const Text('Retry all'),
                      ),
                  ],
                ),
              ),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                      'No servers yet. Scan a QR from another device or add '
                      'your own deployment to get started.',
                      style: theme.textTheme.bodySmall),
                ),
              ListTile(
                dense: true,
                onTap: () => _editDefaultLogin(registry),
                leading: Icon(Icons.person_outline,
                    size: 18,
                    color: registry.hasDefaultLogin ? null : tokens.warning),
                title: const Text('Default login'),
                subtitle: Text(
                    registry.hasDefaultLogin
                        ? registry.defaultEmail
                        : 'Not set, servers need this to sign in',
                    style: registry.hasDefaultLogin
                        ? null
                        : theme.textTheme.bodySmall
                            ?.copyWith(color: tokens.warning)),
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
                      decoration: const InputDecoration(
                        hintText: 'Filter servers',
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              if (failed.isNotEmpty)
                ..._group('Unreachable', failed, registry, cs.error),
              if (connecting.isNotEmpty)
                ..._group('Connecting', connecting, registry, tokens.warning),
              if (healthy.isNotEmpty)
                ..._group('Connected', healthy, registry, tokens.success),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  // the header carries the status color, rows say the rest only when it
  // matters: failures show their error and age, healthy rows stay quiet
  List<Widget> _group(String title, List<ServerConnection> servers,
      ServerRegistry registry, Color color) {
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${title.toUpperCase()} · ${servers.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ),
      ),
      for (final server in servers)
        ListTile(
          dense: true,
          onTap: () => _showDetail(server, registry),
          leading: Semantics(
            label: _statusLabel(server.status),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _statusColor(server.status),
                shape: BoxShape.circle,
              ),
            ),
          ),
          minLeadingWidth: 18,
          title: Text(server.host),
          subtitle: switch (server.status) {
            ServerStatus.healthy => null,
            ServerStatus.connecting => const Text('Connecting…'),
            ServerStatus.failed => Text(
                '${server.lastError ?? 'Unreachable'}'
                '${server.failedAt != null ? ' · ${_ago(server.failedAt!)}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          },
          trailing: const Icon(Icons.chevron_right, size: 16),
        ),
    ];
  }

  void _showDetail(ServerConnection server, ServerRegistry registry) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                    child:
                        Text(server.host, style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_statusLabel(server.status),
                  style: theme.textTheme.bodyMedium),
              if (server.status == ServerStatus.failed &&
                  server.lastError != null) ...[
                const SizedBox(height: 4),
                Text(server.lastError!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              _copyRow('URL', server.url, server.url),
              const SizedBox(height: 12),
              _copyRow('Publishable key', _maskedKey(server.key), server.key),
              const SizedBox(height: 12),
              Text('Login', style: theme.textTheme.bodySmall),
              Text(server.email ?? 'Default (${registry.defaultEmail})',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (server.status == ServerStatus.failed)
                    OutlinedButton.icon(
                      onPressed: () {
                        registry.reconnect(server);
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _editServerLogin(sheetContext, server, registry),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Login'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        _confirmRemove(sheetContext, server, registry),
                    style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmRemove(BuildContext sheetContext,
      ServerConnection server, ServerRegistry registry) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        title: Text('Remove ${server.host}?'),
        content: const Text(
          'Its playlists disappear from search until you add it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
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

  // label + monospace value, tapping copies the (unmasked) value
  Widget _copyRow(String label, String shown, String copyValue) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: copyValue));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label copied'),
        ));
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  Text(shown,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface)),
                ],
              ),
            ),
            const Icon(Icons.copy, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _editDefaultLogin(ServerRegistry registry) =>
      showDefaultLoginDialog(context, registry);

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

  Future<void> _addServers() =>
      addServersFlow(context, context.read<ServerRegistry>());

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
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    return AlertDialog(
      title: const Text('Scan to add these servers'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // white backing stays, scanners need the contrast
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
            title: const Text('Include logins'),
            subtitle: Text('Passwords end up in the QR in plain text',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: tokens.warning)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
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
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.allowUseDefault)
          TextButton(
            onPressed: () => Navigator.pop(context, ('', '')),
            child: const Text('Use default'),
          ),
        TextButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
