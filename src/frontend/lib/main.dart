import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'providers/library_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/player_widgets.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF121212),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
   await JustAudioBackground.init(
    androidNotificationChannelId: 'librebeats.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(const LibreBeatsApp());
}

class LibreBeatsApp extends StatelessWidget {
  const LibreBeatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: MaterialApp(
        title: 'LibreBeats',
        debugShowCheckedModeBanner: false,
        theme: LibreBeatsTheme.theme,
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LibreBeatsTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini player sits above nav bar
              // Mini player sits above nav bar
              if (player.miniPlayerVisible)
                  MiniPlayer(
                  onTap: () => FullPlayerSheet.show(context),
                ),

              // Navigation bar
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF121212),
                  border: Border(
                    top: BorderSide(color: LibreBeatsTheme.border, width: 0.5),
                  ),
                ),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) => setState(() => _currentIndex = i),
                  indicatorColor: LibreBeatsTheme.accentDim,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined, color: LibreBeatsTheme.textDim),
                      selectedIcon: Icon(Icons.home_rounded, color: LibreBeatsTheme.textPrimary),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search_outlined, color: LibreBeatsTheme.textDim),
                      selectedIcon: Icon(Icons.search_rounded, color: LibreBeatsTheme.textPrimary),
                      label: 'Search',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.library_music_outlined, color: LibreBeatsTheme.textDim),
                      selectedIcon: Icon(Icons.library_music_rounded, color: LibreBeatsTheme.textPrimary),
                      label: 'Library',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined, color: LibreBeatsTheme.textDim),
                      selectedIcon: Icon(Icons.settings_rounded, color: LibreBeatsTheme.textPrimary),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}