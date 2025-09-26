part of '../main.dart';

Widget _buildTemplatesView(BuildContext context) {
  final categories = {
    'All': 124,
    'AI': 73,
    'Utility': 32,
    'Assistant': 29,
    'Integration': 17,
    'Database': 16,
    'Bot': 14,
    'Internal Tool': 11,
    'Payment': 10,
    'Web Scraping': 9,
  };

  final templateCards = [
    _TemplateCardData(
      icon: Icons.attractions_outlined,
      title: 'OpenAI Assistant with Retrieval',
      description:
          'Make an Assistant that access to the files you upload in the Assistant playground.',
      tags: ['Assistant', 'AI'],
    ),
    _TemplateCardData(
      icon: Icons.chat,
      title: 'Chat with your Database',
      description:
          'Make an assistant to chat with your database. In this example, we show how to...',
      tags: ['Assistant', 'AI'],
    ),
    _TemplateCardData(
      icon: Icons.chat,
      title: 'Chat with GSheets',
      description:
          'Make an assistant that access to a google sheets to respond.',
      tags: ['Assistant'],
    ),
    _TemplateCardData(
      icon: Icons.location_city,
      title: 'City advisor',
      description:
          'Ask for plans in a specific city and get responses based on your preferences.',
      tags: ['Assistant', 'AI'],
    ),
    _TemplateCardData(
      icon: Icons.bar_chart,
      title: 'Data Analyst',
      description:
          'Recruit a new data analyst for your research. Give it access to your data in a spreadshee...',
      tags: ['Assistant', 'AI'],
    ),
    _TemplateCardData(
      icon: Icons.storage,
      title: 'Supabase Full Text Search',
      description: 'Find documents efficiently with Supabase Full Text Search.',
      tags: ['Database', 'Integration'],
    ),
    _TemplateCardData(
      icon: Icons.webhook,
      title: 'Website Q&A',
      description:
          'Scrape a website and get your Assistant to answer questions about it.',
      tags: ['Assistant', 'AI'],
    ),
    _TemplateCardData(
      icon: Icons.person_outline,
      title: 'Joe - AI Assistant on Apple Shortcut',
      description:
          'Job is an AI Assistant to help resolve kids\'s tantrums! Deployed to Apple Shortcut...',
      tags: ['AI', 'Assistant'],
    ),
    _TemplateCardData(
      icon: Icons.restaurant,
      title: 'Anthropic Extract Restaurant',
      description:
          'Extract structured data from a menu, such as title, price, description, etc., using Anthropic...',
      tags: ['AI', 'Web Scraping'],
    ),
  ];

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search and Categories panel (Fixed width for alignment with sidebar)
        Container(
          width: 280,
          margin: const EdgeInsets.only(right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  // Simple function: filter templates based on search term
                  print('Template search input: $value');
                },
              ),
              const SizedBox(height: 16),
              // Categories List
              Expanded(
                // Use Expanded to allow ListView to fill remaining height
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final entry = categories.entries.elementAt(index);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                      ),
                      title: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: Text(
                        entry.value.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        // Simple function: filter templates by category
                        print('Category "${entry.key}" selected');
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Grid of Templates
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 columns as per image
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.9, // Adjust card height
            ),
            itemCount: templateCards.length,
            itemBuilder: (context, index) {
              final cardData = templateCards[index];
              return buildTemplateCard(context, cardData);
            },
          ),
        ),
      ],
    ),
  );
}
