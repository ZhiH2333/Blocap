import 'comment.dart';
// 笔记模型：负责数据结构与 JSON 序列化
// 状态：active(正常)、draft(草稿)、archived(归档)、deleted(删除)

class Note {
  final String id; // 唯一 ID（字符串，便于 JSON 与文件名）
  String title; // 标题
  String content; // Markdown 内容
  String summary; // 描述/副标题
  List<String> tags; // 关键字
  List<Comment> comments; // 评论列表
  String status; // 状态：active/draft/archived/deleted
  DateTime createdAt; // 创建时间
  DateTime updatedAt; // 修改时间

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.tags,
    required this.comments,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // 工具：从 JSON 创建 Note
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      comments: (json['comments'] as List<dynamic>? ?? [])
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // 工具：转 JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'summary': summary,
        'tags': tags,
        'comments': comments.map((e) => e.toJson()).toList(),
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  // 复制并修改（便于更新）
  Note copyWith({
    String? title,
    String? content,
    String? summary,
    List<String>? tags,
    List<Comment>? comments,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      comments: comments ?? this.comments,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


