import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 新規プロジェクト作成ダイアログ
///
/// プロジェクト名、説明、保存場所を入力してプロジェクトを作成
class NewProjectDialog extends ConsumerStatefulWidget {
  const NewProjectDialog({super.key});

  @override
  ConsumerState<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends ConsumerState<NewProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _authorController = TextEditingController();
  String? _savePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initDefaultPath();
  }

  Future<void> _initDefaultPath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    setState(() {
      _savePath = p.join(documentsDir.path, 'FieldPlanner');
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新規プロジェクト'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // プロジェクト名
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'プロジェクト名 *',
                  hintText: '例：○○イベント会場',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'プロジェクト名を入力してください';
                  }
                  // ファイル名として使用できない文字をチェック
                  final invalidChars = RegExp(r'[<>:"/\\|?*]');
                  if (invalidChars.hasMatch(value)) {
                    return '使用できない文字が含まれています';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 説明
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明',
                  hintText: 'プロジェクトの説明（オプション）',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // 作成者
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: '作成者',
                  hintText: '作成者名（オプション）',
                ),
              ),
              const SizedBox(height: 16),

              // 保存場所
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '保存場所',
                      ),
                      child: Text(
                        _savePath ?? '読み込み中...',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: _selectSavePath,
                    tooltip: 'フォルダを選択',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createProject,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('作成'),
        ),
      ],
    );
  }

  Future<void> _selectSavePath() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _savePath = result;
      });
    }
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate() || _savePath == null) {
      return;
    }

    setState(() => _isLoading = true);

    final result = NewProjectResult(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      author: _authorController.text.trim().isEmpty
          ? null
          : _authorController.text.trim(),
      savePath: _savePath!,
    );

    Navigator.of(context).pop(result);
  }
}

/// 新規プロジェクト作成結果
class NewProjectResult {
  final String name;
  final String? description;
  final String? author;
  final String savePath;

  NewProjectResult({
    required this.name,
    this.description,
    this.author,
    required this.savePath,
  });
}
