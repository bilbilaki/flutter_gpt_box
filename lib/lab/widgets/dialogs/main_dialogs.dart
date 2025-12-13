part of '../../main.dart';

void _showAddNodeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nodes',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    // Simple function: Close current dialog and open 'Generate Node' dialog
                    Navigator.of(context).pop();
                    showGenerateNodeDialog(context);
                    print(
                      'Generate button clicked, opening generate node dialog',
                    );
                  },
                  child: const Text('Generate'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    // Simple function: Close dialog
                    Navigator.of(context).pop();
                    print('Close add node dialog button clicked');
                  },
                ),
              ],
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.4, // Adjust width
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.grid_view),
                    onPressed: () {
                      // Simple function: Toggle view mode or other action
                      print('Grid view icon clicked in add node search');
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                ),
                onChanged: (value) {
                  // Simple function: filter nodes list
                  print('Node search input: $value');
                },
              ),
              const SizedBox(height: 16),
              // Node filter chips
              Row(
                children: [
                  buildNodeFilterChip(context, 'All nodes', isSelected: true),
                  buildNodeFilterChip(context, 'Community'),
                  buildNodeFilterChip(context, 'My library'),
                  buildNodeFilterChip(context, 'Paste'),
                ],
              ),
              // Node categories
              buildNodeSection(context, 'Most popular', [
                _NodeItem(icon: Icons.api, label: 'API Call'),
                _NodeItem(icon: Icons.ramp_right, label: 'OpenAI Assistant'),
                _NodeItem(icon: Icons.info_outline, label: 'Log Message to...'),
                _NodeItem(icon: Icons.text_fields, label: 'Text Generator'),
                _NodeItem(icon: Icons.web_asset, label: 'Crawler'),
                _NodeItem(icon: Icons.article, label: 'Create Document'),
              ]),
              buildNodeSection(context, 'Flow nodes', [
                _NodeItem(icon: Icons.reply_all, label: 'Return'),
                _NodeItem(icon: Icons.call_split, label: 'Branch'),
                _NodeItem(icon: Icons.loop, label: 'Loop'),
                _NodeItem(icon: Icons.call_merge, label: 'Parallel'),
                _NodeItem(icon: Icons.repeat, label: 'Repeat'),
                _NodeItem(icon: Icons.compare_arrows, label: 'Switch'),
              ]),
              buildNodeSection(context, 'Integrations', [
                _NodeItem(
                  icon: Icons.table_chart,
                  label: 'Airtable',
                  color: Colors.orange,
                ),
                _NodeItem(
                  icon: Icons.search,
                  label: 'Algolia',
                  color: Colors.blue,
                ),
              ]),
            ],
          ),
        ),
      );
    },
  );
}

// --- Generate Node Dialog ---
void showGenerateNodeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nodes',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // Simple function: Close dialog
                Navigator.of(context).pop();
                print('Close generate node dialog button clicked');
              },
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.4,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Describe what you want the node to do:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              buildNodeGenerateField(context, 'Given', 'an image'),
              buildNodeGenerateField(context, 'I want to', 'detect the text'),
              buildNodeGenerateField(
                context,
                'And return',
                'the text in plain format',
              ),
              const SizedBox(height: 16),
              Text(
                'Additional context (optional)',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 4,
                decoration: _nodeInputDecoration.copyWith(
                  hintText: 'Paste your code sample here...',
                  counterText: '0/5000',
                  counterStyle: Theme.of(context).textTheme.bodySmall,
                ),
                onChanged: (value) {
                  // Complex function: Update context for AI generation
                  print('Additional context input: $value');
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      // Complex function: Open API spec editor/documentation
                      print('API spec button clicked');
                    },
                    icon: const Icon(Icons.api, size: 18),
                    label: const Text('API spec'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      side: const BorderSide(color: Colors.white30),
                      foregroundColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      // Complex function: Open guideline documentation
                      print('Guideline link clicked');
                    },
                    child: Text(
                      'Guideline for AI to understand your requirements',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Complex function: Trigger AI node generation (empty `onPressed`)
                  print('Generate with AI button clicked');
                },
                icon: const Icon(CupertinoIcons.sparkles, size: 20),
                label: const Text('Generate with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Blue accent
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '50 / 50 left',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
