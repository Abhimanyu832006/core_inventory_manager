import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

const _navItems = [
  _NavItem('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  _NavItem('Products', Icons.inventory_2_outlined, '/products'),
  _NavItem('Receipts', Icons.move_to_inbox_outlined, '/receipts'),
  _NavItem('Deliveries', Icons.local_shipping_outlined, '/deliveries'),
  _NavItem('Transfers', Icons.swap_horiz_outlined, '/transfers'),
  _NavItem('Adjustments', Icons.tune_outlined, '/adjustments'),
  _NavItem('Stock Ledger', Icons.receipt_long_outlined, '/ledger'),
];

const _bottomNavItems = [
  _NavItem('Warehouses', Icons.warehouse_outlined, '/warehouses'),
  _NavItem('Profile', Icons.person_outline, '/profile'),
];

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          SizedBox(
            width: 240,
            child: Container(
              color: AppTheme.sidebarBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'CoreInventory',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main nav
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _SectionLabel('OPERATIONS'),
                        const SizedBox(height: 4),
                        ..._navItems.map((item) => _SidebarTile(
                          item: item,
                          selected: location.startsWith(item.route),
                        )),
                        const SizedBox(height: 16),
                        _SectionLabel('SETTINGS'),
                        const SizedBox(height: 4),
                        ..._bottomNavItems.map((item) => _SidebarTile(
                          item: item,
                          selected: location.startsWith(item.route),
                        )),
                      ],
                    ),
                  ),

                  // Logout
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _SidebarTile(
                      item: const _NavItem('Logout', Icons.logout_outlined, ''),
                      selected: false,
                      onTap: () async {
                        await AuthService().logout();
                        if (context.mounted) context.go('/auth/login');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main Content ─────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: AppTheme.surface,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback? onTap;

  const _SidebarTile({required this.item, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: selected ? AppTheme.sidebarSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          size: 18,
          color: selected ? Colors.white : Colors.white54,
        ),
        title: Text(
          item.label,
          style: GoogleFonts.inter(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        onTap: onTap ?? () => context.go(item.route),
      ),
    );
  }
}
