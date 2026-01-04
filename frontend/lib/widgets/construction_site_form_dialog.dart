import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';

/// Диалог формы создания/редактирования строительного участка
class ConstructionSiteFormDialog extends StatefulWidget {
  final ConstructionSiteModel? constructionSite;
  final VoidCallback? onRefresh;

  const ConstructionSiteFormDialog({
    super.key,
    this.constructionSite,
    this.onRefresh,
  });

  @override
  State<ConstructionSiteFormDialog> createState() => _ConstructionSiteFormDialogState();
}

class _ConstructionSiteFormDialogState extends State<ConstructionSiteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingUsers = false;
  List<UserModel> _users = [];
  int? _selectedManagerId;

  @override
  void initState() {
    super.initState();
    if (widget.constructionSite != null) {
      _nameController.text = widget.constructionSite!.name;
      _descriptionController.text = widget.constructionSite!.description ?? '';
      _selectedManagerId = widget.constructionSite!.managerId;
    }
    _loadUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Загрузка списка пользователей из отдела "Начальник участка"
  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    // Загружаем всех пользователей
    final usersResult = await ApiService.getUsers();
    
    if (mounted) {
      setState(() {
        _isLoadingUsers = false;
        if (usersResult['success'] == true) {
          final data = usersResult['data'];
          List<UserModel> allUsers = [];
          
          if (data is Map && data['results'] != null) {
            final usersList = data['results'] as List;
            allUsers = usersList
                .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
                .toList();
          } else if (data is List) {
            allUsers = data
                .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
                .toList();
          }
          
          // Фильтруем пользователей, которые принадлежат к отделу "Начальник участка"
          _users = allUsers.where((user) {
            return user.department?.name == 'Начальник участка';
          }).toList();
        } else {
          _users = [];
        }
      });
    }
  }

  /// Удаление участка
  Future<void> _deleteConstructionSite() async {
    if (widget.constructionSite == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Удаление участка',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Вы уверены, что хотите удалить участок "${widget.constructionSite!.name}"? Это действие нельзя отменить.',
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

      final result = await ApiService.deleteConstructionSite(widget.constructionSite!.id);

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
                content: Text('Участок удален'),
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

  /// Сохранение участка
  Future<void> _saveConstructionSite() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    Map<String, dynamic> result;
    if (widget.constructionSite == null) {
      // Создание нового участка
      result = await ApiService.createConstructionSite(
        name,
        description: description.isEmpty ? null : description,
        managerId: _selectedManagerId,
      );
    } else {
      // Обновление существующего участка
      result = await ApiService.updateConstructionSite(
        widget.constructionSite!.id,
        {
          'name': name,
          'description': description.isEmpty ? null : description,
          'manager_id': _selectedManagerId,
        },
      );
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
                  widget.constructionSite == null
                      ? 'Создание строительного участка'
                      : 'Редактирование строительного участка',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Название *',
                    prefixIcon: Icon(Icons.construction),
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
                DropdownButtonFormField<int>(
                  value: _selectedManagerId,
                  decoration: const InputDecoration(
                    labelText: 'Начальник участка',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Не назначен'),
                    ),
                    ..._users.map((user) {
                      return DropdownMenuItem<int>(
                        value: user.id,
                        child: Text(user.username),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedManagerId = value;
                    });
                  },
                ),
                if (_isLoadingUsers) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Кнопка удаления (только при редактировании) - слева
                    if (widget.constructionSite != null) ...[
                      TextButton.icon(
                        onPressed: _isLoading ? null : _deleteConstructionSite,
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
                      onPressed: _isLoading ? null : _saveConstructionSite,
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

