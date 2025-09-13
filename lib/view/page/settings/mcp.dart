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
    return AutoMultiList(children: [_buildTools, _buildMcps,_presetMcpExample, _buildList]);
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
      children: [
        CenterGreyTitle("MCP Presets"),
       McpPresetsWidget(
       ),
      ],
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
        _buildSwitchTile(TfSMSSender.instance),
        _buildSwitchTile(TfDownloader.instance),
        _buildSwitchTile(TfPdfManager.instance),
        _buildSwitchTile(TfFileManager.instance),
        _buildSwitchTile(TfZipManager.instance),
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
      onTap: () => _onTapAddMcpServer(
        _mcpStore.mcpServers,
        _mcpStore.mcpServers.get(),
      ),
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
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server removed')),
      );
    }
  } catch (e, s) {
    Loggers.app.warning('Disconnect MCP server failed', e, s);

    // Dismiss progress dialog
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove server')),
      );
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
    url: duckDuckGoServerUrl,
    description:
        'About\nEnable web search capabilities through DuckDuckGo. Fetch and parse webpage content intelligently for enhanced LLM interaction.\n\nTools\nsearch\nSearch DuckDuckGo and return formatted results. Args: query: The search query string max_results: Maximum number of results to return (default: 10) ctx: MCP context for logging\n\nfetch_content\nFetch and parse content from a webpage URL. Args: url: The webpage URL to fetch content from ctx: MCP context for logging',
  ),
  McpServer(
    name: 'YouTube Toolbox',
    url: youtubeToolboxServerUrl,
    description:
        'About\nProvide AI assistants with powerful tools to interact with YouTube, including video searching, transcript extraction, comment retrieval, and more. Enable advanced filtering, detailed video and channel information, trending video discovery, and transcript analysis. Enhance AI capabilities with comprehensive YouTube data access and summarization features.\n\nTools\nsearch_videos\nget_video_details\nget_channel_details\nget_video_comments\nget_video_transcript\nget_related_videos\nget_trending_videos\nget_video_enhanced_transcript\n(etc.)',
  ),
  McpServer(
    name: 'Movie Recommender',
    url: movieRecommenderServerUrl,
    description:
        'About\nProvide personalized movie recommendations based on user preferences and viewing history. Enhance user experience by suggesting relevant movies tailored to individual tastes. Enable seamless integration of movie data and recommendation logic into applications.\n\nTools\nget_movies\nGet movie suggestions based on keyword.',
  ),
  McpServer(
    name: 'Bright Data',
    url: brightDataServerUrl,
    description:
        'About\nOne MCP for the Web. Easily search, crawl, navigate, and extract websites without getting blocked. Ideal for discovering and retrieving structured insights from any public source - effortlessly and ethically.\n\nTools\nsearch_engine\nscrape_as_markdown\nscrape_as_html\nextract\n(plus many more advanced scraping and web data tools)',
  ),
  McpServer(
      name: 'Hugging Face MCP Server',
      url: huggingFaceServerUrl,
      description: '''About
Access Hugging Face's models, datasets, and research papers seamlessly. Interact with a wide range of resources and tools to enhance your LLM's capabilities. Utilize prompt templates for efficient model comparisons and paper summaries.

Tools


search-models
Search for models on Hugging Face Hub

get-model-info
Get detailed information about a specific model

search-datasets
Search for datasets on Hugging Face Hub

get-dataset-info
Get detailed information about a specific dataset

search-spaces
Search for Spaces on Hugging Face Hub
get-space-info
Get detailed information about a specific Space

get-paper-info
Get information about a specific paper on Hugging Face

get-daily-papers
Get the list of daily papers curated by Hugging Face

search-collections
Search for collections on Hugging Face Hub

get-collection-info
Get detailed information about a specific collection'''),
  McpServer(
      name: "PubChem Data Access Server",
      url: pubChemServerUrl,
      description: '''About
Provide seamless access to PubChem chemical and bioassay data through a standardized MCP interface. Search compounds, retrieve detailed chemical and bioassay information, and query molecular properties to enhance your chemical data workflows. Integrate effortlessly with any MCP client to enrich your applications with comprehensive PubChem data.

Tools
search_compound
Search for compounds by name, CID, or other identifiers. Args: query: The search query (compound name, CID, SMILES, etc.) max_results: Maximum number of results to return (default: 10) Returns: Dictionary with search results

get_compound_details
Get detailed information about a specific compound by its PubChem CID. Args: cid: PubChem Compound ID (CID) Returns: Dictionary with compound details

get_compound_properties
Get physical and chemical properties of a compound. Args: cid: PubChem Compound ID (CID) Returns: Dictionary with compound properties

search_bioassay
Search for bioassays related to a compound or target. Args: query: Search query (compound name, target name, etc.) max_results: Maximum number of results to return (default: 5) Returns: Dictionary with bioassay search results

get_substance_details
Get detailed information about a specific substance by its PubChem SID. Args: sid: PubChem Substance ID (SID) Returns: Dictionary with substance details
'''),
  McpServer(
      name: "Crypto Research Server",
      url: cryptoResearchServerUrl,
      description: '''About
Provide a specialized MCP server that enables integration with cryptocurrency research data and tools. Facilitate access to crypto-related resources and operations to enhance LLM applications with up-to-date blockchain and crypto insights. Empower users to leverage crypto data seamlessly within their AI workflows.

Tools
research_get_projects
Search for projects on Research knowledge base.

research_get_project_by_twitter
Get project details by Twitter username on Research knowledge base.

research_get_project_reports_by_twitter
Get project reports by Twitter username on Research knowledge base.

research_search_reports
Search for reports on Research knowledge base.

research_search_news
Search for news on Research knowledge base.'''),
  McpServer(
      name: "PubMed Article Search and Analysis Server",
      url: pubMedServerUrl,
      description: '''Enable AI assistants to search, access, and analyze biomedical literature from PubMed through a simple MCP interface. Perform keyword and advanced searches, retrieve detailed metadata, download full-text PDFs, and conduct deep paper analysis to support biomedical research. Facilitate efficient and comprehensive exploration of scientific articles programmatically.

Tools
search_pubmed_key_words
search_pubmed_advanced
get_pubmed_article_metadata
download_pubmed_pdf
'''),
  McpServer(
      name: "OpenAI Agent Library",
      url: openAIAgentLibraryServerUrl,
      description: '''Enhance your applications with powerful language model capabilities. Integrate seamlessly with external data and tools to create intelligent agents that can perform complex tasks. Empower your projects with dynamic interactions and real-world data manipulation.

Tools

1 / 3

search_docs
Search for a specific term across OpenAI Agents SDK documentation.

search_github
Search for a specific term across the GitHub repository.

get_section
Get a specific section from a documentation page.

search_files
Search for files by name across the GitHub repository. Args: filename_pattern: Part of the filename to search for. Can be a full filename or a partial name. Returns: JSON array of matching files with their paths and URLs.

get_code_examples
Get code examples related to a specific OpenAI Agents SDK topic.
get_api_docs
Get API documentation for a specific class or function in the OpenAI Agents SDK.

get_github_file
Get content of a specific file from the GitHub repository.

get_doc_index
Get the index of all OpenAI Agents SDK documentation pages.

get_doc
Get content of a specific documentation page.

list_github_structure
List the structure of the GitHub repository.


run_diagnostics
Run diagnostics to check the health of the OpenAI Agents SDK documentation and GitHub repository.

''')
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL copied to clipboard')),
    );
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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