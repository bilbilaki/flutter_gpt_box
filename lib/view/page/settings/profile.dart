part of 'setting.dart';

final class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => _ProfilePageState();
}

final class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    ApiBalance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MultiList(
      children: [
        [CenterGreyTitle(l10n.chat), _buildChat()],
        [CenterGreyTitle(l10n.more), _buildMore()],
      ],
    );
  }

  static const refreshIcon = IconButton(
    onPressed: ApiBalance.refresh,
    icon: Icon(Icons.refresh),
  );

  Widget _buildBalance() {
    return ApiBalance.balance.listenVal((val) {
      return ListTile(
        leading: const Icon(Icons.account_balance_wallet),
        title: Text(l10n.balance),
        subtitle: Text(val.state ?? l10n.unsupported, style: UIs.text13Grey),
        trailing: val.loading ? CircularProgressIndicator() : refreshIcon,
      );
    });
  }

  Widget _buildChat() {
    return Cfg.vn.listenVal((cfg) {
      final children = [
        _buildSwitchCfg(cfg),
        _buildBalance(),
        _buildOpenAIKey(cfg.key),
        _buildOpenAIUrl(cfg.url),
        _buildOpenAIModels(cfg),
      ];
      return Column(children: children.map((e) => e.cardx).toList());
    });
  }

  Widget _buildMore() {
    return Cfg.vn.listenVal((cfg) {
      final children = [
        _buildQuickShare(),
        _buildPrompt(cfg.prompt),
        _buildHistoryLength(cfg.historyLen),
        //  _buildGenTitlePrompt(cfg.genTitlePrompt),
        //_buildFollowChatModel(),
      ];
      return Column(children: children.map((e) => e.cardx).toList());
    });
  }

  Widget _buildSwitchCfg(ChatConfig cfg) {
    return ListTile(
      leading: const Icon(Icons.switch_account),
      title: Text(l10n.profile),
      subtitle: Text(cfg.displayName, style: UIs.textGrey),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Delete
          if (!cfg.isDefault)
            Btn.icon(
              icon: const Icon(Icons.delete, size: 19),
              onTap: () {
                if (cfg.isDefault) return;
                context.showRoundDialog(
                  title: l10n.attention,
                  child: Text(l10n.delFmt(cfg.name, l10n.profile)),
                  actions: Btn.ok(
                    onTap: () {
                      Stores.config.delete(cfg.id);
                      context.pop();
                      if (cfg.id == cfg.id) {
                        Cfg.switchToDefault(context);
                      }
                    },
                    red: true,
                  ).toList,
                );
              },
            ),
          // Rename
          Btn.icon(
            icon: const Icon(Icons.edit, size: 19),
            onTap: () {
              final ctrl = TextEditingController(text: cfg.name);
              context.showRoundDialog(
                title: libL10n.edit,
                child: Input(
                  controller: ctrl,
                  label: libL10n.name,
                  autoFocus: true,
                ),
                actions: Btn.ok(
                  onTap: () {
                    final name = ctrl.text;
                    if (name.isEmpty) return;
                    final newCfg = cfg.copyWith(name: name);
                    newCfg.save();
                    Cfg.setTo(cfg: newCfg);
                    context.pop();
                  },
                ).toList,
              );
            },
          ),
          // Switch
          Btn.icon(
            icon: const Icon(OctIcons.arrow_switch, size: 19),
            onTap: () => Cfg.showPickProfileDialog(context),
          ),
          Btn.icon(
            icon: const Icon(Icons.add, size: 19),
            onTap: () async {
              final ctrl = TextEditingController();
              final ok = await context.showRoundDialog(
                title: libL10n.add,
                child: Input(
                  controller: ctrl,
                  label: libL10n.name,
                  autoFocus: true,
                ),
                actions: Btnx.oks,
              );
              if (ok != true) return;
              final clipboardData = await Pfs.paste();
              var (key, url) = ('', ChatConfigX.defaultUrl);
              if (clipboardData != null) {
                if (clipboardData.startsWith('https://')) {
                  url = clipboardData;
                } else if (clipboardData.startsWith('sk-')) {
                  key = clipboardData;
                }
              }
              final newCfg = Cfg.current.copyWith(
                id: shortid.generate(),
                name: ctrl.text,
                key: key,
                url: url,
              );
              newCfg.save();
              Cfg.setTo(cfg: newCfg);
            },
          ),
          Btn.icon(
            icon: const Icon(Icons.cloud_circle_outlined, size: 19),
            onTap: () =>
                _addVertexAIProfile(), // We will create this function next
          ),
        ],
      ),
    );
  }

  Widget _buildOpenAIKey(String val) {
    return ListTile(
      leading: const Icon(Icons.vpn_key),
      title: Text(l10n.secretKey),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 60),
        child: Text(
          val.isEmpty ? libL10n.empty : val,
          style: UIs.textGrey,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      onTap: () async {
        final ctrl = TextEditingController(text: val);
        final result = await context.showRoundDialog<String>(
          title: libL10n.edit,
          child: Input(
            controller: ctrl,
            hint: 'sk-xxx',
            maxLines: 3,
            autoFocus: true,
          ),
          actions: Btn.ok(onTap: () => context.pop(ctrl.text)).toList,
        );
        if (result == null) return;
        Cfg.setTo(cfg: Cfg.current.copyWith(key: result));
      },
    );
  }
  // Widget _buildOpenAISpeechModel() {
  //     final cfg = Cfg.current;
  //     final val = cfg.speechModel;
  //     return ListTile(
  //       leading: const Icon(Icons.speaker),
  //       title: Text(l10n.tts),
  //       trailing: const Icon(Icons.keyboard_arrow_right),
  //       subtitle: Text(val, style: UIs.text13Grey),
  //       onTap: () async {
  //         final model = await _showPickModelDialog(l10n.model, val);
  //         if (model != null) {
  //           Cfg.setTo(Cfg.current.copyWith(speechModel: model));
  //           _cfgRN.notify();
  //         }
  //       },
  //     );
  //   }

  //   Widget _buildOpenAITranscribeModel() {
  //     final cfg = OpenAICfg.current;
  //     final val = cfg.transcribeModel;
  //     return ListTile(
  //       leading: const Icon(Icons.transcribe),
  //       title: Text(l10n.stt),
  //       trailing: const Icon(Icons.keyboard_arrow_right),
  //       subtitle: Text(val, style: UIs.text13Grey),
  //       onTap: () async {
  //   final model = await _showPickModelDialog(l10n.model, val);
  //         if (model != null) {
  //           OpenAICfg.setTo(OpenAICfg.current.copyWith(transcribeModel: model));
  //           _cfgRN.notify();
  //         }
  //       },
  //     );
  //   }

  // Replace your old _addVertexAIProfile function with this new, much better one.

  Future<void> _addVertexAIProfile() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'us-central1');

    // Use StatefulBuilder to manage the state of the async call inside the dialog
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        // State for our dialog
        List<GoogleCloudProject>? projects;
        GoogleCloudProject? selectedProject;
        bool isLoading = true;
        String? errorMessage;

        // This is a common pattern for async operations in a dialog
        return StatefulBuilder(
          builder: (context, setState) {
            // Fetch projects only once
            if (projects == null && isLoading) {
              fetchUserGoogleCloudProjects()
                  .then((fetchedProjects) {
                    setState(() {
                      if (fetchedProjects.isNotEmpty) {
                        projects = fetchedProjects;
                        selectedProject =
                            projects!.first; // Pre-select the first one
                      } else {
                        projects = []; // Mark as loaded, but empty
                        errorMessage =
                            "No Google Cloud projects found or API not enabled.";
                      }
                      isLoading = false;
                    });
                  })
                  .catchError((e) {
                    setState(() {
                      errorMessage = "Error: ${e.toString()}";
                      isLoading = false;
                    });
                  });
            }

            Widget buildContent() {
              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (errorMessage != null) {
                return Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                );
              }
              if (projects!.isEmpty) {
                return const Text(
                  "No Google Cloud projects found for this account.",
                );
              }

              // --- THE UI WITH THE DROPDOWN ---
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Input(
                    controller: nameCtrl,
                    label: 'Profile Name',
                    hint: 'My Vertex AI Project',
                    autoFocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<GoogleCloudProject>(
                    value: selectedProject,
                    decoration: const InputDecoration(
                      labelText: 'Select Google Cloud Project',
                      border: OutlineInputBorder(),
                    ),
                    items: projects!.map((project) {
                      return DropdownMenuItem<GoogleCloudProject>(
                        value: project,
                        child: Text('${project.name} (${project.projectId})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProject = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Input(
                    controller: locationCtrl,
                    label: 'Location (Region)',
                    hint: 'us-central1',
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Add Vertex AI Profile'),
              content: buildContent(),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: (selectedProject == null || isLoading)
                      ? null
                      : () {
                          // The OK button logic
                          final newCfg = Cfg.current.copyWith(
                            id: shortid.generate(),
                            name: nameCtrl.text,

                            isVertex: true,
                            vertexProjectId: selectedProject!
                                .projectId, // Use the ID from the selected project
                            vertexLocation: locationCtrl.text,
                            url: 'vertex-ai-autogenerated',
                            key: 'google-oauth-token',
                          );
                          newCfg.save();
                          Cfg.setTo(cfg: newCfg);
                          Navigator.of(context).pop(); // Close the dialog
                        },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOpenAIUrl(String val) {
    return ListTile(
      leading: const Icon(Icons.link),
      title: const Text('URL'),
      trailing: Text(
        val.isEmpty ? libL10n.empty : val.replaceFirst(RegExp('https?://'), ''),
        style: UIs.text13Grey,
      ),
      onTap: () async {
        final ctrl = TextEditingController(text: val);
        String? result = await context.showRoundDialog<String>(
          title: libL10n.edit,
          child: Input(
            controller: ctrl,
            hint: ChatConfigX.defaultUrl,
            maxLines: 3,
            autoFocus: true,
          ),
          actions: Btn.ok(onTap: () => context.pop(ctrl.text)).toList,
        );
        if (result == null) return;
        if (result == "https://api.groq.com/openai/v1") {
          setState(() {
            result = "https://api.groq.com/openai/v1/chat/completions";
          });
        }
        if (result == "https://generativelanguage.googleapis.com/v1beta") {
          setState(() {
            result =
                "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";
          });
        }

        final isApiUrl = ChatConfigX.apiUrlReg.hasMatch(
          result ?? result.toString(),
        );

        final endsWithV1 = result?.endsWith('/v1') ?? false;
        final isGithubModels = result == Urls.githubModels;
        final showDialog = !isApiUrl && (!endsWithV1 && !isGithubModels);
        if (showDialog) {
          final sure = await context.showRoundDialog(
            title: l10n.attention,
            child: Text(l10n.apiUrlV1Tip),
            actions: Btnx.okReds,
          );
          if (sure != true) return;
        }

        Cfg.setTo(cfg: Cfg.current.copyWith(url: result ?? result.toString()));
      },
    );
  }

  Widget _buildOpenAIModels(ChatConfig cfg) {
    return Cfg.models.listen(() {
      return ExpandTile(
        leading: const Icon(Icons.model_training),
        title: Text(l10n.model),
        children: [
          _buildOpenAIChatModel(),
          _buildOpenAIImgModel(),
          _buildOpenAITaskerModel(),
          _buildOpenAIAlterModel(),
          _buildOpenAITranscribeModel(),
          _buildOpenAIVoiceModel(),
          _buildOpenAIWrkerModel(),
          // _buildOpenAISpeechModel(),
          // _buildOpenAITranscribeModel(),
        ],
      );
    });
  }

  Widget _buildOpenAIChatModel() {
    final cfg = Cfg.current;
    final val = cfg.model;
    return ListTile(
      leading: const Icon(Icons.chat),
      title: Text(l10n.model),
      trailing: Text(val, style: UIs.text13Grey),
      onTap: () {
        Cfg.showPickModelDialog(
          context,
          initial: val,
          onSelected: (model) {
            final newCfg = cfg.copyWith(model: model);
            Cfg.setTo(cfg: newCfg);
          },
        );
      },
    );
  }

  Widget _buildOpenAITaskerModel() {
    final cfg = Cfg.current;
    final val = cfg.imgModel;
    return ListTile(
      leading: const Icon(Icons.chat),
      title: Text('Tasker Administator Model'),
      trailing: Text(val ?? '', style: UIs.text13Grey),
      onTap: () {
        Cfg.showPickModelDialog(
          context,
          initial: val,
          onSelected: (model) {
            final newCfg = cfg.copyWith(imgModel: model);
            Cfg.setTo(cfg: newCfg);
          },
        );
      },
    );
  }

  Widget _buildOpenAIAlterModel() {
    final cfg = Cfg.current;
    final val = cfg.altrModel;
    return ListTile(
      leading: const Icon(Icons.chat),
      title: Text('Alternative Model'),
      trailing: Text(val ?? '', style: UIs.text13Grey),
      onTap: () {
        Cfg.showPickModelDialog(
          context,
          initial: val,
          onSelected: (model) {
            final newCfg = cfg.copyWith(altrModel: model);
            Cfg.setTo(cfg: newCfg);
          },
        );
      },
    );
  }

  Widget _buildOpenAIWrkerModel() {
    final cfg = Cfg.current;
    final val = cfg.wrkrModel;
    return ListTile(
      leading: const Icon(Icons.chat),
      title: Text('Tasker Worker Model'),
      trailing: Text(val ?? '', style: UIs.text13Grey),
      onTap: () {
        Cfg.showPickModelDialog(
          context,
          initial: val,
          onSelected: (model) {
            final newCfg = cfg.copyWith(wrkrModel: model);
            Cfg.setTo(cfg: newCfg);
          },
        );
      },
    );
  }

  Widget _buildOpenAITranscribeModel() {
    final cfg = Cfg.current;
    final val = cfg.trnscrbModel;
    return ListTile(
      leading: const Icon(Icons.chat),
      title: Text('Transcribe Model'),
      trailing: Text(val ?? '', style: UIs.text13Grey),
      onTap: () {
        Cfg.showPickModelDialog(
          context,
          initial: val,
          onSelected: (model) {
            final newCfg = cfg.copyWith(trnscrbModel: model);
            Cfg.setTo(cfg: newCfg);
          },
        );
      },
    );
  }

  Widget _buildOpenAIVoiceModel() {
    final cfg = Cfg.current;
    final val = cfg.audioModel;
    return ListTile(
      leading: const Icon(Icons.chat),
      title: Text('Voice Model'),
      trailing: Text(val ?? '', style: UIs.text13Grey),
      onTap: () {
        Cfg.showPickModelDialog(
          context,
          initial: val,
          onSelected: (model) {
            final newCfg = cfg.copyWith(audioModel: model);
            Cfg.setTo(cfg: newCfg);
          },
        );
      },
    );
  }

  Widget _buildOpenAIImgModel() {
    final cfg = Cfg.current;
    final val = cfg.imgModel ?? libL10n.empty;
    return ListTile(
      leading: const Icon(Icons.photo),
      title: Text(l10n.image),
      trailing: Text(val, style: UIs.text13Grey),
      onTap: () async {
        await Cfg.showPickModelDialog(
          context,
          initial: cfg.imgModel ?? '',
          onSelected: (model) {
            final newCfg = cfg.copyWith(imgModel: model);
            Cfg.setTo(cfg: newCfg);
          },
        );
      },
    );
  }

  // Widget _buildOpenAISpeechModel() {
  //   final cfg = OpenAICfg.current;
  //   final val = cfg.speechModel;
  //   return ListTile(
  //     leading: const Icon(Icons.speaker),
  //     title: Text(l10n.tts),
  //     trailing: const Icon(Icons.keyboard_arrow_right),
  //     subtitle: Text(val, style: UIs.text13Grey),
  //     onTap: () async {
  //       final model = await _showPickModelDialog(l10n.model, val);
  //       if (model != null) {
  //         Cfg.setTo(Cfg.current.copyWith(speechModel: model));
  //       }
  //     },
  //   );
  // }

  // Widget _buildOpenAITranscribeModel() {
  //   final cfg = OpenAICfg.current;
  //   final val = cfg.transcribeModel;
  //   return ListTile(
  //     leading: const Icon(Icons.transcribe),
  //     title: Text(l10n.stt),
  //     trailing: const Icon(Icons.keyboard_arrow_right),
  //     subtitle: Text(val, style: UIs.text13Grey),
  //     onTap: () async {
  // final model = await _showPickModelDialog(l10n.model, val);
  //       if (model != null) {
  //         Cfg.setTo(Cfg.current.copyWith(transcribeModel: model));
  //         Cfg.vn.notify();
  //       }
  //     },
  //   );
  // }
  // profile.dart (snippet)
  Widget _buildPrompt(String val) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.abc),
          title: Text(l10n.promptsSettingsItem),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60, maxHeight: 100),
            child: Text(
              val.isEmpty ? libL10n.empty : val,
              style: UIs.textGrey,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: () async {
            final ctrl = TextEditingController(text: val);
            final result = await context.showRoundDialog<String>(
              title: libL10n.edit,
              child: Input(controller: ctrl, maxLines: 11, autoFocus: true),
              actions: Btn.ok(onTap: () => context.pop(ctrl.text)).toList,
              titleBuilder: (ctx) => IconButton(
                tooltip: 'Prompt generator',
                onPressed: () async {
                  await _navigateToAdvancedPromptPage(context);
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
              ),
            );
            if (result == null) return;
            Cfg.setTo(cfg: Cfg.current.copyWith(prompt: result));
          },
        ),
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: Text(l10n.promptsSettingsItem),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: Text(
              val.isEmpty ? libL10n.empty : val,
              style: UIs.textGrey,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: () async {
            final ctrl = TextEditingController(text: val);
            final result = await showDialog<String>(
              context: context,
              builder: (ctx) => PromptGeneratorDialog(
                onPromptGenerated: (gen) {
                  if (gen.isEmpty) return;
                  final cur = ctrl.text;
                  inputCtrl.text = cur.isEmpty ? gen : '$cur\n$gen';
                  inputCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: inputCtrl.text.length),
                  );
                },
              ),
            );
            if (result == null) return;
            Cfg.setTo(cfg: Cfg.current.copyWith(prompt: result));
          },
        ),
      ],
    );
  }

  Future<void> _navigateToAdvancedPromptPage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      _fadeRoute(PromptGeneratorScreen()),
    ); // Replace AnotherPage with your desired page
  }

  Route<T> _fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim.drive(CurveTween(curve: Curves.easeInOut)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      opaque: true,
      fullscreenDialog: true,
    );
  }
  // void _openPromptGenerator() {
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => PromptGeneratorDialog(
  //       onPromptGenerated: (gen) {
  //         if (gen.isEmpty) return;
  //         final cur = inputCtrl.text;
  //         inputCtrl.text = cur.isEmpty ? gen : '$cur\n$gen';
  //         inputCtrl.selection = TextSelection.fromPosition(
  //           TextPosition(offset: inputCtrl.text.length),
  //         );
  //       },
  //     ),
  //   );
  // }
  // Widget _buildGenTitlePrompt(String? val) {
  //   return ListTile(
  //     leading: const Icon(Icons.title),
  //     title: Text('${l10n.promptsSettingsItem}(${l10n.genTitle})'),
  //     trailing: Text(val ?? libL10n.empty, style: UIs.textGrey),
  //     onTap: () async {
  //       final ctrl = TextEditingController(text: val);
  //       final result = await context.showRoundDialog<String>(
  //         title: libL10n.edit,
  //         child: Input(controller: ctrl, maxLines: 11, autoFocus: true),
  //         actions: Btn.ok(onTap: () => context.pop(ctrl.text)).toList,
  //       );
  //       if (result == null) return;
  //       Cfg.setTo(cfg: Cfg.current.copyWith(genTitlePrompt: result));
  //     },
  //   );
  // }

  Widget _buildHistoryLength(int val) {
    return ListTile(
      leading: const Icon(Icons.history),
      title: TipText(l10n.chatHistoryLength, l10n.chatHistoryTip),
      trailing: Text(val.toString(), style: UIs.text13Grey),
      onTap: () async {
        final ctrl = TextEditingController(text: val.toString());
        final result = await context.showRoundDialog<String>(
          title: libL10n.edit,
          child: Input(
            controller: ctrl,
            hint: '7',
            autoFocus: true,
            type: TextInputType.number,
          ),
          actions: Btn.ok(onTap: () => context.pop(ctrl.text)).toList,
        );
        if (result == null) return;
        final newVal = int.tryParse(result);
        if (newVal == null) {
          context.showSnackBar('Invalid number: $result');
          return;
        }
        Cfg.setTo(cfg: Cfg.current.copyWith(historyLen: newVal));
      },
    );
  }

  Widget _buildQuickShare() {
    return ListTile(
      leading: const Icon(Icons.share),
      title: TipText(libL10n.share, l10n.quickShareTip),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        final url = Cfg.current.shareUrl;
        if (url.isEmpty) return;
        Pfs.shareStr(url);
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  // Widget _buildFollowChatModel() {
  //   return ListTile(
  //     leading: const Icon(OctIcons.arrow_switch, size: 21),
  //     title: Text(l10n.followChatModel),
  //     trailing: StoreSwitch(prop: Stores.config.followModel),
  //   );
  // }
}
