import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/all_providers.dart';
import '../../widgets/shared_widgets.dart';

// ── Receipts List Screen ──────────────────────────────────────────────────────

class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(receiptsProvider);
    final statusFilter = ref.watch(receiptStatusFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Receipts',
          subtitle: 'Incoming stock from vendors',
          action: ElevatedButton.icon(
            onPressed: () => context.go('/receipts/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Receipt'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'draft', 'waiting', 'ready', 'done', 'cancelled'].map((s) {
              final selected = s == 'All' ? statusFilter == null : statusFilter == s;
              return FilterChip(
                label: Text(
                  s == 'All' ? 'All' : s.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
                selected: selected,
                selectedColor: AppTheme.primary,
                backgroundColor: Colors.white,
                showCheckmark: false,
                side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
                onSelected: (_) =>
                    ref.read(receiptStatusFilterProvider.notifier).state =
                        s == 'All' ? null : s,
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: receiptsAsync.when(
              loading: () => const _TableSkeleton(),
              error: (e, _) => ErrorDisplay(
                error: e.toString(),
                onRetry: () => ref.refresh(receiptsProvider),
              ),
              data: (receipts) {
                if (receipts.isEmpty) {
                  return const EmptyState(
                    message: 'No receipts found.',
                    icon: Icons.move_to_inbox_outlined,
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
                        child: const Row(children: [
                          Expanded(flex: 1, child: _TH('ID')),
                          Expanded(flex: 3, child: _TH('SUPPLIER')),
                          Expanded(flex: 2, child: _TH('STATUS')),
                          Expanded(flex: 2, child: _TH('DATE')),
                          SizedBox(width: 40, child: _TH('')),
                        ]),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      Expanded(
                        child: ListView.separated(
                          itemCount: receipts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, i) {
                            final r = receipts[i];
                            return _ReceiptRow(r: r);
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

class _ReceiptRow extends StatelessWidget {
  final Map<String, dynamic> r;
  const _ReceiptRow({required this.r});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/receipts/${r['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Expanded(
            flex: 1,
            child: Text('#${r['id']}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(r['supplier'] ?? 'No Supplier',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(r['status'] ?? '')),
          ),
          Expanded(
            flex: 2,
            child: Text(r['created_at']?.toString().substring(0, 10) ?? '-',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 40, child: Icon(Icons.chevron_right, size: 20, color: AppTheme.textSecondary)),
        ]),
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

// ── Receipt Form Screen ──────────────────────────────────────────────────────

class ReceiptFormScreen extends ConsumerStatefulWidget {
  final int? receiptId;
  const ReceiptFormScreen({super.key, this.receiptId});

  @override
  ConsumerState<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends ConsumerState<ReceiptFormScreen> {
  final _supplierCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int? _locationId;
  bool _loading = false;
  bool _validating = false;
  String? _error;
  String _status = 'draft';
  List<Map<String, dynamic>> _lines = [];

  bool get isEdit => widget.receiptId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    try {
      final data = await ref.read(receiptServiceProvider).getReceipt(widget.receiptId!);
      final r = data['receipt'];
      _supplierCtrl.text = r['supplier'] ?? '';
      _notesCtrl.text = r['notes'] ?? '';
      setState(() {
        _locationId = r['location_id'];
        _status = r['status'] ?? 'draft';
        _lines = List<Map<String, dynamic>>.from((data['lines'] as List).map((l) => {
              'product_id': l['product_id'],
              'expected_qty': l['expected_qty'],
              'received_qty': l['received_qty'],
            }));
      });
    } catch (e) {
      setState(() => _error = "Failed to load receipt details: $e");
    }
  }

  Future<void> _save() async {
    if (_supplierCtrl.text.trim().isEmpty) {
      setState(() => _error = "Supplier name is required");
      return;
    }
    if (_locationId == null) {
      setState(() => _error = "Destination location is required");
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = "At least one product line is required");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = {
        'supplier': _supplierCtrl.text.trim(),
        'location_id': _locationId,
        'notes': _notesCtrl.text.trim(),
        'lines': _lines,
      };
      if (isEdit) {
        await ref.read(receiptServiceProvider).updateReceipt(widget.receiptId!, data);
      } else {
        await ref.read(receiptServiceProvider).createReceipt(data);
      }
      ref.invalidate(receiptsProvider);
      if (mounted) context.go('/receipts');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _validate() async {
    final confirm = await ConfirmDialog.show(context,
        title: 'Validate Receipt',
        message: 'This will add the received quantities to stock. This cannot be undone.',
        confirmLabel: 'Validate',
        confirmColor: AppTheme.success);
    if (!confirm) return;
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      await ref.read(receiptServiceProvider).validateReceipt(widget.receiptId!);
      ref.invalidate(receiptsProvider);
      ref.invalidate(dashboardKpisProvider);
      if (mounted) context.go('/receipts');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _validating = false);
    }
  }

  void _addLine() {
    setState(() => _lines.add({'product_id': null, 'expected_qty': 1.0, 'received_qty': 1.0}));
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _status == 'done';
    final warehousesAsync = ref.watch(warehousesProvider);
    final productsAsync = ref.watch(productsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: isEdit ? 'Receipt #${widget.receiptId}' : 'New Receipt',
            subtitle: 'Record incoming goods from a vendor',
            action: isEdit && !isDone
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _validating ? null : _validate,
                    icon: _validating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(_validating ? 'Validating...' : 'Validate Receipt'),
                  )
                : isDone
                    ? const StatusBadge('done')
                    : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.error.withOpacity(0.2))),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Form Card
                SizedBox(
                  width: 800,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Supplier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _supplierCtrl,
                                      enabled: !isDone,
                                      decoration: InputDecoration(
                                        hintText: 'Enter supplier name',
                                        prefixIcon: const Icon(Icons.business_outlined, size: 20),
                                        filled: isDone,
                                        fillColor: isDone ? Colors.grey[50] : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Destination Location',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 8),
                                    warehousesAsync.when(
                                      loading: () => const SkeletonBox(height: 48, radius: 8),
                                      error: (_, __) => const Text('Failed to load warehouses'),
                                      data: (warehouses) => _LocationDropdown(
                                        warehouses: warehouses,
                                        value: _locationId,
                                        enabled: !isDone,
                                        onChanged: (v) => setState(() => _locationId = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesCtrl,
                            enabled: !isDone,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Add any delivery notes or reference numbers...',
                              prefixIcon: const Icon(Icons.notes, size: 20),
                              filled: isDone,
                              fillColor: isDone ? Colors.grey[50] : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Lines Section
                Row(children: [
                  Text('Product Lines', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('${_lines.length}', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  if (!isDone)
                    TextButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Add Product'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                    ),
                ]),
                const SizedBox(height: 16),

                productsAsync.when(
                  loading: () => const _LineSkeleton(),
                  error: (_, __) => const ErrorDisplay(error: 'Failed to load products'),
                  data: (products) {
                    if (_lines.isEmpty && !isDone) {
                      return Center(
                        child: Container(
                          width: 800,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.add_box_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              const Text('No products added yet', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _addLine, child: const Text('Add your first product')),
                            ],
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      width: 1000,
                      child: Column(
                        children: _lines.asMap().entries.map((entry) {
                          final i = entry.key;
                          final line = entry.value;
                          return _ReceiptLineRow(
                            index: i,
                            line: line,
                            products: products,
                            enabled: !isDone,
                            onChanged: (updated) => setState(() => _lines[i] = updated),
                            onRemove: isDone ? null : () => setState(() => _lines.removeAt(i)),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                if (!isDone)
                  Row(children: [
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(onPressed: () => context.go('/receipts'), child: const Text('Discard Changes')),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32)),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? 'Update Receipt' : 'Create Receipt'),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptLineRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> line;
  final List<dynamic> products;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onRemove;

  const _ReceiptLineRow({required this.index, required this.line, required this.products, required this.enabled, required this.onChanged, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Product Selection
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: line['product_id'],
                    isExpanded: true,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), hintText: 'Select product'),
                    items: products
                        .map((p) => DropdownMenuItem(
                              value: p['id'] as int,
                              child: Text('${p['name']} (${p['sku']})', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: enabled ? (v) => onChanged({...line, 'product_id': v}) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Expected Qty
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expected Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: line['expected_qty']?.toString() ?? '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: enabled,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    onChanged: (v) => onChanged({...line, 'expected_qty': double.tryParse(v) ?? 0}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Received Qty
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Received Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: line['received_qty']?.toString() ?? '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: enabled,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    onChanged: (v) => onChanged({...line, 'received_qty': double.tryParse(v) ?? 0}),
                  ),
                ],
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 22),
                  onPressed: onRemove,
                  tooltip: 'Remove line',
                  splashRadius: 24,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared location dropdown that flattens warehouse → locations ────────────────

class _LocationDropdown extends ConsumerStatefulWidget {
  final List<dynamic> warehouses;
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _LocationDropdown({required this.warehouses, required this.value, required this.enabled, required this.onChanged});

  @override
  ConsumerState<_LocationDropdown> createState() => _LocationDropdownState();
}

class _LocationDropdownState extends ConsumerState<_LocationDropdown> {
  List<Map<String, dynamic>> _allLocations = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final all = <Map<String, dynamic>>[];
    try {
      for (final wh in widget.warehouses) {
        final locs = await ref.read(warehouseServiceProvider).getLocations(wh['id'] as int);
        for (final loc in locs) {
          all.add({'id': loc['id'], 'label': '${wh['name']} › ${loc['name']}'});
        }
      }
    } finally {
      if (mounted) setState(() { _allLocations = all; _loaded = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: widget.value,
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
        hintText: _loaded ? 'Select destination' : 'Loading locations...',
        filled: !_loaded,
        fillColor: !_loaded ? Colors.grey[50] : null,
      ),
      items: _allLocations
          .map((l) => DropdownMenuItem(value: l['id'] as int, child: Text(l['label'] as String, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: widget.enabled && _loaded ? widget.onChanged : null,
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
                    const SkeletonBox(width: 60, height: 16),
                    const SizedBox(width: 24),
                    const Expanded(flex: 3, child: SkeletonBox(height: 16)),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: SkeletonBox(height: 24, radius: 12)),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: SkeletonBox(height: 16)),
                    const SizedBox(width: 24),
                    const SkeletonBox(width: 20, height: 20),
                  ]),
                )),
      ),
    );
  }
}

class _LineSkeleton extends StatelessWidget {
  const _LineSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
          2,
          (i) => const Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SkeletonBox(height: 100, width: double.infinity, radius: 12),
              )),
    );
  }
}

