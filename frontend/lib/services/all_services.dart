// ── product_service.dart ─────────────────────────────────────────────────────
import 'api_client.dart';

class ProductService {
  final _c = ApiClient.instance;

  Future<List<dynamic>> getProducts({String? search, int? categoryId}) async {
    final res = await _c.get('/products', params: {
      if (search != null) 'search': search,
      if (categoryId != null) 'category_id': categoryId,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getProduct(int id) async {
    final res = await _c.get('/products/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> createProduct(Map<String, dynamic> data) =>
      _c.post('/products', data: data);

  Future<void> updateProduct(int id, Map<String, dynamic> data) =>
      _c.put('/products/$id', data: data);

  Future<void> deleteProduct(int id) => _c.delete('/products/$id');

  Future<List<dynamic>> getCategories() async {
    final res = await _c.get('/products/categories');
    return res.data as List<dynamic>;
  }

  Future<void> createCategory(String name) =>
      _c.post('/products/categories', data: {'name': name});
}

// ── receipt_service.dart ─────────────────────────────────────────────────────
class ReceiptService {
  final _c = ApiClient.instance;

  Future<List<dynamic>> getReceipts({String? status}) async {
    final res = await _c.get('/receipts', params: {
      if (status != null) 'status': status,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getReceipt(int id) async {
    final res = await _c.get('/receipts/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> createReceipt(Map<String, dynamic> data) =>
      _c.post('/receipts', data: data);

  Future<void> updateReceipt(int id, Map<String, dynamic> data) =>
      _c.put('/receipts/$id', data: data);

  Future<void> validateReceipt(int id) =>
      _c.post('/receipts/$id/validate');
}

// ── delivery_service.dart ─────────────────────────────────────────────────────
class DeliveryService {
  final _c = ApiClient.instance;

  Future<List<dynamic>> getDeliveries({String? status}) async {
    final res = await _c.get('/deliveries', params: {
      if (status != null) 'status': status,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDelivery(int id) async {
    final res = await _c.get('/deliveries/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> createDelivery(Map<String, dynamic> data) =>
      _c.post('/deliveries', data: data);

  Future<void> updateDelivery(int id, Map<String, dynamic> data) =>
      _c.put('/deliveries/$id', data: data);

  Future<void> validateDelivery(int id) =>
      _c.post('/deliveries/$id/validate');
}

// ── transfer_service.dart ─────────────────────────────────────────────────────
class TransferService {
  final _c = ApiClient.instance;

  Future<List<dynamic>> getTransfers({String? status}) async {
    final res = await _c.get('/transfers', params: {
      if (status != null) 'status': status,
    });
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getTransfer(int id) async {
    final res = await _c.get('/transfers/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> createTransfer(Map<String, dynamic> data) =>
      _c.post('/transfers', data: data);

  Future<void> updateTransfer(int id, Map<String, dynamic> data) =>
      _c.put('/transfers/$id', data: data);

  Future<void> validateTransfer(int id) =>
      _c.post('/transfers/$id/validate');
}

// ── adjustment_service.dart ───────────────────────────────────────────────────
class AdjustmentService {
  final _c = ApiClient.instance;

  Future<List<dynamic>> getAdjustments() async {
    final res = await _c.get('/adjustments');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getAdjustment(int id) async {
    final res = await _c.get('/adjustments/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> createAdjustment(Map<String, dynamic> data) =>
      _c.post('/adjustments', data: data);

  Future<void> updateAdjustment(int id, Map<String, dynamic> data) =>
      _c.put('/adjustments/$id', data: data);

  Future<void> validateAdjustment(int id) =>
      _c.post('/adjustments/$id/validate');
}

// ── dashboard_service.dart ────────────────────────────────────────────────────
class DashboardService {
  final _c = ApiClient.instance;

  Future<Map<String, dynamic>> getKpis() async {
    final res = await _c.get('/dashboard/kpis');
    return res.data as Map<String, dynamic>;
  }
}

// ── ledger_service.dart ───────────────────────────────────────────────────────
class LedgerService {
  final _c = ApiClient.instance;

  Future<List<dynamic>> getLedger({
    int? productId,
    int? locationId,
    String? refType,
    int limit = 100,
    int offset = 0,
  }) async {
    final res = await _c.get('/ledger', params: {
      if (productId != null) 'product_id': productId,
      if (locationId != null) 'location_id': locationId,
      if (refType != null) 'ref_type': refType,
      'limit': limit,
      'offset': offset,
    });
    return res.data as List<dynamic>;
  }
}

// ── warehouse_service.dart ────────────────────────────────────────────────────
class WarehouseService {
  final _c = ApiClient.instance;

  Future<List<dynamic>> getWarehouses() async {
    final res = await _c.get('/warehouses');
    return res.data as List<dynamic>;
  }

  Future<void> createWarehouse(String name, {String? address}) =>
      _c.post('/warehouses', data: {'name': name, 'address': address});

  Future<List<dynamic>> getLocations(int warehouseId) async {
    final res = await _c.get('/warehouses/$warehouseId/locations');
    return res.data as List<dynamic>;
  }

  Future<void> createLocation(int warehouseId, String name) =>
      _c.post('/warehouses/$warehouseId/locations', data: {'name': name});
}
