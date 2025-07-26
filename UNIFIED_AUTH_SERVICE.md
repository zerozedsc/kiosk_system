# Unified Authentication Service

## Overview

I've created a modern, responsive, and unified authentication service for your kiosk application that can be used by both the cashier page and inventory page. This service provides a consistent and modern user experience across your application.

## Key Features

### 🎨 Modern 2025 Kiosk Design
- **Gradient backgrounds** with subtle brand color integration
- **Card-based layouts** with smooth shadows and rounded corners
- **Hero animations** for employee avatars during transitions
- **Responsive grid system** that adapts to different screen sizes
- **Modern iconography** using rounded material icons
- **Smooth animations** for page transitions and loading states

### 📱 Responsive Layout
- **Mobile-first approach** with breakpoints for mobile, tablet, and desktop
- **Dynamic grid calculations** that fit optimal number of employee tiles
- **Adaptive font sizes** that scale based on screen size
- **Flexible dialog constraints** for different screen sizes
- **Touch-optimized** button and input field sizes

### 🔐 Unified Authentication Types
- **Employee Authentication** - For cashier access with employee selection
- **Admin Authentication** - For inventory and settings access
- **Consistent API** - Single service handles both authentication types

## Usage Examples

### Cashier Page Authentication
```dart
// In cashier_page.dart - Shows employee selection screen
Widget _buildEmployeeAuthScreen() {
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
      child: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await UnifiedAuthService.showEmployeeAuth(
              context,
              authenticator: (employee, password) => empAuth(employee, password, LOGS: CASHIER_LOGS),
              employees: EMPQUERY.employees,
              logs: CASHIER_LOGS,
            );
            
            if (result != null && result.success) {
              setState(() {
                _isAuthenticated = true;
                employeeID = result.employeeID!;
                employeeName = result.employeeName!;
              });
            }
          },
          child: Text("Select Employee Account"),
        ),
      ),
    ),
  );
}
```

### Inventory Page Authentication
```dart
// In inventory_page.dart - Shows admin authentication dialog
Future<void> _showAdminAuthDialog() async {
  final authResult = await UnifiedAuthService.showAdminAuth(context);

  if (authResult == null || !authResult.success) {
    showToastMessage(
      context,
      "Admin authentication failed.",
      ToastLevel.error,
    );
    return;
  }

  setState(() => _isAuthenticated = true);
}
```

## Design Features

### Employee Selection Screen
- **Modern grid layout** with responsive columns (1-6 based on screen size)
- **Employee cards** with profile images, names, and usernames
- **Hero animations** for smooth transitions
- **Empty state** with helpful messaging
- **Gradient background** for visual appeal

### Employee Login Dialog
- **Modal dialog** with modern styling
- **Profile display** with employee photo and details
- **Secure password input** with show/hide toggle
- **Real-time error feedback** with styled error messages
- **Loading states** during authentication
- **Keyboard shortcuts** (Enter to submit)

### Admin Authentication Dialog
- **Clean admin-focused design** with security icon
- **Streamlined password entry**
- **Consistent styling** with employee authentication
- **Error handling** and feedback

## Files Created/Modified

### New Files
- `lib/services/auth/unified_auth_service.dart` - Main authentication service

### Modified Files
- `lib/pages/cashier_page.dart` - Updated to use UnifiedAuthService
- `lib/pages/inventory_page.dart` - Updated to use UnifiedAuthService
- `lib/services/auth/auth_service.dart` - Cleaned up old authentication code

## Benefits

1. **Consistency** - Same authentication experience across the app
2. **Maintainability** - Single source of truth for authentication logic
3. **Modern UX** - 2025-appropriate kiosk interface design
4. **Responsive** - Works great on all screen sizes
5. **Accessible** - Proper focus management and keyboard navigation
6. **Performance** - Optimized animations and efficient rendering
7. **Scalable** - Easy to add new authentication types in the future

## Technical Implementation

### AuthResult Class
```dart
class AuthResult {
  final bool success;
  final String? employeeID;
  final String? employeeName;
  final String? errorMessage;
}
```

### UnifiedAuthService Methods
- `showEmployeeAuth()` - Shows employee selection and login
- `showAdminAuth()` - Shows admin authentication dialog
- `showAuth()` - Generic method that routes to appropriate auth type

The service uses the existing `empAuth()` and `AdminAuthDialog.validatePassword()` functions for actual authentication, while providing a modern, unified interface layer.
