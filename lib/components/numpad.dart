import 'package:flutter/material.dart';
import 'buttonswithsound.dart';

class NumPad extends StatefulWidget {
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
  State<NumPad> createState() => _NumPadState();
}

class _NumPadState extends State<NumPad> {
  late String currentValue;

  @override
  void initState() {
    super.initState();
    currentValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final buttons =
        widget.allowDecimal
            ? ['7', '8', '9', '4', '5', '6', '1', '2', '3', 'C', '0', '.']
            : ['7', '8', '9', '4', '5', '6', '1', '2', '3', 'C', '0', ''];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45, // Lower height
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: buttons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 3,
            childAspectRatio: 2.85, // Wider and shorter buttons
          ),
          itemBuilder: (context, index) {
            final text = buttons[index];
            return _buildButton(text);
          },
        ),
      ),
    );
  }

  Widget _buildButton(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    Color bgColor;
    Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    if (text == 'C') {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
    } else if (text == '.') {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
    } else {
      bgColor = Theme.of(context).colorScheme.surfaceVariant;
    }

    return ElevatedButtonWithSound(
      onPressed: () => _handleInput(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: EdgeInsets.zero,
        elevation: 1,
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20, // Smaller font
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _handleInput(String value) {
    setState(() {
      if (value == 'C') {
        currentValue = '';
      } else if (value == '.') {
        if (!currentValue.contains('.') && currentValue.isNotEmpty) {
          currentValue += '.';
        }
      } else {
        if (!(value == '0' && currentValue.isEmpty)) {
          currentValue += value;
        }
      }

      widget.onValueChanged(currentValue);
    });
  }
}
