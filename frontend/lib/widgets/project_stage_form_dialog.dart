import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';
import 'user_autocomplete_field.dart';

/// Диалог формы создания/редактирования этапа проекта
class ProjectStageFormDialog extends StatefulWidget {
  final ProjectStageModel? stage;
  final ProjectModel project;
  final VoidCallback? onRefresh;

  const ProjectStageFormDialog({
    super.key,
    this.stage,
    required this.project,
    this.onRefresh,
  });

  @override
  State<ProjectStageFormDialog> createState() => _ProjectStageFormDialogState();
}

class _ProjectStageFormDialogState extends State<ProjectStageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  StatusModel? _selectedStatus;
  List<StatusModel> _statuses = [];
  List<UserModel> _selectedResponsibleUsers = [];
  bool _isLoading = false;
  bool _isLoadingStatuses = true;

  @override
  void initState() {
    super.initState();
    if (widget.stage != null) {
      _descriptionController.text = widget.stage!.description ?? '';
      _selectedDateTime = widget.stage!.datetime;
      _selectedResponsibleUsers = widget.stage!.responsibleUsers ?? [];
    }
    _loadStatuses();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Загрузка статусов
  Future<void> _loadStatuses() async {
    final result = await ApiService.getStatuses(statusType: 'stage');
    if (mounted && result['success'] == true) {
      setState(() {
        _statuses = (result['data'] as List)
            .map((s) => StatusModel.fromJson(s as Map<String, dynamic>))
            .toList();
        _isLoadingStatuses = false;
        // Устанавливаем выбранный статус только после загрузки списка
        if (widget.stage?.statusId != null && _statuses.isNotEmpty) {
          try {
            _selectedStatus = _statuses.firstWhere(
              (s) => s.id == widget.stage!.statusId,
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

  /// Удаление этапа
  Future<void> _deleteStage() async {
    if (widget.stage == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Удаление этапа',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Вы уверены, что хотите удалить этот этап? Это действие нельзя отменить.',
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

      final result = await ApiService.deleteProjectStage(widget.stage!.id);

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
                content: Text('Этап удален'),
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

  /// Сохранение этапа
  Future<void> _saveStage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final currentUser = await ApiService.getCurrentUser();
    final userId = currentUser?['id'] as int?;

    final data = {
      'project_id': widget.project.id,
      'datetime': _selectedDateTime.toIso8601String(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      if (_selectedStatus != null) 'status_id': _selectedStatus!.id,
      if (userId != null) 'author_id': userId,
      if (_selectedResponsibleUsers.isNotEmpty)
        'responsible_user_ids': _selectedResponsibleUsers.map((u) => u.id).toList(),
    };

    Map<String, dynamic> result;
    if (widget.stage == null) {
      result = await ApiService.createProjectStage(data);
    } else {
      result = await ApiService.updateProjectStage(widget.stage!.id, data);
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

  /// Выбор даты и времени
  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentBlue,
              onPrimary: AppColors.textPrimary,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.accentBlue,
                onPrimary: AppColors.textPrimary,
                surface: AppColors.cardBackground,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
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
                  widget.stage == null
                      ? 'Создание этапа'
                      : 'Редактирование этапа',
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
                // Выбор даты и времени
                InkWell(
                  onTap: _selectDateTime,
                  child: Container(
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
                        const Icon(
                          Icons.calendar_today,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Дата и время *',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_selectedDateTime.day.toString().padLeft(2, '0')}.${_selectedDateTime.month.toString().padLeft(2, '0')}.${_selectedDateTime.year} ${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
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
                // Выбор ответственных лиц
                UserAutocompleteField(
                  selectedUsers: _selectedResponsibleUsers,
                  onUsersChanged: (users) {
                    setState(() {
                      _selectedResponsibleUsers = users;
                    });
                  },
                  labelText: 'Ответственные лица',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.stage != null) ...[
                      TextButton.icon(
                        onPressed: _isLoading ? null : _deleteStage,
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
                      onPressed: _isLoading ? null : _saveStage,
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

