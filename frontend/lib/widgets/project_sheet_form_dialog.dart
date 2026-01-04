import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';

/// Диалог формы создания/редактирования проектного листа
class ProjectSheetFormDialog extends StatefulWidget {
  final ProjectSheetModel? sheet;
  final ProjectModel project;
  final VoidCallback? onRefresh;

  const ProjectSheetFormDialog({
    super.key,
    this.sheet,
    required this.project,
    this.onRefresh,
  });

  @override
  State<ProjectSheetFormDialog> createState() => _ProjectSheetFormDialogState();
}

class _ProjectSheetFormDialogState extends State<ProjectSheetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  StatusModel? _selectedStatus;
  List<StatusModel> _statuses = [];
  DepartmentModel? _selectedDepartment;
  List<DepartmentModel> _departments = [];
  bool _isCompleted = false;
  bool _isLoading = false;
  bool _isLoadingStatuses = true;
  bool _isLoadingDepartments = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    if (widget.sheet != null) {
      _nameController.text = widget.sheet!.name ?? '';
      _descriptionController.text = widget.sheet!.description ?? '';
      _selectedDepartment = widget.sheet!.responsibleDepartment;
      _isCompleted = widget.sheet!.isCompleted;
    }
    _loadCurrentUser();
    _loadStatuses();
    _loadDepartments();
  }

  /// Загрузка текущего пользователя
  Future<void> _loadCurrentUser() async {
    final user = await ApiService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUserId = user['id'] as int?;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Загрузка статусов
  Future<void> _loadStatuses() async {
    final result = await ApiService.getStatuses(statusType: 'sheet');
    if (mounted && result['success'] == true) {
      setState(() {
        _statuses = (result['data'] as List)
            .map((s) => StatusModel.fromJson(s as Map<String, dynamic>))
            .toList();
        _isLoadingStatuses = false;
        // Устанавливаем выбранный статус только после загрузки списка
        if (widget.sheet?.statusId != null && _statuses.isNotEmpty) {
          try {
            _selectedStatus = _statuses.firstWhere(
              (s) => s.id == widget.sheet!.statusId,
            );
          } catch (e) {
            // Если статус не найден, оставляем null
            _selectedStatus = null;
          }
        }
      });
    } else {
      setState(() {
        _isLoadingStatuses = false;
      });
    }
  }

  /// Загрузка отделов
  Future<void> _loadDepartments() async {
    final result = await ApiService.getDepartments();
    if (mounted && result['success'] == true) {
      final data = result['data'] as List;
      setState(() {
        _departments = data
            .map((d) => DepartmentModel.fromJson(d as Map<String, dynamic>))
            .toList();
        _isLoadingDepartments = false;
        // Устанавливаем выбранный отдел только после загрузки списка
        if (widget.sheet?.responsibleDepartmentId != null && _departments.isNotEmpty) {
          try {
            _selectedDepartment = _departments.firstWhere(
              (d) => d.id == widget.sheet!.responsibleDepartmentId,
            );
          } catch (e) {
            // Если отдел не найден, оставляем null
            _selectedDepartment = null;
          }
        }
      });
    } else {
      setState(() {
        _isLoadingDepartments = false;
      });
    }
  }

  /// Удаление листа
  Future<void> _deleteSheet() async {
    if (widget.sheet == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Удаление листа',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Вы уверены, что хотите удалить этот лист? Это действие нельзя отменить.',
          style: TextStyle(color: AppColors.textSecondary),
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

      final result = await ApiService.deleteProjectSheet(widget.sheet!.id);

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
                content: Text('Лист удален'),
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

  /// Сохранение листа
  Future<void> _saveSheet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final data = {
      'project_id': widget.project.id,
      'name': _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      if (_selectedStatus != null) 'status_id': _selectedStatus!.id,
      if (_selectedDepartment != null) 'responsible_department_id': _selectedDepartment!.id,
      'is_completed': _isCompleted,
    };

    Map<String, dynamic> result;
    if (widget.sheet == null) {
      result = await ApiService.createProjectSheet(data);
    } else {
      result = await ApiService.updateProjectSheet(widget.sheet!.id, data);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        Navigator.pop(context, result);
        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
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

  /// Проверка прав на изменение статуса выполнения
  bool _canToggleCompleted() {
    if (widget.sheet == null) return false;
    if (_currentUserId == null) return false;
    
    // Проверяем created_by_id или created_by.id
    final createdById = widget.sheet!.createdById ?? widget.sheet!.createdBy?.id;
    if (createdById == null) return false;
    
    return _currentUserId == createdById;
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
                  widget.sheet == null
                      ? 'Создание листа'
                      : 'Редактирование листа',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                // Информация о проекте
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
                        Icons.folder,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Проект: ${widget.project.name}',
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
                    labelText: 'Название',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Выбор статуса
                if (_isLoadingStatuses)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  DropdownButtonFormField<StatusModel>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Статус',
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: _statuses.map((status) {
                      return DropdownMenuItem<StatusModel>(
                        value: status,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _parseColor(status.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(status.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                // Выбор ответственного отдела
                if (_isLoadingDepartments)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  DropdownButtonFormField<DepartmentModel>(
                    value: _selectedDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Ответственный отдел',
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: [
                      const DropdownMenuItem<DepartmentModel>(
                        value: null,
                        child: Text('Не выбрано'),
                      ),
                      ..._departments.map((dept) {
                        return DropdownMenuItem<DepartmentModel>(
                          value: dept,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _parseColor(dept.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(dept.name),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDepartment = value;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                // Чекбокс "Выполнено"
                if (widget.sheet != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isCompleted,
                          onChanged: (_canToggleCompleted())
                              ? (value) {
                                  setState(() {
                                    _isCompleted = value ?? false;
                                  });
                                }
                              : null,
                          activeColor: AppColors.accentGreen,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Выполнено',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!_canToggleCompleted())
                                const Text(
                                  'Только инициатор листа может изменить статус выполнения',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.sheet != null) ...[
                      TextButton.icon(
                        onPressed: _isLoading ? null : _deleteSheet,
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
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveSheet,
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

  /// Парсинг цвета из HEX строки
  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', '0xFF')));
    } catch (e) {
      return AppColors.textSecondary;
    }
  }
}

