import 'package:flutter/material.dart';
import 'package:focus_swiftbill/screens/pending_bills.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:focus_swiftbill/services/database_service.dart';
import 'package:focus_swiftbill/services/auth_service.dart';
import 'package:focus_swiftbill/services/api_service.dart';
import 'package:focus_swiftbill/services/session_service.dart';
import 'package:focus_swiftbill/utils/constants.dart';
import 'package:focus_swiftbill/theme/app_theme.dart';
import 'providers/navigation_provider.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/payment/payment_screen.dart';          // ✅ keep only this one
import 'screens/receipt/receipt_screen.dart';
import 'screens/billing/billing_hub_screen.dart';
import 'screens/billing/view_all_billings_screen.dart';
import 'screens/sales orders/salesorders.dart';
import 'screens/camera_scanner/camera_scanner_screen.dart';
import 'screens/admin_settings/admin_setting.dart';
import 'providers/orders_provider.dart'; 
import 'package:focus_swiftbill/providers/data_refresh_provider.dart';

// ❌ removed duplicate: import 'package:focus_swiftbill/screens/payment/payment_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DatabaseService.init();
  await AuthService().init();
  await ApiService().init();
  runApp(const FocusSupermarketApp());
}

class FocusSupermarketApp extends StatefulWidget {
  const FocusSupermarketApp({super.key});

  @override
  State<FocusSupermarketApp> createState() => _FocusSupermarketAppState();
}

class _FocusSupermarketAppState extends State<FocusSupermarketApp> with WidgetsBindingObserver {
  late final SessionService _sessionService;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _sessionService = SessionService(
      onTimeout: () {
        if (navigatorKey.currentContext != null) {
          Navigator.pushNamedAndRemoveUntil(
            navigatorKey.currentContext!,
            '/login',
            (route) => false,
          );
        }
      },
    );
    WidgetsBinding.instance.addObserver(this);
    _sessionService.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionService.resetTimer();
    }
  }

  Widget _withHomeBackButton(Widget child, String routeName) {
    if (routeName == '/main' || routeName == '/login') {
      return child;
    }
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (navigatorKey.currentState != null && 
              navigatorKey.currentState!.canPop()) {
            navigatorKey.currentState!.maybePop();
          } else {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/main', (route) => false);
          }
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()), 
        ChangeNotifierProvider(create: (_) => DataRefreshProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/login',
        navigatorKey: navigatorKey,
        routes: {
          '/login': (context) => _withHomeBackButton(const LoginScreen(), '/login'),
          '/billing': (context) => _withHomeBackButton(const BillingHubScreen(), '/billing'),
          '/pending_bills': (context) => const PendingBillsScreen(),
          '/main': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as int?;
            if (args != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Provider.of<NavigationProvider>(context, listen: false).setIndex(args);
              });
            }
            return const MainScreen();   // ✅ const works after full restart
          },
          '/payment': (context) => _withHomeBackButton(const PaymentScreen(), '/payment'),
          '/receipt': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map?;
            return _withHomeBackButton(ReceiptScreen(order: args?['order'], change: args?['change'] ?? 0), '/receipt');
          },
          '/camera_scanner': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map?;
            return _withHomeBackButton(CameraScannerScreen(title: args?['title'] as String?), '/camera_scanner');
          },
          '/view_all_billings': (context) => _withHomeBackButton(const ViewAllBillingsScreen(), '/view_all_billings'),
          '/salesorders': (context) => _withHomeBackButton(const BillingScreen(), '/salesorders'),
          '/settings': (context) => _withHomeBackButton(const AdminSettingScreen(), '/settings'),
        },
      ),
    );
  }
}
