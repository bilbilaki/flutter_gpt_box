import 'package:flutter/material.dart';

class ProgressTrackerSection extends StatelessWidget {
  final int totalUrls;
  final int completedUrls;
  final bool isRunning;
  final String currentUrl;

  const ProgressTrackerSection({
    Key? key,
    required this.totalUrls,
    required this.completedUrls,
    required this.isRunning,
    required this.currentUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Tracker',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Progress Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Total URLs', totalUrls.toString()),
                _buildStatColumn('Completed', completedUrls.toString()),
                _buildStatColumn(
                  'Remaining',
                  (totalUrls - completedUrls).toString(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Overall Progress:'),
                    Text(
                      totalUrls == 0
                          ? '0%'
                          : '${((completedUrls / totalUrls) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalUrls == 0 ? 0 : completedUrls / totalUrls,
                    minHeight: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Currently Processing
            if (isRunning && currentUrl.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Currently Processing:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentUrl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
