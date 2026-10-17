import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_logo.dart';
import 'nurse_page.dart';

/// One page of the supervisor dashboard: sidebar label, icon (prototype glyphs) and URL.
class AdminNavItem {
  final String label;
  final String icon;
  final String path;

  const AdminNavItem(this.label, this.icon, this.path);
}

/// The dashboard pages, in sidebar order (Decision 5, plus problem reports).
const adminNavItems = [
  AdminNavItem('Problem reports', '!', '/supervisor/problems'),
  AdminNavItem('Stock', '▦', '/supervisor/stock'),
  AdminNavItem('Low stock', '▽', '/supervisor/low-stock'),
  AdminNavItem('Dispensing log', '↔', '/supervisor/log'),
  AdminNavItem('Reports', '▤', '/supervisor/reports'),
];

/// Counts shown as sidebar badges. Pages update them after they load or change data,
/// so the badge always matches the page.
class AdminCounts extends ChangeNotifier {
  int? _openReports;
  int? _lowStock;

  /// Open problem reports, or null before the first load.
  int? get openReports => _openReports;

  set openReports(int? value) {
    if (value == _openReports) return;
    _openReports = value;
    notifyListeners();
  }

  /// Items at or below their minimum, or null before the first load.
  int? get lowStock => _lowStock;

  set lowStock(int? value) {
    if (value == _lowStock) return;
    _lowStock = value;
    notifyListeners();
  }

  /// The badge number for a sidebar page, or null for no badge (unknown or 0).
  int? badgeFor(String path) {
    final count = switch (path) {
      '/supervisor/problems' => _openReports,
      '/supervisor/low-stock' => _lowStock,
      _ => null,
    };
    return (count ?? 0) > 0 ? count : null;
  }

  /// Loads the counts from the API. A failed load keeps the old numbers.
  Future<void> refresh(ApiService api) async {
    try {
      openReports = (await api.listProblemReports()).length;
      lowStock = (await api.getLowStock()).length;
    } catch (_) {
      // The page itself shows the error; the badge just stays as it was.
    }
  }
}

/// Supervisor dashboard frame (prototype: .admin-shell): dark sidebar with the pages and
/// "Sign out", a white header with the page title, and the page below it.
/// The sidebar stays on screen while the page changes (a go_router ShellRoute).
/// Pages get the [AppScale] with `context.watch<AppScale>()` and must fit the space they get.
class AdminShell extends StatefulWidget {
  /// The URL of the page being shown, to highlight its sidebar item and pick the title.
  final String location;
  final Widget child;

  const AdminShell({super.key, required this.location, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  /// Same tighter spacing as the Prepare result, so tables get room at 1280x720.
  static const _spacingReferenceHeight = 1000.0;

  final _counts = AdminCounts();

  @override
  void initState() {
    super.initState();
    _counts.refresh(context.read<ApiService>());
  }

  @override
  void didUpdateWidget(AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) _counts.refresh(context.read<ApiService>());
  }

  @override
  void dispose() {
    _counts.dispose();
    super.dispose();
  }

  AdminNavItem get _current =>
      adminNavItems.firstWhere((i) => widget.location.startsWith(i.path), orElse: () => adminNavItems.first);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    if (user == null) return const SizedBox.shrink(); // the router sends us back to /login

    final window = MediaQuery.sizeOf(context);
    // Measured like ScaledPage (below the top bar and step tracker), so text has the
    // same size as on the nurse screens in the same window.
    final scale = AppScale.forHeight(
      window.height - AppSpacing.topBarHeight - AppSpacing.stepTrackerHeight,
      spacingReferenceHeight: _spacingReferenceHeight,
    );
    final sidebarWidth = window.width <= AppSpacing.adminSidebarBreakpoint
        ? AppSpacing.adminSidebarWidthNarrow
        : AppSpacing.adminSidebarWidth;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminCounts>.value(value: _counts),
        Provider<AppScale>.value(value: scale),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: sidebarWidth,
              child: _Sidebar(current: _current, userName: user.name, role: user.role),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(title: _current.label),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.adminContentPaddingX,
                        vertical: scale.size(AppSpacing.adminContentPaddingY),
                      ),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// .admin-sidebar: logo, page buttons, then the user and "Sign out" at the bottom.
class _Sidebar extends StatelessWidget {
  final AdminNavItem current;
  final String userName;
  final String role;

