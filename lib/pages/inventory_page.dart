import '../configs/configs.dart';
import '../services/inventory/inventory_services.dart';

import '../page_sections/inventory_page/responsive_inventory_list.dart';

class InventoryPage extends StatefulWidget {
  final ValueNotifier<int> reloadNotifier;
  const InventoryPage({super.key, required this.reloadNotifier});

  @override
  State<InventoryPage> createState() => InventoryPageState();
}

class InventoryPageState extends State<InventoryPage> {
  bool _isAuthenticated = false;
  String employeeID = "RZ0000";
  String employeeName = "RZ";

  // Add this method
  void resetAuthentication() {
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.reloadNotifier.addListener(() async {
      await _reloadInventory();
    });
    resetAuthentication();
  }

  @override
  void dispose() {
    super.dispose();
    widget.reloadNotifier.removeListener(_reloadInventory);
  }

  Future<void> _reloadInventory() async {
    await inventory.updateDataInVar();
  }

  // [NEW:260725] [Employee Selection and Login Screen] - Now using UnifiedAuthService
  Widget _buildEmployeeAuthScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withOpacity(0.1),
              primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await UnifiedAuthService.showEmployeeAuth(
                context,
                authenticator:
                    (employee, password) =>
                        empAuth(employee, password, LOGS: INVENTORY_LOGS),
                employees: EMPQUERY.employees,
                logs: INVENTORY_LOGS,
              );

              if (result != null && result.success) {
                setState(() {
                  _isAuthenticated = true;
                  employeeID = result.employeeID!;
                  employeeName = result.employeeName!;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              LOCALIZATION.localize("cashier_page.select_account"),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildEmployeeAuthScreen();
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: ResponsiveInventoryList(reloadNotifier: widget.reloadNotifier),
      ),
    );
  }
}
