import 'package:flutter/material.dart';

class TaskConfigurationSection extends StatelessWidget {
  final String selectedTask;
  final ValueChanged<String?> onTaskChanged;
  final String selectedDevice;
  final ValueChanged<String?> onDeviceChanged;
  final TextEditingController selectorController;
  final int screencastWidth;
  final int screencastHeight;
  final int screencastDuration;
  final ValueChanged<int?> onWidthChanged;
  final ValueChanged<int?> onHeightChanged;
  final ValueChanged<int?> onDurationChanged;
  final String selectedWaitRule;
  final ValueChanged<String?> onWaitRuleChanged;
  final bool isRunning;

  const TaskConfigurationSection({
    Key? key,
    required this.selectedTask,
    required this.onTaskChanged,
    required this.selectedDevice,
    required this.onDeviceChanged,
    required this.selectorController,
    required this.screencastWidth,
    required this.screencastHeight,
    required this.screencastDuration,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onDurationChanged,
    required this.selectedWaitRule,
    required this.onWaitRuleChanged,
    required this.isRunning,
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
              'Task Configuration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTaskSelector(),
            const SizedBox(height: 20),
            if (selectedTask == 'screenshot') _buildDeviceSelector(),
            if (selectedTask == 'element') _buildSelectorInput(),
            if (selectedTask == 'screencast') _buildScreencastConfig(),
            _buildWaitRuleSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Task',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Radio<String>(
              value: 'pdf',
              groupValue: selectedTask,
              onChanged: isRunning ? null : onTaskChanged,
            ),
            const Text('Generate PDF'),
            const SizedBox(width: 24),
            Radio<String>(
              value: 'screenshot',
              groupValue: selectedTask,
              onChanged: isRunning ? null : onTaskChanged,
            ),
            const Text('Take Screenshots'),
            const SizedBox(width: 24),
            Radio<String>(
              value: 'element',
              groupValue: selectedTask,
              onChanged: isRunning ? null : onTaskChanged,
            ),
            const Text('Element Screenshot'),
            const SizedBox(width: 24),
            Radio<String>(
              value: 'html',
              groupValue: selectedTask,
              onChanged: isRunning ? null : onTaskChanged,
            ),
            const Text('Save Page HTML'),
            const SizedBox(width: 24),
            Radio<String>(
              value: 'screencast',
              groupValue: selectedTask,
              onChanged: isRunning ? null : onTaskChanged,
            ),
            const Text('Screencast (GIF)'),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Device to Emulate',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          isExpanded: true,
          value: selectedDevice,
          items: const [
            DropdownMenuItem(
              value: 'none',
              child: Text('Desktop (No Emulation)'),
            ),
            DropdownMenuItem(
              value: 'iPhoneX',
              child: Text('iPhone X'),
            ),
            DropdownMenuItem(
              value: 'pixel2',
              child: Text('Pixel 2'),
            ),
            DropdownMenuItem(
              value: 'iPad',
              child: Text('iPad'),
            ),
          ],
          onChanged: isRunning ? null : onDeviceChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSelectorInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CSS Selector',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: selectorController,
          enabled: !isRunning,
          decoration: const InputDecoration(
            hintText: 'e.g. input[id="search-box"], #main, .btn-primary',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildScreencastConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Screencast Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Width (px)'),
                  const SizedBox(height: 4),
                  TextField(
                    enabled: !isRunning,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: screencastWidth.toString(),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      onWidthChanged(int.tryParse(value));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Height (px)'),
                  const SizedBox(height: 4),
                  TextField(
                    enabled: !isRunning,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: screencastHeight.toString(),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      onHeightChanged(int.tryParse(value));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Duration (sec)'),
                  const SizedBox(height: 4),
                  TextField(
                    enabled: !isRunning,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: screencastDuration.toString(),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      onDurationChanged(int.tryParse(value));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text(
                    'Resolution',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${screencastWidth}x${screencastHeight}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text(
                    'Duration',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${screencastDuration}s',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWaitRuleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Page Load Wait Rule',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          isExpanded: true,
          value: selectedWaitRule,
          items: const [
            DropdownMenuItem(
              value: 'domContentLoaded',
              child: Text('DOM Content Loaded'),
            ),
            DropdownMenuItem(
              value: 'networkIdle',
              child: Text('Network Idle'),
            ),
            DropdownMenuItem(
              value: 'networkAlmostIdle',
              child: Text('Network Almost Idle'),
            ),
          ],
          onChanged: isRunning ? null : onWaitRuleChanged,
        ),
      ],
    );
  }
}
