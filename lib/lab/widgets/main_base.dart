part of '../main.dart';

Widget buildMainContent(BuildContext context) {
  switch (currentView) {
    case CurrentView.templates:
      return _buildTemplatesView(context);
    case CurrentView.autoIndexFlow:
      return buildFlowEditorView(context, isAutoIndexFlow: true);
    case CurrentView.helloWorldFlow:
      return buildFlowEditorView(context, isAutoIndexFlow: false);
    case CurrentView.projectSettings:
      return buildProjectSettingsView(context);
    case CurrentView.database:
      return _buildDatabaseView(context);
    case CurrentView.inviteToWorkspace:
      return buildInviteToWorkspaceView(context);
    case CurrentView.learningAndSocials:
      return _buildLearningAndSocialsView(context);
    case CurrentView.support:
      return _buildSupportView(context);
  }
}
