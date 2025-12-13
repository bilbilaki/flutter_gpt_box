part of '../main.dart';

class FlowStep {
  final String label;
  final IconData icon;
  final List<FlowStep>? children; // For nested steps like 'Then' / 'Else'
  final bool isExpandable;
  final bool isHeader; // e.g., "Then", "Else"
  final bool hasEditorIcon; // little pen icon
  final bool hasGearIcon; // little gear icon

  FlowStep({
    required this.label,
    this.icon = Icons.circle_outlined, // Default icon, can be overridden
    this.children,
    this.isExpandable = false,
    this.isHeader = false,
    this.hasEditorIcon = false,
    this.hasGearIcon = false,
  });
}
