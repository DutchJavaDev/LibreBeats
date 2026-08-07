import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Expected payload: {"url": "https://...", "key": "sb_publishable_..."}
// or a json list of those for adding multiple servers with one code.
// returns null on anything malformed so the scanner keeps going
List<(String, String)>? parseServerQrPayload(String raw) {
  try {
    final json = jsonDecode(raw);
    final items = json is List ? json : [json];

    final servers = <(String, String)>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) return null;
      final url = (item['url'] as String?)?.trim() ?? '';
      final key = (item['key'] as String?)?.trim() ?? '';
      if (url.isEmpty || key.isEmpty) return null;
      servers.add((url, key));
    }
    return servers.isEmpty ? null : servers;
  } catch (_) {
    return null;
  }
}

/// Fullscreen QR scanner for adding servers, pops with a list of (url, key)
/// or null. One code can hold one server or a whole list of them.
/// "Enter manually" is there for emulators without a camera.
class AddServerScanScreen extends StatefulWidget {
  const AddServerScanScreen({super.key});

  @override
  State<AddServerScanScreen> createState() => _AddServerScanScreenState();
}

class _AddServerScanScreenState extends State<AddServerScanScreen> {
  bool _handled = false;
  String? _error;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final result = parseServerQrPayload(raw);
    if (result == null) {
      setState(() => _error = 'Not a valid server QR code');
      return;
    }

    _handled = true;
    Navigator.pop(context, result);
  }

  Future<void> _enterManually() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const AddServerDialog(),
    );
    if (result != null && mounted) {
      _handled = true;
      Navigator.pop(context, [result]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan server QR',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.6),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFE8453C), fontSize: 13)),
                    ),
                  const Text(
                    'Point the camera at a server QR code:\n{"url": "https://…", "key": "sb_publishable_…"}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFA7A7A7), fontSize: 12),
                  ),
                  TextButton(
                    onPressed: _enterManually,
                    child: const Text('Enter manually',
                        style:
                            TextStyle(color: Color(0xFF1ED760), fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Manual fallback. NOTE: the controllers have to live in the state, disposing
// them right after showDialog returns crashes the closing animation
class AddServerDialog extends StatefulWidget {
  const AddServerDialog({super.key});

  @override
  State<AddServerDialog> createState() => AddServerDialogState();
}

class AddServerDialogState extends State<AddServerDialog> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();
    if (url.isEmpty || key.isEmpty) return;
    Navigator.pop(context, (url, key));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF181818),
      title: const Text('Add server',
          style: TextStyle(color: Colors.white, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://your-server.example.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
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
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFFA7A7A7))),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Add', style: TextStyle(color: Color(0xFF1ED760))),
        ),
      ],
    );
  }
}
