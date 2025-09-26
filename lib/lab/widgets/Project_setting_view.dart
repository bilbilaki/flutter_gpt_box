part of '../main.dart';

Widget buildProjectSettingsView(BuildContext context) {
  return Row(
    children: [
      // Settings Menu (Left Column)
      Container(
        width: 280, // Same width as sidebar for consistency
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: ListView(
          children: [
            buildSettingsMenuItem(
              context,
              'General',
              Icons.settings,
              isSelected: true,
            ),
            buildSettingsMenuItem(context, 'Members', Icons.people_outline),
            buildSettingsMenuItem(context, 'Plan', Icons.star_border),
            buildSettingsMenuItem(
              context,
              'Secret Keys',
              Icons.vpn_key_outlined,
            ),
            buildSettingsMenuItem(context, 'Integrations', Icons.apps_outlined),
            buildSettingsMenuItem(context, 'Storage', Icons.storage_outlined),
            buildSettingsMenuItem(
              context,
              'Export APIs',
              Icons.import_export_outlined,
            ),
            buildSettingsMenuItem(context, 'Status', Icons.bar_chart_outlined),
          ],
        ),
      ),
      // Settings Content (Right Column)
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Workspace name',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: _nodeInputDecoration.copyWith(
                        hintText: 'Chelsea\'s Project',
                        prefixIcon: const Icon(
                          Icons.circle,
                          size: 10,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      onChanged: (value) {
                        // Simple function: update workspace name input
                        print('Workspace name input: $value');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Simple function: apply workspace name change
                      print('Apply button clicked for Workspace name');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF33334A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Danger zone',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Workspace',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Permanently delete this Workspace.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Complex function: trigger delete workspace confirmation (empty `onPressed`)
                      print('Delete Workspace button clicked');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete Workspace'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              buildDetailRow(context, 'Project ID', 'buildship-il2tkl'),
              buildDetailRow(
                context,
                'Project ID',
                'buildship-il2tkl-us-central1',
                isCopyToClipboard: true,
              ),
              buildDetailRow(
                context,
                'Service Account',
                'runtime@buildship-il2tkl.iam.gserviceaccount.com',
                isCopyToClipboard: true,
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text:
                      'Connect to your Firestore project for CRUD operations. ',
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Complete documentation',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                      // In a real app, this would use a TapGestureRecognizer for `onTap`
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
