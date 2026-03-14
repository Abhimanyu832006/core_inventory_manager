import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/all_services.dart';
import '../services/auth_service.dart';

// ── Service singletons ────────────────────────────────────────────────────────
final authServiceProvider = Provider((_) => AuthService());
final productServiceProvider = Provider((_) => ProductService());
final receiptServiceProvider = Provider((_) => ReceiptService());
final deliveryServiceProvider = Provider((_) => DeliveryService());
final transferServiceProvider = Provider((_) => TransferService());
final adjustmentServiceProvider = Provider((_) => AdjustmentService());
final dashboardServiceProvider = Provider((_) => DashboardService());
final ledgerServiceProvider = Provider((_) => LedgerService());
final warehouseServiceProvider = Provider((_) => WarehouseService());

// ── Auth ──────────────────────────────────────────────────────────────────────
final authStateProvider = StateProvider<bool>((ref) => false);

// ── Dashboard KPIs ────────────────────────────────────────────────────────────
final dashboardKpisProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(dashboardServiceProvider).getKpis();
});

// ── Products ──────────────────────────────────────────────────────────────────
final productSearchProvider = StateProvider<String>((ref) => '');
final productCategoryFilterProvider = StateProvider<int?>((ref) => null);

final productsProvider = FutureProvider<List<dynamic>>((ref) async {
  final search = ref.watch(productSearchProvider);
  final catId = ref.watch(productCategoryFilterProvider);
  return ref.read(productServiceProvider).getProducts(
    search: search.isEmpty ? null : search,
    categoryId: catId,
  );
});

final categoriesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(productServiceProvider).getCategories();
});

// ── Receipts ──────────────────────────────────────────────────────────────────
final receiptStatusFilterProvider = StateProvider<String?>((ref) => null);

final receiptsProvider = FutureProvider<List<dynamic>>((ref) async {
  final status = ref.watch(receiptStatusFilterProvider);
  return ref.read(receiptServiceProvider).getReceipts(status: status);
});

// ── Deliveries ────────────────────────────────────────────────────────────────
final deliveryStatusFilterProvider = StateProvider<String?>((ref) => null);

final deliveriesProvider = FutureProvider<List<dynamic>>((ref) async {
  final status = ref.watch(deliveryStatusFilterProvider);
  return ref.read(deliveryServiceProvider).getDeliveries(status: status);
});

// ── Transfers ─────────────────────────────────────────────────────────────────
final transferStatusFilterProvider = StateProvider<String?>((ref) => null);

final transfersProvider = FutureProvider<List<dynamic>>((ref) async {
  final status = ref.watch(transferStatusFilterProvider);
  return ref.read(transferServiceProvider).getTransfers(status: status);
});

// ── Adjustments ───────────────────────────────────────────────────────────────
final adjustmentsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(adjustmentServiceProvider).getAdjustments();
});

// ── Warehouses ────────────────────────────────────────────────────────────────
final warehousesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(warehouseServiceProvider).getWarehouses();
});

final allLocationsProvider = FutureProvider<Map<int, String>>((ref) async {
  final warehouses = await ref.watch(warehousesProvider.future);
  final Map<int, String> locMap = {};
  for (final wh in warehouses) {
    final locs = await ref.read(warehouseServiceProvider).getLocations(wh['id'] as int);
    for (final loc in locs) {
      locMap[loc['id'] as int] = "${wh['name']} › ${loc['name']}";
    }
  }
  return locMap;
});

// ── Ledger ────────────────────────────────────────────────────────────────────
final ledgerProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(ledgerServiceProvider).getLedger();
});

final enrichedLedgerProvider = FutureProvider<List<dynamic>>((ref) async {
  final entries = await ref.watch(ledgerProvider.future);
  final products = await ref.watch(productsProvider.future);
  final locations = await ref.watch(allLocationsProvider.future);

  final productMap = {for (var p in products) p['id'] as int: p['name'] as String};

  return entries.map((e) => {
    ...e,
    'product_name': productMap[e['product_id']] ?? 'Unknown Product',
    'location_label': locations[e['location_id']] ?? 'Unknown Location',
  }).toList();
});
