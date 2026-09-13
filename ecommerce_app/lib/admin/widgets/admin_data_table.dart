import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';

/// Fixed-height horizontal scroll track under the table (always visible when scrollable).
/// Synced to [controller]; brand saffron thumb on a light orange track.
class _AdminBottomHorizontalScrollbar extends StatefulWidget {
  const _AdminBottomHorizontalScrollbar({required this.controller});

  final ScrollController controller;

  @override
  State<_AdminBottomHorizontalScrollbar> createState() =>
      _AdminBottomHorizontalScrollbarState();
}

class _AdminBottomHorizontalScrollbarState
    extends State<_AdminBottomHorizontalScrollbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _AdminBottomHorizontalScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const barHeight = 16.0;
    const trackRadius = 8.0;
    final trackBg = AppColors.brandSaffron.withValues(alpha: 0.22);
    final thumbColor = AppColors.brandSaffron;
    final borderColor = AppColors.brandSaffronDeep.withValues(alpha: 0.35);

    return LayoutBuilder(
      builder: (context, constraints) {
        final controller = widget.controller;
        if (!controller.hasClients) {
          return SizedBox(
            height: barHeight,
            width: constraints.maxWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: trackBg,
                borderRadius: BorderRadius.circular(trackRadius),
                border: Border.all(color: borderColor, width: 1),
              ),
            ),
          );
        }

        final position = controller.position;
        if (!position.hasContentDimensions) {
          return SizedBox(height: barHeight, width: constraints.maxWidth);
        }

        final maxExtent = position.maxScrollExtent;
        final width = constraints.maxWidth;
        if (maxExtent <= 0 || !width.isFinite || width <= 0) {
          return SizedBox(
            height: barHeight,
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: trackBg,
                borderRadius: BorderRadius.circular(trackRadius),
                border: Border.all(color: borderColor, width: 1),
              ),
            ),
          );
        }

        final contentExtent = maxExtent + position.viewportDimension;
        final minThumb = 40.0;
        final thumbW = ((position.viewportDimension / contentExtent) * width)
            .clamp(minThumb, width);
        final maxThumbTravel = (width - thumbW).clamp(0.0, double.infinity);
        final thumbLeft = maxThumbTravel > 0
            ? (position.pixels / maxExtent) * maxThumbTravel
            : 0.0;

        void jumpScrollToLocalX(double localX) {
          if (maxThumbTravel <= 0) return;
          final clamped = localX.clamp(0.0, width);
          var targetLeft = clamped - thumbW / 2;
          targetLeft = targetLeft.clamp(0.0, maxThumbTravel);
          final targetPixels = (targetLeft / maxThumbTravel) * maxExtent;
          controller.jumpTo(targetPixels.clamp(0.0, maxExtent));
        }

        return Semantics(
          label: 'Scroll table horizontally',
          child: SizedBox(
            height: barHeight,
            width: width,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => jumpScrollToLocalX(d.localPosition.dx),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: trackBg,
                  borderRadius: BorderRadius.circular(trackRadius),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: thumbLeft,
                      top: 3,
                      bottom: 3,
                      width: thumbW,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          if (!controller.hasClients || maxThumbTravel <= 0) {
                            return;
                          }
                          final pos = controller.position;
                          final me = pos.maxScrollExtent;
                          if (me <= 0) return;
                          final deltaScroll =
                              details.delta.dx * me / maxThumbTravel;
                          controller.jumpTo(
                              (pos.pixels + deltaScroll).clamp(0.0, me));
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: thumbColor,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandSaffronPressed
                                    .withValues(alpha: 0.45),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminTableColumn<T> {
  final String label;
  final Widget Function(T row) cellBuilder;
  final Comparable<dynamic>? Function(T row)? sortValue;

  const AdminTableColumn({
    required this.label,
    required this.cellBuilder,
    this.sortValue,
  });
}

class AdminDataTable<T> extends StatefulWidget {
  final List<T> rows;
  final List<AdminTableColumn<T>> columns;
  final int initialRowsPerPage;
  final String? emptyMessage;
  final double minTableWidth;
  final String Function(T row)? rowKey;
  final Set<String> selectedRowKeys;
  final ValueChanged<Set<String>>? onSelectionChanged;

  const AdminDataTable({
    super.key,
    required this.rows,
    required this.columns,
    this.initialRowsPerPage = 10,
    this.emptyMessage,
    this.minTableWidth = 900,
    this.rowKey,
    this.selectedRowKeys = const <String>{},
    this.onSelectionChanged,
  });

  @override
  State<AdminDataTable<T>> createState() => _AdminDataTableState<T>();
}

class _AdminDataTableState<T> extends State<AdminDataTable<T>> {
  static const List<int> _pageSizeOptions = [5, 10, 20, 50];
  int? _sortColumnIndex;
  bool _sortAscending = true;
  late int _rowsPerPage;
  int _page = 0;
  late final ScrollController _horizontalController;
  late final ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    _rowsPerPage = _pageSizeOptions.contains(widget.initialRowsPerPage)
        ? widget.initialRowsPerPage
        : 20;
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant AdminDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pageSizeOptions.contains(_rowsPerPage)) {
      setState(() {
        _rowsPerPage = 20;
        _page = 0;
      });
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedRows = [...widget.rows];
    if (_sortColumnIndex != null) {
      final cfg = widget.columns[_sortColumnIndex!];
      final getter = cfg.sortValue;
      if (getter != null) {
        sortedRows.sort((a, b) {
          final av = getter(a);
          final bv = getter(b);
          final result = _compareComparable(av, bv);
          return _sortAscending ? result : -result;
        });
      }
    }

    if (sortedRows.isEmpty) {
      return Card(
        child: SizedBox.expand(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(widget.emptyMessage ?? 'No data available'),
            ),
          ),
        ),
      );
    }

    final totalPages =
        sortedRows.isEmpty ? 1 : ((sortedRows.length - 1) ~/ _rowsPerPage) + 1;
    if (_page >= totalPages) {
      _page = totalPages - 1;
    }
    final start = _page * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, sortedRows.length);
    final pageRows = sortedRows.sublist(start, end);
    final canSelect =
        widget.rowKey != null && widget.onSelectionChanged != null;
    final pageKeys =
        canSelect ? pageRows.map(widget.rowKey!).toSet() : const <String>{};
    final selectedPageCount =
        pageKeys.where(widget.selectedRowKeys.contains).length;
    final allPageSelected =
        pageKeys.isNotEmpty && selectedPageCount == pageKeys.length;
    final somePageSelected = selectedPageCount > 0 && !allPageSelected;

    void updateSelection(Iterable<String> keys, bool selected) {
      if (!canSelect) return;
      final next = {...widget.selectedRowKeys};
      if (selected) {
        next.addAll(keys);
      } else {
        next.removeAll(keys);
      }
      widget.onSelectionChanged!(next);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: widget.minTableWidth),
                      child: DataTable(
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 62,
                        headingRowHeight: 52,
                        headingRowColor: WidgetStateProperty.all(
                            AppColors.deepGold.withValues(alpha: 0.08)),
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        columns: [
                          for (var i = 0; i < widget.columns.length; i++)
                            DataColumn(
                              label: Text(widget.columns[i].label),
                              onSort: widget.columns[i].sortValue == null
                                  ? null
                                  : (columnIndex, ascending) {
                                      setState(() {
                                        _sortColumnIndex = columnIndex;
                                        _sortAscending = ascending;
                                        _page = 0;
                                      });
                                    },
                            ),
                          if (canSelect)
                            DataColumn(
                              label: Checkbox(
                                tristate: true,
                                value: allPageSelected
                                    ? true
                                    : somePageSelected
                                        ? null
                                        : false,
                                onChanged: (value) =>
                                    updateSelection(pageKeys, value == true),
                              ),
                            ),
                        ],
                        showCheckboxColumn: false,
                        rows: pageRows
                            .map(
                              (row) => DataRow(
                                selected: canSelect &&
                                    widget.selectedRowKeys
                                        .contains(widget.rowKey!(row)),
                                cells: [
                                  for (final c in widget.columns)
                                    DataCell(c.cellBuilder(row)),
                                  if (canSelect)
                                    DataCell(
                                      Checkbox(
                                        value: widget.selectedRowKeys
                                            .contains(widget.rowKey!(row)),
                                        onChanged: (value) => updateSelection(
                                          [widget.rowKey!(row)],
                                          value == true,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: _AdminBottomHorizontalScrollbar(
                  controller: _horizontalController),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final controls = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<int>(
                        value: _pageSizeOptions.contains(_rowsPerPage)
                            ? _rowsPerPage
                            : 20,
                        isDense: true,
                        items: _pageSizeOptions
                            .map(
                              (v) => DropdownMenuItem(
                                  value: v, child: Text('$v / page')),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _rowsPerPage = value;
                            _page = 0;
                          });
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        onPressed:
                            _page > 0 ? () => setState(() => _page -= 1) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Page ${_page + 1}/$totalPages'),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        onPressed: _page < totalPages - 1
                            ? () => setState(() => _page += 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  );

                  final summary = Text(
                    'Rows: $start-${end == 0 ? 0 : end} of ${sortedRows.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );

                  // Narrow widths: avoid Row+Spacer overflow; keep next/prev reachable via scroll.
                  if (constraints.maxWidth < 520) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          summary,
                          const SizedBox(width: 12),
                          controls,
                        ],
                      ),
                    );
                  }

                  return Row(
                    children: [
                      Flexible(child: summary),
                      const Spacer(),
                      controls,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _compareComparable(Comparable<dynamic>? a, Comparable<dynamic>? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}
