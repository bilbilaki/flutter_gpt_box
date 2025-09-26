part of '../main.dart';

Widget buildLeftSidebar(BuildContext context) {
  return Container(
    width: 280, // Fixed width for the sidebar
    color: Theme.of(context).cardColor, // Background color for the sidebar
    child: Column(
      children: [
        // Top user/project section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF8B5CF6), // Placeholder color
                radius: 16,
                child: Text(
                  'C',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: "Chelsea's Project",
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white70,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                    dropdownColor: Theme.of(context).dialogBackgroundColor,
                    items: <String>["Chelsea's Project", "My Other Project"]
                        .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        })
                        .toList(),
                    onChanged: (String? newValue) {
                      // Simple function: print selected project
                      print('Project changed to $newValue');
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  // Simple function: Navigate to project settings
                  setState(() {
                    currentView = CurrentView.projectSettings;
                  });
                  print(
                    'Settings button clicked, navigating to Project Settings',
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  // Simple function: Trigger search action
                  print('Search button clicked');
                },
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () {
                  // Simple function: Open help/documentation
                  print('Help button clicked');
                },
              ),
            ],
          ),
        ),
        // Search Flows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              // Simple function: filter flows list
              print('Flow search input: $value');
            },
          ),
        ),
        // Flows list section (always visible)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Flows (2/5)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      // Simple function: trigger add new flow dialog/action
                      print('Add new flow button clicked');
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            // Flow list items (static for navigation)
            buildFlowListItem(
              context,
              'Auto Index Website...',
              CurrentView.autoIndexFlow,
            ),
            buildFlowListItem(
              context,
              'Hello World',
              CurrentView.helloWorldFlow,
            ),
          ],
        ),
        // Dynamic content for the selected flow's steps (if a flow is selected)
        if (currentView == CurrentView.autoIndexFlow ||
            currentView == CurrentView.helloWorldFlow)
          Expanded(
            // This Expanded widget will now hold the selected flow's detailed steps
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.grid_view,
                        ), // List view selector from image
                        onPressed: () {
                          /* Simple function: change flow list view */
                          print('Flow list view selector clicked');
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                    ),
                    onChanged: (value) {
                      // Simple function: filter nodes in current flow
                      print('Flow step search input: $value');
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    children:
                        (currentView == CurrentView.autoIndexFlow
                                ? autoIndexFlowSteps
                                : helloWorldFlowSteps)
                            .map(
                              (step) => buildFlowStepItem(context, step, 0),
                            ) // level 0 for top-level
                            .toList(),
                  ),
                ),
              ],
            ),
          )
        else // If no flow editor is active, fill remaining space with an empty spacer or other global content
          const Spacer(),

        // Bottom Navigation Items
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // "Free Plan" / "Upgrade" block
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF33334A),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Free Plan',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Simple function: Navigate to upgrade page/dialog
                        print('Upgrade button clicked');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor, // Purple
                        minimumSize: Size.zero, // Remove fixed size
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Upgrade'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Static bottom menu items
              buildSidebarMenuItem(
                context,
                Icons.data_usage,
                'Database',
                CurrentView.database,
              ),
              buildSidebarMenuItem(
                context,
                Icons.person_add_alt_1,
                'Invite to Workspace',
                CurrentView.inviteToWorkspace,
              ),
              buildSidebarMenuItem(
                context,
                Icons.dashboard,
                'Templates',
                CurrentView.templates,
              ),
              buildSidebarMenuItem(
                context,
                Icons.school_outlined,
                'Learning & Socials',
                CurrentView.learningAndSocials,
              ),
              buildSidebarMenuItem(
                context,
                Icons.support_agent,
                'Support',
                CurrentView.support,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
