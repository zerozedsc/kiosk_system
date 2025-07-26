import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../../configs/configs.dart';
import '../../components/buttonswithsound.dart';
import '../../components/toastmsg.dart';
import '../../configs/responsive_layout.dart';
import 'auth_service.dart';

/// Authentication types supported by the unified auth service
enum AuthType { employee, admin }

/// Authentication result data
class AuthResult {
  final bool success;
  final String? employeeID;
  final String? employeeName;
  final String? errorMessage;

  const AuthResult({
    required this.success,
    this.employeeID,
    this.employeeName,
    this.errorMessage,
  });

  factory AuthResult.success({String? employeeID, String? employeeName}) {
    return AuthResult(
      success: true,
      employeeID: employeeID,
      employeeName: employeeName,
    );
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult(success: false, errorMessage: errorMessage);
  }
}

/// Modern, responsive authentication service for kiosk applications
/// Supports both employee and admin authentication with a unified interface
class UnifiedAuthService {
  static const Duration _animationDuration = Duration(milliseconds: 300);

  /// Show employee selection screen for cashier authentication
  static Future<AuthResult?> showEmployeeAuth(
    BuildContext context, {
    required Future<dynamic> Function(Map<String, dynamic>, String)
    authenticator,
    required Map<String, Map<String, dynamic>> employees,
    LoggingService? logs,
  }) async {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => _EmployeeAuthScreen(
              authenticator: authenticator,
              employees: employees,
              logs: logs,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
            ),
            child: child,
          );
        },
        transitionDuration: _animationDuration,
      ),
    );
  }

  /// Show admin authentication dialog
  static Future<AuthResult?> showAdminAuth(
    BuildContext context, {
    String? directPassword,
  }) async {
    if (directPassword != null) {
      final isValid = await AdminAuthDialog.validatePassword(directPassword);
      return isValid
          ? AuthResult.success()
          : AuthResult.failure(
            LOCALIZATION.localize('main_word.password_incorrect'),
          );
    }

    return showDialog<AuthResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AdminAuthDialog(),
    );
  }

  /// Show appropriate authentication based on type
  static Future<AuthResult?> showAuth(
    BuildContext context, {
    required AuthType authType,
    Map<String, Map<String, dynamic>>? employees,
    Future<dynamic> Function(Map<String, dynamic>, String)? authenticator,
    LoggingService? logs,
    String? directPassword,
  }) async {
    switch (authType) {
      case AuthType.employee:
        if (employees == null || authenticator == null) {
          throw ArgumentError(
            'Employee authentication requires employees map and authenticator',
          );
        }
        return showEmployeeAuth(
          context,
          authenticator: authenticator,
          employees: employees,
          logs: logs,
        );
      case AuthType.admin:
        return showAdminAuth(context, directPassword: directPassword);
    }
  }
}

/// Modern employee authentication screen with responsive design
class _EmployeeAuthScreen extends StatefulWidget {
  final Future<dynamic> Function(Map<String, dynamic>, String) authenticator;
  final Map<String, Map<String, dynamic>> employees;
  final LoggingService? logs;

  const _EmployeeAuthScreen({
    required this.authenticator,
    required this.employees,
    this.logs,
  });

  @override
  State<_EmployeeAuthScreen> createState() => _EmployeeAuthScreenState();
}

