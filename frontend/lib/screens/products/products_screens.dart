import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/all_providers.dart';
import '../../widgets/shared_widgets.dart';

// ── Products List Screen ─────────────────────────────────────────────────────

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final search = ref.watch(productSearchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Product Catalog',
          subtitle: 'Manage inventory items, SKUs and stock levels',
          action: ElevatedButton.icon(
            onPressed: () => context.go('/products/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Product'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name or SKU...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => ref.read(productSearchProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 16),
              const _CategoryFilter(),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: productsAsync.when(
              loading: () => const _TableSkeleton(),
              error: (e, _) => ErrorDisplay(error: e.toString(), onRetry: () => ref.refresh(productsProvider)),
              data: (products) {
                if (products.isEmpty) {
                  return const EmptyState(
                    message: 'No products matching your search.',
                    icon: Icons.inventory_2_outlined,
                  );
                }
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: _TH('PRODUCT NAME')),
                            Expanded(flex: 2, child: _TH('SKU')),
                            Expanded(flex: 1, child: _TH('UNIT')),
                            Expanded(flex: 1, child: _TH('STOCK')),
                            Expanded(flex: 2, child: _TH('STATUS')),
                            SizedBox(width: 40, child: _TH('')),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      Expanded(
                        child: ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, i) {
                            final p = products[i];
                            final lowStock = p['low_stock'] == true;
                            return _ProductRow(p: p, lowStock: lowStock);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  final dynamic p;
  final bool lowStock;
  const _ProductRow({required this.p, required this.lowStock});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/products/${p['id']}/edit'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                  if (p['category_name'] != null)
                    Text(p['category_name'], style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(p['sku'] ?? '', style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.textSecondary, letterSpacing: -0.2)),
            ),
            Expanded(flex: 1, child: Text(p['unit_of_measure'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
            Expanded(
              flex: 1,
              child: Text(
                '${p['total_stock'] ?? 0}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: lowStock ? AppTheme.error : AppTheme.textPrimary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: lowStock ? const StatusBadge('cancelled') : const StatusBadge('done'), // Using existing types for simplicity
              ),
            ),
            const SizedBox(width: 40, child: Icon(Icons.chevron_right, size: 20, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedId = ref.watch(productCategoryFilterProvider);

    return categoriesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (cats) => DropdownButton<int?>(
        value: selectedId,
        hint: const Text('Filter by Category', style: TextStyle(fontSize: 13)),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.filter_list, size: 18, color: AppTheme.textSecondary),
        items: [
          const DropdownMenuItem(value: null, child: Text('All Categories')),
          ...cats.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] as String))),
        ],
        onChanged: (v) => ref.read(productCategoryFilterProvider.notifier).state = v,
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 1.0));
}

// ── Product Form Screen ──────────────────────────────────────────────────────

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _uomCtrl = TextEditingController(text: 'pcs');
  final _reorderCtrl = TextEditingController(text: '10');
  int? _categoryId;
  bool _loading = false;
  String? _error;

  bool get isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final data = await ref.read(productServiceProvider).getProduct(widget.productId!);
      _nameCtrl.text = data['name'] ?? '';
      _skuCtrl.text = data['sku'] ?? '';
      _uomCtrl.text = data['unit_of_measure'] ?? 'pcs';
      _reorderCtrl.text = '${data['reorder_min'] ?? 10}';
      setState(() => _categoryId = data['category_id']);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _skuCtrl.text.isEmpty) {
      setState(() => _error = "Name and SKU are required");
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'unit_of_measure': _uomCtrl.text.trim(),
        'reorder_min': int.tryParse(_reorderCtrl.text) ?? 10,
        if (_categoryId != null) 'category_id': _categoryId,
      };
      if (isEdit) {
        await ref.read(productServiceProvider).updateProduct(widget.productId!, data);
      } else {
        await ref.read(productServiceProvider).createProduct(data);
      }
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardKpisProvider);
      if (mounted) context.go('/products');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: isEdit ? 'Edit Product' : 'New Product',
            subtitle: isEdit ? 'Modify existing item details' : 'Register a new item in the warehouse catalogue',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 500,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null) ...[
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.error.withOpacity(0.2))),
                                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w500))),
                            const SizedBox(height: 24),
                          ],
                          _FormField(label: 'Product Name', child: TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Industrial Steel Plate'))),
                          _FormField(label: 'Unique SKU / Code', child: TextField(controller: _skuCtrl, decoration: const InputDecoration(hintText: 'e.g. ISP-001-BLA'))),
                          _FormField(
                            label: 'Category',
                            child: categoriesAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) => const Text('Error loading categories'),
                              data: (cats) => DropdownButtonFormField<int>(
                                value: _categoryId,
                                decoration: const InputDecoration(hintText: 'Uncategorized'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('No Category')),
                                  ...cats.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] as String))),
                                ],
                                onChanged: (v) => setState(() => _categoryId = v),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(flex: 3, child: _FormField(label: 'Unit of Measure', child: TextField(controller: _uomCtrl, decoration: const InputDecoration(hintText: 'pcs, kg, box...')))),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _FormField(label: 'Min. Reorder', child: TextField(controller: _reorderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '10')))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(onPressed: () => context.go('/products'), child: const Text('Cancel')),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _save,
                                    child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'Save Changes' : 'Create Product'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                if (isEdit)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Inventory Summary', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Current Stock'), Text('450.0', style: TextStyle(fontWeight: FontWeight.bold))]),
                                Divider(height: 24),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Allocated'), Text('120.0', style: TextStyle(color: AppTheme.textSecondary))]),
                                Divider(height: 24),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Available'), Text('330.0', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold))]),
                              ],
                            ),
                          ),
                        ),
                      ],
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

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ── Skeletons ───────────────────────────────────────────────────────────────

class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton();
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
      child: Column(
        children: List.generate(
            6,
            (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(children: [
                    const Expanded(flex: 3, child: SkeletonBox(height: 16)),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: SkeletonBox(height: 16)),
                    const SizedBox(width: 24),
                    const Expanded(flex: 1, child: SkeletonBox(height: 16)),
                    const SizedBox(width: 24),
                    const Expanded(flex: 1, child: SkeletonBox(height: 16)),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: SkeletonBox(height: 24, radius: 12)),
                    const SizedBox(width: 24),
                    const SkeletonBox(width: 20, height: 20),
                  ]),
                )),
      ),
    );
  }
}
