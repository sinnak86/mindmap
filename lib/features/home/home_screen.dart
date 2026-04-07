import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/mind_map.dart';
import '../../models/mind_folder.dart';
import '../../models/node_style.dart';
import '../canvas/canvas_screen.dart';
import 'home_notifier.dart';

// ── Folder name length: Korean=2 units, others=1, max=16 units (~8 Korean / ~16 English)
class _FolderNameFormatter extends TextInputFormatter {
  static const int _maxUnits = 16;

  static int _units(String text) {
    int u = 0;
    for (final r in text.runes) {
      u += (r >= 0xAC00 && r <= 0xD7A3) ? 2 : 1;
    }
    return u;
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    if (_units(next.text) <= _maxUnits) return next;
    return old;
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final notifier = ref.read(homeProvider.notifier);
    final focusedFolder = homeState.focusedFolderId != null
        ? homeState.folders
            .where((f) => f.id == homeState.focusedFolderId)
            .firstOrNull
        : null;

    final allMaps = homeState.mindMaps.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final visibleMaps = focusedFolder != null
        ? allMaps.where((m) => m.folderId == focusedFolder.id).toList()
        : allMaps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Mind Maps'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _onMenuSelected(context, ref, value, focusedFolder),
            itemBuilder: (_) => _buildMenuItems(homeState, focusedFolder),
          ),
        ],
      ),
      body: homeState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Folders ───────────────────────────────────────────────
                if (homeState.folders.isNotEmpty) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: homeState.folders.map((folder) {
                      return _FolderTile(
                        folder: folder,
                        isFocused: homeState.focusedFolderId == folder.id,
                        onTap: () => notifier.toggleFolderFocus(folder.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    thickness: 2,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                ],
                // ── Maps ──────────────────────────────────────────────────
                if (visibleMaps.isEmpty)
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

  // ── Menu ──────────────────────────────────────────────────────────────────

  List<PopupMenuEntry<String>> _buildMenuItems(
      HomeState state, MindFolder? focusedFolder) {
    if (focusedFolder != null) {
      return [
        const PopupMenuItem(value: 'rename', child: Text('폴더명 변경')),
        const PopupMenuItem(value: 'color', child: Text('폴더 색상 변경')),
        if (focusedFolder.name != '기본')
          const PopupMenuItem(
            value: 'delete',
            child: Text('폴더 삭제', style: TextStyle(color: Colors.red)),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'create_folder',
          enabled: state.folders.length < HomeNotifier.maxFolders,
          child: Text(
            '폴더생성 (${state.folders.length}/${HomeNotifier.maxFolders})',
          ),
        ),
      ];
    }
    return [
      PopupMenuItem(
        value: 'create_folder',
        enabled: state.folders.length < HomeNotifier.maxFolders,
        child: Text(
          '폴더생성 (${state.folders.length}/${HomeNotifier.maxFolders})',
        ),
      ),
    ];
  }

  void _onMenuSelected(BuildContext context, WidgetRef ref, String value,
      MindFolder? focusedFolder) {
    switch (value) {
      case 'create_folder':
        _showCreateFolderDialog(context, ref);
      case 'rename':
        if (focusedFolder != null) {
          _showRenameFolderDialog(context, ref, focusedFolder);
        }
      case 'color':
        if (focusedFolder != null) {
          _showColorPickerDialog(context, ref, focusedFolder);
        }
      case 'delete':
        if (focusedFolder != null) {
          _confirmDeleteFolder(context, ref, focusedFolder);
        }
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더생성'),
        content: TextField(
          controller: controller,
          autofocus: true,
          inputFormatters: [_FolderNameFormatter()],
          decoration: const InputDecoration(
            labelText: '폴더 이름',
            hintText: '한글 최대 8자 / 영문 최대 16자',
          ),
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

  void _showRenameFolderDialog(
      BuildContext context, WidgetRef ref, MindFolder folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더명 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          inputFormatters: [_FolderNameFormatter()],
          decoration: const InputDecoration(
            labelText: '새 폴더 이름',
            hintText: '한글 최대 8자 / 영문 최대 16자',
          ),
          onSubmitted: (_) => _renameFolder(ctx, ref, folder.id, controller.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () =>
                  _renameFolder(ctx, ref, folder.id, controller.text),
              child: const Text('변경')),
        ],
      ),
    );
  }

  void _renameFolder(
      BuildContext context, WidgetRef ref, String id, String name) {
    if (name.trim().isEmpty) return;
    Navigator.of(context).pop();
    ref.read(homeProvider.notifier).renameFolder(id, name.trim());
  }

  void _showColorPickerDialog(
      BuildContext context, WidgetRef ref, MindFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더 색상 변경'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: NodeStyle.presetColors.map((colorValue) {
              final isSelected = folder.colorValue == colorValue;
              return GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref
                      .read(homeProvider.notifier)
                      .updateFolderColor(folder.id, colorValue);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(colorValue),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Color(colorValue).withAlpha(80),
                        blurRadius: isSelected ? 12 : 4,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
        ],
      ),
    );
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

  // ── Navigation ────────────────────────────────────────────────────────────

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
          .push(MaterialPageRoute(
              builder: (_) => CanvasScreen(mindMap: mindMap)))
          .then((_) => ref.read(homeProvider.notifier).loadAll());
    }
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
}

// ── Compact Folder Tile ───────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final MindFolder folder;
  final bool isFocused;
  final VoidCallback onTap;

  const _FolderTile({
    required this.folder,
    required this.isFocused,
    required this.onTap,
  });

  /// Returns a color with sufficient contrast against a very light background.
  Color _accentColor() {
    if (folder.colorValue != null) {
      final base = Color(folder.colorValue!);
      final lum = base.computeLuminance();
      // If too light (e.g. yellow), darken it so it's visible on a white-ish bg
      if (lum > 0.5) {
        final hsl = HSLColor.fromColor(base);
        return hsl.withLightness(0.35).toColor();
      }
      return base;
    }
    return isFocused ? const Color(0xFF007AFF) : Colors.amber.shade700;
  }

  Color _bgColor() {
    if (folder.colorValue != null) {
      return Color(folder.colorValue!).withAlpha(22);
    }
    return isFocused ? const Color(0xFFF0F6FF) : Colors.amber.shade50;
  }

  Color _tabColor() {
    if (folder.colorValue != null) {
      return Color(folder.colorValue!).withAlpha(55);
    }
    return isFocused
        ? const Color(0xFF007AFF).withAlpha(55)
        : Colors.amber.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab (decorative, no text)
          Container(
            width: 44,
            height: 9,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: _tabColor(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(10),
              ),
            ),
          ),
          // Body
          _GradientBorderBox(
            isActive: isFocused,
            accentColor: accent,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Container(
              width: 90,
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              decoration: BoxDecoration(
                color: _bgColor(),
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
                    color: accent,
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
                      fontWeight:
                          isFocused ? FontWeight.w700 : FontWeight.w500,
                      color: accent,
                    ),
                  ),
                ],
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
  final Color accentColor;
  final BorderRadius borderRadius;

  const _GradientBorderBox({
    required this.child,
    required this.isActive,
    required this.accentColor,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
              color: accentColor.withAlpha(80), width: 1),
        ),
        child: child,
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, Color.lerp(accentColor, const Color(0xFF5856D6), 0.5)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(70),
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
