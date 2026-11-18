import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPage,
    this.enabled = true,
  });

  final int page;
  final int totalPages;
  final int total;
  final ValueChanged<int> onPage;
  final bool enabled;

  /// Page numbers to show: first, last, and a window around the current page.
  List<int?> get _numbers {
    final shown = {
      1,
      totalPages,
      page - 1,
      page,
      page + 1,
    }.where((p) => p >= 1 && p <= totalPages).toList()..sort();
    final out = <int?>[];
    for (final p in shown) {
      if (out.isNotEmpty && p - out.last! > 1) out.add(null);
      out.add(p);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Semantics(
      label: 'Page $page of $totalPages, $total goals',
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 8,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: enabled && page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          for (final p in _numbers)
            if (p == null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('…', style: TextStyle(color: AppColors.text2)),
              )
            else
              SizedBox(
                width: 44,
                height: 44,
                child: TextButton(
                  onPressed: enabled && p != page ? () => onPage(p) : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(),
                    backgroundColor: p == page ? AppColors.gold : null,
                    foregroundColor: p == page ? AppColors.onGold : AppColors.text,
                    disabledForegroundColor: p == page ? AppColors.onGold : AppColors.text3,
                  ),
                  child: Text('$p'),
                ),
              ),
          IconButton(
            tooltip: 'Next page',
            onPressed: enabled && page < totalPages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
