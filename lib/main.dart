import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
// Removed direct HomeScreen import; shown via AppLockGate
import 'screens/auth/auth_screen.dart';
import 'screens/transaction/transaction_form_screen.dart';
import 'screens/transaction/transaction_detail_screen.dart';
import 'screens/wallet/wallet_form_screen.dart';
import 'screens/wallet/wallets_manage_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/category/categories_screen.dart';
import 'screens/about/about_screen.dart';
import 'screens/transaction/debt_form_screen.dart';
import 'screens/event/events_screen.dart';
import 'screens/debug/app_check_debug_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/persistent_notification_screen.dart';
import 'screens/wallet/wallet_detail_screen.dart';
import 'screens/wallet/transfer_screen.dart';
import 'screens/wallet/transfer_across_screen.dart';
import 'screens/wallet/adjust_balance_screen.dart';
import 'screens/wallet/wallet_pin_setup_screen.dart';
import 'screens/wallet/wallet_pin_verify_screen.dart';
import 'screens/settings/app_pin_setup_screen.dart';
import 'screens/settings/app_pin_verify_screen.dart';
import 'screens/settings/app_pin_settings_screen.dart';
import 'screens/settings/app_lock_gate.dart';
import 'models/wallet.dart';
import 'utils/app_theme.dart';
import 'services/user_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// CONFIGURATION: Set to false to disable App Check temporarily
const bool ENABLE_APP_CHECK = false; // DISABLED for web compatibility

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Startup logs trimmed to reduce noise

  // Initialize Indonesian locale for date formatting
  await initializeDateFormatting('id_ID', null);
  // Locale initialized

  // Initialize Firebase
  // Firebase initializing
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase initialized

  // Initialize Firebase App Check with conditional loading
  if (ENABLE_APP_CHECK) {
  // App Check init
    try {
  // Attempting App Check activate

      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );

  // App Check activated

      // Test token retrieval
      try {
  await FirebaseAppCheck.instance.getToken();
  // Token obtained (value ignored intentionally)
      } catch (tokenError) {
  // Token error
      }
    } catch (e) {
  debugPrint('[ERROR] Firebase App Check activation failed: $e');

      // Additional debug info
  // Debug context removed
    }
  } else {
  // App Check disabled
  }

  // Initialize Hive for offline storage
  // Hive init
  await Hive.initFlutter();
  // Hive ready

  // Launching app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navKey,
      title: 'Money Tracker',
      debugShowCheckedModeBanner: false,
      // Localization configuration for Indonesian
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Indonesian
        Locale('en', 'US'), // English (fallback)
      ],
      locale: const Locale('id', 'ID'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // TODO: Make this configurable
      routes: {
        '/add-transaction': (context) => const TransactionFormScreen(),
        '/transaction-detail': (context) {
          final transaction = ModalRoute.of(context)!.settings.arguments;
          return TransactionDetailScreen(transaction: transaction as dynamic);
        },
        '/add-debt': (context) => const DebtFormScreen(),
        '/add-wallet': (context) {
          final wallet = ModalRoute.of(context)?.settings.arguments as Wallet?;
          return WalletFormScreen(initial: wallet);
        },
        '/manage-wallets': (context) => const WalletsManageScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/categories': (context) => const CategoriesScreen(),
        '/about': (context) => const AboutScreen(),
        '/events': (context) => const EventsScreen(),
        '/debug-appcheck': (context) => const AppCheckDebugScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/persistent-notifications': (context) =>
            const PersistentNotificationScreen(),
        '/wallet-pin-setup': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return WalletPinSetupScreen(
            walletId: args['walletId'] as String,
            walletName: args['walletName'] as String,
            currentPin: args['currentPin'] as String?,
          );
        },
        '/wallet-pin-verify': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return WalletPinVerifyScreen(
            walletName: args['walletName'] as String,
            correctPin: args['pin'] as String,
            onSuccess: () {},
          );
        },
        '/app-pin-setup': (context) => const AppPinSetupScreen(),
        '/app-pin-verify': (context) => const AppPinVerifyScreen(),
        '/app-pin-settings': (context) => const AppPinSettingsScreen(),
        '/wallet-detail': (context) {
          final wallet = ModalRoute.of(context)!.settings.arguments;
          return WalletDetailScreen(wallet: wallet as dynamic);
        },
        '/transfer': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return TransferScreen(
            sourceWallet: args['sourceWallet'] as Wallet,
            otherWallets: args['otherWallets'] as List<Wallet>,
          );
        },
        '/transfer-across': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return TransferAcrossScreen(
            sourceWallet: args['sourceWallet'] as Wallet,
          );
        },
        '/adjust-balance': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return AdjustBalanceScreen(wallet: args['wallet'] as Wallet);
        },
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Auth state changes

          // Show splash while waiting for auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Splash while waiting auth
            return const SplashScreen();
          }

          // Handle auth errors
          if (snapshot.hasError) {
            debugPrint('[ERROR] Auth error: ${snapshot.error}');
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Auth Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Force restart by rebuilding the widget tree
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const MyApp()),
                          (route) => false,
                        );
                      },
                      child: const Text('Restart'),
                    ),
                  ],
                ),
              ),
            );
          }

          final user = snapshot.data;
          // Current user id logged suppressed

          if (user == null) {
            // No user -> Auth screen
            return const AuthScreen();
          }

          // Show splash while initializing user data
          return FutureBuilder<void>(
            future: UserService().ensureUserInitialized(user),
            builder: (context, initSnapshot) {
              // User init state

              if (initSnapshot.connectionState == ConnectionState.waiting) {
                // Splash while initializing user
                return const SplashScreen();
              }

              if (initSnapshot.hasError) {
                debugPrint('[ERROR] User initialization error: ${initSnapshot.error}');
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text('Init Error: ${initSnapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const MyApp()),
                              (route) => false,
                            );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // App lock gate check
              return AppLockGate(uid: user.uid);
            },
          );
        },
      ),
    );
  }
}
