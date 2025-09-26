part of '../main.dart';

// Helper widget for a single step in the flow editor sidebar (recursive for nesting)
Widget buildFlowStepItem(BuildContext context, FlowStep step, int level) {
  final double indent = 16.0 * level; // Indentation for nested steps

  if (step.isExpandable) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: ExpansionTile(
        key: PageStorageKey(
          step.label,
        ), // Required for ExpansionTile state persistence
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
        collapsedIconColor: Colors.white70,
        iconColor: Colors.white70,
        title: Row(
          children: [
            Icon(step.icon, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                step.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (step.hasEditorIcon)
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: () {
                  print('Editor icon for ${step.label} clicked');
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            if (step.hasGearIcon)
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 16),
                onPressed: () {
                  print('Settings icon for ${step.label} clicked');
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
        children: step.children!
            .map(
              (childStep) => buildFlowStepItem(context, childStep, level + 1),
            )
            .toList(),
      ),
    );
  } else {
    return Padding(
      padding: EdgeInsets.only(
        left: indent + (step.isHeader ? 12 : 0),
      ), // Extra indent for "Then/Else" headers visually
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
        leading: step.isHeader
            ? null
            : Icon(step.icon, size: 18, color: Colors.white70),
        title: Text(
          step.label,
          style: step.isHeader
              ? Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                )
              : Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (step.hasEditorIcon)
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: () {
                  print('Editor icon for ${step.label} clicked');
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            if (step.hasGearIcon)
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 16),
                onPressed: () {
                  print('Settings icon for ${step.label} clicked');
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
        onTap: () {
          // Simple function: select this step in the flow, possibly scroll to it in the canvas
          print('Flow step "${step.label}" clicked');
        },
      ),
    );
  }
}
