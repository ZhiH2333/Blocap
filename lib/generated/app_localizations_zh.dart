// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get capsule => 'Capsule';

  @override
  String get search_hint => '搜索...';

  @override
  String get new_item => '新建';

  @override
  String get settings => '设置';

  @override
  String get statistics => '统计信息';

  @override
  String get font_size => '字体大小';

  @override
  String get background_image => '背景图片';

  @override
  String get export_notes => '导出笔记';

  @override
  String get about => '关于';

  @override
  String get summary => '统计';

  @override
  String get notes => '笔记';

  @override
  String get this_year => '今年';

  @override
  String get preview => '预览：';

  @override
  String get title_preview => '标题预览 123';

  @override
  String get body_preview => '正文预览';

  @override
  String get options => '选项';

  @override
  String get choose_image => '选择图片';

  @override
  String get no_background => '暂无背景图片';

  @override
  String get language => '语言';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get replies => '回复';

  @override
  String get write_reply => '写回复...';

  @override
  String get no_replies => '暂无回复，试试开启讨论吧';

  @override
  String get content => '内容';

  @override
  String get title => '标题';

  @override
  String get description => '描述';

  @override
  String get search => '搜索';

  @override
  String get new_note => '新建';

  @override
  String get restore => '恢复';

  @override
  String get delete_permanently => '永久删除';

  @override
  String get archive => '归档';

  @override
  String get unarchive => '取消归档';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get note => '笔记';

  @override
  String get more_info => '更多信息';

  @override
  String get close => '关闭';

  @override
  String get words => '词数';

  @override
  String get characters => '字符数';

  @override
  String get creation => '创建时间';

  @override
  String get modified => '修改时间';

  @override
  String get no_notes_selected => '未选中笔记';

  @override
  String get include_comments => '包含评论';

  @override
  String get include_comments_sub => '启用后，评论将被包含在导出文件中。';

  @override
  String get exported_notes => '已导出的笔记';

  @override
  String get export_selected_notes => '导出所选笔记';

  @override
  String get untitled => '未命名';

  @override
  String get untitled_note => '未命名笔记';

  @override
  String get clear => '清除';

  @override
  String get about_description => '一个极简的 Material 3 笔记应用。';

  @override
  String get editing_existing_note => '您正在编辑一个已存在的笔记';

  @override
  String get month_initials => '一,二,三,四,五,六,七,八,九,十,十一,十二';

  @override
  String search_results(Object count) {
    return '$count 条结果';
  }

  @override
  String search_match_snippet(Object snippet) {
    return '匹配片段：\"$snippet\"';
  }
}
