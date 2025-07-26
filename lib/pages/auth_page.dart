// main import
import '../configs/configs.dart';

import '../services/auth/auth_service.dart';
import '../services/page_controller.dart';

// components
import '../components/toastmsg.dart';
import '../components/buttonswithsound.dart';

class RegisterKioskPage extends StatefulWidget {
  const RegisterKioskPage({Key? key}) : super(key: key);

  @override
  State<RegisterKioskPage> createState() => _RegisterKioskPageState();
}

class _RegisterKioskPageState extends State<RegisterKioskPage> {
  final kioskNameController = TextEditingController();
  final locationController = TextEditingController();
  final adminPasswordController = TextEditingController();
  bool callNotRegisterToast = false;

  @override
  void dispose() {
    kioskNameController.dispose();
    locationController.dispose();
    adminPasswordController.dispose();
    super.dispose();
  }

  Widget _buildRegistrationForm(BoxConstraints constraints) {
    bool isWideScreen = constraints.maxWidth > 800;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWideScreen ? 500 : constraints.maxWidth - 32,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LOCALIZATION.localize('auth_page.signup_kiosk'),
                style: TextStyle(
                  fontSize: isWideScreen ? 24 : 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isWideScreen ? 20 : 16),

              // Kiosk Name
              TextField(
                controller: kioskNameController,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: InputDecoration(
                  labelText: LOCALIZATION.localize('auth_page.kiosk_name'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.store),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isWideScreen ? 16 : 12,
                  ),
                ),
              ),
              SizedBox(height: isWideScreen ? 20 : 16),

