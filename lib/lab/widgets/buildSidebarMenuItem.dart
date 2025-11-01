part of '../main.dart';
Widget buildSidebarMenuItem(
  BuildContext context,
  IconData icon,
  String title,
  CurrentView view,
) {
  bool isSelected = currentView == view;
  return ListTile(
    leading: Icon(
      icon,
      color: isSelected
          ? Theme.of(context).listTileTheme.selectedColor
          : Theme.of(context).listTileTheme.iconColor,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: isSelected
            ? Theme.of(context).listTileTheme.selectedColor
            : Theme.of(context).listTileTheme.textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    selected: isSelected,
    selectedTileColor: Theme.of(context).listTileTheme.selectedTileColor,
    onTap: () {
      // Simple function: Navigate to selected view
      setState(() {
        currentView = view;
      });
      print('$title button clicked, navigating to view: $view');
    },
  );
}
  // endregion

