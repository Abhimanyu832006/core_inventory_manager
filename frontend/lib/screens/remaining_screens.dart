import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/all_providers.dart';
import '../../widgets/shared_widgets.dart';

// ── Ledger Screen ─────────────────────────────────────────────────────────────

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  static const _refTypeColors = {
    'receipt': Color(0xFF10B981),
    'delivery': Color(0xFFEF4444),
    'transfer': Color(0xFFF59E0B),
    'adjustment': Color(0xFF8B5CF6),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(enrichedLedgerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Stock Ledger',
          subtitle: 'Full audit trail of all inventory movements',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: ledgerAsync.when(
              loading: () => const _LedgerSkeleton(),
              error: (e, _) => ErrorDisplay(
                error: e.toString(),
                onRetry: () => ref.refresh(ledgerProvider),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyState(
                    message: 'No stock movements recorded yet.',
                    icon: Icons.history_edu_outlined,
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
                          Expanded(flex: 2, child: _TH('TYPE')),
                          Expanded(flex: 1, child: _TH('REF #')),
                          Expanded(flex: 3, child: _TH('PRODUCT')),
                          Expanded(flex: 3, child: _TH('LOCATION')),
                          Expanded(flex: 1, child: _TH('DELTA')),
                          Expanded(flex: 1, child: _TH('BALANCE')),
                          Expanded(flex: 2, child: _TH('DATE')),
                        ]),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      Expanded(
                        child: ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                          itemBuilder: (context, i) {
                            final e = entries[i];
                            final delta = (e['delta'] as num).toDouble();
                            final refType = e['ref_type'] as String? ?? '';
                            final color = _refTypeColors[refType] ?? AppTheme.textSecondary;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Row(children: [
                                Expanded(flex: 2, child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text(refType.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
                                  ),
                                )),
                                Expanded(flex: 1, child: Text('#${e['ref_id']}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
                                Expanded(flex: 3, child: Text(e['product_name'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                                Expanded(flex: 3, child: Text(e['location_label'] ?? 'Unknown', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                                Expanded(flex: 1, child: Text(
                                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: delta >= 0 ? AppTheme.success : AppTheme.error),
                                )),
                                Expanded(flex: 1, child: Text('${(e['qty_after'] as num).toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                Expanded(flex: 2, child: Text(e['created_at']?.toString().substring(0, 16) ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                              ]),
                            );
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

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 1.0));
}

// ── Warehouses Screen ─────────────────────────────────────────────────────────

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(warehousesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Warehouses',
          subtitle: 'Manage physical storage locations',
          action: ElevatedButton.icon(
            onPressed: () => _showAddWarehouseDialog(context, ref),
            icon: const Icon(Icons.add_home_work_outlined, size: 18),
            label: const Text('Add Warehouse'),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: warehousesAsync.when(
              loading: () => const _GridSkeleton(),
              error: (e, _) => ErrorDisplay(error: e.toString()),
              data: (warehouses) {
                if (warehouses.isEmpty) return const EmptyState(message: 'No warehouses defined yet.', icon: Icons.warehouse_outlined);
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: warehouses.length,
                  itemBuilder: (context, i) {
                    final wh = warehouses[i];
                    return _WarehouseCard(wh: wh);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showAddWarehouseDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('New Warehouse'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Warehouse Name', hintText: 'e.g. Main Distribution Center')),
          const SizedBox(height: 16),
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Street Address', hintText: 'Physical location...')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          await ref.read(warehouseServiceProvider).createWarehouse(nameCtrl.text, address: addrCtrl.text.isEmpty ? null : addrCtrl.text);
          ref.invalidate(warehousesProvider);
          if (context.mounted) context.pop();
        }, child: const Text('Create Warehouse')),
      ],
    ));
  }
}

class _WarehouseCard extends ConsumerWidget {
  final dynamic wh;
  const _WarehouseCard({required this.wh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.warehouse_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(wh['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 12),
            if (wh['address'] != null)
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(wh['address'], style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              ]),
            const Spacer(),
            const Divider(height: 24),
            Row(children: [
              const Text('Locations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddLocationDialog(context, ref, wh['id'] as int),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showAddLocationDialog(BuildContext context, WidgetRef ref, int warehouseId) {
    final nameCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Add Location'),
      content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Location Key', hintText: 'e.g. A-102 or Rack 5')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          await ref.read(warehouseServiceProvider).createLocation(warehouseId, nameCtrl.text);
          ref.invalidate(allLocationsProvider); // Clear location cache
          if (context.mounted) context.pop();
        }, child: const Text('Create Location')),
      ],
    ));
  }
}

// ── Profile Screen ────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _name;
  String? _email;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final auth = ref.read(authServiceProvider);
    final name = await auth.getUserName();
    final email = await auth.getUserEmail();
    final role = await auth.getUserRole();
    setState(() {
      _name = name;
      _email = email;
      _role = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'My Account',
            subtitle: 'Manage your settings and preferences',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: SizedBox(
              width: 500,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          _name != null && _name!.isNotEmpty
                              ? _name![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _name ?? '—',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      if (_email != null) ...[
                        Text(
                          _email ?? '',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        _role?.toUpperCase() ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Change password
                      _ProfileTile(
                        icon: Icons.lock_outline,
                        label: 'Change Password',
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                      const SizedBox(height: 8),

                      // Logout
                      _ProfileTile(
                        icon: Icons.logout_outlined,
                        label: 'Logout',
                        color: AppTheme.error,
                        onTap: () async {
                          final confirm = await ConfirmDialog.show(
                            context,
                            title: 'Logout',
                            message: 'Are you sure you want to logout?',
                            confirmLabel: 'Logout',
                            confirmColor: AppTheme.error,
                          );
                          if (confirm && context.mounted) {
                            await ref.read(authServiceProvider).logout();
                            context.go('/auth/login');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(
        userName: _name,
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  final String? userName;
  const _ChangePasswordDialog({this.userName});

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _requestOtp() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).requestOtp(_emailCtrl.text.trim());
      setState(() { _otpSent = true; _success = 'OTP sent to your email'; });
    } catch (e) {
      setState(() => _error = 'Failed to send OTP');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyAndChange() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).verifyOtp(
        _emailCtrl.text.trim(),
        _otpCtrl.text.trim(),
        _newPassCtrl.text,
      );
      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Invalid OTP or request failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Change Password'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],
            if (_success != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_success!,
                    style: const TextStyle(color: AppTheme.success, fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailCtrl,
              enabled: !_otpSent,
              decoration: const InputDecoration(labelText: 'Your email'),
            ),
            if (_otpSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'OTP code'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : (_otpSent ? _verifyAndChange : _requestOtp),
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_otpSent ? 'Change Password' : 'Send OTP'),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: c, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.chevron_right, size: 18, color: c.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// ── Shared Skeletons ──────────────────────────────────────────────────────────

class _LedgerSkeleton extends StatelessWidget {
  const _LedgerSkeleton();
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.border)),
      child: Column(
        children: List.generate(8, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(children: [
            const _SkeletonBox(width: 70, height: 20, radius: 4),
            const SizedBox(width: 24),
            const _SkeletonBox(width: 100, height: 16),
            const SizedBox(width: 24),
            const Expanded(child: _SkeletonBox(height: 16)),
            const SizedBox(width: 24),
            const _SkeletonBox(width: 60, height: 20),
          ]),
        )),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400, mainAxisExtent: 180, crossAxisSpacing: 20, mainAxisSpacing: 20),
      itemCount: 4,
      itemBuilder: (context, i) => const _SkeletonBox(height: 180, radius: 12),
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
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: Colors.grey[200]!.withOpacity(_animation.value), borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}
