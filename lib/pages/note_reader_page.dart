import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/note.dart';
import '../models/comment.dart';
import '../services/storage_service.dart';
import '../main.dart' show EditorPage; // reuse editor page
import '../l10n/app_localizations.dart';

/// Note reader with two-page UX:
/// - Page 0: shows note content only
/// - Page 1: shows replies only, with a Post Reply button and input
class NoteReaderPage extends StatefulWidget {
  const NoteReaderPage({super.key, required this.note});
  final Note note;

  @override
  State<NoteReaderPage> createState() => _NoteReaderPageState();
}

class _NoteReaderPageState extends State<NoteReaderPage> {
  late Note _note;

  final PageController _pageController = PageController();
  int _pageIndex = 0;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.note),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.more_info,
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final beforeId = _note.id;
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EditorPage(note: _note),
              ));
              // Refresh from storage (in case of edit)
              final refreshed = StorageService.instance
                  .getNotes(status: 'all')
                  .firstWhere((n) => n.id == beforeId, orElse: () => _note);
              setState(() => _note = refreshed);
            },
          ),
        ],
      ),
      // Gesture to dismiss keyboard when tapping blank areas
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: [
                // Page 0: Note content only
                _buildContentPage(context),
                // Page 1: Replies only
                _buildRepliesPage(context),
              ],
            ),
            // Floating two-dot indicator — moved to top-right of the page
            Positioned(
              top: 12,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // animated dot 1
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: _pageIndex == 0 ? 1.0 : 0.9,
                          end: _pageIndex == 0 ? 1.0 : 0.9),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        final active = _pageIndex == 0;
                        return Transform.scale(
                          scale: active ? 1.12 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            width: active ? 14 : 12,
                            height: active ? 14 : 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha((0.28 * 255).round()),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    // animated dot 2
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: _pageIndex == 1 ? 1.0 : 0.9,
                          end: _pageIndex == 1 ? 1.0 : 0.9),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        final active = _pageIndex == 1;
                        return Transform.scale(
                          scale: active ? 1.12 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            width: active ? 14 : 12,
                            height: active ? 14 : 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha((0.28 * 255).round()),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Show reply input only on replies page; AnimatedPadding avoids keyboard overlap
      bottomNavigationBar: _pageIndex == 1
          ? AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.write_reply,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        icon: const Icon(Icons.send), onPressed: _addComment),
                  ]),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContentPage(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _note.createdAt.toIso8601String().split('T').first,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_note.title.isNotEmpty)
          Text(_note.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (_note.summary.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withAlpha((0.6 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_note.summary.trim(),
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        if (_note.content.isNotEmpty) const SizedBox(height: 8),
        if (_note.content.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withAlpha((0.5 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MarkdownBody(
                    data: _note.content.replaceAll('\n', '  \n'),
                    selectable: true),
              ),
            ),
          ),
        const SizedBox(height: 12),
        const SizedBox(height: 68),
      ],
    );
  }

  Widget _buildRepliesPage(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.replies,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox.shrink(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _note.comments.isEmpty
              ? Center(
                  child: Text(AppLocalizations.of(context)!.no_replies,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).hintColor)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _note.comments.length,
                  itemBuilder: (_, i) {
                    final c = _note.comments[i];
                    return _CommentCard(
                      comment: c,
                      onEdit: (text) => _editComment(c, text),
                      onDelete: () => _deleteComment(c),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('More Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Words: ${_note.content.trim().split(RegExp(r"\\\\s+")).where((e) => e.isNotEmpty).length}'),
            Text('Characters: ${_note.content.length}'),
            Text('Creation: ${_note.createdAt}'),
            Text('Modified: ${_note.updatedAt}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('关闭'))
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final newComment = Comment(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        timestamp: DateTime.now());
    final updated = _note.copyWith(
        comments: [..._note.comments, newComment], updatedAt: DateTime.now());
    await StorageService.instance.upsert(updated);
    setState(() {
      _note = updated;
      _commentController.clear();
    });
  }

  Future<void> _deleteComment(Comment c) async {
    final updated = _note.copyWith(
        comments: _note.comments.where((e) => e.id != c.id).toList(),
        updatedAt: DateTime.now());
    await StorageService.instance.upsert(updated);
    setState(() => _note = updated);
  }

  Future<void> _editComment(Comment c, String newText) async {
    final list = _note.comments
        .map((e) => e.id == c.id
            ? Comment(id: c.id, text: newText, timestamp: c.timestamp)
            : e)
        .toList();
    final updated = _note.copyWith(comments: list, updatedAt: DateTime.now());
    await StorageService.instance.upsert(updated);
    setState(() => _note = updated);
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard(
      {required this.comment, required this.onEdit, required this.onDelete});
  final Comment comment;
  final Future<void> Function(String newText) onEdit;
  final Future<void> Function() onDelete;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  Offset? _tapPosition;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final time =
        '${_two(c.timestamp.month)} ${_two(c.timestamp.day)}, ${_two(c.timestamp.hour)}:${_two(c.timestamp.minute)}';
    return GestureDetector(
      onTapDown: (d) => _tapPosition = d.globalPosition,
      onLongPress: _showMenu,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withAlpha((0.6 * 255).round()),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.05 * 255).round()),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(time, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(c.text, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
    );
  }

  void _showMenu() async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = _tapPosition ?? overlay.size.center(Offset.zero);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withAlpha((0.9 * 255).round()),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 12),
              Text('Edit')
            ])),
        const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 12),
              Text('Delete')
            ])),
      ],
    );
    if (!mounted) return;
    if (selected == 'delete') {
      await widget.onDelete();
    } else if (selected == 'edit') {
      final controller = TextEditingController(text: widget.comment.text);
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Edit'),
          content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 4),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      );
      if (ok == true) {
        await widget.onEdit(controller.text.trim());
      }
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
