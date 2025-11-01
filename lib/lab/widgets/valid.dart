part of '../main.dart';
final List<FlowStep> autoIndexFlowSteps = [
  FlowStep(
    label: 'Rest API Call',
    icon: Icons.api,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: 'XML to JSON',
    icon: Icons.code,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: 'Branch',
    icon: Icons.call_split,
    isExpandable: true,
    hasEditorIcon: true,
    hasGearIcon: true,
    children: [
      FlowStep(label: 'Then', isHeader: true),
      FlowStep(
        label: '{ } Concat Propert...',
        icon: Icons.code,
        hasEditorIcon: true,
        hasGearIcon: true,
      ),
      FlowStep(label: 'Else', isHeader: true),
      FlowStep(
        label: '{ } Concat Propert...',
        icon: Icons.code,
        hasEditorIcon: true,
        hasGearIcon: true,
      ),
    ],
  ),
  FlowStep(
    label: '{ } Concat...',
    icon: Icons.code,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: '{ } Log Messag...',
    icon: Icons.info_outline,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: '{ } Loop',
    icon: Icons.loop,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: '{ } Get Site...',
    icon: Icons.web_asset,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: '{ } Needs Up...',
    icon: Icons.sync,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: '{ } Branch',
    icon: Icons.call_split,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(label: '{ } Then', isHeader: true),
  FlowStep(
    label: '{ } Indexed Si...',
    icon: Icons.check_circle_outline,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(label: '{ } Else', isHeader: true),
  FlowStep(
    label: '{ } Index Sta...',
    icon: Icons.error_outline,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: '{ } Indexed Pa...',
    icon: Icons.file_present,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: '{ } Return',
    icon: Icons.reply_all,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
];

// Define the structure of the Hello World flow for the sidebar (using Image 3's nodes)
final List<FlowStep> helloWorldFlowSteps = [
  FlowStep(
    label: 'Rest API Call',
    icon: Icons.api,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: 'Return',
    icon: Icons.reply_all,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  FlowStep(
    label: 'API Call',
    icon: Icons.http,
    hasEditorIcon: true,
    hasGearIcon: true,
  ),
  // If you want to show the Supabase Trigger as a separate flow or part of a different variant,
  // you would define another list of FlowStep or integrate it here.
  // FlowStep(label: 'Supabase Trigger', icon: Icons.flash_on, hasEditorIcon: true, hasGearIcon: true),
];
