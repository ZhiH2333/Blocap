import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/note.dart';
import '../services/storage_service.dart';
import '../models/comment.dart';
import '../main.dart' show EditorPage; // 直接复用已有编辑页

// 只读笔记页面：展示创建时间/标题/副标题与 Markdown 内容
class NoteReaderPage extends StatefulWidget {
  const NoteReaderPage({super.key, required this.note});
  final Note note;

  @override
  State<NoteReaderPage> createState() => _NoteReaderPageState();
}

class _NoteReaderPageState extends State<NoteReaderPage> {
  late Note _note;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            tooltip: '信息',
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final beforeId = _note.id;
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EditorPage(note: _note),
              ));
              // 返回后从存储刷新该笔记
              final refreshed = StorageService.instance
                  .getNotes(status: 'all')
                  .firstWhere((n) => n.id == beforeId, orElse: () => _note);
              setState(() => _note = refreshed);
            },
          ),
        ],
      ),
      body: ListView(
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
          // Description：独立 summary 字段，为空则不显示
          Builder(builder: (_) {
            final firstLine = _note.summary.trim();
            if (firstLine.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(firstLine, style: Theme.of(context).textTheme.bodyLarge),
            );
          }),
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
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: MarkdownBody(
                    data: _note.content.replaceAll('\n', '  \n'),
                    selectable: true,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 8),
          Text('Replies', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_note.comments.isEmpty)
            Text('No replies yet. Why not start a discussion?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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

          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Post your reply',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _addComment(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.send), onPressed: _addComment),
          ]),
        ),
      ),
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
            Text('Words: ${_note.content.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length}') ,
            Text('Characters: ${_note.content.length}'),
            Text('Creation: ${_note.createdAt}'),
            Text('Modified: ${_note.updatedAt}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final newComment = Comment(id: 'c_${DateTime.now().millisecondsSinceEpoch}', text: text, timestamp: DateTime.now());
    final updated = _note.copyWith(comments: [..._note.comments, newComment], updatedAt: DateTime.now());
    await StorageService.instance.upsert(updated);
    setState(() {
      _note = updated;
      _commentController.clear();
    });
  }

  Future<void> _deleteComment(Comment c) async {
    final updated = _note.copyWith(comments: _note.comments.where((e) => e.id != c.id).toList(), updatedAt: DateTime.now());
    await StorageService.instance.upsert(updated);
    setState(() => _note = updated);
  }

  Future<void> _editComment(Comment c, String newText) async {
    final list = _note.comments.map((e) => e.id == c.id ? Comment(id: c.id, text: newText, timestamp: c.timestamp) : e).toList();
    final updated = _note.copyWith(comments: list, updatedAt: DateTime.now());
    await StorageService.instance.upsert(updated);
    setState(() => _note = updated);
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({required this.comment, required this.onEdit, required this.onDelete});
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
    final time = '${_two(c.timestamp.month)} ${_two(c.timestamp.day)}, ${_two(c.timestamp.hour)}:${_two(c.timestamp.minute)}';
    return GestureDetector(
      onTapDown: (d) => _tapPosition = d.globalPosition,
      onLongPress: _showMenu,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
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
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(value: 'edit', child: Row(children: const [Icon(Icons.edit_outlined), SizedBox(width: 12), Text('Edit')])),
        PopupMenuItem(value: 'delete', child: Row(children: const [Icon(Icons.delete_outline), SizedBox(width: 12), Text('Delete')])),
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
          content: TextField(controller: controller, autofocus: true, minLines: 1, maxLines: 4),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
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


