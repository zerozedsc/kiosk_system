// main import
import '../configs/configs.dart';

import '../services/auth/auth_service.dart';
import '../services/page_controller.dart';

// components
import '../components/toastmsg.dart';
import '../components/buttonswithsound.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final kioskNameController = TextEditingController();
  final locationController = TextEditingController();
  final adminPasswordController = TextEditingController();

  @override
  void dispose() {
    kioskNameController.dispose();
    locationController.dispose();
    adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!globalAppConfig["kiosk_info"]?["registered"]) {
      // If the app is already registered, navigate to the login page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showToastMessage(
          context,
          LOCALIZATION.localize("main_word.app_not_registered"),
          ToastLevel.warning,
        );
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.app_registration,
                      size: 100,
                      color: secondaryColor,
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

            // Right side - Signup form
            Expanded(
              flex: 3,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          LOCALIZATION.localize('auth_page.signup_kiosk'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Kiosk Name
                        TextField(
                          controller: kioskNameController,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize('auth_page.kiosk_name') ??
                                "Kiosk Name",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.store),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Kiosk Location
                        TextField(
                          controller: locationController,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize('auth_page.location') ??
                                "Location",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.location_on),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.my_location),
                              tooltip:
                                  LOCALIZATION.localize(
                                    'main_word.get_location',
                                  ) ??
                                  "Get Current Location",
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
                                  Navigator.of(
                                    context,
                                  ).pop(); // Close loading dialog
                                  if (address["success"]) {
                                    setState(() {
                                      locationController.text =
                                          address["address"];
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
                                  Navigator.of(
                                    context,
                                  ).pop(); // Close loading dialog
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
                        const SizedBox(height: 20),

                        // Admin Password
                        TextField(
                          controller: adminPasswordController,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize(
                                  'auth_page.admin_password',
                                ) ??
                                "Admin Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 20),

                        // Signup Button
                        ElevatedButtonWithSound(
                          onPressed: () async {
                            Map<String, dynamic> data = {
                              "kiosk_id": "RZKIOSK001",
                              "kiosk_password":
                                  DEBUG ? "1234" : generateStrongPassword(6),
                              "kiosk_name": kioskNameController.text.trim(),
                              "location": locationController.text.trim(),
                            };

                            final checkSignUp =
                                await AppFirstAuthService.signup(context, data);

                            if (checkSignUp) {
                              showToastMessage(
                                context,
                                LOCALIZATION.localize(
                                  'auth_page.account_created',
                                ),
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
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(
                                              context,
                                            ).pop(); // Close dialog
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        const LoginPage(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            LOCALIZATION.localize(
                                                  'main_word.ok',
                                                ) ??
                                                "OK",
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                            } else {
                              showToastMessage(
                                context,
                                LOCALIZATION.localize(
                                  'auth_page.account_creation_failed',
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
                          ),
                          child: Text(
                            LOCALIZATION.localize('auth_page.signup_button'),
                          ),
                        ),
                        const SizedBox(height: 10),

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
                            } // Return to login page
                          },
                          child: Text(
                            LOCALIZATION.localize(
                              'auth_page.already_have_account',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
      resizeToAvoidBottomInset: false,
      body: Padding(
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
                    Icon(Icons.store, size: 100, color: secondaryColor),
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

            // Right side - Login form
            Expanded(
              flex: 3,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LOCALIZATION.localize('auth_page.login'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Kiosk ID
                      TextField(
                        controller: kioskIdController,
                        decoration: InputDecoration(
                          labelText: LOCALIZATION.localize(
                            'auth_page.kiosk_id',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          prefixIcon: const Icon(Icons.fingerprint),
                          labelStyle: const TextStyle(color: Colors.black),
                          hintStyle: const TextStyle(color: Colors.black),
                        ),
                        style: const TextStyle(color: Colors.black),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 20),

                      // Kiosk Password
                      TextField(
                        controller: kioskPasswordController,
                        decoration: InputDecoration(
                          labelText:
                              LOCALIZATION.localize(
                                'auth_page.kiosk_password',
                              ) ??
                              "Kiosk Password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          prefixIcon: const Icon(Icons.lock),
                          labelStyle: const TextStyle(color: Colors.black),
                          hintStyle: const TextStyle(color: Colors.black),
                        ),
                        style: const TextStyle(color: Colors.black),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),

                      // Login Button
                      ElevatedButtonWithSound(
                        onPressed: () async {
                          final kioskId = kioskIdController.text.trim();
                          final kioskPassword =
                              kioskPasswordController.text.trim();

                          if (kioskId.isEmpty || kioskPassword.isEmpty) {
                            showToastMessage(
                              context,
                              "Please enter both Kiosk ID and Password",
                              ToastLevel.error,
                              position: ToastPosition.bottom,
                            );
                            return;
                          }

                          final checkLogin = await AppFirstAuthService.login(
                            context,
                            {
                              "kiosk_id": kioskId,
                              "kiosk_password": kioskPassword,
                            },
                          );

                          if (checkLogin["success"]) {
                            showToastMessage(
                              context,
                              LOCALIZATION.localize(
                                'auth_page.${checkLogin["message"]}',
                              ),
                              ToastLevel.success,
                              position: ToastPosition.bottom,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const PageControllerClass(),
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
                        ),
                        child: Text(
                          LOCALIZATION.localize('auth_page.login_button'),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Signup Button
                          TextButton(
                            onPressed: () async {
                              if (!globalAppConfig["kiosk_info"]?["registered"]) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupPage(),
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
                            ),
                          ),

                          // Forgot Password Button
                          TextButton(
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
                              LOCALIZATION.localize(
                                'auth_page.forgot_password',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
