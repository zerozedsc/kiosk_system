import '../configs/configs.dart';

class CustomScaffold extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const CustomScaffold({
    Key? key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: backgroundColor ?? Colors.white,
        padding: padding,
        width: double.infinity,
        height: double.infinity,
        child: child,
      ),
    );
  }
}

/// [150725] A modern, reusable login widget designed for a kiosk system.
class EmployeeLoginCard extends StatefulWidget {
  final Map<String, dynamic> employee;
  final Function(BuildContext context, String password) onPerformLogin;

  const EmployeeLoginCard({
    Key? key,
    required this.employee,
    required this.onPerformLogin,
  }) : super(key: key);

  @override
  State<EmployeeLoginCard> createState() => EmployeeLoginCardState();
}

class EmployeeLoginCardState extends State<EmployeeLoginCard> {
  final TextEditingController _passwordController = TextEditingController();
  final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);
  String? _errorText;

  void _login() {
    // Clear previous error message
    setState(() {
      _errorText = null;
    });

    // We now call the login logic passed from the parent widget
    widget.onPerformLogin(context, _passwordController.text);
  }

  // A method for the parent to update the error text
  void setError(String? newError) {
    if (mounted) {
      setState(() {
        _errorText = newError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: SingleChildScrollView(
        child: Dialog(
          insetPadding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 8.0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 24.0),
                _buildPasswordInput(),
                const SizedBox(height: 24.0),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // ... (Header code from previous answer remains the same)
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage:
              (widget.employee['image'] != null &&
                      widget.employee['image'] is Uint8List &&
                      widget.employee['image'].isNotEmpty)
                  ? MemoryImage(widget.employee['image'])
                  : null,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child:
              (widget.employee['image'] == null ||
                      !(widget.employee['image'] is Uint8List) ||
                      widget.employee['image'].isEmpty)
                  ? Icon(
                    Icons.person,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  )
                  : null,
        ),
        const SizedBox(height: 16.0),
        Text(
          "${widget.employee['name'] ?? 'Employee'}",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4.0),
        Text(
          LOCALIZATION.localize("main_word.enter_password_to_continue"),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPasswordInput() {
    return ValueListenableBuilder<bool>(
      valueListenable: _obscurePassword,
      builder: (context, obscure, _) {
        return TextField(
          controller: _passwordController,
          obscureText: obscure,
          autofocus: true,
          decoration: InputDecoration(
            labelText: LOCALIZATION.localize("main_word.password"),
            errorText: _errorText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => _obscurePassword.value = !obscure,
            ),
          ),
          onSubmitted: (_) => _login(),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
          onPressed: _login,
          child: Text(LOCALIZATION.localize("main_word.login")),
        ),
        const SizedBox(height: 12.0),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(LOCALIZATION.localize("main_word.cancel")),
        ),
      ],
    );
  }
}
