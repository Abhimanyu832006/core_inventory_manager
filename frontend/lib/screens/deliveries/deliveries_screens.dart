import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/all_providers.dart';
import '../../widgets/shared_widgets.dart';

// ── Deliveries List Screen ────────────────────────────────────────────────────

class DeliveriesScreen extends ConsumerWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(deliveriesProvider);
    final statusFilter = ref.watch(deliveryStatusFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Deliveries',
          subtitle: 'Outgoing stock to customers',
          action: ElevatedButton.icon(
            onPressed: () => context.go('/deliveries/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Delivery'),
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
                    ref.read(deliveryStatusFilterProvider.notifier).state =
                        s == 'All' ? null : s,
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: deliveriesAsync.when(
              loading: () => const _DeliveriesSkeleton(),
              error: (e, _) => ErrorDisplay(
                error: e.toString(),
                onRetry: () => ref.refresh(deliveriesProvider),
              ),
              data: (deliveries) {
                if (deliveries.isEmpty) {
                  return const EmptyState(
                    message: 'No deliveries found.',
                    icon: Icons.local_shipping_outlined,
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
                          Expanded(flex: 3, child: _TH('CUSTOMER')),
                          Expanded(flex: 2, child: _TH('STATUS')),
                          Expanded(flex: 2, child: _TH('DATE')),
                          SizedBox(width: 40, child: _TH('')),
                        ]),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      Expanded(
                        child: ListView.separated(
                          itemCount: deliveries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, i) {
                            final d = deliveries[i];
                            return _DeliveryRow(d: d);
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

class _DeliveryRow extends StatelessWidget {
  final Map<String, dynamic> d;
  const _DeliveryRow({required this.d});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/deliveries/${d['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Expanded(
            flex: 1, 
            child: Text('#${d['id']}', 
              style: GoogleFonts.inter(
                fontSize: 13, 
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              )
            )
          ),
          Expanded(
            flex: 3, 
            child: Text(d['customer'] ?? 'No Customer', 
              style: const TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              )
            )
          ),
          Expanded(
            flex: 2, 
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(d['status'] ?? '')
            )
          ),
          Expanded(
            flex: 2, 
            child: Text(
              d['created_at']?.toString().substring(0, 10) ?? '-', 
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)
            )
          ),
          const SizedBox(
            width: 40, 
            child: Icon(Icons.chevron_right, size: 20, color: AppTheme.textSecondary)
          ),
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
      style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 1.0));
}

// ── Delivery Form Screen ──────────────────────────────────────────────────────

class DeliveryFormScreen extends ConsumerStatefulWidget {
  final int? deliveryId;
  const DeliveryFormScreen({super.key, this.deliveryId});

  @override
  ConsumerState<DeliveryFormScreen> createState() => _DeliveryFormScreenState();
}

class _DeliveryFormScreenState extends ConsumerState<DeliveryFormScreen> {
  final _customerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  bool _validating = false;
  String? _error;
  String _status = 'draft';
  List<Map<String, dynamic>> _lines = [];

  bool get isEdit => widget.deliveryId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _loadDelivery();
  }

  Future<void> _loadDelivery() async {
    try {
      final data =
          await ref.read(deliveryServiceProvider).getDelivery(widget.deliveryId!);
      final d = data['delivery'];
      _customerCtrl.text = d['customer'] ?? '';
      _notesCtrl.text = d['notes'] ?? '';
      setState(() {
        _status = d['status'] ?? 'draft';
        _lines = List<Map<String, dynamic>>.from(
          (data['lines'] as List).map((l) => {
                'product_id': l['product_id'],
                'location_id': l['location_id'],
                'qty': l['qty'],
              }),
        );
      });
    } catch (e) {
      setState(() => _error = "Failed to load delivery details: $e");
    }
  }

  Future<void> _save() async {
    if (_customerCtrl.text.trim().isEmpty) {
      setState(() => _error = "Customer name is required");
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = "At least one product line is required");
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final data = {
        'customer': _customerCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'lines': _lines,
      };
      
      if (isEdit) {
        await ref.read(deliveryServiceProvider).updateDelivery(widget.deliveryId!, data);
      } else {
        await ref.read(deliveryServiceProvider).createDelivery(data);
      }
      
      ref.invalidate(deliveriesProvider);
      if (mounted) context.go('/deliveries');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _validate() async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Validate Delivery',
      message:
          'This will deduct the quantities from stock. This cannot be undone.',
      confirmLabel: 'Validate',
      confirmColor: AppTheme.success,
    );
    if (!confirm) return;
    setState(() { _validating = true; _error = null; });
    try {
      await ref.read(deliveryServiceProvider).validateDelivery(widget.deliveryId!);
      ref.invalidate(deliveriesProvider);
      ref.invalidate(dashboardKpisProvider);
      if (mounted) context.go('/deliveries');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _validating = false);
    }
  }

  void _addLine() {
    setState(() => _lines.add({'product_id': null, 'location_id': null, 'qty': 1.0}));
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
            title: isEdit ? 'Delivery #${widget.deliveryId}' : 'New Delivery',
            subtitle: 'Record outgoing goods to a customer',
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
                    label: Text(_validating ? 'Validating...' : 'Validate Delivery'),
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
                                    const Text('Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _customerCtrl,
                                      enabled: !isDone,
                                      decoration: InputDecoration(
                                        hintText: 'Enter customer name',
                                        prefixIcon: const Icon(Icons.person_outline, size: 20),
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
                                    const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                                          const SizedBox(width: 12),
                                          Text(_status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
                                        ],
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
                              hintText: 'Any special instructions or details...',
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
                
                warehousesAsync.when(
                  loading: () => const _LineSkeleton(),
                  error: (_, __) => const ErrorDisplay(error: 'Failed to load warehouses'),
                  data: (warehouses) => productsAsync.when(
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
                              border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
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
                            return _DeliveryLineRow(
                              index: i,
                              line: line,
                              products: products,
                              warehouses: warehouses,
                              enabled: !isDone,
                              onChanged: (updated) =>
                                  setState(() => _lines[i] = updated),
                              onRemove: isDone
                                  ? null
                                  : () => setState(() => _lines.removeAt(i)),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 40),
                
                if (!isDone)
                  Row(children: [
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                          onPressed: () => context.go('/deliveries'),
                          child: const Text('Discard Changes')),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? 'Update Delivery' : 'Create Delivery'),
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

class _DeliveryLineRow extends ConsumerStatefulWidget {
  final int index;
  final Map<String, dynamic> line;
  final List<dynamic> products;
  final List<dynamic> warehouses;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onRemove;

  const _DeliveryLineRow({
    required this.index,
    required this.line,
    required this.products,
    required this.warehouses,
    required this.enabled,
    required this.onChanged,
    this.onRemove,
  });

  @override
  ConsumerState<_DeliveryLineRow> createState() => _DeliveryLineRowState();
}

class _DeliveryLineRowState extends ConsumerState<_DeliveryLineRow> {
  List<Map<String, dynamic>> _locations = [];
  bool _loadingLocs = true;

  @override
  void initState() {
    super.initState();
    _loadAllLocations();
  }

  Future<void> _loadAllLocations() async {
    final all = <Map<String, dynamic>>[];
    try {
      // In a real app we'd cache this in a provider
      for (final wh in widget.warehouses) {
        final locs = await ref.read(warehouseServiceProvider).getLocations(wh['id'] as int);
        for (final loc in locs) {
          all.add({
            'id': loc['id'],
            'label': '${wh['name']} › ${loc['name']}',
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _locations = all;
          _loadingLocs = false;
        });
      }
    }
  }

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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Product Selection
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: widget.line['product_id'],
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: 'Select product',
                    ),
                    items: widget.products
                        .map((p) => DropdownMenuItem(
                              value: p['id'] as int,
                              child: Text('${p['name']} (${p['sku']})',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: widget.enabled
                        ? (v) => widget.onChanged({...widget.line, 'product_id': v})
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Location Selection
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('From Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: widget.line['location_id'],
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: _loadingLocs ? 'Loading...' : 'Select source',
                    ),
                    items: _locations
                        .map((l) => DropdownMenuItem(
                              value: l['id'] as int,
                              child: Text(l['label'] as String,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: widget.enabled && !_loadingLocs
                        ? (v) =>
                            widget.onChanged({...widget.line, 'location_id': v})
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Quantity
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: widget.line['qty']?.toString() ?? '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: widget.enabled,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0;
                      widget.onChanged({...widget.line, 'qty': val});
                    },
                  ),
                ],
              ),
            ),
            if (widget.onRemove != null) ...[
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 22),
                  onPressed: widget.onRemove,
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

// ── Skeletons ───────────────────────────────────────────────────────────────

class _DeliveriesSkeleton extends StatelessWidget {
  const _DeliveriesSkeleton();
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
      child: Column(
        children: List.generate(6, (i) => 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(children: [
              _SkeletonBox(width: 60, height: 16),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _SkeletonBox(height: 16)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _SkeletonBox(height: 24, radius: 12)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _SkeletonBox(height: 16)),
              const SizedBox(width: 24),
              _SkeletonBox(width: 20, height: 20),
            ]),
          )
        ),
      ),
    );
  }
}

class _LineSkeleton extends StatelessWidget {
  const _LineSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(2, (i) => 
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SkeletonBox(height: 100, width: double.infinity, radius: 12),
        )
      ),
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const _SkeletonBox({this.width, required this.height, this.radius = 4});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200]!.withOpacity(_animation.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
