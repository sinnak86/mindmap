import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/mind_map.dart';
import '../../models/mind_folder.dart';
import '../canvas/canvas_screen.dart';
import 'home_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Mind Maps'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'create_folder') {
                _showCreateFolderDialog(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'create_folder', child: Text('폴더생성')),
            ],
          ),
        ],
      ),
      body: homeState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : homeState.folders.isEmpty && homeState.mindMaps.isEmpty
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildTree(context, ref, homeState, null, 0),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Map'),
      ),
    );
  }

  // ── Tree builder ────────────────────────────────────────────────────────────
  List<Widget> _buildTree(
    BuildContext context,
    WidgetRef ref,
    HomeState state,
    String? parentId,
    int depth,
  ) {
    final widgets = <Widget>[];
    final notifier = ref.read(homeProvider.notifier);
    final foldersAtLevel =
        state.folders.where((f) => f.parentId == parentId).toList();

    for (final folder in foldersAtLevel) {
      final isFocused = state.focusedFolderId == folder.id;
      final mapsInFolder = state.mindMaps
          .where((m) => m.folderId == folder.id)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // Children (maps + subfolders) collected first
      final childWidgets = <Widget>[];
      for (final map in mapsInFolder) {
        childWidgets.add(
          _MindMapCard(
            mindMap: map,
            onTap: () => _openCanvas(context, ref, map),
            onDelete: () => notifier.deleteMindMap(map.id),
          ),
        );
      }
      childWidgets.addAll(
          _buildTree(context, ref, state, folder.id, depth + 1));

      // Folder tile
      widgets.add(
        _FolderTile(
          folder: folder,
          isFocused: isFocused,
          onTap: () => notifier.toggleFolderFocus(folder.id),
          onDelete: () => _confirmDeleteFolder(context, ref, folder),
        ),
      );

      // Children wrapped with hierarchy line
      if (childWidgets.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Vertical connecting line
                  Container(
                    width: 2,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isFocused
                              ? const Color(0xFF007AFF)
                              : Colors.amber.shade400,
                          (isFocused
                                  ? const Color(0xFF007AFF)
                                  : Colors.amber.shade400)
                              .withAlpha(40),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: childWidgets,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No mind maps yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Tap the button below to create your first mind map'),
        ],
      ),
    );
  }

  void _openCanvas(BuildContext context, WidgetRef ref, MindMap mindMap) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CanvasScreen(mindMap: mindMap)))
        .then((_) => ref.read(homeProvider.notifier).loadAll());
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Mind Map'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'e.g. Project Ideas',
          ),
          onSubmitted: (_) => _create(ctx, ref, controller.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _create(ctx, ref, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
  }

  Future<void> _create(
      BuildContext context, WidgetRef ref, String title) async {
    if (title.trim().isEmpty) return;
    Navigator.of(context).pop();
    final mindMap =
        await ref.read(homeProvider.notifier).createMindMap(title.trim());
    if (context.mounted) {
      Navigator.of(context)
          .push(
              MaterialPageRoute(builder: (_) => CanvasScreen(mindMap: mindMap)))
          .then((_) => ref.read(homeProvider.notifier).loadAll());
    }
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더생성'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '폴더 이름'),
          onSubmitted: (_) => _createFolder(ctx, ref, controller.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => _createFolder(ctx, ref, controller.text),
              child: const Text('생성')),
        ],
      ),
    );
  }

  void _createFolder(BuildContext context, WidgetRef ref, String name) {
    if (name.trim().isEmpty) return;
    Navigator.of(context).pop();
    ref.read(homeProvider.notifier).createFolder(name.trim());
  }

  void _confirmDeleteFolder(
      BuildContext context, WidgetRef ref, MindFolder folder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('폴더 삭제'),
        content: Text('"${folder.name}" 폴더와 포함된 모든 맵을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(homeProvider.notifier).deleteFolder(folder.id);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── Folder Tile ───────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final MindFolder folder;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FolderTile({
    required this.folder,
    required this.isFocused,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isFocused ? const Color(0xFF007AFF) : Colors.amber.shade600;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Folder tab (top-left bump) ──────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(isFocused ? 25 : 30),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: accentColor.withAlpha(80), width: 1),
                  left:
                      BorderSide(color: accentColor.withAlpha(80), width: 1),
                  right:
                      BorderSide(color: accentColor.withAlpha(80), width: 1),
                ),
              ),
              child: Text(
                folder.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            // ── Folder body ─────────────────────────────────────────────────
            _GradientBorderBox(
              isActive: isFocused,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isFocused
                      ? const Color(0xFFF0F6FF)
                      : Colors.amber.shade50,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(
                      isFocused
                          ? Icons.folder_open_rounded
                          : Icons.folder_rounded,
                      color: accentColor,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        folder.name,
                        style: TextStyle(
                          fontWeight: isFocused
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 15,
                          color: isFocused
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                    if (isFocused)
                      Icon(Icons.check_circle,
                          size: 16,
                          color: const Color(0xFF007AFF).withAlpha(180)),
                    if (folder.name != '기본')
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: onDelete,
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gradient Border Box ───────────────────────────────────────────────────────

class _GradientBorderBox extends StatelessWidget {
  final Widget child;
  final bool isActive;
  final BorderRadius borderRadius;

  const _GradientBorderBox({
    required this.child,
    required this.isActive,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: Colors.amber.shade300, width: 1),
        ),
        child: child,
      );
    }
    // Gradient border: outer gradient container, inner content
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withAlpha(60),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(borderRadius.topRight.x - 2),
          bottomLeft: Radius.circular(borderRadius.bottomLeft.x - 2),
          bottomRight: Radius.circular(borderRadius.bottomRight.x - 2),
        ),
        child: child,
      ),
    );
  }
}

// ── MindMap Card ──────────────────────────────────────────────────────────────

class _MindMapCard extends StatelessWidget {
  final MindMap mindMap;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MindMapCard({
    required this.mindMap,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(mindMap.updatedAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_tree,
              color: Color(0xFF007AFF), size: 20),
        ),
        title: Text(mindMap.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${mindMap.nodes.length} nodes · $dateStr',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: IconButton(
          icon:
              const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          onPressed: () => _confirmDelete(context),
        ),
        onTap: onTap,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Mind Map'),
        content: Text('Delete "${mindMap.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
