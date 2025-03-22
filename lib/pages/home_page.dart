import '../configs/configs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LOCALIZATION.localize('home_page.title')),
        automaticallyImplyLeading: false, // This removes the back button
        // Optional: Add other AppBar customizations
        centerTitle: true, // Centers the title if you prefer
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // Enables scrolling when content is too long
          child: Column(
            children: [
              // First Row: Attendance & Live Sales Summary
              Row(
                children: [
                  Expanded(
                    child: _buildScrollableSection(_buildAttendanceSection()),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildScrollableSection(_buildSalesSummary()),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Second Row: Notification Panel & Future Feature Section
              Row(
                children: [
                  Expanded(
                    child: _buildScrollableSection(_buildNotificationPanel()),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildScrollableSection(
                      _buildFutureFeatureSection(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Wrap each section in a scrollable container
  Widget _buildScrollableSection(Widget child) {
    return Container(
      height: 300, // Adjust the height to fit your layout
      child: SingleChildScrollView(child: child),
    );
  }

  // Attendance Section
  Widget _buildAttendanceSection() {
    return Container(
      decoration: _boxDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Replace the simple Text with a Row containing Text and IconButton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(LOCALIZATION.localize('home_page.attendance'), style: _headerStyle),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Colors.orange.shade700, // using your primary color
                onPressed: () {
                  // Handle button press
                  _handleAddAttendance();
                },
                tooltip: LOCALIZATION.localize('home_page.add_attendance'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAttendanceTile("John Doe", LOCALIZATION.localize('home_page.checked_in')),
          _buildAttendanceTile("Jane Smith", LOCALIZATION.localize('home_page.checked_out')),
          _buildAttendanceTile("Mike Johnson", LOCALIZATION.localize('home_page.checked_in')),
          _buildAttendanceTile("Alice Brown", LOCALIZATION.localize('home_page.checked_out')),
          _buildAttendanceTile("Bob Williams", LOCALIZATION.localize('home_page.checked_in')),
          _buildAttendanceTile("Charlie Davis", LOCALIZATION.localize('home_page.checked_in')),
        ],
      ),
    );
  }

  // Add this method to handle the button press
  void _handleAddAttendance() {
    // Show a dialog or navigate to a form for adding attendance
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LOCALIZATION.localize('home_page.add_attendance')),
        content: Text(LOCALIZATION.localize('home_page.add_attendance')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LOCALIZATION.localize('main_word.cancel')),
          ),
          TextButton(
            onPressed: () {
              // Handle adding attendance logic
              Navigator.of(context).pop();
              // You could update state here to add a new entry
              setState(() {
                // Add new attendance entry to your data model
              });
            },
            child: Text(LOCALIZATION.localize('main_word.add')),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTile(String name, String status) {
    return ListTile(
      title: Text(name),
      subtitle: Text(status),
      trailing: Icon(
        status == LOCALIZATION.localize('home_page.checked_in') ? Icons.check_circle : Icons.cancel,
        color: status == LOCALIZATION.localize('home_page.checked_in') ? Colors.green : Colors.red,
      ),
    );
  }

  // Live Sales Summary
  Widget _buildSalesSummary() {
    return Container(
      decoration: _boxDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LOCALIZATION.localize('home_page.live_sales_summary'), style: _headerStyle),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.shopping_cart, color: Colors.blue),
            title: Text(LOCALIZATION.localize('home_page.orders')),
            trailing: const Text("120"),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money, color: Colors.green),
            title: Text(LOCALIZATION.localize('home_page.revenue')),
            trailing: Text("${globalAppConfig["userPreferences"]["currency"]} 5,000"),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.orange),
            title: Text(LOCALIZATION.localize('home_page.profit')),
            trailing: Text("${globalAppConfig["userPreferences"]["currency"]} 1,000"),
          ),
          ListTile(
            leading: const Icon(Icons.trending_up, color: Colors.purple),
            title: Text(LOCALIZATION.localize('home_page.best_selling_item')),
            trailing: const Text("Cheeseburger"),
          ),
        ],
      ),
    );
  }

  // Notification Panel
  Widget _buildNotificationPanel() {
    return Container(
      decoration: _boxDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LOCALIZATION.localize('home_page.notifications'), style: _headerStyle),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: Text(LOCALIZATION.localize('home_page.low_inventory_alert')),
            subtitle: const Text("Burger Buns running low"),
          ),
          ListTile(
            leading: const Icon(Icons.print, color: Colors.blue),
            title: Text(LOCALIZATION.localize('home_page.printer_issue')),
            subtitle: const Text("Receipt printer needs attention"),
          ),
          ListTile(
            leading: const Icon(Icons.store, color: Colors.orange),
            title: Text(LOCALIZATION.localize('home_page.new_shipment_arrived')),
            subtitle: const Text("Restocked Soft Drinks"),
          ),
          ListTile(
            leading: const Icon(Icons.security, color: Colors.green),
            title: Text(LOCALIZATION.localize('home_page.security_alert')),
            subtitle: const Text("Suspicious login detected"),
          ),
        ],
      ),
    );
  }

  // Future Feature Placeholder
  Widget _buildFutureFeatureSection() {
    return Container(
      decoration: _boxDecoration(),
      alignment: Alignment.center,
      child: Text(
        LOCALIZATION.localize('home_page.coming_soon'),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  // Box Decoration for Sections
  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 6,
          spreadRadius: 2,
          offset: const Offset(2, 2),
        ),
      ],
    );
  }
}

// Header Text Style
const TextStyle _headerStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
);
