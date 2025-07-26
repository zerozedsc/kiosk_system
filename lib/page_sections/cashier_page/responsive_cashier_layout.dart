import 'package:flutter/material.dart';
import '../../configs/responsive_layout.dart';
import 'responsive_order_summary.dart';

class ResponsiveCashierLayout extends StatelessWidget {
  final Widget categoryTabs;
  final Widget productGrid;
  final ResponsiveOrderSummary orderSummary;

  const ResponsiveCashierLayout({
    super.key,
    required this.categoryTabs,
    required this.productGrid,
    required this.orderSummary,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveLayout.isMobile(context)) {
          return _buildMobileLayout(context);
        } else {
          return _buildTabletDesktopLayout(context);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            // Tab bar for switching between products and cart
            Container(
              color: Colors.white,
              child: TabBar(
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: const [
                  Tab(icon: Icon(Icons.inventory), text: "Products"),
                  Tab(icon: Icon(Icons.shopping_cart), text: "Cart"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Products tab
                  Column(
                    children: [categoryTabs, Expanded(child: productGrid)],
                  ),
                  // Cart tab
                  orderSummary,
                ],
              ),
            ),
          ],
        ),
        // Floating action button to show cart summary on products tab
        floatingActionButton: _buildCartFab(context),
      ),
    );
  }

  Widget _buildTabletDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: ResponsiveLayout.isDesktop(context) ? 5 : 4, // Reduced from 2:3
          child: Column(children: [categoryTabs, Expanded(child: productGrid)]),
        ),
        Expanded(
          flex:
              ResponsiveLayout.isDesktop(context) ? 3 : 2, // Increased from 1:1
          child: orderSummary,
        ),
      ],
    );
  }

  Widget _buildCartFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        // Switch to cart tab
        DefaultTabController.of(context).animateTo(1);
      },
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.shopping_cart),
      label: Text(
        "Cart (${orderSummary.cart.length})",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
