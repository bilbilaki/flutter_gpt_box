part of 'setting.dart';

class McpPage extends StatefulWidget {
  const McpPage({super.key});

  @override
  State<McpPage> createState() => _McpPageState();
}

final class _McpPageState extends State<McpPage>
    with AutomaticKeepAliveClientMixin {
  final _mcpStore = Stores.mcp;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AutoMultiList(
      children: [_buildTools, _buildMcps, _presetMcpExample, _buildList],
    );
  }

  Widget get _buildTools {
    return Column(
      children: [
        CenterGreyTitle(l10n.tool),
        _buildUseTool(),
        _buildModelRegExp(),
      ],
    );
  }

  Widget get _presetMcpExample {
    return Column(
      children: [CenterGreyTitle("MCP Presets"), McpPresetsWidget()],
    );
  }

  Widget get _buildList {
    return Column(
      children: [
        CenterGreyTitle(l10n.list),
        _buildSwitchTile(TfHistory.instance),
        _buildSwitchTile(TfHttpReq.instance),
        _buildSwitchTile(TfTerminal.instance),
        _buildSwitchTile(TfUrlLuancher.instance),
        _buildSwitchTile(TfDownloader.instance),
        _buildSwitchTile(TfFileManager.instance),
        _buildSwitchTile(TfWebBuilder.instance),

        _buildMemory(),
      ],
    );
  }

  Widget get _buildMcps {
    return Column(
      children: [
        CenterGreyTitle('MCP'),
        _buildAddMcpServer(),
        _buildMcpServers(),
      ],
    );
  }

  Widget _buildMemory() {
    return ExpandTile(
      title: Text(l10n.memory),
      children: [
        _buildSwitchTile(TfMemory.instance, title: l10n.switcher),
        ListTile(
          title: Text(libL10n.edit),
          onTap: () async {
            final data = _mcpStore.memories.get();
            final dataMap = <String, String>{};
            for (var idx = 0; idx < data.length; idx++) {
              dataMap['$idx'] = data[idx];
            }
            final res = await KvEditor.route.go(
              context,
              KvEditorArgs(data: dataMap),
            );
            if (res != null) {
              _mcpStore.memories.set(res.values.toList());
              context.showSnackBar(libL10n.success);
            }
          },
          trailing: const Icon(Icons.keyboard_arrow_right),
        ),
      ],
    ).cardx;
  }

  Widget _buildUseTool() {
    return ListTile(
      leading: const Icon(MingCute.tool_line),
      title: Text(l10n.switcher),
      trailing: StoreSwitch(prop: _mcpStore.enabled),
    ).cardx;
  }

  Widget _buildModelRegExp() {
    final prop = _mcpStore.mcpRegExp;
    final listenable = prop.listenable();
    return ListTile(
      leading: const Icon(Bootstrap.regex),
      title: TipText(l10n.regExp, l10n.modelRegExpTip),
      trailing: SizedBox(
        width: 60,
        child: listenable.listenVal(
          (val) => Text(
            val,
            style: UIs.textGrey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      onTap: () {
        final ctrl = TextEditingController(text: listenable.value);
        void onSave(String v) {
          prop.set(v);
          context.pop();
        }

        context.showRoundDialog(
          title: l10n.regExp,
          child: Input(
            controller: ctrl,
            maxLines: 3,
            autoFocus: true,
            onSubmitted: onSave,
          ),
          actions: Btn.ok(onTap: () => onSave(ctrl.text)).toList,
        );
      },
    ).cardx;
  }

  Widget _buildMcpServers() {
    return _mcpStore.mcpServers.listenable().listenVal((servers) {
      const maxRows = 7;
      const rowHeight = 56.0;
      final itemCount = servers.length;
      final visibleRows = itemCount < maxRows ? itemCount : maxRows;
      final height = visibleRows * rowHeight;
      return SizedBox(
        height: height,
        child: ListView.builder(
          itemCount: itemCount,
          itemBuilder: (ctx, idx) => _buildMcpServerItem(idx, servers),
        ),
      );
    }).cardx;
  }

  Widget _buildAddMcpServer() {
    return ListTile(
      leading: const Icon(Icons.add),
      title: Text(libL10n.add),
      onTap: () =>
          _onTapAddMcpServer(_mcpStore.mcpServers, _mcpStore.mcpServers.get()),
    ).cardx;
  }

  Widget _buildMcpServerItem(int idx, List<String> servers) {
    final url = servers[idx];
    final serverName = 'server_$idx';
    final isConnected = McpTools.isServerConnected(serverName);
    final toolCount = McpTools.getToolsFromServer(serverName).length;

    return Dismissible(
      key: ValueKey(url),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _onDeleteMcpServer(serverName, url);
        final newList = List<String>.from(servers)..removeAt(idx);
        _mcpStore.mcpServers.set(newList);
      },
      child: ListTile(
        leading: Icon(
          isConnected ? Icons.cloud_done : Icons.cloud_off,
          color: isConnected ? Colors.green : Colors.red,
        ),
        title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          isConnected ? 'Connected • $toolCount tools' : 'Disconnected',
          style: TextStyle(
            color: isConnected ? Colors.green : Colors.red,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isConnected)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _onRetryMcpServer(serverName),
                tooltip: 'Retry connection',
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await _onDeleteMcpServer(serverName, url);
                final newList = List<String>.from(servers)..removeAt(idx);
                _mcpStore.mcpServers.set(newList);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(ToolFunc e, {String? title}) {
    final prop = _mcpStore.disabledTools;
    return ValBuilder(
      listenable: prop.listenable(),
      builder: (vals) {
        final name = e.name;
        final tip = e.l10nTip;
        final titleW = tip != null
            ? TipText(title ?? e.l10nName, tip)
            : Text(title ?? e.l10nName);
        return ListTile(
          title: titleW,
          trailing: Switch(
            value: !vals.contains(name),
            onChanged: (val) {
              final _ = switch (val) {
                true => prop.set(vals..remove(name)),
                false => prop.set(vals..add(name)),
              };
            },
          ),
        );
      },
    ).cardx;
  }

  @override
  bool get wantKeepAlive => true;
}

extension on _McpPageState {
  void _onTapAddMcpServer(HivePropDefault prop, List<String> servers) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(libL10n.add),
        content: Input(
          controller: ctrl,
          autoFocus: true,
          hint: 'https://your-mcp-server',
          onSubmitted: context.pop,
        ),
        actions: [
          TextButton(onPressed: context.pop, child: Text(libL10n.cancel)),
          TextButton(
            onPressed: () => context.pop(ctrl.text),
            child: Text(libL10n.ok),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok == null) return;
    final url = ok.trim();
    if (url.isEmpty) return;

    await context.showLoadingDialog(
      fn: () async {
        final serverName = 'server_${servers.length}';
        final ts = McpTools.newHttpTs(url: url);
        final result = await McpTools.addTs(ts, serverName);
        if (result != null) {
          final newList = List<String>.from(servers)..add(url);
          prop.set(newList);
        } else {
          throw Exception('Failed to connect to MCP server');
        }
      },
    );
  }

  Future<void> _onDeleteMcpServer(String serverName, String url) async {
    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(libL10n.delete),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(libL10n.askContinue('${libL10n.delete} $url')),
              const SizedBox(height: 12),
              Text(serverName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(url, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                // Fallback text if your l10n doesn't provide this key
                'This action cannot be undone.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error, // destructive color
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(libL10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Show blocking progress indicator while deleting
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await McpTools.removeServer(serverName);

      // Dismiss progress dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Server removed')));
      }
    } catch (e, s) {
      Loggers.app.warning('Disconnect MCP server failed', e, s);

      // Dismiss progress dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove server')));
      }
    }
  }

  Future<void> _onRetryMcpServer(String serverName) async {
    try {
      await McpTools.retryConnection(serverName);
      context.showSnackBar('Retrying connection...');
    } catch (e, s) {
      Loggers.app.warning('Retry MCP server failed', e, s);
      context.showSnackBar('Retry failed: $e');
    }
  }
}

class McpServer {
  final String name;
  final String url;
  final String description;

  const McpServer({
    required this.name,
    required this.url,
    this.description = '',
  });
}

/// Default preset list (S1..S4) provided by the user
// Original file (assuming McpServer class is defined elsewhere)

// Don't forget to import your env.dart file

const List<McpServer> _defaultMcpPresets = [
  McpServer(
    name: 'DuckDuckGo Search Server',
    url:
        "https://server.smithery.ai/@OEvortex/ddg_search/mcp?api_key=b6c5b6d9-c2d3-444f-843c-27adafd1701b&profile=socialist-duck-7ALnWh",
    description:
        'About\nEnable web search capabilities through DuckDuckGo. Fetch and parse webpage content intelligently for enhanced LLM interaction.\n\nTools\nsearch\nSearch DuckDuckGo and return formatted results. Args: query: The search query string max_results: Maximum number of results to return (default: 10) ctx: MCP context for logging\n\nfetch_content\nFetch and parse content from a webpage URL. Args: url: The webpage URL to fetch content from ctx: MCP context for logging',
  ),
  McpServer(
    name: 'Toolbox',
    url:
        "https://server.smithery.ai/@smithery/toolbox/mcp?api_key=b6c5b6d9-c2d3-444f-843c-27adafd1701b&profile=socialist-duck-7ALnWh",
    description:
        'Toolbox dynamically finds MCPs in the Smithery registry based on your agent\'s need',
  ),
  McpServer(
    name: 'Parallel Web Search',
    url:
        "https://server.smithery.ai/@parallel/search/mcp?api_key=b6c5b6d9-c2d3-444f-843c-27adafd1701b&profile=socialist-duck-7ALnWh",
    description:
        '''Purpose: Perform web searches for a given objective and return results in an LLM-friendly format and with parameters tuned for LLMs.

Ideal Use Cases:

    For live queries that benefit from updated data from the web.
    When needing to gather information from multiple sources at once or gathering detailed information from a single source. Performance Benefits:
    Ability to handle complex queries more effectively.
    Controllability in output size and sources considered.

Examples:

    Performing a broad search on a topic with multiple facets.
    Enquiring about a specific detail on a topic.

How to use:
''',
  ),

  McpServer(
    name: "Fetch",
    url:
        "https://server.smithery.ai/@smithery-ai/fetch/mcp?api_key=b6c5b6d9-c2d3-444f-843c-27adafd1701b&profile=socialist-duck-7ALnWh",
    description: '''A simple tool that performs a fetch request to a webpage.

''',
  ),
];

/// Preset MCP servers widget
/// - Shows list of preset servers
/// - Each item has a copy button (left) that copies the server URL to clipboard
/// - Tapping the item shows details in a popup dialog
class McpPresetsWidget extends StatelessWidget {
  final List<McpServer> presets;
  final String title;

  const McpPresetsWidget({
    Key? key,
    this.presets = _defaultMcpPresets,
    this.title = 'MCP Presets',
  }) : super(key: key);

  void _copyUrl(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('URL copied to clipboard')));
  }

  Future<void> _showDetailsDialog(BuildContext context, McpServer s) {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(s.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('URL: ${s.url}'),
                const SizedBox(height: 12),
                Text('Description:', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(s.description.isEmpty ? '—' : s.description),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _copyUrl(context, s.url);
              },
              child: const Text('COPY URL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Replace this with your CenterGreyTitle if available
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: presets.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (ctx, idx) {
            final s = presets[idx];
            return ListTile(
              leading: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy URL',
                onPressed: () => _copyUrl(context, s.url),
              ),
              title: Text(s.name),
              subtitle: Text(
                s.url,
                style: const TextStyle(color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showDetailsDialog(context, s),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              dense: false,
              // Optionally show a small trailing icon to hint for details
              trailing: const Icon(Icons.keyboard_arrow_right),
            );
          },
        ),
      ],
    );
  }
}
