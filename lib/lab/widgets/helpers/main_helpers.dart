part of '../../main.dart';

// Helper for node filter chips in Add Node dialog
Widget buildNodeFilterChip(
  BuildContext context,
  String label, {
  bool isSelected = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8.0),
    child: ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // Simple function: filter node list
        print('Node filter "$label" selected: $selected');
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: isSelected ? Theme.of(context).primaryColor : Colors.white70,
      ),
      side: BorderSide(
        color: isSelected ? Theme.of(context).primaryColor : Colors.white30,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// Helper for a section of nodes in Add Node dialog
Widget buildNodeSection(
  BuildContext context,
  String title,
  List<_NodeItem> nodes,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: nodes
            .map(
              (node) => ActionChip(
                avatar: CircleAvatar(
                  backgroundColor:
                      node.color?.withOpacity(0.2) ??
                      Theme.of(context).scaffoldBackgroundColor,
                  child: Icon(
                    node.icon,
                    size: 16,
                    color: node.color ?? Colors.white70,
                  ),
                ),
                label: Text(
                  node.label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                onPressed: () {
                  // Simple function: Select node, close dialog
                  print('Node "${node.label}" selected');
                  Navigator.of(context).pop();
                },
                backgroundColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
            )
            .toList(),
      ),
    ],
  );
}

// Data class for node items
// Helper for log filter chips
Widget buildLogFilterChip(
  BuildContext context,
  String label,
  int count, {
  Color? color,
  bool isSelected = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4.0),
    child: ChoiceChip(
      label: Text('$label $count'),
      selected: isSelected,
      onSelected: (selected) {
        // Simple function: filter logs by type/environment
        print('Log filter "$label" selected: $selected');
      },
      selectedColor:
          color?.withOpacity(0.2) ??
          Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundColor: Theme.of(context).cardColor,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: isSelected ? (color ?? Colors.white) : Colors.white70,
      ),
      side: BorderSide(
        color: isSelected ? (color ?? Colors.white70) : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
// endregion

// Helper for input fields in Generate Node dialog
Widget buildNodeGenerateField(BuildContext context, String label, String hint) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        TextField(
          decoration: _nodeInputDecoration.copyWith(
            hintText: hint,
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down,
            ), // Placeholder for dropdown
          ),
          onChanged: (value) {
            // Simple function: update generate field value
            print('Generate field "$label" input: $value');
          },
        ),
      ],
    ),
  );
}
