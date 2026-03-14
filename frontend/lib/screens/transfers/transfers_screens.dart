import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/all_providers.dart';
import '../../widgets/shared_widgets.dart';

// ── Transfers List Screen ─────────────────────────────────────────────────────

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfersAsync = ref.watch(transfersProvider);
    final statusFilter = ref.watch(transferStatusFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Internal Transfers',
          subtitle: 'Move stock between locations and warehouses',
          action: ElevatedButton.icon(
            onPressed: () => context.go('/transfers/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Transfer'),
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
                    ref.read(transferStatusFilterProvider.notifier).state =
                        s == 'All' ? null : s,
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: transfersAsync.when(
              loading: () => const _TableSkeleton(),
              error: (e, _) => ErrorDisplay(
                error: e.toString(),
                onRetry: () => ref.refresh(transfersProvider),
              ),
              data: (transfers) {
                if (transfers.isEmpty) {
                  return const EmptyState(
                    message: 'No transfers found.',
                    icon: Icons.swap_horiz_outlined,
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
                          Expanded(flex: 2, child: _TH('FROM')),
                          Expanded(flex: 2, child: _TH('TO')),
                          Expanded(flex: 2, child: _TH('STATUS')),
                          Expanded(flex: 2, child: _TH('DATE')),
                          SizedBox(width: 40, child: _TH('')),
                        ]),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      Expanded(
                        child: ListView.separated(
                          itemCount: transfers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, i) {
                            final t = transfers[i];
                            return _TransferRow(t: t);
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

class _TransferRow extends StatelessWidget {
  final Map<String, dynamic> t;
  const _TransferRow({required this.t});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/transfers/${t['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(children: [
          Expanded(
            flex: 1,
            child: Text('#${t['id']}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.outbox, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(t['from_location_name'] ?? 'Loc ${t['from_location_id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.move_to_inbox, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(t['to_location_name'] ?? 'Loc ${t['to_location_id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerLeft, child: StatusBadge(t['status'] ?? '')),
          ),
          Expanded(
            flex: 2,
            child: Text(t['created_at']?.toString().substring(0, 10) ?? '-',
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

// ── Transfer Form Screen ──────────────────────────────────────────────────────

class TransferFormScreen extends ConsumerStatefulWidget {
  final int? transferId;
  const TransferFormScreen({super.key, this.transferId});

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  final _notesCtrl = TextEditingController();
  int? _fromLocationId;
  int? _toLocationId;
  bool _loading = false;
  bool _validating = false;
  String? _error;
  String _status = 'draft';
  List<Map<String, dynamic>> _lines = [];
  List<Map<String, dynamic>> _allLocations = [];
  bool _loadingLocs = true;

  bool get isEdit => widget.transferId != null;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    if (isEdit) _loadTransfer();
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

  Future<void> _loadTransfer() async {
    try {
      final data = await ref.read(transferServiceProvider).getTransfer(widget.transferId!);
      final t = data['transfer'];
      _notesCtrl.text = t['notes'] ?? '';
      setState(() {
        _fromLocationId = t['from_location_id'];
        _toLocationId = t['to_location_id'];
        _status = t['status'] ?? 'draft';
        _lines = List<Map<String, dynamic>>.from((data['lines'] as List).map((l) => {
              'product_id': l['product_id'],
              'qty': l['qty'],
            }));
      });
    } catch (e) {
      setState(() => _error = "Failed to load transfer details: $e");
    }
  }

  Future<void> _save() async {
    if (_fromLocationId == null || _toLocationId == null) {
      setState(() => _error = 'Select both source and destination locations');
      return;
    }
    if (_fromLocationId == _toLocationId) {
      setState(() => _error = 'Source and destination must be different');
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
        'from_location_id': _fromLocationId,
        'to_location_id': _toLocationId,
        'notes': _notesCtrl.text.trim(),
        'lines': _lines,
      };
      if (isEdit) {
        await ref.read(transferServiceProvider).updateTransfer(widget.transferId!, data);
      } else {
        await ref.read(transferServiceProvider).createTransfer(data);
      }
      ref.invalidate(transfersProvider);
      if (mounted) context.go('/transfers');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _validate() async {
    final confirm = await ConfirmDialog.show(context,
        title: 'Validate Transfer',
        message: 'Stock will be moved from the source to the destination location. This cannot be undone.',
        confirmLabel: 'Validate',
        confirmColor: AppTheme.success);
    if (!confirm) return;
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      await ref.read(transferServiceProvider).validateTransfer(widget.transferId!);
      ref.invalidate(transfersProvider);
      ref.invalidate(dashboardKpisProvider);
      if (mounted) context.go('/transfers');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _validating = false);
    }
  }

  void _addLine() => setState(() => _lines.add({'product_id': null, 'qty': 1.0}));

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
            title: isEdit ? 'Transfer #${widget.transferId}' : 'New Transfer',
            subtitle: 'Move stock between internal locations',
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
                    label: Text(_validating ? 'Validating...' : 'Validate Transfer'),
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
                                    const Text('Source Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<int>(
                                      value: _fromLocationId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        hintText: _loadingLocs ? 'Loading...' : 'Select source',
                                        prefixIcon: const Icon(Icons.outbox_outlined, size: 20),
                                        filled: isDone,
                                        fillColor: isDone ? Colors.grey[50] : null,
                                      ),
                                      items: _allLocations
                                          .map((l) => DropdownMenuItem(value: l['id'] as int, child: Text(l['label'] as String, style: const TextStyle(fontSize: 14))))
                                          .toList(),
                                      onChanged: isDone || _loadingLocs ? null : (v) => setState(() => _fromLocationId = v),
                                    ),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                                child: Icon(Icons.arrow_forward_rounded, color: AppTheme.textSecondary),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Destination Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<int>(
                                      value: _toLocationId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        hintText: _loadingLocs ? 'Loading...' : 'Select destination',
                                        prefixIcon: const Icon(Icons.move_to_inbox_outlined, size: 20),
                                        filled: isDone,
                                        fillColor: isDone ? Colors.grey[50] : null,
                                      ),
                                      items: _allLocations
                                          .map((l) => DropdownMenuItem(value: l['id'] as int, child: Text(l['label'] as String, style: const TextStyle(fontSize: 14))))
                                          .toList(),
                                      onChanged: isDone || _loadingLocs ? null : (v) => setState(() => _toLocationId = v),
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
                              hintText: 'Reason for transfer, stock request ID, etc...',
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
                  Text('Products to Move', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
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
                              Icon(Icons.swap_horiz_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              const Text('No products selected for transfer', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _addLine, child: const Text('Add products to move')),
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
                          return _TransferLineRow(
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
                      child: OutlinedButton(onPressed: () => context.go('/transfers'), child: const Text('Discard Changes')),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32)),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? 'Update Transfer' : 'Create Transfer'),
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

class _TransferLineRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> line;
  final List<dynamic> products;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onRemove;

  const _TransferLineRow({required this.index, required this.line, required this.products, required this.enabled, required this.onChanged, this.onRemove});

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
            Expanded(
              flex: 6,
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
                  const Text('Qty to Move', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: line['qty']?.toString() ?? '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: enabled,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    onChanged: (v) => onChanged({...line, 'qty': double.tryParse(v) ?? 0}),
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
                  tooltip: 'Remove product',
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
                    const _SkeletonBox(width: 60, height: 16),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: _SkeletonBox(height: 16)),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: _SkeletonBox(height: 16)),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: _SkeletonBox(height: 24, radius: 12)),
                    const SizedBox(width: 24),
                    const _SkeletonBox(width: 20, height: 20),
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
                child: _SkeletonBox(height: 100, width: double.infinity, radius: 12),
              )),
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
