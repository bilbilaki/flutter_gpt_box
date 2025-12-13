part of '../main.dart';

Widget buildSettingsMenuItem(
  BuildContext context,
  String title,
  IconData icon, {
  bool isSelected = false,
}) {
  return ListTile(
    leading: Icon(
      icon,
      color: isSelected ? Theme.of(context).primaryColor : Colors.white70,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    selected: isSelected,
    selectedTileColor: Theme.of(context).listTileTheme.selectedTileColor,
    onTap: () {
      // Simple function: select the setting category (visual highlight)
      print('Settings category "$title" selected');
      // In a real app, this would update the right-hand content.
    },
  );
}
