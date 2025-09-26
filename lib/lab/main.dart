import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gpt_box/lab/configs/enum.dart';
import 'app.dart';
// For the sparkle icon (CupertinoIcons.sparkle)
part 'models/templete_card_data.dart';
part 'models/flow_steps.dart';
part 'models/node_item.dart';
part 'widgets/temple_view.dart';
part 'widgets/build_temple_card.dart';
part 'widgets/left_sidebar.dart';
part 'widgets/buildFlowStepItem.dart';
part 'widgets/buildFlowListItem.dart';
part 'widgets/main_appbar.dart';
part 'widgets/buildDetailRow.dart';
part 'widgets/buildSettingItemMenu.dart';
part 'widgets/buildSidebarMenuItem.dart';
part 'widgets/Project_setting_view.dart';
part 'widgets/invite_to_workspace_view.dart';
part 'widgets/helpers/main_helpers.dart';
part 'widgets/dialogs/main_dialogs.dart';
part 'widgets/editors/editor.dart';
part 'widgets/logs_panel.dart';
part 'widgets/learning_and_socials_view.dart';
part 'widgets/support_view.dart';
part 'widgets/valid.dart';
part 'widgets/main_base.dart';
// part 'widgets/database_view.dart'; --- IGNORE ---
 CurrentView currentView = CurrentView.templates; // Initial view
late Function setState; // State updater function
void main() {
  runApp(const MyApp());
}

class BuildShipHomeFake extends StatelessWidget {
  final Function setState;
  const BuildShipHomeFake(this.setState, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar (Fixed Width)
          buildLeftSidebar(context),
          // Main Content Area (Takes remaining space)
          Expanded(
            child: Column(
              children: [
                buildMainAppBar(context), // Dynamic AppBar based on current view
                Expanded(
                  child: buildMainContent(context), // Dynamic main content
                ),
                // Logs panel only visible for flow editor views
                if (currentView == CurrentView.autoIndexFlow || currentView == CurrentView.helloWorldFlow)
                  _buildLogsPanel(context, showNoLogs: currentView == CurrentView.helloWorldFlow),
              ],
            ),
          ),
        ],
      ),
    );
  }


}




