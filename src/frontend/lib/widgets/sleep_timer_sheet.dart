import 'package:flutter/material.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:provider/provider.dart';

/// Bottom sheet with the sleep timer choices. Duration options pause
/// playback when they run out, end of track pauses when the current song
/// finishes. Opened from the full player.
void showSleepTimerSheet(BuildContext context, BackgroundAudioProvider player) {
  showModalBottomSheet(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: player,
      child: const _SleepTimerSheet(),
    ),
  );
}

class _SleepTimerSheet extends StatelessWidget {
  const _SleepTimerSheet();

  static const _options = [
    (label: '15 minutes', duration: Duration(minutes: 15)),
    (label: '30 minutes', duration: Duration(minutes: 30)),
    (label: '45 minutes', duration: Duration(minutes: 45)),
    (label: '1 hour', duration: Duration(hours: 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<BackgroundAudioProvider>();

    Widget check(bool selected) => selected
        ? Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check,
                size: 13, color: theme.colorScheme.onPrimary),
          )
        : Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline),
            ),
          );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.bedtime_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Sleep timer', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          for (final option in _options)
            ListTile(
              onTap: () {
                player.setSleepTimer(option.duration);
                Navigator.pop(context);
              },
              title: Text(option.label),
              trailing: check(player.sleepDuration == option.duration),
            ),
          ListTile(
            onTap: () {
              player.setSleepEndOfTrack();
              Navigator.pop(context);
            },
            title: const Text('End of track'),
            trailing: check(player.sleepEndOfTrack),
          ),
          if (player.sleepArmed)
            ListTile(
              onTap: () {
                player.setSleepTimer(null);
                Navigator.pop(context);
              },
              title: Text('Turn off timer',
                  style: theme.textTheme.titleSmall!
                      .copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
