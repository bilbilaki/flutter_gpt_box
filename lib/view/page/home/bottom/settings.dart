part of '../home.dart';

final class _ChatSettings extends StatefulWidget {
  final ChatHistory args;

  const _ChatSettings({Key? key, required this.args});

  static const route = AppRouteArg(
    page: _ChatSettings.new,
    path: '/chat_settings',
  );

  @override
  State<_ChatSettings> createState() => _ChatSettingsState();
}

final class _ChatSettingsState extends State<_ChatSettings> {
  late final settings = (widget.args.settings ?? const ChatSettings()).vn;
  final _mcpStore = Stores.mcp;

  @override
  Widget build(BuildContext context) {
    final items = [
      _buildIgnoreCtxConstraint(),
      _buildUseTools(),
      _buildHeadTailMode(),
      SizedBox(child: _buildList),
    ];

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('${libL10n.setting} - ${widget.args.name}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _save();
          context.pop();
        },
        child: const Icon(Icons.save),
      ),
      body: ListView(
        children: items
            .map((e) => e.cardx.paddingSymmetric(vertical: 1, horizontal: 7))
            .toList(),
      ),
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
        _buildSwitchTile(TfWebBuilder.instance),

        _buildMemory(),
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

  Widget _buildIgnoreCtxConstraint() {
    return ListTile(
      title: Text(l10n.ignoreContextConstraint),
      trailing: settings.listenVal((val) {
        return Switch(
          value: val.ignoreContextConstraint,
          onChanged: (_) {
            settings.value = settings.value.copyWith(
              ignoreContextConstraint: !val.ignoreContextConstraint,
            );
            if (settings.value.headTailMode &&
                settings.value.ignoreContextConstraint) {
              settings.value = settings.value.copyWith(headTailMode: false);
            }
          },
        );
      }),
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

  Widget _buildUseTools() {
    return ListTile(
      title: Text(l10n.tool),
      trailing: settings.listenVal((val) {
        return Switch(
          value: val.useTools,
          onChanged: (_) {
            settings.value = settings.value.copyWith(useTools: !val.useTools);
          },
        );
      }),
    );
  }

  Widget _buildUseTool() {
    return ListTile(
      leading: const Icon(MingCute.tool_line),
      title: Text(l10n.switcher),
      trailing: StoreSwitch(prop: _mcpStore.enabled),
    ).cardx;
  }

  Widget _buildHeadTailMode() {
    return ListTile(
      title: TipText(l10n.headTailMode, l10n.headTailModeTip),
      trailing: settings.listenVal((val) {
        return Switch(
          value: val.headTailMode,
          onChanged: (_) {
            settings.value = settings.value.copyWith(
              headTailMode: !val.headTailMode,
            );
            if (settings.value.headTailMode &&
                settings.value.ignoreContextConstraint) {
              settings.value = settings.value.copyWith(
                ignoreContextConstraint: false,
              );
            }
          },
        );
      }),
    );
  }

  void _save() {
    final newOne = widget.args.copyWith(settings: settings.value);
    newOne.save();
    allHistories[_curChatId.value] = newOne;
  }
}
