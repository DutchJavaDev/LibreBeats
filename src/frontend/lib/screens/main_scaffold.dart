import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/server_registry.dart';
import '../providers/catalog_provider.dart';
import '../widgets/lb_brand.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'liked_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// App shell. Keeps every screen mounted via [IndexedStack] (scroll position and
/// field state survive tab switches) and docks the [MiniPlayer] above the bar.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // only build a tab once its actually visited, saves a lot of first frame
  // work. IndexedStack keeps them alive afterwards so state is preserved.
  final _visited = <int>{0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Pause the catalog watcher in the background, lazy refresh only there.
  // Coming back to the app on the search tab counts as visiting the page.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final catalog = context.read<LibreProvider>();
    if (state == AppLifecycleState.resumed) {
      catalog.setSearchVisible(_selectedIndex == 1);
      if (_selectedIndex == 1) catalog.ensureCatalog();
      // coming back to the app on home counts as visiting it
      if (_selectedIndex == 0) context.read<ServerRegistry>().checkHealth();
    } else {
      catalog.setSearchVisible(false);
    }
  }

  void _selectTab(int i) {
    final catalog = context.read<LibreProvider>();
    // search tab, load the catalog (cached after the first time).
    // the watcher auto refreshes while the user stays on the page.
    catalog.setSearchVisible(i == 1);
    if (i == 1) catalog.ensureCatalog();
    // home tab, refresh the server health digest (throttled in the registry)
    if (i == 0) context.read<ServerRegistry>().checkHealth();
    setState(() {
      _visited.add(i);
      _selectedIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const SearchScreen(),
      // the Liked Songs entry in the library jumps to the liked tab
      LibraryScreen(onOpenLiked: () => _selectTab(3)),
      const LikedScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < screens.length; i++)
            _visited.contains(i) ? screens[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectTab,
            // the active tab gets a small gradient underline instead of the
            // M3 pill (indicator is transparent in the theme)
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: NavUnderlineIcon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: NavUnderlineIcon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: NavUnderlineIcon(Icons.library_music),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: NavUnderlineIcon(Icons.favorite),
                label: 'Liked',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: NavUnderlineIcon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
