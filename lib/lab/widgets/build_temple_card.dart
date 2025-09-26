part of '../main.dart';

Widget buildTemplateCard(BuildContext context, _TemplateCardData data) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      // Make card clickable
      onTap: () {
        // Simple function: Open template details or start new flow
        print('Template card "${data.title}" clicked');
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).scaffoldBackgroundColor, // Darker circle background
              radius: 20,
              child: Icon(data.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                data.description,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: data.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      labelStyle: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}
