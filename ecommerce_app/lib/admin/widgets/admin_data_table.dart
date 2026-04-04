import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';

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

  const AdminDataTable({
    super.key,
    required this.rows,
    required this.columns,
    this.initialRowsPerPage = 10,
    this.emptyMessage,
    this.minTableWidth = 900,
  });

  @override
  State<AdminDataTable<T>> createState() => _AdminDataTableState<T>();
}

class _AdminDataTableState<T> extends State<AdminDataTable<T>> {
  int? _sortColumnIndex;
  bool _sortAscending = true;
  late int _rowsPerPage;
  int _page = 0;
  late final ScrollController _horizontalController;
  late final ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    _rowsPerPage = widget.initialRowsPerPage;
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
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

    final totalPages = sortedRows.isEmpty ? 1 : ((sortedRows.length - 1) ~/ _rowsPerPage) + 1;
    if (_page >= totalPages) {
      _page = totalPages - 1;
    }
    final start = _page * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, sortedRows.length);
    final pageRows = sortedRows.sublist(start, end);

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
                  child: Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    thickness: 12,
                    radius: const Radius.circular(8),
                    notificationPredicate: (notification) => notification.depth == 1,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: widget.minTableWidth),
                        child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(AppColors.deepGold.withOpacity(0.08)),
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
                        ],
                        rows: pageRows
                            .map(
                              (row) => DataRow(
                                cells: [
                                  for (final c in widget.columns)
                                    DataCell(c.cellBuilder(row)),
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
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text('Rows: $start-${end == 0 ? 0 : end} of ${sortedRows.length}'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _rowsPerPage,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 / page')),
                      DropdownMenuItem(value: 10, child: Text('10 / page')),
                      DropdownMenuItem(value: 20, child: Text('20 / page')),
                      DropdownMenuItem(value: 50, child: Text('50 / page')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _rowsPerPage = value;
                        _page = 0;
                      });
                    },
                  ),
                  IconButton(
                    onPressed: _page > 0 ? () => setState(() => _page -= 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page ${_page + 1}/$totalPages'),
                  IconButton(
                    onPressed: _page < totalPages - 1 ? () => setState(() => _page += 1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
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
