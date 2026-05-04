import 'package:flutter/material.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:focus_swiftbill/screens/more/printer_settings_screen.dart';
import 'package:focus_swiftbill/screens/more/backup_screen.dart';
import 'package:focus_swiftbill/screens/more/user_management_screen.dart';
import 'package:focus_swiftbill/screens/more/quick_login_settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _auth = AuthService();
    final userRole = _auth.getUserRole();
    final userName = _auth.getUserName();

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                    child: Icon(Icons.person, size: 30, color: AppTheme.primaryOrange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           userName ?? 'User',
                           style: const TextStyle(
                             fontSize: 16,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         Text(
                           userRole ?? AppConstants.roleCashier,
                           style: TextStyle(
                             fontSize: 13,
                             color: Colors.grey.shade600,
                           ),
                         ),
                       ],
                     ),
                  ),
                  
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),

          _buildTile(
            icon: Icons.store,
            title: 'Store Profile',
            subtitle: 'Edit store name, address, GST',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          _buildTile(
            icon: Icons.print,
            title: 'Printer Settings',
            subtitle: 'Configure Bluetooth / Wi-Fi printer',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrinterSettingsScreen(),
                ),
              );
            },
          ),

          _buildTile(
            icon: Icons.cloud_upload,
            title: 'Offline Data',
            subtitle: 'View pending sync, force sync',
          onTap: () {
            final pending = DatabaseService.getPendingOrders().length;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$pending orders pending sync'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          ),

          _buildTile(
            icon: Icons.backup,
            title: 'Backup & Restore',
            subtitle: 'Export/Import local data',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackupScreen(),
                ),
              );
            },
          ),

          if (userRole == AppConstants.roleManager) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildTile(
              icon: Icons.people,
              title: 'User Management',
              subtitle: 'Add/edit cashiers, reset passwords',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          

          

          const SizedBox(height: 24),

          const Text(
            'ABOUT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),

          _buildTile(
            icon: Icons.info,
            title: 'About',
            subtitle: 'Version ${AppConstants.appVersion}',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationIcon: const Icon(
                  Icons.shopping_cart_checkout,
                  color: AppTheme.primaryOrange,
                ),
              );
            },
          ),

          _buildTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppTheme.primaryOrange),
        ),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}