class _EmployeeAuthScreenState extends State<_EmployeeAuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: UnifiedAuthService._animationDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeEmployees =
        widget.employees.values
            .where((emp) => emp['exist'] == 1 || emp['exist'] == '1')
            .toList();

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
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child:
                      activeEmployees.isEmpty
                          ? _buildEmptyState(context)
                          : _buildEmployeeGrid(context, activeEmployees),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: ResponsiveLayout.getResponsivePadding(
        context,
        mobile: 16,
        tablet: 20,
        desktop: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new),
            style: IconButton.styleFrom(
              backgroundColor: primaryColor.withOpacity(0.1),
              foregroundColor: primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LOCALIZATION.localize("auth_page.select_account"),
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      24,
                    ),
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  LOCALIZATION.localize("auth_page.choose_your_account"),
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      14,
                    ),
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: ResponsiveLayout.isMobile(context) ? 60 : 80,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            LOCALIZATION.localize("auth_page.no_employees_found"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 18),
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LOCALIZATION.localize("auth_page.contact_admin"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeGrid(
    BuildContext context,
    List<Map<String, dynamic>> employees,
  ) {
    // Calculate responsive grid parameters
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = ResponsiveLayout.isMobile(context) ? 16.0 : 24.0;
    final availableWidth = screenWidth - (padding * 2);

    double tileWidth;
    if (ResponsiveLayout.isMobile(context)) {
      tileWidth = 160.0;
    } else if (ResponsiveLayout.isTablet(context)) {
      tileWidth = 180.0;
    } else {
      tileWidth = 200.0;
    }

    final crossAxisCount = (availableWidth / tileWidth).floor().clamp(1, 6);

    return Container(
      padding: EdgeInsets.all(padding),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: employees.length,
        itemBuilder: (context, index) {
          return _buildEmployeeTile(context, employees[index], index);
        },
      ),
    );
  }

  Widget _buildEmployeeTile(
    BuildContext context,
    Map<String, dynamic> employee,
    int index,
  ) {
    final imageBytes = employee['image'];

    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + (index * 50)),
      child: Card(
        elevation: 8,
        shadowColor: primaryColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showEmployeeLoginDialog(context, employee),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, primaryColor.withOpacity(0.02)],
              ),
            ),
            padding: ResponsiveLayout.getResponsivePadding(
              context,
              mobile: 12,
              tablet: 16,
              desktop: 20,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'employee_${employee['username']}',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: ResponsiveLayout.isMobile(context) ? 32 : 40,
                      backgroundColor: primaryColor.withOpacity(0.1),
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
                                size:
                                    ResponsiveLayout.isMobile(context)
                                        ? 32
                                        : 40,
                                color: primaryColor,
                              )
                              : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  employee['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      16,
                    ),
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '@${employee['username'] ?? '...'}',
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.7),
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      12,
                    ),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmployeeLoginDialog(
    BuildContext context,
    Map<String, dynamic> employee,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => _EmployeeLoginDialog(
            employee: employee,
            authenticator: widget.authenticator,
            logs: widget.logs,
            onSuccess: (employeeID, employeeName) {
              Navigator.of(context).pop(
                AuthResult.success(
                  employeeID: employeeID,
                  employeeName: employeeName,
                ),
              );
            },
          ),
    );
  }
}

/// Modern employee login dialog
class _EmployeeLoginDialog extends StatefulWidget {
  final Map<String, dynamic> employee;
  final Future<dynamic> Function(Map<String, dynamic>, String) authenticator;
  final LoggingService? logs;
  final Function(String, String) onSuccess;

  const _EmployeeLoginDialog({
    required this.employee,
    required this.authenticator,
    required this.onSuccess,
    this.logs,
  });

  @override
  State<_EmployeeLoginDialog> createState() => _EmployeeLoginDialogState();
}

