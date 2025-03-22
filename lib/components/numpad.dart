import 'package:flutter/material.dart';

import 'buttonswithsound.dart';

class NumPad extends StatelessWidget {
  final Function(String) onValueChanged;
  final String initialValue;
  final bool allowDecimal;

  const NumPad({
    Key? key,
    required this.onValueChanged,
    this.initialValue = '',
    this.allowDecimal = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      child: buildNumpad(context),
    );
  }

  Widget buildNumpad(BuildContext context) {
    List<String> buttons;
    if (allowDecimal) {
      buttons = [
        '7', '8', '9',
        '4', '5', '6',
        '1', '2', '3',
        'C', '0', '.'
      ];
    } else {
      buttons = [
        '7', '8', '9',
        '4', '5', '6',
        '1', '2', '3',
        'C', '0', ''
      ];
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns
        childAspectRatio: 2.5, // Kept your original aspect ratio
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: buttons.length,
      itemBuilder: (context, index) {
        return _buildNumpadButton(buttons[index], context);
      },
    );
  }

  Widget _buildNumpadButton(String text, BuildContext context) {
    if (text.isEmpty) return const SizedBox();

    Color? backgroundColor;
    if (text == 'C') backgroundColor = Colors.red.shade100;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: ElevatedButtonWithSound(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: text.isEmpty ? null : () => _handleButtonPress(text),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 30,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleButtonPress(String value) {
    String currentValue = initialValue;

    if (value == 'C') {
      currentValue = '';
    } else if (value == '.') {
      if (!currentValue.contains('.') && currentValue.isNotEmpty) {
        currentValue += '.';
      }
    } else {
      if (value == '0' && currentValue.isEmpty) {
        // Do nothing for leading zero
      } else {
        currentValue += value;
      }
    }

    onValueChanged(currentValue);
  }
}


