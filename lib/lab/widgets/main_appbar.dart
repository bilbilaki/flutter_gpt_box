part of '../main.dart';

PreferredSizeWidget buildMainAppBar(BuildContext context) {
  String title = "BuildShip"; // Default
  List<Widget> actions = [];

  // Different AppBar configurations based on the current view
  switch (currentView) {
    case CurrentView.templates:
    case CurrentView.database:
    case CurrentView.inviteToWorkspace:
    case CurrentView.learningAndSocials:
    case CurrentView.support:
      // This is the dashboard/templates view's app bar, which includes BuildShip logo and project dropdown
      // and general actions.
      return AppBar(
        title: Row(
          children: [
            const Text(
              'BuildShip',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(width: 16),
            const CircleAvatar(
              backgroundColor: Color(0xFF8B5CF6), // Placeholder color
              radius: 12,
              child: Text(
                'C',
                style: TextStyle(color: Colors.white, fontSize: 12),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge, // Smaller text for the app bar dropdown
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
                    // Simple function: handle project change
                    print('App bar project changed to $newValue');
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Simple function: Navigate to project settings
              setState(() {
                currentView = CurrentView.projectSettings;
              });
              print(
                'Settings button clicked from main app bar, navigating to Project Settings',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Simple function: Trigger search action
              print('Search button clicked from main app bar');
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Simple function: Open help/documentation
              print('Help button clicked from main app bar');
            },
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            backgroundColor: Color(0xFF8B5CF6),
            radius: 16,
            child: Text(
              'C',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 16),
        ],
      );
    case CurrentView.autoIndexFlow:
    case CurrentView.helloWorldFlow:
      // App bar for flow editor views
      title = currentView == CurrentView.autoIndexFlow
          ? "Auto Index Websites to Google"
          : "Hello World";
      actions = [
        ElevatedButton.icon(
          onPressed: () {
            // Simple function: Open "Add Node" dialog
            _showAddNodeDialog(context);
            print('Add node button clicked');
          },
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add node'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF33334A), // Darker background
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: () {
            // Complex function: Simulate test run (empty `onPressed`)
            print('Test button clicked');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
          child: const Text('Test'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            // Complex function: Simulate deployment (empty `onPressed`)
            print('Ship button clicked');
          },
          icon: const Icon(Icons.rocket_launch),
          label: const Text('Ship'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1), // A blue accent
          ),
        ),
        const SizedBox(width: 16),
      ];
      break;
    case CurrentView.projectSettings:
      // App bar for project settings view
      title = "Project Settings";
      actions = [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Simple function: Close settings, return to templates view
            setState(() {
              currentView = CurrentView.templates; // Return to a default view
            });
            print('Close project settings button clicked');
          },
        ),
        const SizedBox(width: 16),
      ];
      break;
  }
  // Default AppBar for other views or as a fallback
  return AppBar(title: Text(title), actions: actions);
}
  // e