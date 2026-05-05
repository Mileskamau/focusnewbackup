class AppConstants {
  // App Info
  static const String appName = 'Focus SwiftBill';
  static const String appVersion = '1.0.0';

  // Routes
  static const String routeLogin = '/login';
  static const String routeQuickLogin = '/quick-login';
  static const String routeQuickLoginSetup = '/quick-login-setup';
  static const String routeDashboard = '/dashboard';
  static const String routeBilling = '/billing';
  static const String routeOrders = '/orders';
  static const String routeCustomers = '/customers';
  static const String routeReports = '/reports';
  static const String routeMore = '/more';
  static const String routeCart = '/cart';
  static const String routePayment = '/payment';
  static const String routeReceipt = '/receipt';
  static const String routeCustomerProfile = '/customer-profile';
  static const String routeOrderDetails = '/order-details';
  static const String routePrinters = '/printers';
  static const String routeBackup = '/backup';
  

  // User Roles
  static const String roleManager = 'Outlet Manager';
  static const String roleCashier = 'Counter (Cashier)';

  // Session
  static const int sessionTimeoutMinutes = 15;

  // PIN
  static const int pinLength = 6;

  // Tax
  static const double taxRate = 0.18; // 10% GST
  
  // Currency
  static const String currencySymbol = '';

  // Discount
  static const double maxDiscountPercentage = 0.25; // 25% max
  static const double cashierMaxDiscount = 0.05; // 5% for cashiers

  // Pagination
  static const int productsPerPage = 20;

  // Sync
  static const int maxSyncRetries = 3;

  // Shared Preferences Keys
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyAccessToken = 'access_token';
  static const String keyRememberMe = 'remember_me';
  static const String keyUsername = 'username';
  static const String keyQuickLoginEnabled = 'quick_login_enabled';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyUserPin = 'user_pin';
  static const String keySessionStart = 'session_start';

  // Demo Credentials
  static const String demoUsername = 'counter01';
  static const String demoPassword = 'demo123';

  // Order Status
  
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  

  // Payment Methods
  static const String paymentCash = 'cash';
  static const String paymentCard = 'card';
  static const String paymentUPI = 'upi';
  static const String paymentWallet = 'wallet';
  static const String paymentmpesa = 'mpesa';


  // Sync Status
  static const String syncSyncing = 'syncing';
  static const String syncFailed = 'failed';
  static const String syncCompleted = 'completed';
}
