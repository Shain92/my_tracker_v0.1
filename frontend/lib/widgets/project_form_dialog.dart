import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';

/// Диалог формы создания/редактирования проекта
class ProjectFormDialog extends StatefulWidget {
  final ProjectModel? project;
  final ConstructionSiteModel constructionSite;
  final VoidCallback? onRefresh;

  const ProjectFormDialog({
    super.key,
    this.project,
    required this.constructionSite,
    this.onRefresh,
  });

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  final _cipherController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _descriptionController.text = widget.project!.description ?? '';
      _codeController.text = widget.project!.code;
      _cipherController.text = widget.project!.cipher;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    _cipherController.dispose();
    super.dispose();
  }

  /// Удаление проекта
  Future<void> _deleteProject() async {
    if (widget.project == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Удаление проекта',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Вы уверены, что хотите удалить проект "${widget.project!.name}"? Это действие нельзя отменить.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPink,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isLoading = true;
      });

      final result = await ApiService.deleteProject(widget.project!.id);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          Navigator.pop(context, {'success': true, 'deleted': true});
          if (widget.onRefresh != null) {
            widget.onRefresh!();
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Проект удален'),
                backgroundColor: AppColors.accentGreen,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Ошибка удаления'),
              backgroundColor: AppColors.accentPink,
            ),
          );
        }
      }
    }
  }

  /// Сохранение проекта
  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final code = _codeController.text.trim();
    final cipher = _cipherController.text.trim();

    final data = {
      'name': name,
      'description': description.isEmpty ? null : description,
      'code': code,
      'cipher': cipher,
      'construction_site_id': widget.constructionSite.id,
    };

    Map<String, dynamic> result;
    if (widget.project == null) {
      // Создание нового проекта
      result = await ApiService.createProject(data);
    } else {
      // Обновление существующего проекта
      result = await ApiService.updateProject(widget.project!.id, data);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        Navigator.pop(context, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка сохранения'),
            backgroundColor: AppColors.accentPink,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.project == null
                      ? 'Создание проекта'
                      : 'Редактирование проекта',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                // Информация о строительном участке (только для чтения)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.borderColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.construction,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Участок: ${widget.constructionSite.name}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название *',
                    prefixIcon: Icon(Icons.folder),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Название обязательно';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Код *',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Код обязателен';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cipherController,
                  decoration: const InputDecoration(
                    labelText: 'Шифр *',
                    prefixIcon: Icon(Icons.code),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Шифр обязателен';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Кнопка удаления (только при редактировании) - слева
                    if (widget.project != null) ...[
                      TextButton.icon(
                        onPressed: _isLoading ? null : _deleteProject,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Удалить'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentPink,
                        ),
                      ),
                      const Spacer(),
                    ] else ...[
                      const Spacer(),
                    ],
                    // Остальные кнопки справа
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProject,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

