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
    final notifier = ref.read(homeProvider.notifier);

    // Maps to show: filtered by focused folder, or all maps
    final allMaps = homeState.mindMaps.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final visibleMaps = homeState.focusedFolderId != null
        ? allMaps
            .where((m) => m.folderId == homeState.focusedFolderId)
            .toList()
        : allMaps;

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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Folders section ─────────────────────────────────────────
                if (homeState.folders.isNotEmpty) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: homeState.folders.map((folder) {
                      return _FolderTile(
                        folder: folder,
                        isFocused: homeState.focusedFolderId == folder.id,
                        onTap: () =>
                            notifier.toggleFolderFocus(folder.id),
                        onDelete: () =>
                            _confirmDeleteFolder(context, ref, folder),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                ],

                // ── Maps section ────────────────────────────────────────────
                if (visibleMaps.isEmpty && !homeState.isLoading)
                  _buildEmptyMaps(context)
                else
                  ...visibleMaps.map((map) => _MindMapCard(
                        mindMap: map,
                        onTap: () => _openCanvas(context, ref, map),
                        onDelete: () => notifier.deleteMindMap(map.id),
                      )),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Map'),
      ),
    );
  }

  Widget _buildEmptyMaps(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('맵이 없습니다',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          ],
        ),
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

// ── Compact Folder Tile ───────────────────────────────────────────────────────

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
    final bgColor =
        isFocused ? const Color(0xFFF0F6FF) : Colors.amber.shade50;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Folder shape
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab (decorative only, no text)
              Container(
                width: 44,
                height: 9,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(isFocused ? 60 : 50),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(10),
                  ),
                ),
              ),
              // Body with gradient border when focused
              _GradientBorderBox(
                isActive: isFocused,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Container(
                  width: 90,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(11),
                      bottomLeft: Radius.circular(11),
                      bottomRight: Radius.circular(11),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFocused
                            ? Icons.folder_open_rounded
                            : Icons.folder_rounded,
                        color: accentColor,
                        size: 32,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        folder.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isFocused
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isFocused
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF1C1C1E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Delete button (top-right, only for non-기본 folders)
          if (folder.name != '기본')
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
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
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${mindMap.nodes.length} nodes · $dateStr',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              color: Colors.redAccent, size: 20),
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
