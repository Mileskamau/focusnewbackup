import 'package:flutter/material.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';

// Logo Header with Gradient Circle
class CustomLogoHeader extends StatelessWidget {
  const CustomLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryOrange, AppTheme.primaryLightOrange],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
         child: Image.asset(
           'assets/logo.png',
           width: 48,
           height: 48,
           fit: BoxFit.contain,
         ),
      ),
    );
  }
}

// Brand Text
class CustomBrandText extends StatelessWidget {
  const CustomBrandText({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text(
            '',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppTheme.primaryOrange,
            ),
          ),
          const Text(
            '',
            style: TextStyle(
              fontSize: 16,
              letterSpacing: 4,
              color: AppTheme.accentGold,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 14, color: AppTheme.accentGold),
                SizedBox(width: 4),
                Text(
                  'Smart Billing • Fast Checkout',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Welcome Section
class CustomWelcomeSection extends StatelessWidget {
  const CustomWelcomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Login to your account',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// Role Dropdown
class CustomRoleDropdown extends StatelessWidget {
  final String selectedRole;
  final List<String> roles;
  final Function(String) onRoleChanged;

  const CustomRoleDropdown({
    super.key,
    required this.selectedRole,
    required this.roles,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedRole,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryOrange),
          isExpanded: true,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textDark,
          ),
          items: roles.map((String role) {
            return DropdownMenuItem<String>(
              value: role,
              child: Row(
                children: [
                  Icon(
                    role == 'Outlet'
                        ? Icons.storefront
                        : Icons.point_of_sale,
                    size: 20,
                    color: AppTheme.primaryOrange,
                  ),
                  const SizedBox(width: 12),
                  Text(role),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onRoleChanged(value);
            }
          },
        ),
      ),
    );
  }
}

// Custom Text Field
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: AppTheme.primaryOrange),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
    );
  }
}

// Custom Checkbox
class CustomCheckbox extends StatelessWidget {
  final bool value;
  final Function(bool) onChanged;
  final String label;

  const CustomCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: (val) => onChanged(val ?? false),
            activeColor: AppTheme.primaryOrange,
            checkColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

// Custom Text Button
class CustomTextButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const CustomTextButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.accentGold,
      ),
      child: Text(label),
    );
  }
}

// Login Button
class CustomLoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CustomLoginButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryOrange.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'LOGIN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}

// Demo Info Card
class CustomDemoCard extends StatelessWidget {
  const CustomDemoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.accentGold, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Demo: Use "counter01" / any password',
              style: TextStyle(color: AppTheme.textLight, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// Footer
class CustomFooter extends StatelessWidget {
  const CustomFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Version 1.0.0',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
      ),
    );
  }
}
