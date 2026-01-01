import 'package:flutter/material.dart';

class FilterTabs extends StatelessWidget {
  final List<FilterTabItem> tabs;
  final String selected;
  final Function(int index, String label) onChanged;

  const FilterTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final bool isSelected = tab.label == selected;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index, tab.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color.fromARGB(255, 168, 231, 184)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: isSelected
                      ? [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(2, 2),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: isSelected
                            ? TextOverflow.visible   // 👈 Selected shows full text
                            : TextOverflow.ellipsis, // 👈 Others get "..."
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterTabItem {
  final String label;
  final IconData icon;

  FilterTabItem(this.label, this.icon);
}