  const _Sidebar({required this.current, required this.userName, required this.role});

  @override
  Widget build(BuildContext context) {
    final counts = context.watch<AdminCounts>();
    final initials = userName.split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join();
    const footText = TextStyle(fontFamily: AppText.fontFamily, fontSize: 14, color: Colors.white);

    return Container(
      color: AppColors.adminSidebar,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.adminSidebarPaddingX,
        vertical: AppSpacing.adminSidebarPaddingY,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, AppSpacing.gapXxl),
            child: Align(alignment: Alignment.centerLeft, child: AppLogo(textColor: Colors.white)),
          ),
          for (final item in adminNavItems)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.adminNavGap),
              child: _NavButton(
                item: item,
                active: item == current,
                badge: counts.badgeFor(item.path),
              ),
            ),
          const Spacer(),
          // .sidebar-foot
          Container(
            padding: const EdgeInsets.fromLTRB(8, AppSpacing.gapXl, 8, 0),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.adminSidebarDivider))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: AppSpacing.avatarSize,
                      height: AppSpacing.avatarSize,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                      child: Text(initials, style: AppText.strong.copyWith(color: AppColors.primary)),
                    ),
                    const SizedBox(width: AppSpacing.gapM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: footText.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(role == 'supervisor' ? 'Supervisor' : 'Nurse',
                              style: footText.copyWith(fontSize: 12, color: AppColors.adminSidebarMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gapM),
                OutlinedButton(
                  onPressed: () => signOutUser(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.adminSignOutHeight),
                    foregroundColor: AppColors.adminSidebarButtonText,
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: AppColors.adminSidebarButtonBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Sign out', style: footText.copyWith(color: AppColors.adminSidebarButtonText)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One sidebar button (.admin-sidebar nav button): icon, label, optional count badge.
/// The active page is teal with white bold text.
class _NavButton extends StatelessWidget {
  final AdminNavItem item;
  final bool active;
  final int? badge;

  const _NavButton({required this.item, required this.active, this.badge});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.adminSidebarText;
    final style = TextStyle(
      fontFamily: AppText.fontFamily,
      fontSize: 15,
      color: color,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
    );
    return Material(
      key: ValueKey('nav-${item.path}'),
      color: active ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        onTap: active ? null : () => context.go(item.path),
        child: Container(
          height: AppSpacing.adminNavItemHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.adminNavItemPaddingX),
          child: Row(
            children: [
              SizedBox(
                width: AppSpacing.adminNavIconWidth,
                child: Text(item.icon, style: style.copyWith(fontSize: 19)),
              ),
              Expanded(child: Text(item.label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (badge != null)
                Container(
                  key: ValueKey('nav-badge-${item.path}'),
                  constraints: const BoxConstraints(minWidth: AppSpacing.adminNavBadgeSize),
                  height: AppSpacing.adminNavBadgeSize,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(AppSpacing.adminNavBadgeSize),
                  ),
                  child: Text(
                    '$badge',
                    style: style.copyWith(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// .admin-header: "ID NURSE ADMIN" above the page title.
class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.adminHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.adminHeaderPaddingX),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ID NURSE ADMIN', style: AppText.eyebrow),
          const SizedBox(height: 2),
          Text(title, key: const Key('admin-title'), style: AppText.h1.copyWith(fontSize: 27)),
        ],
      ),
    );
  }
}

/// White rounded card (.admin-card) that fills the page area. Every dashboard page uses one.
class AdminCard extends StatelessWidget {
  final Widget child;

  const AdminCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AppScale>();
    return Container(
      key: const Key('admin-card'),
      width: double.infinity,
      padding: EdgeInsets.all(scale.size(AppSpacing.adminCardPadding)),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: child,
    );
  }
}
