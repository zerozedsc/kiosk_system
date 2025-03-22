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
      const HomePage(),
      // Add placeholder widgets for other pages
      const CashierPage(),
      const Center(child: Text('Inventory Page')),
      const Center(child: Text('More Options')),
      const DebugPage(),
    ];
  }

  @override
  void dispose() {
    // Allow all orientations when this screen is disposed
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  void onTabTapped(int index) async{
    // Simple index change without page controller
    await AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
    if (_currentIndex != index) {
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
  Widget build(BuildContext context) {
    return Scaffold(
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
            backgroundColor: Colors.white,
            selectedIconTheme: IconThemeData(
              color: primaryColor, // Use primaryColor directly
            ),
            unselectedIconTheme: IconThemeData(
              color: Colors.grey.shade600,
            ),
            selectedLabelTextStyle: TextStyle(
              color: primaryColor, // Use primaryColor directly
              fontWeight: FontWeight.bold,
            ),
            minWidth: 85,
            useIndicator: true,
            indicatorColor: primaryColor.withOpacity(0.2), // Use primaryColor directly
          ),
            
            // Vertical divider between navigation rail and content
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: Colors.grey.withOpacity(0.2),
            ),
            
            // Main content area
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}