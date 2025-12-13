part of '../../main.dart';

Widget buildFlowEditorView(
  BuildContext context, {
  required bool isAutoIndexFlow,
}) {
  return SingleChildScrollView(
    // Allow scrolling for the node canvas
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          [
                if (isAutoIndexFlow) ...[
                  // Auto Index Website Flow (from Image 2)
                  buildNodeCard(
                    context,
                    title: 'Rest API Call',
                    icon: Icons.api,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNodeField(
                          context,
                          'Path',
                          TextField(
                            decoration: _nodeInputDecoration.copyWith(
                              hintText: '/auto-indexing',
                            ),
                          ),
                        ),
                        _buildNodeField(
                          context,
                          'Method',
                          DropdownButtonFormField<String>(
                            value: 'POST',
                            decoration: _nodeInputDecoration,
                            dropdownColor: Theme.of(
                              context,
                            ).dialogBackgroundColor,
                            style: Theme.of(context).textTheme.bodyMedium,
                            items: ['GET', 'POST', 'PUT', 'DELETE'].map((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              // Simple function: update method
                              print('Rest API method changed to $newValue');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  buildConnectionArrow(),
                  buildNodeCard(
                    context,
                    title: 'XML to JSON',
                    icon: Icons.code,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNodeField(
                          context,
                          'XML File...',
                          DropdownButtonFormField<String>(
                            value: 'Sitemap URL',
                            decoration: _nodeInputDecoration,
                            dropdownColor: Theme.of(
                              context,
                            ).dialogBackgroundColor,
                            style: Theme.of(context).textTheme.bodyMedium,
                            items: ['Sitemap URL'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              // Simple function: update XML file source
                              print('XML file source changed to $newValue');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  buildConnectionArrow(),
                  buildNodeCard(
                    context,
                    title: 'Branch',
                    icon: Icons.call_split,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNodeField(
                          context,
                          'XML File...',
                          TextField(
                            decoration: _nodeInputDecoration.copyWith(
                              hintText: 'Editor',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Branch "Then" and "Else" labels with a divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Then',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                        Expanded(
                          child: Container(height: 1, color: Colors.white30),
                        ),
                        Icon(Icons.arrow_right_alt, color: Colors.white30),
                        Expanded(
                          child: Container(height: 1, color: Colors.white30),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Else',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Branch outcome nodes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: buildNodeCard(
                          context,
                          title: 'Concat Propert...',
                          icon: Icons.code,
                          isCompact: true,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildNodeField(
                                context,
                                'JSON Obj...',
                                TextField(
                                  decoration: _nodeInputDecoration.copyWith(
                                    hintText: 'Editor',
                                  ),
                                ),
                              ),
                              _buildNodeField(
                                context,
                                'Key',
                                TextField(
                                  decoration: _nodeInputDecoration.copyWith(
                                    hintText: 'sitemap',
                                  ),
                                ),
                              ),
                              _buildNodeField(
                                context,
                                'Properties',
                                TextField(
                                  decoration: _nodeInputDecoration.copyWith(
                                    hintText: '[] Editor',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: buildNodeCard(
                          context,
                          title: 'Concat Propert...',
                          icon: Icons.code,
                          isCompact: true,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildNodeField(
                                context,
                                'JSON Obj...',
                                TextField(
                                  decoration: _nodeInputDecoration.copyWith(
                                    hintText: 'Editor',
                                  ),
                                ),
                              ),
                              _buildNodeField(
                                context,
                                'Key',
                                TextField(
                                  decoration: _nodeInputDecoration.copyWith(
                                    hintText: 'url',
                                  ),
                                ),
                              ),
                              _buildNodeField(
                                context,
                                'Properties',
                                TextField(
                                  decoration: _nodeInputDecoration.copyWith(
                                    hintText: '[] Editor',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Hello World Flow (from Image 3, Image 4 shows a 'Supabase Trigger' as an alternative/start)
                  // Option 1: Show the flow as in Image 3
                  buildNodeCard(
                    context,
                    title: 'Rest API Call',
                    icon: Icons.api,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNodeField(
                          context,
                          'Path',
                          TextField(
                            decoration: _nodeInputDecoration.copyWith(
                              hintText: '/hello',
                            ),
                          ),
                        ),
                        _buildNodeField(
                          context,
                          'Method',
                          DropdownButtonFormField<String>(
                            value: 'GET',
                            decoration: _nodeInputDecoration,
                            dropdownColor: Theme.of(
                              context,
                            ).dialogBackgroundColor,
                            style: Theme.of(context).textTheme.bodyMedium,
                            items: ['GET', 'POST', 'PUT', 'DELETE'].map((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              print('Rest API method changed to $newValue');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  buildConnectionArrow(),
                  buildNodeCard(
                    context,
                    title: 'Return',
                    icon: Icons.reply_all,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNodeField(
                          context,
                          'Status co...',
                          DropdownButtonFormField<String>(
                            value: 'OK (200)',
                            decoration: _nodeInputDecoration,
                            dropdownColor: Theme.of(
                              context,
                            ).dialogBackgroundColor,
                            style: Theme.of(context).textTheme.bodyMedium,
                            items:
                                [
                                  'OK (200)',
                                  'Bad Request (400)',
                                  'Internal Server Error (500)',
                                ].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              print('Return status code changed to $newValue');
                            },
                          ),
                        ),
                        _buildNodeField(
                          context,
                          'Value',
                          TextField(
                            decoration: _nodeInputDecoration.copyWith(
                              hintText: 'Hello World 👋',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  buildConnectionArrow(),
                  buildNodeCard(
                    context,
                    title: 'API Call',
                    icon: Icons.http,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNodeField(
                          context,
                          'HTTP Met...',
                          DropdownButtonFormField<String>(
                            value: 'GET',
                            decoration: _nodeInputDecoration,
                            dropdownColor: Theme.of(
                              context,
                            ).dialogBackgroundColor,
                            style: Theme.of(context).textTheme.bodyMedium,
                            items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
                                .map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                })
                                .toList(),
                            onChanged: (String? newValue) {
                              print('HTTP Method changed to $newValue');
                            },
                          ),
                        ),
                        _buildNodeField(
                          context,
                          'URL',
                          TextField(decoration: _nodeInputDecoration),
                        ),
                        _buildNodeField(
                          context,
                          'Authoriza...',
                          TextField(decoration: _nodeInputDecoration),
                        ),
                        _buildNodeField(
                          context,
                          'Query Par...',
                          TextField(decoration: _nodeInputDecoration),
                        ),
                        _buildNodeField(
                          context,
                          'Body',
                          TextField(decoration: _nodeInputDecoration),
                        ),
                        _buildNodeField(
                          context,
                          'Content.T...',
                          TextField(decoration: _nodeInputDecoration),
                        ),
                        Padding(
                          // Special layout for checkbox
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Text(
                                'Await?',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(width: 8),
                              Checkbox(
                                value: true, // Example value
                                onChanged: (bool? val) {
                                  // Simple function: toggle checkbox
                                  print('Await checkbox changed to $val');
                                },
                                fillColor: MaterialStateProperty.resolveWith((
                                  states,
                                ) {
                                  if (states.contains(MaterialState.selected)) {
                                    return Theme.of(context).primaryColor;
                                  }
                                  return Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor; // Unchecked color
                                }),
                                side: const BorderSide(color: Colors.white30),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Option 2: If you want to show the 'Supabase Trigger' from Image 4 instead/additionally:
                  // Uncomment the following section and adjust as needed.
                  /*
            buildNodeCard(
              context,
              title: 'Supabase Trigger',
              icon: Icons.flash_on, // Or a database icon, flash_on seems closer to 'trigger'
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNodeField(context, 'Path', TextField(decoration: _nodeInputDecoration.copyWith(hintText: 'Authenticate'))),
                  Center(child: Icon(Icons.lock, size: 24, color: Colors.white70)),
                  Center(child: Text('Authenticate', style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
            buildConnectionArrow(),
            */
                ],
              ]
              .expand((widget) => [widget, const SizedBox(height: 16)])
              .toList(), // Add spacing between nodes
    ),
  );
}

// Common input decoration for node text fields and dropdowns
final InputDecoration _nodeInputDecoration = InputDecoration(
  filled: true,
  fillColor: const Color(0xFF33334A),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6.0),
    borderSide: BorderSide.none,
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  isDense: true,
);

// Helper for displaying a label and an input widget within a node card
Widget _buildNodeField(BuildContext context, String label, Widget inputWidget) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        inputWidget,
      ],
    ),
  );
}

// Helper for creating a node card in the flow editor
Widget buildNodeCard(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Widget content,
  bool isCompact = false, // For smaller nodes like branch outcomes
}) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    color: Theme.of(context).cardColor,
    child: Container(
      padding: const EdgeInsets.all(12.0),
      width: isCompact
          ? null
          : 360, // Nodes have fixed width, compact for branch outcomes
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                radius: 12,
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              // Node action buttons (copy, connect, more options)
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  print('Copy node button clicked');
                },
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right_alt, size: 16),
                onPressed: () {
                  print('Connect node button clicked');
                },
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 16),
                onPressed: () {
                  print('More options button clicked for node');
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          content,
        ],
      ),
    ),
  );
}

// Visual representation of a connection arrow between nodes
Widget buildConnectionArrow() {
  return Center(
    child: Container(
      height: 40,
      width: 1,
      color: Colors.white30,
      alignment: Alignment.bottomCenter,
      child: const Icon(Icons.arrow_downward, color: Colors.white30, size: 16),
    ),
  );
}

// --- Logs Panel ---
Widget _buildLogsPanel(BuildContext context, {bool showNoLogs = false}) {
  return Container(
    color: Theme.of(context).cardColor,
    padding: const EdgeInsets.all(16.0),
    height: 200, // Fixed height for logs panel
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Logs',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.fullscreen),
              onPressed: () {
                // Simple function: Expand logs panel
                print('Fullscreen logs button clicked');
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!showNoLogs) // Only show filter options if there are supposed to be logs
          Row(
            children: [
              // Dropdowns for log filtering
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'Last 7 days',
                  items: ['Last 7 days', 'Last 30 days', 'Today']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    // Simple function: filter logs by date range
                    print('Logs date range changed to $val');
                  },
                  dropdownColor: Theme.of(context).dialogBackgroundColor,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'v', // Placeholder for version dropdown
                  items: ['v']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    // Simple function: filter logs by version
                    print('Logs version changed to $val');
                  },
                  dropdownColor: Theme.of(context).dialogBackgroundColor,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Refreshes in 56s',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              // Log filter chips
              buildLogFilterChip(context, 'All', 0, isSelected: true),
              buildLogFilterChip(context, 'Success', 0, color: Colors.green),
              buildLogFilterChip(context, 'Failed', 0, color: Colors.red),
              buildLogFilterChip(context, 'Prod', 0),
              buildLogFilterChip(context, 'Test', 0),
            ],
          ),
        const SizedBox(height: 16),
        Expanded(
          child: showNoLogs
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No logs. Hit refresh.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Simple function: refresh logs
                          print('Refresh logs button clicked (no logs state)');
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : Center(
                  // Placeholder for actual log entries
                  child: Text(
                    'Displaying actual log entries...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
        ),
      ],
    ),
  );
}

// region Placeholder Views (Enriched)
Widget _buildDatabaseView(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.data_usage, size: 80, color: Colors.white30),
        const SizedBox(height: 16),
        Text(
          'Database Management',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Connect and manage your data sources here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            print('Connect Database button clicked');
          },
          icon: const Icon(Icons.add),
          label: const Text('Connect New Database'),
        ),
      ],
    ),
  );
}

Widget buildInviteToWorkspaceView(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_add_alt_1, size: 80, color: Colors.white30),
        const SizedBox(height: 16),
        Text(
          'Invite Members to Workspace',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Collaborate with your team by inviting them to this workspace.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            print('Send Invite button clicked');
          },
          icon: const Icon(Icons.mail_outline),
          label: const Text('Send Invite'),
        ),
      ],
    ),
  );
}

Widget _buildLearningAndSocialsView(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.school_outlined, size: 80, color: Colors.white30),
        const SizedBox(height: 16),
        Text(
          'Learning & Community',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Explore tutorials, join the community, and learn more about BuildShip.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            print('Go to Tutorials button clicked');
          },
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Go to Tutorials'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            print('Join Community button clicked');
          },
          icon: const Icon(Icons.groups_outlined),
          label: const Text('Join Community'),
        ),
      ],
    ),
  );
}

Widget _buildSupportView(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.support_agent, size: 80, color: Colors.white30),
        const SizedBox(height: 16),
        Text('Need Help?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Our support team is here to assist you with any questions.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            print('Contact Support button clicked');
          },
          icon: const Icon(Icons.email_outlined),
          label: const Text('Contact Support'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            print('Visit Documentation clicked');
          },
          child: const Text('Visit Documentation'),
        ),
      ],
    ),
  );
}
