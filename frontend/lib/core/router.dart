import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/otp_reset_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/products/product_form_screen.dart';
import '../screens/receipts/receipts_screen.dart';
import '../screens/receipts/receipt_form_screen.dart';
import '../screens/deliveries/deliveries_screen.dart';
import '../screens/deliveries/delivery_form_screen.dart';
import '../screens/transfers/transfers_screen.dart';
import '../screens/transfers/transfer_form_screen.dart';
import '../screens/adjustments/adjustments_screen.dart';
import '../screens/adjustments/adjustment_form_screen.dart';
import '../screens/ledger/ledger_screen.dart';
import '../screens/warehouses/warehouses_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/app_shell.dart';

final _authService = AuthService();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) async {
      final loggedIn = await _authService.isLoggedIn();
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      if (!loggedIn && !isAuthRoute) return '/auth/login';
      if (loggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // ── Auth routes (no shell) ────────────────────────────────────────────
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/auth/otp-reset', builder: (_, __) => const OtpResetScreen()),

      // ── App routes (with shell) ───────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),

          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/products/new', builder: (_, __) => const ProductFormScreen()),
          GoRoute(path: '/products/:id/edit', builder: (_, state) =>
              ProductFormScreen(productId: int.parse(state.pathParameters['id']!))),

          GoRoute(path: '/receipts', builder: (_, __) => const ReceiptsScreen()),
          GoRoute(path: '/receipts/new', builder: (_, __) => const ReceiptFormScreen()),
          GoRoute(path: '/receipts/:id', builder: (_, state) =>
              ReceiptFormScreen(receiptId: int.parse(state.pathParameters['id']!))),

          GoRoute(path: '/deliveries', builder: (_, __) => const DeliveriesScreen()),
          GoRoute(path: '/deliveries/new', builder: (_, __) => const DeliveryFormScreen()),
          GoRoute(path: '/deliveries/:id', builder: (_, state) =>
              DeliveryFormScreen(deliveryId: int.parse(state.pathParameters['id']!))),

          GoRoute(path: '/transfers', builder: (_, __) => const TransfersScreen()),
          GoRoute(path: '/transfers/new', builder: (_, __) => const TransferFormScreen()),
          GoRoute(path: '/transfers/:id', builder: (_, state) =>
              TransferFormScreen(transferId: int.parse(state.pathParameters['id']!))),

          GoRoute(path: '/adjustments', builder: (_, __) => const AdjustmentsScreen()),
          GoRoute(path: '/adjustments/new', builder: (_, __) => const AdjustmentFormScreen()),
          GoRoute(path: '/adjustments/:id', builder: (_, state) =>
              AdjustmentFormScreen(adjustmentId: int.parse(state.pathParameters['id']!))),

          GoRoute(path: '/ledger', builder: (_, __) => const LedgerScreen()),
          GoRoute(path: '/warehouses', builder: (_, __) => const WarehousesScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
