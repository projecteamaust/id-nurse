import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import '../services/order_draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/nurse_page.dart';
import '../widgets/status_chip.dart';
import '../widgets/supply_card.dart';

/// Step 3: choose supplies (prototype: SupplySelection in App.tsx).
/// Three columns: categories + search, the item list, and "Your request".
/// The page itself never scrolls; only the item list (and a long request list) scroll
/// inside their own areas. Items come from ApiService.getItems(); the chosen lines are
/// kept in [OrderDraft] for the Review step.
class SuppliesScreen extends StatefulWidget {
  const SuppliesScreen({super.key});

  @override
  State<SuppliesScreen> createState() => _SuppliesScreenState();
}

class _SuppliesScreenState extends State<SuppliesScreen> {
  final _searchController = TextEditingController();

  List<Item>? _items; // null while loading
  bool _loadFailed = false;
  String? _category; // selected category; the first one once items are loaded

  /// Quantity on each card's stepper, by item id (not yet added to the request).
  final Map<int, int> _stepperQty = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _items = null;
      _loadFailed = false;
    });
    try {
      final items = await context.read<ApiService>().getItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _category ??= items.firstOrNull?.category;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  /// Categories in the order they first appear in the item list.
  List<String> get _categories => {for (final item in _items ?? const <Item>[]) item.category}.toList();

  String get _query => _searchController.text.trim().toLowerCase();

  /// While searching: matches from all categories. Otherwise: the selected category.
  List<Item> get _visibleItems => (_items ?? const <Item>[])
      .where((item) => _query.isEmpty ? item.category == _category : item.name.toLowerCase().contains(_query))
      .toList();

  void _selectCategory(String category) {
    _searchController.clear(); // picking a category ends the search
    setState(() => _category = category);
  }

  /// Highest stepper value: the order limit and the stock, minus what is already requested.
  int _maxQty(Item item, OrderDraft draft) =>
      math.max(0, math.min(AppConfig.maxQtyPerItem, item.quantity) - draft.qtyFor(item.id));

  void _add(Item item, OrderDraft draft) {
    draft.add(item, _stepperQty[item.id] ?? 0);
    setState(() => _stepperQty.remove(item.id));
  }

  void _showReviewNotReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review comes in a later step.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OrderDraft>();
    final patient = draft.patient;
    if (patient == null) {
      // Opened without choosing a patient (or after sign out): go back to step 2.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/patient');
      });
      return const SizedBox.shrink();
    }

    final wide = MediaQuery.sizeOf(context).width >= AppSpacing.supplyLayoutBreakpoint;
    return NursePage(
      step: 2,
      withCard: false,
      builder: (context, scale) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sidePanel(
            width: wide ? AppSpacing.categoryPanelWidth : AppSpacing.categoryPanelWidthNarrow,
            border: const Border(right: BorderSide(color: AppColors.border)),
            scale: scale,
            child: _buildCategoryPanel(scale),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: _buildCenter(patient.fileNumber, draft, scale),
            ),
          ),
          _sidePanel(
            width: wide ? AppSpacing.cartPanelWidth : AppSpacing.cartPanelWidthNarrow,
            border: const Border(left: BorderSide(color: AppColors.border)),
            scale: scale,
            child: _buildRequestPanel(draft, scale),
          ),
        ],
      ),
    );
  }

  /// White side column (.category-panel / .cart-panel).
  Widget _sidePanel({required double width, required Border border, required AppScale scale, required Widget child}) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: scale.size(AppSpacing.sidePanelPaddingX),
        vertical: scale.size(AppSpacing.sidePanelPaddingY),
      ),
      decoration: BoxDecoration(color: AppColors.card, border: border),
      child: child,
    );
  }

  // ------------------------------------------------------------------ left: categories

  Widget _buildCategoryPanel(AppScale scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Supplies', style: scale.text(AppText.h2)),
        SizedBox(height: scale.size(18)),
        Text('Search', style: scale.text(AppText.chip.copyWith(fontSize: 13, color: AppColors.muted))),
        SizedBox(height: scale.size(AppSpacing.gapXs)),
        TextField(
          key: const Key('supply-search'),
          controller: _searchController,
          style: scale.body,
          decoration: InputDecoration(
            hintText: 'Search supplies',
            hintStyle: scale.bodyMuted, // same size as the typed text, no extra letter spacing
            constraints: BoxConstraints(minHeight: scale.control(AppSpacing.searchFieldHeight)),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: scale.size(12)),
          ),
        ),
        SizedBox(height: scale.size(AppSpacing.gapXl)),
        for (final category in _categories) ...[
          _categoryButton(category, scale),
          SizedBox(height: scale.size(5)),
        ],
      ],
    );
  }

  /// One category (.category-panel nav button). Active: light teal with dark teal text.
  Widget _categoryButton(String category, AppScale scale) {
    final active = category == _category && _query.isEmpty;
    return Material(
      color: active ? AppColors.primaryLight : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        onTap: () => _selectCategory(category),
        child: Container(
          constraints: BoxConstraints(minHeight: scale.control(AppSpacing.categoryButtonHeight)),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapM),
          alignment: Alignment.centerLeft,
          child: Text(
            category,
            style: scale.body.copyWith(
              color: active ? AppColors.primaryDark : AppColors.muted,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ centre: items

  Widget _buildCenter(String fileNumber, OrderDraft draft, AppScale scale) {
    final visible = _visibleItems;
    final title = _query.isEmpty ? (_category ?? 'Supplies') : 'Results for "${_searchController.text.trim()}"';
    return Padding(
      padding: EdgeInsets.all(scale.size(AppSpacing.supplyCenterPadding)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PATIENT $fileNumber', style: scale.text(AppText.eyebrow)),
                    SizedBox(height: scale.size(AppSpacing.gapXxs)),
                    Text(title, style: scale.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (_items != null) StatusChip(label: '${visible.length} supplies', scale: scale),
            ],
          ),
          SizedBox(height: scale.size(AppSpacing.gapL)),
          Expanded(child: _buildItemList(visible, draft, scale)),
        ],
      ),
    );
  }

  Widget _buildItemList(List<Item> visible, OrderDraft draft, AppScale scale) {
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load supplies.', style: scale.bodyMuted),
            SizedBox(height: scale.size(AppSpacing.gapL)),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.secondary,
              onPressed: _loadItems,
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
          ],
        ),
      );
    }
    if (_items == null) return const Center(child: CircularProgressIndicator());
    if (visible.isEmpty) {
      return Center(child: Text('No supplies match your search.', style: scale.bodyMuted));
    }

    final gap = scale.size(AppSpacing.supplyGridGap);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns when both cards get at least 240 px (.supply-grid), otherwise one.
        final columns = constraints.maxWidth >= 2 * AppSpacing.supplyCardMinColumnWidth + gap ? 2 : 1;
        final rowCount = (visible.length / columns).ceil();
        return ListView.separated(
          key: const Key('supply-list'),
          itemCount: rowCount,
          separatorBuilder: (_, _) => SizedBox(height: gap),
          itemBuilder: (context, row) {
            final rowItems = visible.skip(row * columns).take(columns).toList();
            // IntrinsicHeight gives both cards in a row the same height.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: i < rowItems.length ? _card(rowItems[i], draft, scale) : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _card(Item item, OrderDraft draft, AppScale scale) {
    return SupplyCard(
      key: ValueKey('supply-${item.id}'),
      item: item,
      qty: _stepperQty[item.id] ?? 0,
      maxQty: _maxQty(item, draft),
      onQtyChanged: (qty) => setState(() => _stepperQty[item.id] = qty),
      onAdd: () => _add(item, draft),
      scale: scale,
    );
  }

  // ------------------------------------------------------------------ right: your request

  Widget _buildRequestPanel(OrderDraft draft, AppScale scale) {
    final total = draft.totalUnits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Your request', style: scale.text(AppText.h2))),
            StatusChip(label: '$total units', tone: ChipTone.teal, scale: scale),
          ],
        ),
        SizedBox(height: scale.size(AppSpacing.gapL)),
        Expanded(child: draft.isEmpty ? _buildEmptyRequest(scale) : _buildRequestLines(draft, scale)),
        // Footer (.cart-footer)
        Container(
          padding: EdgeInsets.only(top: scale.size(AppSpacing.gapL)),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Total units', style: scale.body)),
                  Text('$total', style: scale.text(AppText.strong.copyWith(fontSize: 22))),
                ],
              ),
              SizedBox(height: scale.size(AppSpacing.gapL)),
              AppButton(
                label: 'Review request',
                onPressed: total > 0 ? _showReviewNotReady : null,
                expand: true,
                height: scale.buttonHeight,
                textStyle: scale.button,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Your request is empty" (.cart-empty).
  Widget _buildEmptyRequest(AppScale scale) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: scale.size(AppSpacing.cartEmptyIconSize),
            height: scale.size(AppSpacing.cartEmptyIconSize),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
            child: Text('+', style: scale.text(AppText.h1.copyWith(fontSize: 28, color: AppColors.primary))),
          ),
          SizedBox(height: scale.size(AppSpacing.gapM)),
          Text('Your request is empty', style: scale.strong, textAlign: TextAlign.center),
          SizedBox(height: scale.size(AppSpacing.gapXxs)),
          Text(
            'Add supplies to continue.',
            style: scale.text(AppText.small.copyWith(fontSize: 14)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// The chosen items (.cart-lines). Scrolls inside its own area if the list gets long.
  Widget _buildRequestLines(OrderDraft draft, AppScale scale) {
    return ListView(
      key: const Key('request-lines'),
      children: [
        for (final line in draft.lines)
          Container(
            padding: EdgeInsets.symmetric(vertical: scale.size(14)),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.item.name, style: scale.strong),
                SizedBox(height: scale.size(3)),
                Text('Slot ${line.item.slotNumber}', style: scale.small),
                SizedBox(height: scale.size(AppSpacing.gapS)),
                Row(
                  children: [
                    Expanded(child: Text('${line.qty}', style: scale.strong)),
                    TextButton(
                      onPressed: () => draft.remove(line.item.id),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        minimumSize: const Size(0, AppScale.minTouchHeight),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapS),
                      ),
                      child: Text('Remove', style: scale.body),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
