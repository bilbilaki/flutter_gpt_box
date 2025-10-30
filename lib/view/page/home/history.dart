part of 'home.dart';

class _HistoryPage extends StatefulWidget {
  const _HistoryPage();

  @override
  State<StatefulWidget> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _buildBody,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _curPage,
        builder: (_, page, _) => page.fab,
      ),
    );
  }

  Widget get _buildBody {
    return CustomScrollView(
      controller: _historyScrollCtrl,
      slivers: [
        _buildTrash,
        _buildHisotry,
      ],
    );
  }

  Widget get _buildTrash {
    return Stores.trash.historiesVN.listenVal((vals) {
      if (vals.isEmpty) return SliverToBoxAdapter(child: UIs.placeholder);
      return SliverPersistentHeader(
        delegate: _TrashSheetHeader(),
      );
    });
  }

  Widget get _buildHisotry {
    return _historyRN.listen(() {
      final folders = _allFolders.value.values.toList();
      final chatsWithoutFolder = allHistories.entries
          .where((e) => e.value.folderId == null)
          .toList();
      
      // Sort: pinned first, then by time
      chatsWithoutFolder.sort((a, b) {
        final aPinned = a.value.isPinned ?? false;
        final bPinned = b.value.isPinned ?? false;
        
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        
        final now = DateTime.now();
        final aTime = a.value.items.lastOrNull?.createdAt ?? now;
        final bTime = b.value.items.lastOrNull?.createdAt ?? now;
        return bTime.compareTo(aTime);
      });

      final List<Widget> items = [];

      // Add folder management button
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () => _onCreateFolder(context),
            icon: const Icon(Icons.create_new_folder, size: 18),
            label: const Text('New Folder'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),
      );

      // Add folders with their chats
      for (final folder in folders) {
        final folderChats = allHistories.entries
            .where((e) => e.value.folderId == folder.id)
            .toList();
        
        // Sort folder chats
        folderChats.sort((a, b) {
          final aPinned = a.value.isPinned ?? false;
          final bPinned = b.value.isPinned ?? false;
          
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;
          
          final now = DateTime.now();
          final aTime = a.value.items.lastOrNull?.createdAt ?? now;
          final bTime = b.value.items.lastOrNull?.createdAt ?? now;
          return bTime.compareTo(aTime);
        });

        items.add(_buildFolderHeader(folder, folderChats.length));
        
        if (folder.isExpanded ?? true) {
          for (final entry in folderChats) {
            items.add(_buildHistoryListItem(entry.key).cardx);
          }
        }
      }

      // Add chats without folder
      if (chatsWithoutFolder.isNotEmpty) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Text(
              'Uncategorized',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        );
        
        for (final entry in chatsWithoutFolder) {
          items.add(_buildHistoryListItem(entry.key).cardx);
        }
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 11),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => items[index],
            childCount: items.length,
          ),
        ),
      );
    });
  }

  Widget _buildFolderHeader(ChatFolder folder, int chatCount) {
    return ListenableBuilder(
      listenable: _allFolders,
      builder: (context, _) {
        return ListTile(
          leading: Icon(
            folder.isExpanded ?? true
                ? Icons.folder_open
                : Icons.folder,
            color: folder.colorIndicator != null
                ? _getColorFromString(folder.colorIndicator!)
                : null,
          ),
          title: Text(
            '${folder.name} ($chatCount)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  folder.isExpanded ?? true
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                ),
                onPressed: () => _onToggleFolderExpanded(folder.id),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 19),
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _onRenameFolder(folder.id, context);
                      break;
                    case 'duplicate':
                      _onDuplicateFolder(folder.id, context);
                      break;
                    case 'delete':
                      _onDeleteFolder(folder.id, context);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(BoxIcons.bx_rename, size: 18),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.content_copy, size: 18),
                        SizedBox(width: 8),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () => _onToggleFolderExpanded(folder.id),
        );
      },
    );
  }

  Color? _getColorFromString(String colorStr) {
    switch (colorStr) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      default:
        return null;
    }
  }

  Widget _buildHistoryListItem(String chatId) {
    final entity = allHistories[chatId];
    if (entity == null) return UIs.placeholder;

    // Get color indicator
    Color? indicatorColor;
    if (entity.colorIndicator != null) {
      switch (entity.colorIndicator) {
        case 'red':
          indicatorColor = Colors.red;
          break;
        case 'orange':
          indicatorColor = Colors.orange;
          break;
        case 'yellow':
          indicatorColor = Colors.yellow;
          break;
        case 'green':
          indicatorColor = Colors.green;
          break;
        case 'blue':
          indicatorColor = Colors.blue;
          break;
        case 'purple':
          indicatorColor = Colors.purple;
          break;
        case 'pink':
          indicatorColor = Colors.pink;
          break;
      }
    }

    return Container(
      decoration: indicatorColor != null
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: indicatorColor, width: 4),
              ),
            )
          : null,
      child: ListTile(
        leading: entity.isPinned == true
            ? const Icon(Icons.push_pin, size: 18)
            : null,
        title: Text(
          entity.name ?? l10n.untitled,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text15,
        ),
        subtitle: ListenBuilder(
          listenable: _timeRN,
          builder: () {
            final len = '${entity.items.length} ${l10n.message}';
            final time = entity.items.lastOrNull?.createdAt
                .difference(DateTime.now())
                .toAgoStr;
            if (time == null) return Text(len, style: UIs.textGrey);
            return Text(
              '$len · $time',
              style: UIs.text13Grey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        contentPadding: const EdgeInsets.only(left: 17, right: 15),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 19),
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    _onTapRenameChat(chatId, context);
                    break;
                  case 'clone':
                    _onCloneChat(chatId, context);
                    break;
                  case 'pin':
                    _onTogglePinChat(chatId, context);
                    break;
                  case 'color':
                    _onSetColorIndicator(chatId, context);
                    break;
                  case 'folder':
                    _onMoveToFolder(chatId, context);
                    break;
                  case 'delete':
                    _onTapDeleteChat(chatId, context);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      const Icon(BoxIcons.bx_rename, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.rename),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clone',
                  child: const Row(
                    children: [
                      Icon(Icons.content_copy, size: 18),
                      SizedBox(width: 8),
                      Text('Clone'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        entity.isPinned == true
                            ? Icons.push_pin_outlined
                            : Icons.push_pin,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(entity.isPinned == true ? 'Unpin' : 'Pin'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'color',
                  child: Row(
                    children: [
                      Icon(Icons.color_lens, size: 18),
                      SizedBox(width: 8),
                      Text('Set Color'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'folder',
                  child: Row(
                    children: [
                      Icon(Icons.folder, size: 18),
                      SizedBox(width: 8),
                      Text('Move to Folder'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Fns.throttle(
            () {
              _switchChat(chatId);
              if (!_isDesktop.value && _curPage.value != HomePageEnum.chat) {
                _switchPage(HomePageEnum.chat);
              }
            },
            id: 'history_item',
            duration: 70,
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
