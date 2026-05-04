import 'package:focus_swiftbill/utils/constants.dart';

class RbacService {
  String getStoreName() {
    return '';
  }

  bool canViewReports(String role) {
    return role == AppConstants.roleManager;
  }

  bool canCancelOrder(String role) {
    return role == AppConstants.roleManager || role == AppConstants.roleCashier;
  }

  bool canRefund(String role) {
    return role == AppConstants.roleManager;
  }

  bool canManageCashiers(String role) {
    return role == AppConstants.roleManager;
  }

  bool canApplyDiscount(String role, [double maxPercent = 0]) {
    if (role == AppConstants.roleManager) {
      return true;
    }
    if (role == AppConstants.roleCashier) {
      return maxPercent <= 10.0;
    }
    return false;
  }

  bool canViewFullDashboard(String role) {
    return role == AppConstants.roleManager;
  }
}
