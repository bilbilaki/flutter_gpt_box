part of '../main.dart';

Widget buildFlowListItem(BuildContext context, String title, CurrentView view) {
  bool isSelected = currentView == view;
  return GestureDetector(
    onTap: () {
      // Simple function: Navigate to selected flow editor view
      setState(() {
        currentView = view;
      });
      print('Flow "$title" selected');
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).listTileTheme.selectedTileColor
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 18,
            color: isSelected
                ? Theme.of(context).listTileTheme.selectedColor
                : Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).listTileTheme.selectedColor
                    : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
