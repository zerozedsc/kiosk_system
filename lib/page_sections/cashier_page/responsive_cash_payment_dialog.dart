import '../../configs/configs.dart';
import '../../components/numpad.dart';
import '../../components/buttonswithsound.dart';
import '../../configs/responsive_layout.dart';

class ResponsiveCashPaymentDialog extends StatefulWidget {
  final double totalAmount;
  final Function(BuildContext, String, double, double) onProcessPayment;

  const ResponsiveCashPaymentDialog({
    super.key,
    required this.totalAmount,
    required this.onProcessPayment,
  });

  @override
  ResponsiveCashPaymentDialogState createState() =>
      ResponsiveCashPaymentDialogState();
}

class ResponsiveCashPaymentDialogState
    extends State<ResponsiveCashPaymentDialog> {
  String enteredAmount = '';
  bool showError = false;

  @override
  Widget build(BuildContext context) {
    // Calculate change amount if valid
    double? changeAmount;
    if (enteredAmount.isNotEmpty) {
      try {
        double cashGiven = double.parse(enteredAmount);
        if (cashGiven >= widget.totalAmount) {
          changeAmount = cashGiven - widget.totalAmount;
        }
      } catch (e) {
        // Handle parsing error
      }
    }

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.isMobile(context) ? 16 : 20,
        vertical: ResponsiveLayout.isMobile(context) ? 20 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              ResponsiveLayout.isMobile(context)
                  ? MediaQuery.of(context).size.width * 0.95
                  : MediaQuery.of(context).size.width * 0.4,
        ),
        padding: ResponsiveLayout.getResponsivePadding(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildAmountDisplay(),
              const SizedBox(height: 16),
              _buildAmountEntryField(),
              if (showError) _buildErrorMessage(),
              if (changeAmount != null) _buildChangeDisplay(changeAmount),
              const SizedBox(height: 5),
              _buildNumPad(),
              const SizedBox(height: 5),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      LOCALIZATION.localize("cashier_page.payment_cash"),
      style: TextStyle(
        fontSize: ResponsiveLayout.getResponsiveFontSize(context, 20),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Text(
      "${LOCALIZATION.localize("cashier_page.total")}: ${globalAppConfig["userPreferences"]["currency"]}${widget.totalAmount.toStringAsFixed(2)}",
      style: TextStyle(
        fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildAmountEntryField() {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
        horizontal: ResponsiveLayout.isMobile(context) ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: showError ? Colors.red : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Text(
            "${globalAppConfig["userPreferences"]["currency"]}",
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 24),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              enteredAmount.isEmpty ? "0.00" : enteredAmount,
              style: TextStyle(
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 24),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        LOCALIZATION.localize("cashier_page.amount_too_small"),
        style: TextStyle(
          color: Colors.red,
          fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
        ),
      ),
    );
  }

  Widget _buildChangeDisplay(double changeAmount) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: ResponsiveLayout.getResponsivePadding(
        context,
        mobile: 8,
        tablet: 10,
        desktop: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            LOCALIZATION.localize("cashier_page.reminder"),
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
            ),
          ),
          Text(
            "${globalAppConfig["userPreferences"]["currency"]}${changeAmount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 18),
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumPad() {
    return NumPad(
      initialValue: enteredAmount,
      onValueChanged: (value) {
        setState(() {
          enteredAmount = value;
          showError = false;
        });
      },
    );
  }

  Widget _buildActionButtons() {
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: ResponsiveLayout.isMobile(context) ? 12 : 16,
      vertical: ResponsiveLayout.isMobile(context) ? 8 : 10,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(padding: buttonPadding),
          child: Text(
            LOCALIZATION.localize("main_word.cancel"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
            // This will be handled by parent to reopen checkout dialog
          },
          style: OutlinedButton.styleFrom(padding: buttonPadding),
          child: Text(
            LOCALIZATION.localize("main_word.back"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButtonWithSound(
          onPressed: () async {
            try {
              double cashGiven = double.parse(enteredAmount);
              if (cashGiven >= widget.totalAmount) {
                double? changeAmount;
                if (enteredAmount.isNotEmpty) {
                  changeAmount = cashGiven - widget.totalAmount;
                }

                widget.onProcessPayment(
                  context,
                  'cash',
                  cashGiven,
                  changeAmount ?? 0.0,
                );
              } else {
                AudioManager().playSound(
                  soundPath: 'assets/sounds/warning.mp3',
                );
                setState(() {
                  showError = true;
                });
              }
            } catch (e) {
              AudioManager().playSound(soundPath: 'assets/sounds/error.mp3');
              setState(() {
                showError = true;
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.isMobile(context) ? 16 : 24,
              vertical: ResponsiveLayout.isMobile(context) ? 8 : 10,
            ),
          ),
          child: Text(
            LOCALIZATION.localize("main_word.enter"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            ),
          ),
        ),
      ],
    );
  }
}
