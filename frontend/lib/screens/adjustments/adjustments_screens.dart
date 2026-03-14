import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/all_providers.dart';
import '../../widgets/shared_widgets.dart';

// ── Adjustments List Screen ───────────────────────────────────────────────────

class AdjustmentsScreen extends ConsumerWidget {
  const AdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjustmentsAsync = ref.watch(adjustmentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Stock Adjustments',
          subtitle: 'Reconcile physical counts with system inventory',
          action: ElevatedButton.icon(
            onPressed: () => context.go('/adjustments/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Adjustment'),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: adjustmentsAsync.when(
              loading: () => const _TableSkeleton(),
              error: (e, _) => ErrorDisplay(
                error: e.toString(),
                onRetry: () => ref.refresh(adjustmentsProvider),
              ),
              data: (adjustments) {
                if (adjustments.isEmpty) {
                  return const EmptyState(
                    message: 'No adjustments recorded.',
                    icon: Icons.tune_outlined,
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
                          Expanded(flex: 2, child: _TH('LOCATION')),
                          Expanded(flex: 2, child: _TH('STATUS')),
                          Expanded(flex: 2, child: _TH('DATE')),
                          Expanded(flex: 3, child: _TH('NOTES')),
                          SizedBox(width: 40, child: _TH('')),
                        ]),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      Expanded(
                        child: ListView.separated(
                          itemCount: adjustments.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, i) {
                            final a = adjustments[i];
                            return _AdjustmentRow(a: a);
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

class _AdjustmentRow extends StatelessWidget {
  final Map<String, dynamic> a;
  const _AdjustmentRow({required this.a});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/adjustments/${a['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Expanded(
            flex: 1,
            child: Text('#${a['id']}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text('Loc ${a['location_id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(a['status'] ?? '')),
          ),
          Expanded(
            flex: 2,
            child: Text(a['created_at']?.toString().substring(0, 10) ?? '-',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            flex: 3,
            child: Text(a['notes'] ?? '—',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
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

// ── Adjustment Form Screen ───────────────────────────────────────────────────

class AdjustmentFormScreen extends ConsumerStatefulWidget {
  final int? adjustmentId;
  const AdjustmentFormScreen({super.key, this.adjustmentId});

  @override
  ConsumerState<AdjustmentFormScreen> createState() => _AdjustmentFormScreenState();
}

class _AdjustmentFormScreenState extends ConsumerState<AdjustmentFormScreen> {
  final _notesCtrl = TextEditingController();
  int? _locationId;
  bool _loading = false;
  bool _validating = false;
  String? _error;
  String _status = 'draft';
  List<Map<String, dynamic>> _lines = [];
  List<Map<String, dynamic>> _allLocations = [];
  bool _loadingLocs = true;

  bool get isEdit => widget.adjustmentId != null;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    if (isEdit) _loadAdjustment();
  }

  Future<void> _loadLocations() async {
    try {
      final warehouses = await ref.read(warehouseServiceProvider).getWarehouses();
      final all = <Map<String, dynamic>>[];
      for (final wh in warehouses) {
        final locs = await ref.read(warehouseServiceProvider).getLocations(wh['id'] as int);
        for (final loc in locs) {
          all.add({'id': loc['id'], 'label': '${wh['name']} › ${loc['name']}'});
        }
      }
      if (mounted) setState(() { _allLocations = all; _loadingLocs = false; });
    } catch (e) {
      if (mounted) setState(() => _error = "Failed to load locations: $e");
    }
  }

  Future<void> _loadAdjustment() async {
    try {
      final data = await ref.read(adjustmentServiceProvider).getAdjustment(widget.adjustmentId!);
      final a = data['adjustment'];
      _notesCtrl.text = a['notes'] ?? '';
      setState(() {
        _locationId = a['location_id'];
        _status = a['status'] ?? 'draft';
        _lines = List<Map<String, dynamic>>.from((data['lines'] as List).map((l) => {
              'product_id': l['product_id'],
              'system_qty': l['system_qty'],
              'counted_qty': l['counted_qty'],
            }));
      });
    } catch (e) {
      setState(() => _error = "Failed to load adjustment: $e");
    }
  }

  Future<void> _save() async {
    if (_locationId == null) {
      setState(() => _error = 'Please select a location');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = "At least one product line is required");
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final data = {
        'location_id': _locationId,
        'notes': _notesCtrl.text.trim(),
        'lines': _lines.map((l) => {'product_id': l['product_id'], 'counted_qty': l['counted_qty']}).toList(),
      };
      if (isEdit) {
        await ref.read(adjustmentServiceProvider).updateAdjustment(widget.adjustmentId!, data);
      } else {
        await ref.read(adjustmentServiceProvider).createAdjustment(data);
      }
      ref.invalidate(adjustmentsProvider);
      if (mounted) context.go('/adjustments');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _validate() async {
    final confirm = await ConfirmDialog.show(context,
        title: 'Apply Adjustment',
        message: 'System inventory will be updated to match your physical count. This action is irreversible.',
        confirmLabel: 'Apply Count',
        confirmColor: const Color(0xFF8B5CF6));
    if (!confirm) return;
    setState(() { _validating = true; _error = null; });
    try {
      await ref.read(adjustmentServiceProvider).validateAdjustment(widget.adjustmentId!);
      ref.invalidate(adjustmentsProvider);
      ref.invalidate(dashboardKpisProvider);
      if (mounted) context.go('/adjustments');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _validating = false);
    }
  }

  void _addLine() => setState(() => _lines.add({'product_id': null, 'system_qty': 0.0, 'counted_qty': 0.0}));

  @override
  Widget build(BuildContext context) {
    final isDone = _status == 'done';
    final productsAsync = ref.watch(productsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: isEdit ? 'Adjustment #${widget.adjustmentId}' : 'New Adjustment',
            subtitle: 'Reconcile physical stock with the system',
            action: isEdit && !isDone
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _validating ? null : _validate,
                    icon: _validating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(_validating ? 'Processing...' : 'Apply Count to Inventory'),
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
                          const Text('Adjustment Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _locationId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: _loadingLocs ? 'Loading...' : 'Select location to count',
                              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                              filled: isDone,
                              fillColor: isDone ? Colors.grey[50] : null,
                            ),
                            items: _allLocations
                                .map((l) => DropdownMenuItem(value: l['id'] as int, child: Text(l['label'] as String, style: const TextStyle(fontSize: 14))))
                                .toList(),
                            onChanged: isDone || _loadingLocs ? null : (v) => setState(() => _locationId = v),
                          ),
                          const SizedBox(height: 20),
                          const Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesCtrl,
                            enabled: !isDone,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Reason for adjustment (e.g. Annual stocktake, damaged items...)',
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
                  Text('Physical Counts', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('${_lines.length}', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  if (!isDone)
                    TextButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Add Product'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6)),
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
                              Icon(Icons.tune_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              const Text('No products added for adjustment', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _addLine, child: const Text('Start counting products')),
                            ],
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      width: 900,
                      child: Column(
                        children: _lines.asMap().entries.map((entry) {
                          final i = entry.key;
                          final line = entry.value;
                          return _AdjustmentLineRow(
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
                      child: OutlinedButton(onPressed: () => context.go('/adjustments'), child: const Text('Discard')),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 32)),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? 'Save Changes' : 'Create Draft'),
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

class _AdjustmentLineRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> line;
  final List<dynamic> products;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onRemove;

  const _AdjustmentLineRow({required this.index, required this.line, required this.products, required this.enabled, required this.onChanged, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final systemQty = (line['system_qty'] as num?)?.toDouble() ?? 0.0;
    final countedQty = (line['counted_qty'] as num?)?.toDouble() ?? 0.0;
    final delta = countedQty - systemQty;

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
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
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
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: systemQty.toStringAsFixed(1),
                    enabled: false,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), fillColor: Color(0xFFF8FAFC), filled: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Counted Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: countedQty.toStringAsFixed(1),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: enabled,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    onChanged: (v) => onChanged({...line, 'counted_qty': double.tryParse(v) ?? 0}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: delta == 0 ? Colors.grey[50] : (delta > 0 ? AppTheme.success.withOpacity(0.05) : AppTheme.error.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: delta == 0 ? AppTheme.border : (delta > 0 ? AppTheme.success.withOpacity(0.3) : AppTheme.error.withOpacity(0.3))),
                    ),
                    child: Text(
                      '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: delta == 0 ? AppTheme.textSecondary : (delta > 0 ? AppTheme.success : AppTheme.error)),
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 22),
                  onPressed: onRemove,
                  tooltip: 'Remove',
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
                    const Expanded(flex: 2, child: SkeletonBox(height: 16)),
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