              // Kiosk Location
              TextField(
                controller: locationController,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: InputDecoration(
                  labelText: LOCALIZATION.localize('auth_page.location'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isWideScreen ? 16 : 12,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: LOCALIZATION.localize('main_word.get_location'),
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                      );
                      try {
                        Map<String, dynamic> address =
                            await getCurrentAddress();
                        Navigator.of(context).pop(); // Close loading dialog
                        if (address["success"]) {
                          setState(() {
                            locationController.text = address["address"];
                          });
                        } else {
                          setState(() {
                            locationController.text = "";
                          });
                          showToastMessage(
                            context,
                            "auth_page.${address["message"]}",
                            ToastLevel.error,
                            position: ToastPosition.bottom,
                          );
                        }
                      } catch (e) {
                        Navigator.of(context).pop(); // Close loading dialog
                        setState(() {
                          locationController.text = "";
                        });
                        showToastMessage(
                          context,
                          LOCALIZATION.localize(
                            'auth_page.failed_to_get_location',
                          ),
                          ToastLevel.error,
                          position: ToastPosition.bottom,
                        );
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: isWideScreen ? 20 : 16),

              // Admin Password
              TextField(
                controller: adminPasswordController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: LOCALIZATION.localize('auth_page.admin_password'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isWideScreen ? 16 : 12,
                  ),
                ),
                obscureText: true,
              ),
              SizedBox(height: isWideScreen ? 20 : 16),

              // Signup Button
              ElevatedButtonWithSound(
                onPressed: () async {
                  String adminPassword = adminPasswordController.text.trim();

                  bool checkAdminAuth =
                      adminPassword ==
                      const String.fromEnvironment('ADMIN_PASSWORD');
                  if (!checkAdminAuth) {
                    showToastMessage(
                      context,
                      LOCALIZATION.localize('auth_page.invalid_admin_password'),
                      ToastLevel.error,
                      position: ToastPosition.bottom,
                    );
                    return;
                  }

                  Map<String, dynamic> data = {
                    "kiosk_id": "RZKIOSK001",
                    "kiosk_password": EncryptService().generateStrongPassword(
                      6,
                    ),
                    "kiosk_name": kioskNameController.text.trim(),
                    "location": locationController.text.trim(),
                  };

                  final checkSignUp = await KioskAuthService.registerKiosk(
                    context,
                    data,
                  );

                  data["kiosk_id"] = checkSignUp["kiosk_id"];

                  if (checkSignUp["success"]) {
                    showToastMessage(
                      context,
                      LOCALIZATION.localize('auth_page.account_created'),
                      ToastLevel.success,
                      position: ToastPosition.bottom,
                    );

                    // Show dialog with kiosk ID and password
                    final kioskId = data["kiosk_id"];
                    final kioskPassword = data["kiosk_password"];

                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (context) => AlertDialog(
                            title: Text(
                              LOCALIZATION.localize(
                                'auth_page.kiosk_credentials',
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${LOCALIZATION.localize('auth_page.kiosk_id')}: $kioskId",
                                ),
                                const SizedBox(height: 8),

                                Text(
                                  "${LOCALIZATION.localize('auth_page.kiosk_password')}: $kioskPassword",
                                ),
                              ],
                            ),
                            actions: [
                              // Close dialog
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  LOCALIZATION.localize('main_word.ok'),
                                ),
                              ),

                              // Copy credentials to clipboard
                              TextButton(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: "$kioskPassword"),
                                  );
                                  showToastMessage(
                                    context,
                                    LOCALIZATION.localize(
                                      'auth_page.credentials_copied',
                                    ),
                                    ToastLevel.success,
                                    position: ToastPosition.bottom,
                                  );
                                },
                                child: Text(
                                  LOCALIZATION.localize('main_word.copy'),
                                ),
                              ),
                            ],
                          ),
                    );
                  } else {
                    showToastMessage(
                      context,
                      "${LOCALIZATION.localize('auth_page.account_creation_failed')} ${checkSignUp["message"]}",
                      ToastLevel.error,
                      position: ToastPosition.bottom,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: secondaryColor,
                  shadowColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    vertical: isWideScreen ? 16 : 14,
                  ),
                ),
                child: Text(
                  LOCALIZATION.localize('auth_page.signup_button'),
                  style: TextStyle(fontSize: isWideScreen ? 16 : 14),
                ),
              ),
              SizedBox(height: isWideScreen ? 10 : 8),

              // Already have an account button
              TextButton(
                onPressed: () {
                  if (ModalRoute.of(context)?.isCurrent == true) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  }
                },
                child: Text(
                  LOCALIZATION.localize('auth_page.already_have_account'),
                  style: TextStyle(fontSize: isWideScreen ? 14 : 12),
                ),
              ),
              // Add bottom padding for keyboard space
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!globalAppConfig["kiosk_info"]?["registered"] &&
        !callNotRegisterToast) {
      // If the app is already registered, navigate to the login page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showToastMessage(
          context,
          LOCALIZATION.localize("main_word.app_not_registered"),
          ToastLevel.warning,
        );
      });
      callNotRegisterToast = true;
    }

    return Scaffold(
      resizeToAvoidBottomInset: true, // Allow keyboard to resize the content
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive layout based on screen size
          bool isWideScreen = constraints.maxWidth > 800;

          if (isWideScreen) {
            // Wide screen layout (tablet/desktop)
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/rozeriya_logo.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.app_registration,
                                size: 100,
                                color: secondaryColor,
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            LOCALIZATION.localize('app_name'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(thickness: 1, width: 40),
                  Expanded(flex: 3, child: _buildRegistrationForm(constraints)),
                ],
              ),
            );
          } else {
            // Narrow screen layout (mobile)
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Logo section
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        /// Icon
                        Image.asset(
                          'assets/images/rozeriya-logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.app_registration,
                              size: 80,
                              color: secondaryColor,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          LOCALIZATION.localize('app_name'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Form section
                  _buildRegistrationForm(constraints),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final kioskIdController = TextEditingController();
  final kioskPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-fill Kiosk ID if registered
    if (globalAppConfig["kiosk_info"]?["registered"] == true) {
      kioskIdController.text = globalAppConfig["kiosk_info"]?["kiosk_id"] ?? "";
    }
  }

  @override
  void dispose() {
    kioskIdController.dispose();
    kioskPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Allow keyboard to resize the content
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive layout based on screen size
          bool isWideScreen = constraints.maxWidth > 800;

          if (isWideScreen) {
            // Wide screen layout (tablet/desktop)
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Left side - Logo or image (optional)
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/rozeriya_logo.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.store,
                                size: 100,
                                color: secondaryColor,
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            LOCALIZATION.localize('app_name'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(thickness: 1, width: 40),
                  Expanded(flex: 3, child: _buildLoginForm(constraints)),
                ],
              ),
            );
          } else {
            // Narrow screen layout (mobile)
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Logo section
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/rozeriya-logo.png',
                          width: 100,
                          height: 80,
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.store,
                              size: 80,
                              color: secondaryColor,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          LOCALIZATION.localize('app_name'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Form section
                  _buildLoginForm(constraints),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildLoginForm(BoxConstraints constraints) {
    bool isWideScreen = constraints.maxWidth > 800;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWideScreen ? 500 : constraints.maxWidth - 32,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LOCALIZATION.localize('auth_page.login'),
                style: TextStyle(
                  fontSize: isWideScreen ? 24 : 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isWideScreen ? 20 : 16),

              // Kiosk ID
              TextField(
                controller: kioskIdController,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: InputDecoration(
                  labelText: LOCALIZATION.localize('auth_page.kiosk_id'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.fingerprint),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isWideScreen ? 16 : 12,
                  ),
                  labelStyle: const TextStyle(color: Colors.black),
                  hintStyle: const TextStyle(color: Colors.black),
                ),
                style: const TextStyle(color: Colors.black),
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: isWideScreen ? 20 : 16),

              // Kiosk Password
              TextField(
                controller: kioskPasswordController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: LOCALIZATION.localize('auth_page.kiosk_password'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isWideScreen ? 16 : 12,
                  ),
                  labelStyle: const TextStyle(color: Colors.black),
                  hintStyle: const TextStyle(color: Colors.black),
                ),
                style: const TextStyle(color: Colors.black),
                obscureText: true,
              ),
              SizedBox(height: isWideScreen ? 20 : 16),

              // Login Button
              ElevatedButtonWithSound(
                onPressed: () async {
                  final kioskId = kioskIdController.text.trim();
                  final kioskPassword = kioskPasswordController.text.trim();

                  if (kioskId.isEmpty || kioskPassword.isEmpty) {
                    showToastMessage(
                      context,
                      "Please enter both Kiosk ID and Password",
                      ToastLevel.warning,
                    );
                    return;
                  }

                  final checkLogin = await KioskAuthService.loginKiosk(
                    context,
                    {"kiosk_id": kioskId, "kiosk_password": kioskPassword},
                  );

                  if (checkLogin["success"]) {
                    // Show login success message
                    String successMessage = LOCALIZATION.localize(
                      'auth_page.${checkLogin["message"]}',
                    );

                    // Add online status to message
                    bool isOnline = checkLogin["is_online"] ?? false;
                    String statusMessage =
                        isOnline ? " (Online)" : " (Offline)";

                    showToastMessage(
                      context,
                      successMessage + statusMessage,
                      ToastLevel.success,
                      position: ToastPosition.bottom,
                    );

                    // Sync kiosk credentials to config
                    KioskAuthService.syncKioskKeyToConfig();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PageControllerClass(),
                      ),
                    );
                  } else {
                    showToastMessage(
                      context,
                      LOCALIZATION.localize(
                        'auth_page.${checkLogin["message"]}',
                      ),
                      ToastLevel.error,
                      position: ToastPosition.bottom,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: secondaryColor,
                  shadowColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    vertical: isWideScreen ? 16 : 14,
                  ),
                ),
                child: Text(
                  LOCALIZATION.localize('auth_page.login_button'),
                  style: TextStyle(fontSize: isWideScreen ? 16 : 14),
                ),
              ),
              SizedBox(height: isWideScreen ? 10 : 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Signup Button
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        if (!globalAppConfig["kiosk_info"]?["registered"]) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterKioskPage(),
                            ),
                          );
                        } else {
                          showToastMessage(
                            context,
                            "${LOCALIZATION.localize('main_word.already_registered')}: Please contact support for assistance.",
                            ToastLevel.warning,
                          );
                        }
                      },
                      child: Text(
                        LOCALIZATION.localize('auth_page.new_account'),
                        style: TextStyle(fontSize: isWideScreen ? 14 : 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Forgot Password Button
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        showToastMessage(
                          context,
                          LOCALIZATION.localize(
                            'auth_page.forgot_password_message',
                          ),
                          ToastLevel.info,
                          position: ToastPosition.bottom,
                        );
                      },
                      child: Text(
                        LOCALIZATION.localize('auth_page.forgot_password'),
                        style: TextStyle(fontSize: isWideScreen ? 14 : 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              // Add bottom padding for keyboard space
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }
}
