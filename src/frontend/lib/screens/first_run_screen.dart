import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/server_registry.dart';
import '../theme/lb_tokens.dart';
import '../widgets/lb_brand.dart';
import '../widgets/servers_section.dart';

/// What a fresh install sees instead of the main scaffold: the emblem, one
/// paragraph of what this is, and the two things the app actually needs to
/// work (a server and a login). Shown until the first server is added, then
/// app.dart swaps to the real scaffold.
class FirstRunScreen extends StatelessWidget {
  const FirstRunScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    // watched so the login status line follows the dialog
    final registry = context.watch<ServerRegistry>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const LbEmblem(size: 96),
              const SizedBox(height: 20),
              Text('LibreBeats', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 5),
              const BrandRule(width: 44),
              const SizedBox(height: 16),
              Text(
                'Streams and downloads music from your own self hosted '
                'servers. Add one to get started. Accounts already exist '
                'on the server, nothing is created here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              GradientPillButton(
                label: 'Add your first server',
                icon: Icons.qr_code_scanner,
                onPressed: () =>
                    addServersFlow(context, context.read<ServerRegistry>()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Set your login'),
                onPressed: () => showDefaultLoginDialog(
                    context, context.read<ServerRegistry>()),
              ),
              const SizedBox(height: 8),
              Text(
                registry.hasDefaultLogin
                    ? registry.defaultEmail
                    : 'No login set yet, servers need one to sign in',
                textAlign: TextAlign.center,
                style: registry.hasDefaultLogin
                    ? theme.textTheme.bodySmall
                    : theme.textTheme.bodySmall
                        ?.copyWith(color: tokens.warning),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
