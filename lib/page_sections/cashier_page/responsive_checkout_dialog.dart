import '../../configs/configs.dart';
import '../../configs/responsive_layout.dart';

class ResponsiveCheckoutDialog extends StatefulWidget {
  final BuildContext context;
  final double totalAmount;
  final List<Map<String, dynamic>> cart;
  final Map<String, dynamic> receiptData;
  final Function(BuildContext, double) onShowCashPaymentDialog;
  final Function(String, dynamic) onSetReceiptData;

  const ResponsiveCheckoutDialog({
    super.key,
    required this.context,
    required this.totalAmount,
    required this.cart,
    required this.receiptData,
    required this.onShowCashPaymentDialog,
    required this.onSetReceiptData,
  });

  @override
  ResponsiveCheckoutDialogState createState() =>
      ResponsiveCheckoutDialogState();
}

class ResponsiveCheckoutDialogState extends State<ResponsiveCheckoutDialog> {
  String selectedPaymentMethod = 'cash';
  bool checkPrintReceipt =
      globalAppConfig["cashier"]["bluetooth_printer"]["enabled"];

  @override
  Widget build(BuildContext context) {
    // Calculate necessary values for display
    double subtotal = widget.cart.fold(
      0.0,
      (sum, item) => sum + ((item['price'] ?? 0.0) * (item['quantity'] ?? 1)),
    );
    double discountAmount =
        0.0; // Replace with actual discount calculation if needed
    double taxRate =
        (globalAppConfig["cashier"]["tax"] as num?)?.toDouble() ?? 0.0;
    double taxAmount = subtotal * taxRate;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.isMobile(context) ? 16 : 20,
        vertical: ResponsiveLayout.isMobile(context) ? 20 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: ResponsiveLayout.getDialogConstraints(context),
        padding: ResponsiveLayout.getResponsivePadding(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildOrderItemsList(),
              const SizedBox(height: 16),
              _buildTotalSection(subtotal, taxAmount, discountAmount),
              const SizedBox(height: 16),
              _buildPaymentMethodSelection(),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          LOCALIZATION.localize("cashier_page.checkout_confirmation"),
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildOrderItemsList() {
    // Responsive height for item list (show up to 3 items, else scroll)
    const double itemHeight = 38;
    int maxVisibleItems = ResponsiveLayout.isMobile(context) ? 2 : 3;
    double listBoxHeight =
        (widget.cart.length <= maxVisibleItems)
            ? widget.cart.length * itemHeight
            : maxVisibleItems * itemHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LOCALIZATION.localize("cashier_page.order_items"),
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(
            maxHeight: listBoxHeight == 0 ? itemHeight : listBoxHeight,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              widget.cart.isEmpty
                  ? Container(
                    height: itemHeight,
                    alignment: Alignment.center,
                    child: Text(
                      LOCALIZATION.localize("cashier_page.cart_empty"),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: ResponsiveLayout.getResponsiveFontSize(
                          context,
                          14,
                        ),
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics:
                        widget.cart.length > maxVisibleItems
                            ? const AlwaysScrollableScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                    itemCount: widget.cart.length,
                    itemBuilder: (context, index) {
                      final item = widget.cart[index];
                      final quantity = item['quantity'] ?? 1;
                      final price = item['price'] ?? 0.0;
                      final itemTotal = price * quantity;

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveLayout.isMobile(context) ? 4 : 6,
                          horizontal:
                              ResponsiveLayout.isMobile(context) ? 8 : 12,
                        ),
                        child: Row(
                          children: [
                            Text(
                              "$quantity x",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    ResponsiveLayout.getResponsiveFontSize(
                                      context,
                                      14,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['name'] ?? "",
                                style: TextStyle(
                                  fontSize:
                                      ResponsiveLayout.getResponsiveFontSize(
                                        context,
                                        14,
                                      ),
                                ),
                              ),
                            ),
                            Text(
                              "${globalAppConfig["userPreferences"]["currency"]}${itemTotal.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize:
                                    ResponsiveLayout.getResponsiveFontSize(
                                      context,
                                      14,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildTotalSection(
    double subtotal,
    double taxAmount,
    double discountAmount,
  ) {
    return Container(
      padding: ResponsiveLayout.getResponsivePadding(
        context,
        mobile: 8,
        tablet: 10,
        desktop: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LOCALIZATION.localize("main_word.total"),
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${globalAppConfig["userPreferences"]["currency"]}${widget.totalAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 20),
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Divider(
            height: 10,
            thickness: 0.5,
            color: Colors.grey.withOpacity(0.5),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${LOCALIZATION.localize("cashier_page.tax")}: ${globalAppConfig["userPreferences"]["currency"]}${taxAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                "${LOCALIZATION.localize("cashier_page.discount")}: ${globalAppConfig["userPreferences"]["currency"]}${discountAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
                  color:
                      discountAmount > 0 ? Colors.orange : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LOCALIZATION.localize("cashier_page.select_payment_method"),
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: ResponsiveLayout.isMobile(context) ? 6 : 8,
          runSpacing: ResponsiveLayout.isMobile(context) ? 6 : 8,
          children: [
            if (globalAppConfig["cashier"]["payment_methods"]["cash"])
              _buildPaymentMethodButton(
                icon: Icons.money,
                label: LOCALIZATION.localize("cashier_page.payment_cash"),
                value: 'cash',
              ),
            if (globalAppConfig["cashier"]["payment_methods"]["credit"])
              _buildPaymentMethodButton(
                icon: Icons.credit_card,
                label: LOCALIZATION.localize("cashier_page.payment_credit"),
                value: 'credit',
              ),
            if (globalAppConfig["cashier"]["payment_methods"]["debit"])
              _buildPaymentMethodButton(
                icon: Icons.payment,
                label: LOCALIZATION.localize("cashier_page.payment_debit"),
                value: 'debit',
              ),
            if (globalAppConfig["cashier"]["payment_methods"]["qr"])
              _buildPaymentMethodButton(
                icon: Icons.qr_code,
                label: LOCALIZATION.localize("cashier_page.payment_qr"),
                value: 'qr',
              ),
            if (globalAppConfig["cashier"]["payment_methods"]["apple"])
              _buildPaymentMethodButton(
                icon: Icons.apple,
                label: LOCALIZATION.localize("cashier_page.payment_apple"),
                value: 'apple',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodButton({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isSelected = value == selectedPaymentMethod;

    return InkWell(
      onTap: () async {
        await AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
        setState(() {
          selectedPaymentMethod = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
          horizontal: ResponsiveLayout.isMobile(context) ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: ResponsiveLayout.isMobile(context) ? 16 : 20,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.isMobile(context) ? 12 : 16,
            ),
            minimumSize: Size(0, ResponsiveLayout.isMobile(context) ? 32 : 36),
          ),
          child: Text(
            LOCALIZATION.localize("main_word.cancel"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            Row(
              children: [
                Text(
                  LOCALIZATION.localize("cashier_page.print_receipt"),
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      13,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: ResponsiveLayout.isMobile(context) ? 0.7 : 0.8,
                  child: Switch(
                    value: checkPrintReceipt,
                    activeColor: primaryColor,
                    onChanged:
                        checkPrintReceipt
                            ? (value) {
                              setState(() {
                                checkPrintReceipt = value;
                                widget.onSetReceiptData('checkPrint', value);
                              });
                            }
                            : null,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: Icon(
                Icons.check,
                size: ResponsiveLayout.isMobile(context) ? 14 : 16,
              ),
              label: Text(
                LOCALIZATION.localize("cashier_page.confirm_payment"),
                style: TextStyle(
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 13),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                if (selectedPaymentMethod == 'cash') {
                  widget.onShowCashPaymentDialog(context, widget.totalAmount);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveLayout.isMobile(context) ? 12 : 16,
                ),
                minimumSize: Size(
                  0,
                  ResponsiveLayout.isMobile(context) ? 32 : 36,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