class _EmployeeLoginDialogState extends State<_EmployeeLoginDialog>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  String? _errorMessage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();

    // Auto-focus password field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _setError(String? error) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      _setError(LOCALIZATION.localize('main_word.password_required'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await widget.authenticator(
        widget.employee,
        _passwordController.text,
      );

      if (isValid == true) {
        Navigator.of(context).pop();
        widget.onSuccess(widget.employee['username'], widget.employee['name']);

        showToastMessage(
          context,
          'Welcome, ${widget.employee['name']}!',
          ToastLevel.success,
        );
      } else {
        _setError(LOCALIZATION.localize(isValid));
        showToastMessage(
          context,
          LOCALIZATION.localize('main_word.password_incorrect'),
          ToastLevel.error,
        );
      }
    } catch (e) {
      _setError('Authentication failed. Please try again.');
      widget.logs?.error(
        'Employee authentication error',
        e,
        StackTrace.current,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = widget.employee['image'];

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          constraints: ResponsiveLayout.getDialogConstraints(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, primaryColor.withOpacity(0.02)],
            ),
          ),
          child: SingleChildScrollView(
            padding: ResponsiveLayout.getResponsivePadding(
              context,
              mobile: 20,
              tablet: 24,
              desktop: 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildEmployeeInfo(imageBytes),
                const SizedBox(height: 24),
                _buildPasswordField(),
                if (_errorMessage != null) _buildErrorMessage(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
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
          LOCALIZATION.localize("auth_page.employee_login"),
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 22),
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeInfo(dynamic imageBytes) {
    return Column(
      children: [
        Hero(
          tag: 'employee_${widget.employee['username']}',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: ResponsiveLayout.isMobile(context) ? 40 : 50,
              backgroundColor: primaryColor.withOpacity(0.1),
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
                        size: ResponsiveLayout.isMobile(context) ? 40 : 50,
                        color: primaryColor,
                      )
                      : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.employee['name'] ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 20),
            color: Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '@${widget.employee['username'] ?? '...'}',
          style: TextStyle(
            color: primaryColor.withOpacity(0.7),
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
            fontWeight: FontWeight.w500,
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
            fontWeight: FontWeight.w600,
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: LOCALIZATION.localize("main_word.enter_password"),
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lock_outline, color: primaryColor),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            onSubmitted: (_) => _handleLogin(),
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w500,
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
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.isMobile(context) ? 16 : 20,
              vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
            ),
          ),
          child: Text(
            LOCALIZATION.localize("main_word.cancel"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButtonWithSound(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: primaryColor.withOpacity(0.4),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.isMobile(context) ? 20 : 28,
              vertical: ResponsiveLayout.isMobile(context) ? 12 : 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child:
              _isLoading
                  ? SizedBox(
                    width: 20,
                    height: 20,
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
                        16,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ],
    );
  }
}

/// Modern admin authentication dialog
class _AdminAuthDialog extends StatefulWidget {
  const _AdminAuthDialog();

  @override
  State<_AdminAuthDialog> createState() => _AdminAuthDialogState();
}

class _AdminAuthDialogState extends State<_AdminAuthDialog>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();

    // Auto-focus password field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = LOCALIZATION.localize('main_word.password_required');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await AdminAuthDialog.validatePassword(
        _passwordController.text,
      );

      if (isValid) {
        Navigator.of(context).pop(AuthResult.success());
      } else {
        setState(() {
          _errorMessage = LOCALIZATION.localize('main_word.password_incorrect');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          constraints: ResponsiveLayout.getDialogConstraints(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, primaryColor.withOpacity(0.02)],
            ),
          ),
          child: SingleChildScrollView(
            padding: ResponsiveLayout.getResponsivePadding(
              context,
              mobile: 20,
              tablet: 24,
              desktop: 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildAdminIcon(),
                const SizedBox(height: 24),
                _buildPasswordField(),
                if (_errorMessage != null) _buildErrorMessage(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
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
          LOCALIZATION.localize("main_word.admin_authentication"),
          style: TextStyle(
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 22),
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed:
              () => Navigator.of(context).pop(AuthResult.failure("Cancelled")),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminIcon() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: ResponsiveLayout.isMobile(context) ? 40 : 50,
        backgroundColor: primaryColor.withOpacity(0.1),
        child: Icon(
          Icons.admin_panel_settings_rounded,
          size: ResponsiveLayout.isMobile(context) ? 40 : 50,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LOCALIZATION.localize("main_word.admin_password"),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: LOCALIZATION.localize("main_word.enter_admin_password"),
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.security_rounded, color: primaryColor),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            onSubmitted: (_) => _handleLogin(),
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: ResponsiveLayout.getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w500,
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
          onPressed:
              _isLoading
                  ? null
                  : () => Navigator.of(
                    context,
                  ).pop(AuthResult.failure("Cancelled")),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.isMobile(context) ? 16 : 20,
              vertical: ResponsiveLayout.isMobile(context) ? 8 : 12,
            ),
          ),
          child: Text(
            LOCALIZATION.localize("main_word.cancel"),
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 16),
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButtonWithSound(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: primaryColor.withOpacity(0.4),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveLayout.isMobile(context) ? 20 : 28,
              vertical: ResponsiveLayout.isMobile(context) ? 12 : 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child:
              _isLoading
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Text(
                    LOCALIZATION.localize("main_word.authenticate"),
                    style: TextStyle(
                      fontSize: ResponsiveLayout.getResponsiveFontSize(
                        context,
                        16,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
        ),
      ],
    );
  }
}
