import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/all_providers.dart';
import '../../widgets/shared_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKpisProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Inventory Overview',
            subtitle: 'Real-time performance metrics and quick actions',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── KPI Grid ─────────────────────────────────────────────
                kpisAsync.when(
                  loading: () => const _KpiSkeleton(),
                  error: (e, _) => ErrorDisplay(error: e.toString(), onRetry: () => ref.refresh(dashboardKpisProvider)),
                  data: (kpis) => _KpiGrid(kpis: kpis),
                ),

                const SizedBox(height: 36),

                // ── Quick Actions ─────────────────────────────────────────
                Text('Operations Shortcuts', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickAction(label: 'Receive Goods', icon: Icons.move_to_inbox, color: AppTheme.primary, onTap: () => context.go('/receipts/new')),
                    _QuickAction(label: 'Dispatch Delivery', icon: Icons.local_shipping, color: AppTheme.success, onTap: () => context.go('/deliveries/new')),
                    _QuickAction(label: 'Internal Transfer', icon: Icons.swap_horiz, color: AppTheme.warning, onTap: () => context.go('/transfers/new')),
                    _QuickAction(label: 'Inventory Adjustment', icon: Icons.tune, color: const Color(0xFF8B5CF6), onTap: () => context.go('/adjustments/new')),
                    _QuickAction(label: 'Catalogue Product', icon: Icons.add_box, color: const Color(0xFF06B6D4), onTap: () => context.go('/products/new')),
                  ],
                ),

                const SizedBox(height: 40),

                // ── Recent Activity ───────────────────────────────────────
                Row(
                  children: [
                    Text('Recent Activity', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.go('/ledger'), 
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Full Audit Trail'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recent Receipts
                    Expanded(
                      flex: 1,
                      child: _DashboardListCard(
                        title: 'Recent Receipts',
                        provider: receiptsProvider,
                        itemBuilder: (r) => _ActivityTile(
                          title: r['supplier'] ?? 'Unknown Vendor',
                          subtitle: 'ID: #${r['id']} • ${r['created_at']?.toString().substring(0, 10)}',
                          status: r['status'] ?? 'draft',
                          onTap: () => context.go('/receipts/${r['id']}'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Recent Deliveries
                    Expanded(
                      flex: 1,
                      child: _DashboardListCard(
                        title: 'Recent Deliveries',
                        provider: deliveriesProvider,
                        itemBuilder: (d) => _ActivityTile(
                          title: d['customer'] ?? 'Unknown Customer',
                          subtitle: 'ID: #${d['id']} • ${d['created_at']?.toString().substring(0, 10)}',
                          status: d['status'] ?? 'draft',
                          onTap: () => context.go('/deliveries/${d['id']}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> kpis;
  const _KpiGrid({required this.kpis});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1100 ? 3 : constraints.maxWidth > 700 ? 2 : 1;
        return GridView.count(
          crossAxisCount: cols,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: [
            KpiCard(label: 'Total Products', value: '${kpis['total_products'] ?? 0}', icon: Icons.inventory_2_rounded),
            KpiCard(label: 'Low Stock Alerts', value: '${kpis['low_stock'] ?? 0}', icon: Icons.warning_amber_rounded, iconColor: AppTheme.warning, valueColor: AppTheme.warning),
            KpiCard(label: 'Out of Stock', value: '${kpis['out_of_stock'] ?? 0}', icon: Icons.error_outline_rounded, iconColor: AppTheme.error, valueColor: AppTheme.error),
            KpiCard(label: 'Pending Receipts', value: '${kpis['pending_receipts'] ?? 0}', icon: Icons.move_to_inbox_rounded, iconColor: AppTheme.primary),
            KpiCard(label: 'Active Deliveries', value: '${kpis['pending_deliveries'] ?? 0}', icon: Icons.local_shipping_rounded, iconColor: AppTheme.success),
            KpiCard(label: 'In-Transit Transfers', value: '${kpis['pending_transfers'] ?? 0}', icon: Icons.swap_horiz_rounded, iconColor: const Color(0xFF8B5CF6)),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _DashboardListCard extends StatelessWidget {
  final String title;
  final FutureProvider<List<dynamic>> provider;
  final Widget Function(dynamic) itemBuilder;

  const _DashboardListCard({required this.title, required this.provider, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Consumer(
            builder: (context, ref, _) {
              final asyncData = ref.watch(provider);
              return asyncData.when(
                loading: () => const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()),
                error: (e, _) => Padding(padding: EdgeInsets.all(20), child: Text('Error: $e')),
                data: (items) {
                  final recent = items.take(5).toList();
                  if (recent.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: EmptyState(message: 'No recent records', icon: Icons.history),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => itemBuilder(recent[i]),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  const _ActivityTile({required this.title, required this.subtitle, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            StatusBadge(status),
          ],
        ),
      ),
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      shrinkWrap: true,
      childAspectRatio: 2.2,
      children: List.generate(6, (i) => const SkeletonBox(height: 120, radius: 16)),
    );
  }
}
