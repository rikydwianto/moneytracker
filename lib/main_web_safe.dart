import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/debug/debug_splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/transaction/transaction_form_screen.dart';
import 'screens/transaction/transaction_detail_screen.dart';
import 'screens/wallet/wallet_form_screen.dart';
import 'screens/wallet/wallets_manage_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/category/categories_screen.dart';
import 'screens/category/add_category_quick_screen.dart';
import 'screens/about/about_screen.dart';
import 'screens/transaction/debt_form_screen.dart';
import 'screens/event/events_screen.dart';
import 'screens/debug/app_check_debug_screen.dart';
import 'screens/wallet/transfer_screen.dart';
import 'screens/wallet/transfer_across_screen.dart';
import 'screens/wallet/adjust_balance_screen.dart';
import 'models/wallet.dart';
import 'utils/app_theme.dart';
import 'services/user_service.dart';
import 'config/app_check_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// CONFIGURATION: Set to false to disable App Check temporarily
const bool ENABLE_APP_CHECK = false; // DISABLED for web compatibility

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('[STARTUP] Starting Money Tracker App...');
  print(
    '[CONFIG] App Check Status: ${ENABLE_APP_CHECK ? "ENABLED" : "DISABLED"}',
  );

  // Initialize Indonesian locale for date formatting
  await initializeDateFormatting('id_ID', null);
  print('[LOCALE] Indonesian locale initialized');

  // Initialize Firebase
  print('[FIREBASE] Initializing Firebase...');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[FIREBASE] Firebase initialized successfully');

  // Initialize Firebase App Check with conditional loading
  if (ENABLE_APP_CHECK) {
    print('[APPCHECK] Initializing Firebase App Check...');
    try {
      print('[APPCHECK] Attempting to activate...');

      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );

      print('[APPCHECK] Activated successfully');

      // Test token retrieval
      try {
        final token = await FirebaseAppCheck.instance.getToken();
        print(
          '[TOKEN] App Check token obtained: ${token?.substring(0, 20) ?? 'null'}...',
        );
      } catch (tokenError) {
        print('[TOKEN] App Check token error: $tokenError');
      }
    } catch (e) {
      print('[ERROR] Firebase App Check activation failed: $e');
      print('[WARNING] App will continue without App Check protection');

      // Additional debug info
      print('[DEBUG] Platform: Web/Chrome');
      print('[DEBUG] Build mode: Debug');
      print('[DEBUG] Provider: AndroidProvider.debug');
    }
  } else {
    print('[DISABLED] Firebase App Check DISABLED by configuration');
    print('[WARNING] App running without App Check protection');
  }

  // Initialize Hive for offline storage
  print('[STORAGE] Initializing Hive...');
  await Hive.initFlutter();
  print('[STORAGE] Hive initialized successfully');

  print('[LAUNCH] Launching app...');
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
        '/add-wallet': (context) => const WalletFormScreen(),
        '/manage-wallets': (context) => const WalletsManageScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/categories': (context) => const CategoriesScreen(),
        '/add-category-quick': (context) => const AddCategoryQuickScreen(),
        '/about': (context) => const AboutScreen(),
        '/events': (context) => const EventsScreen(),
        '/debug-appcheck': (context) => const AppCheckDebugScreen(),
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
          print('DEBUG Route - received args: $args');
          final sourceWallet = args['sourceWallet'] as Wallet;
          print(
            'DEBUG Route - sourceWallet: ${sourceWallet.name}, balance: ${sourceWallet.balance}',
          );
          return TransferAcrossScreen(sourceWallet: sourceWallet);
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
          print(
            '[AUTH] Auth state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, data: ${snapshot.data}',
          );

          // Show splash while waiting for auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('[AUTH] Showing splash - waiting for auth state');
            return const SplashScreen();
          }

          // Handle auth errors
          if (snapshot.hasError) {
            print('[AUTH] Auth error: ${snapshot.error}');
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
          print('[AUTH] Current user: ${user?.uid}');

          if (user == null) {
            print('[AUTH] No user - showing auth screen');
            return const AuthScreen();
          }

          // Show splash while initializing user data
          return FutureBuilder<void>(
            future: UserService().ensureUserInitialized(user),
            builder: (context, initSnapshot) {
              print(
                '[USER] User init state: ${initSnapshot.connectionState}, hasError: ${initSnapshot.hasError}',
              );

              if (initSnapshot.connectionState == ConnectionState.waiting) {
                print('[USER] Showing splash - initializing user data');
                return const SplashScreen();
              }

              if (initSnapshot.hasError) {
                print(
                  '[USER] User initialization error: ${initSnapshot.error}',
                );
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

              print('[USER] Showing home screen');
              return const HomeScreen();
            },
          );
        },
      ),
    );
  }
}
