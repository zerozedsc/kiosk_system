import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../configs/configs.dart';
import '../../components/toastmsg.dart';
import '../../components/buttonswithsound.dart';
import '../../configs/responsive_layout.dart';

class ResponsiveOrderSummary extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final int currentOrderId;
  final Map<int, dynamic> outOfStockItems;
  final Function(int) toggleSelection;
  final Function(int) removeFromCart;
  final Function(Map<String, dynamic>) increaseQuantity;
  final Function() selectAll;
  final Function(BuildContext) showCouponDialog;
  final Function(BuildContext, double) showCheckoutDialog;
  final Function(String, dynamic) setReceiptData;

  const ResponsiveOrderSummary({
    super.key,
    required this.cart,
    required this.currentOrderId,
    required this.outOfStockItems,
    required this.toggleSelection,
    required this.removeFromCart,
    required this.increaseQuantity,
    required this.selectAll,
    required this.showCouponDialog,
    required this.showCheckoutDialog,
    required this.setReceiptData,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    double totalPrice = cart.fold(
      0.0,
      (sum, item) => sum + ((item['price'] ?? 0.0) * (item['quantity'] ?? 1)),
    );
    double discountAmount = 0.0;
    double taxRate =
        (globalAppConfig["cashier"]["tax"] as num?)?.toDouble() ?? 0.0;
    double taxAmount = totalPrice * taxRate;
    double finalTotal = totalPrice + taxAmount - discountAmount;
    int totalItems = cart.length;

    // Format order ID to 6 digits with leading zeros
    String formattedOrderId = NumberFormat(
      globalAppConfig["cashier"]["formattedOrderId"],
    ).format(currentOrderId);

    // Check if any items are selected
    bool hasSelectedItems = cart.any((item) => item["selected"] == true);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, formattedOrderId, totalItems, hasSelectedItems),
          _buildCartItemsList(context),
          _buildActionBarBottom(
            context,
            totalPrice,
            taxAmount,
            discountAmount,
            finalTotal,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String formattedOrderId,
    int totalItems,
    bool hasSelectedItems,
  ) {
    return Container(
      padding: ResponsiveLayout.getResponsivePadding(
        context,
        mobile: 8,
        tablet: 10,
        desktop: 12,
      ),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(25),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Combined title and order ID in single line
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: LOCALIZATION.localize("cashier_page.order_summary"),
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getResponsiveFontSize(
                        context,
                        13,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: " #$formattedOrderId",
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getResponsiveFontSize(
                        context,
                        11,
                      ),
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right side: Item count and actions menu
          Row(
            children: [
              // Items count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$totalItems ${LOCALIZATION.localize("main_word.items")}",
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      9,
                    ),
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Actions menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: ResponsiveLayout.getResponsiveFontSize(context, 16),
                  color: Colors.grey[700],
                ),
                onSelected: (String action) {
                  switch (action) {
                    case 'select_all':
                      selectAll();
                      break;
                    case 'coupon':
                      showCouponDialog(context);
                      break;
                    case 'remove_selected':
                      if (hasSelectedItems) {
                        _removeSelectedItems(context);
                      }
                      break;
                  }
                },
                itemBuilder:
                    (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'select_all',
                        child: Row(
                          children: [
                            Icon(
                              Icons.select_all,
                              size: ResponsiveLayout.getResponsiveFontSize(
                                context,
                                16,
                              ),
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              LOCALIZATION.localize("main_word.select_all"),
                              style: TextStyle(
                                fontSize:
                                    ResponsiveLayout.getResponsiveFontSize(
                                      context,
                                      12,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'coupon',
                        child: Row(
                          children: [
                            Icon(
                              Icons.discount,
                              size: ResponsiveLayout.getResponsiveFontSize(
                                context,
                                16,
                              ),
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              LOCALIZATION.localize(
                                "cashier_page.coupon_placeholder",
                              ),
                              style: TextStyle(
                                fontSize:
                                    ResponsiveLayout.getResponsiveFontSize(
                                      context,
                                      12,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasSelectedItems)
                        PopupMenuItem<String>(
                          value: 'remove_selected',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: ResponsiveLayout.getResponsiveFontSize(
                                  context,
                                  16,
                                ),
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                LOCALIZATION.localize(
                                  "cashier_page.bulk_remove",
                                ),
                                style: TextStyle(
                                  fontSize:
                                      ResponsiveLayout.getResponsiveFontSize(
                                        context,
                                        12,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsList(BuildContext context) {
    return Expanded(
      child:
          cart.isEmpty
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LOCALIZATION.localize("cashier_page.cart_empty"),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: cart.length,
                itemBuilder: (context, index) => _buildCartItem(context, index),
              ),
    );
  }

  Widget _buildCartItem(BuildContext context, int index) {
    final item = cart[index];
    final quantity = item['quantity'] ?? 1;
    final price = item['price'] ?? 0.0;
    final setItems = item['set'] as List<Map<String, dynamic>>?;

    // Determine if the item is pcs or pack based on the conditions
    String unitType;
    if (setItems != null || item["type"] == "total_pieces_used") {
      unitType = "(pcs)";
    } else {
      unitType = "(pack)";
    }

    return Dismissible(
      key: Key("cart-item-$index"),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => removeFromCart(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: item["selected"] == true ? primaryColor.withAlpha(20) : null,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveLayout.isMobile(context) ? 1 : 2,
          ),
          child: ListTile(
            leading: Checkbox(
              activeColor: primaryColor,
              value: item["selected"] ?? false,
              onChanged: (_) => toggleSelection(index),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item["name"] ?? "",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      12,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: ResponsiveLayout.isMobile(context) ? 1 : 2,
                ),
                Text(
                  "${globalAppConfig["userPreferences"]["currency"]}${price.toStringAsFixed(2)} $unitType",
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      10,
                    ),
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (setItems != null && setItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: InkWell(
                      onTap:
                          () => _showSetDetailsDialog(
                            context,
                            item["name"],
                            setItems,
                          ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.dining,
                              size: ResponsiveLayout.getResponsiveFontSize(
                                context,
                                12,
                              ),
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Set includes ${setItems.length} items",
                              style: TextStyle(
                                fontSize:
                                    ResponsiveLayout.getResponsiveFontSize(
                                      context,
                                      9,
                                    ),
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.info_outline,
                              size: ResponsiveLayout.getResponsiveFontSize(
                                context,
                                10,
                              ),
                              color: Colors.blue[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            trailing:
                setItems == null
                    ? _buildQuantityControls(context, item, quantity, index)
                    : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.isMobile(context) ? 4 : 6,
            ),
            dense: ResponsiveLayout.isMobile(context),
            horizontalTitleGap: ResponsiveLayout.isMobile(context) ? 4 : 8,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControls(
    BuildContext context,
    Map<String, dynamic> item,
    int quantity,
    int index,
  ) {
    return Container(
      height: ResponsiveLayout.isMobile(context) ? 28 : 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrease button
          InkWell(
            onTap: () {
              AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
              if (quantity > 1) {
                item["quantity"] = quantity - 1;
                if (outOfStockItems.containsKey(item["id"]) &&
                    outOfStockItems[item["id"]]?.containsKey(item["type"])) {
                  outOfStockItems[item["id"]].remove(item["type"]);
                }
              } else {
                removeFromCart(index);
              }
            },
            child: Container(
              padding: EdgeInsets.all(
                ResponsiveLayout.isMobile(context) ? 4 : 6,
              ),
              child: Icon(
                Icons.remove,
                size: ResponsiveLayout.isMobile(context) ? 12 : 14,
                color: primaryColor,
              ),
            ),
          ),
          // Quantity indicator
          SizedBox(
            width: ResponsiveLayout.isMobile(context) ? 20 : 24,
            child: Center(
              child: Text(
                "$quantity",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 11),
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // Increase button
          InkWell(
            onTap: () {
              AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
              increaseQuantity(item);
            },
            child: Container(
              padding: EdgeInsets.all(
                ResponsiveLayout.isMobile(context) ? 4 : 6,
              ),
              child: Icon(
                Icons.add,
                size: ResponsiveLayout.isMobile(context) ? 12 : 14,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBarBottom(
    BuildContext context,
    double totalPrice,
    double taxAmount,
    double discountAmount,
    double finalTotal,
  ) {
    return Container(
      padding: ResponsiveLayout.getResponsivePadding(
        context,
        mobile: 8,
        tablet: 10,
        desktop: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildCostBreakdown(
              context,
              totalPrice,
              taxAmount,
              discountAmount,
              finalTotal,
            ),
            SizedBox(height: ResponsiveLayout.isMobile(context) ? 8 : 10),
            _buildCheckoutButton(
              context,
              finalTotal,
              totalPrice.toInt(),
              taxAmount,
              discountAmount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostBreakdown(
    BuildContext context,
    double totalPrice,
    double taxAmount,
    double discountAmount,
    double finalTotal,
  ) {
    final taxRate =
        (globalAppConfig["cashier"]["tax"] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        _buildCostRow(
          context,
          LOCALIZATION.localize("cashier_page.subtotal"),
          "${globalAppConfig["userPreferences"]["currency"]}${totalPrice.toStringAsFixed(2)}",
        ),
        SizedBox(height: ResponsiveLayout.isMobile(context) ? 2 : 3),
        _buildCostRow(
          context,
          "${LOCALIZATION.localize("cashier_page.tax")} (${(taxRate * 100).toStringAsFixed(0)}%)",
          "${globalAppConfig["userPreferences"]["currency"]}${taxAmount.toStringAsFixed(2)}",
        ),
        SizedBox(height: ResponsiveLayout.isMobile(context) ? 2 : 3),
        _buildCostRow(
          context,
          LOCALIZATION.localize("cashier_page.discount"),
          "-${globalAppConfig["userPreferences"]["currency"]}${discountAmount.toStringAsFixed(2)}",
          color: Colors.orange,
        ),
        Divider(
          height: ResponsiveLayout.isMobile(context) ? 8 : 10,
          thickness: 0.8,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              LOCALIZATION.localize("main_word.total"),
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 13),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${globalAppConfig["userPreferences"]["currency"]}${finalTotal.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCostRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    double finalTotal,
    int totalItems,
    double taxAmount,
    double discountAmount,
  ) {
    return ElevatedButtonWithSound.icon(
      onPressed:
          cart.isEmpty
              ? null
              : () {
                setReceiptData("items", totalItems);
                setReceiptData("tax", taxAmount);
                setReceiptData("discountAmount", discountAmount);
                showCheckoutDialog(context, finalTotal);
              },
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: Size(
          double.infinity,
          ResponsiveLayout.isMobile(context) ? 36 : 40,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        Icons.payment,
        size: ResponsiveLayout.isMobile(context) ? 14 : 16,
      ),
      label: Text(
        LOCALIZATION.localize("cashier_page.checkout"),
        style: TextStyle(
          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 13),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _removeSelectedItems(BuildContext context) {
    // This will be handled by the parent widget through the callback
    showToastMessage(
      context,
      LOCALIZATION.localize("cashier_page.items_removed"),
      ToastLevel.info,
      position: ToastPosition.topRight,
    );
  }

  void _showSetDetailsDialog(
    BuildContext context,
    String setName,
    List<dynamic> setItems,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            setName.isNotEmpty ? setName : "Set Details",
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
              maxWidth: ResponsiveLayout.getDialogWidth(context),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children:
                    setItems
                        .map<Widget>(
                          (setItem) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${setItem['name']} x${setItem['quantity']}",
                                    style: TextStyle(
                                      fontSize:
                                          ResponsiveLayout.getResponsiveFontSize(
                                            context,
                                            12,
                                          ),
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Close",
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
