// main import
import '../configs/configs.dart';
import '../services/page_controller.dart';

// components
import '../components/toastmsg.dart';
import '../components/buttonswithsound.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(LOCALIZATION.localize('auth_page.signup_button')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Left side - Logo or image
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

            // Divider
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
                          LOCALIZATION.localize('auth_page.sigup'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          decoration: InputDecoration(
                            labelText: LOCALIZATION.localize('auth_page.email'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          decoration: InputDecoration(
                            labelText: LOCALIZATION.localize(
                              'auth_page.password',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          decoration: InputDecoration(
                            labelText: LOCALIZATION.localize(
                              'auth_page.confirm_password',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            showToastMessage(
                              context,
                              LOCALIZATION.localize(
                                'auth_page.account_created',
                              ),
                              ToastLevel.success,
                              position: ToastPosition.bottom,
                            );
                            Navigator.pop(context); // Return to login page
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
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Return to login page
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

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

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
                    // You can add your logo here
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

            // Divider
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
                      TextField(
                        decoration: InputDecoration(
                          labelText: LOCALIZATION.localize(
                            'auth_page.username',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          prefixIcon: const Icon(Icons.email),
                          labelStyle: const TextStyle(color: Colors.black),
                          hintStyle: const TextStyle(color: Colors.black),
                        ),
                        style: const TextStyle(color: Colors.black),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        decoration: InputDecoration(
                          labelText: LOCALIZATION.localize(
                            'auth_page.password',
                          ),
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
                      ElevatedButtonWithSound(
                        onPressed: () {
                          AuthService.login(context, "email", "password");
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
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignupPage(),
                                ),
                              );
                            },
                            child: Text(
                              LOCALIZATION.localize('auth_page.new_account'),
                            ),
                          ),
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

class AuthService {
  static Future<bool> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    // Simulate login process
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Close loading dialog
    Navigator.of(context).pop();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PageControllerClass()),
    );

    showToastMessage(
      context,
      LOCALIZATION.localize('auth_page.login_success'),
      ToastLevel.success,
      position: ToastPosition.bottom,
    );
    return true;
  }

  static Future<bool> signup(
    BuildContext context,
    String email,
    String password,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    // Simulate signup process
    await Future.delayed(const Duration(seconds: 2));

    // Close loading dialog
    Navigator.of(context).pop();

    return true;
  }
}
