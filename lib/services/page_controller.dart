import '../configs/configs.dart';
import '../pages/pages.dart';

// Page controller optimized for landscape orientation
class PageControllerClass extends StatefulWidget {
  final Map<String, dynamic>? state;

  const PageControllerClass({super.key, this.state});

  @override
  State<PageControllerClass> createState() => PageControllerClassState();
}

class PageControllerClassState extends State<PageControllerClass> {
  late String initialQuery;
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<InventoryPageState> inventoryPageKey =
      GlobalKey<InventoryPageState>();

  final ValueNotifier<int> cashierReloadNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> inventoryReloadNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> homeReloadNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> moreReloadNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> debugReloadNotifier = ValueNotifier<int>(0);

  late final List<Widget> _children;

  @override
  void initState() {
    super.initState();

    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize variables safely
    initialQuery = widget.state?['query'] ?? '';
    _currentIndex = initialQuery.isNotEmpty ? 1 : 0;

    // Set up page children
    _children = [
      HomePage(reloadNotifier: homeReloadNotifier),
      // Add placeholder widgets for other pages
      CashierPage(reloadNotifier: cashierReloadNotifier),
      InventoryPage(
        key: inventoryPageKey,
        reloadNotifier: inventoryReloadNotifier,
      ),
      const MorePage(),
      DebugPage(reloadNotifier: debugReloadNotifier),
    ];
  }

  @override
  void dispose() {
    // Allow all orientations when this screen is disposed
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  void onTabTapped(int index) async {
    // Simple index change without page controller
    await AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
    if (_currentIndex != index) {
      if (index == 0) {
        // Home tab index
        homeReloadNotifier.value++;
      }

      if (index == 1) {
        // Cashier tab index
        cashierReloadNotifier.value++;
      }

      if (index == 2) {
        // Inventory tab index
        inventoryReloadNotifier.value++;
        // Reset authentication when entering Inventory tab
        inventoryPageKey.currentState?.resetAuthentication();
      }

      if (index == 3) {
        // More tab index
        moreReloadNotifier.value++;
      }

      if (index == 4) {
        // Debug tab index
        debugReloadNotifier.value++;
      }

      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Navigation items - optimized for landscape view
  List<NavigationRailDestination> get navRailItems => const [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale),
      label: Text('Cashier'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory),
      label: Text('Inventory'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('More'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bug_report_outlined),
      selectedIcon: Icon(Icons.bug_report),
      label: Text('Debug'),
    ),
  ];

  @override
  // ...existing code...
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      body: SafeArea(
        child: Row(
          children: [
            // NavigationRail on the left side
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: onTabTapped,
              labelType: NavigationRailLabelType.all,
              destinations: navRailItems,
              backgroundColor: theme.colorScheme.background,
              selectedIconTheme: IconThemeData(
                color: theme.colorScheme.primary,
              ),
              unselectedIconTheme: IconThemeData(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              selectedLabelTextStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              minWidth: 85,
              useIndicator: true,
              indicatorColor: theme.colorScheme.primary.withOpacity(0.2),
            ),

            // Vertical divider between navigation rail and content
            VerticalDivider(
              thickness: 1,
              width: 1,
              color:
                  isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.withOpacity(0.2),
            ),

            // Main content area
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _children),
            ),
          ],
        ),
      ),
    );
  }

  // ...existing code...
}
