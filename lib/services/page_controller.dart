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
  final GlobalKey<CashierPageState> cashierPageKey =
      GlobalKey<CashierPageState>();
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
      CashierPage(key: cashierPageKey, reloadNotifier: cashierReloadNotifier),
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
        // Reset authentication when entering Cashier tab
        cashierPageKey.currentState?.resetAuthentication();
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

  // Navigation items - optimized for landscape view with responsive sizing
  List<NavigationRailDestination> _buildNavRailItems(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive sizes based on screen dimensions
    final iconSize = (screenHeight * 0.035).clamp(20.0, 28.0);
    final fontSize = (screenHeight * 0.018).clamp(10.0, 14.0);

    return [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined, size: iconSize),
        selectedIcon: Icon(Icons.home, size: iconSize),
        label: Text('Home', style: TextStyle(fontSize: fontSize)),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.point_of_sale_outlined, size: iconSize),
        selectedIcon: Icon(Icons.point_of_sale, size: iconSize),
        label: Text('Cashier', style: TextStyle(fontSize: fontSize)),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined, size: iconSize),
        selectedIcon: Icon(Icons.inventory, size: iconSize),
        label: Text('Inventory', style: TextStyle(fontSize: fontSize)),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined, size: iconSize),
        selectedIcon: Icon(Icons.settings, size: iconSize),
        label: Text('More', style: TextStyle(fontSize: fontSize)),
      ),
      if (DEBUG)
        NavigationRailDestination(
          icon: Icon(Icons.bug_report_outlined, size: iconSize),
          selectedIcon: Icon(Icons.bug_report, size: iconSize),
          label: Text('Debug', style: TextStyle(fontSize: fontSize)),
        ),
    ];
  }

  @override
  // ...existing code...
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive rail width based on screen size
    final railWidth = (screenWidth * 0.1).clamp(70.0, 100.0);
    final railIconSize = (screenHeight * 0.035).clamp(20.0, 28.0);
    final railFontSize = (screenHeight * 0.018).clamp(10.0, 14.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      body: SafeArea(
        child: Row(
          children: [
            // NavigationRail on the left side with responsive sizing and overflow protection
            SizedBox(
              width: railWidth,
              height: screenHeight,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        screenHeight - 50, // Account for safe area and padding
                  ),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: onTabTapped,
                      labelType: NavigationRailLabelType.all,
                      destinations: _buildNavRailItems(context),
                      backgroundColor: theme.colorScheme.surface,
                      selectedIconTheme: IconThemeData(
                        color: theme.colorScheme.primary,
                        size: railIconSize,
                      ),
                      unselectedIconTheme: IconThemeData(
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                        size: railIconSize,
                      ),
                      selectedLabelTextStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: railFontSize,
                      ),
                      unselectedLabelTextStyle: TextStyle(
                        fontSize: railFontSize,
                      ),
                      minWidth: railWidth,
                      useIndicator: true,
                      indicatorColor: theme.colorScheme.primary.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Vertical divider between navigation rail and content
            VerticalDivider(
              thickness: 1,
              width: 1,
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.2),
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
}
