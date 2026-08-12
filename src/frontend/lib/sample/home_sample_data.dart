// Hardcoded sample data for the still-mocked home section (the per-server
// update cards under "From your servers"). Deliberately in its own
// `sample/` folder: nothing in providers/ or data/ may import this, only
// the home screen does. On repeat, Heavy rotation and the health digest
// are real now and live off the play stats and the server registry.

class SampleServerUpdate {
  final String host;
  final String message;
  final String timeAgo;

  const SampleServerUpdate({
    required this.host,
    required this.message,
    required this.timeAgo,
  });
}

const sampleServerUpdates = <SampleServerUpdate>[
  SampleServerUpdate(
    host: 'herman.example.com',
    message: '3 new beatmixes',
    timeAgo: '2h ago',
  ),
  SampleServerUpdate(
    host: 'nas.local',
    message: 'New playlist: Deep Focus',
    timeAgo: '1d ago',
  ),
];
