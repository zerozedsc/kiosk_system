import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../../configs/configs.dart';
import '../../components/buttonswithsound.dart';
import '../../configs/responsive_layout.dart';

class EmployeeLoginCard extends StatefulWidget {
  final Map<String, dynamic> employee;
  final Function(BuildContext, String) onPerformLogin;

  const EmployeeLoginCard({
    super.key,
    required this.employee,
    required this.onPerformLogin,
  });

  @override
  EmployeeLoginCardState createState() => EmployeeLoginCardState();
}

class EmployeeLoginCardState extends State<EmployeeLoginCard> {
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  String? _errorMessage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Auto-focus password field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void setError(String? error) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  void _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      setError(LOCALIZATION.localize('main_word.password_required'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    widget.onPerformLogin(context, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = widget.employee['image'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: ResponsiveLayout.getDialogConstraints(context),
        padding: ResponsiveLayout.getResponsivePadding(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildEmployeeInfo(imageBytes),
              const SizedBox(height: 20),
              _buildPasswordField(),
              if (_errorMessage != null) _buildErrorMessage(),
              const SizedBox(height: 20),
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
          LOCALIZATION.localize("cashier_page.employee_login"),
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildEmployeeInfo(dynamic imageBytes) {
    return Column(
      children: [
        CircleAvatar(
          radius: ResponsiveLayout.isMobile(context) ? 35 : 45,
          backgroundImage:
              (imageBytes != null &&
                      imageBytes is Uint8List &&
                      imageBytes.isNotEmpty)
                  ? MemoryImage(imageBytes)
                  : null,
          child:
              (imageBytes == null ||
                      !(imageBytes is Uint8List) ||
                      imageBytes.isEmpty)
                  ? Icon(
                    Icons.person,
                    size: ResponsiveLayout.isMobile(context) ? 35 : 45,
                  )
                  : null,
        ),
        const SizedBox(height: 12),
        Text(
          widget.employee['name'] ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 18),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '@${widget.employee['username'] ?? '...'}',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LOCALIZATION.localize("main_word.password"),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscurePassword,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: LOCALIZATION.localize("main_word.enter_password"),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
          onSubmitted: (_) => _handleLogin(),
          inputFormatters: [LengthLimitingTextInputFormatter(50)],
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButtonWithSound(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            LOCALIZATION.localize("main_word.cancel"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButtonWithSound(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.isMobile(context) ? 16 : 24,
              vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              _isLoading
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Text(
                    LOCALIZATION.localize("main_word.login"),
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getResponsiveFontSize(
                        context,
                        14,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ],
    );
  }
}
