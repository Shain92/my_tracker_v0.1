import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

/// Диалог формы создания/редактирования пользователя
class UserFormDialog extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onDelete;
  final VoidCallback? onRefresh;

  const UserFormDialog({
    super.key,
    this.user,
    this.onToggleStatus,
    this.onDelete,
    this.onRefresh,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSuperuser = false;
  bool _isActive = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  List<DepartmentModel> _departments = [];
  int? _selectedDepartmentId;
  bool _isLoadingDepartments = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!.username;
      _emailController.text = widget.user!.email ?? '';
      _firstNameController.text = widget.user!.firstName ?? '';
      _lastNameController.text = widget.user!.lastName ?? '';
      _isSuperuser = widget.user!.isSuperuser;
      _isActive = widget.user!.isActive;
      _selectedDepartmentId = widget.user!.department?.id;
    }
    _loadDepartments();
  }

  /// Загрузка списка отделов
  Future<void> _loadDepartments() async {
    setState(() {
      _isLoadingDepartments = true;
    });

    final result = await ApiService.getDepartments();
    if (mounted) {
      setState(() {
        _isLoadingDepartments = false;
        if (result['success'] == true) {
          final data = result['data'] as List;
          _departments = data.map((json) => DepartmentModel.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          // Если ошибка, показываем сообщение
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Ошибка загрузки отделов'),
              backgroundColor: AppColors.accentPink,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Сохранение пользователя
  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final userData = {
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'is_superuser': _isSuperuser,
      'is_active': _isActive,
    };

    if (_passwordController.text.isNotEmpty) {
      userData['password'] = _passwordController.text;
    }

    // Всегда передаем department_id, даже если null (чтобы можно было убрать отдел)
    userData['department_id'] = _selectedDepartmentId as dynamic;

    Map<String, dynamic> result;
    if (widget.user == null) {
      // Создание нового пользователя
      if (_passwordController.text.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пароль обязателен при создании пользователя'),
            backgroundColor: AppColors.accentPink,
          ),
        );
        return;
      }
      result = await ApiService.createUser(userData);
    } else {
      // Обновление существующего пользователя
      result = await ApiService.updateUser(widget.user!.id, userData);
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
                  widget.user == null
                      ? 'Создание пользователя'
                      : 'Редактирование пользователя',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username обязателен';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Фамилия',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedDepartmentId != null && _departments.any((d) => d.id == _selectedDepartmentId)
                            ? _selectedDepartmentId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Отдел',
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Без отдела'),
                          ),
                          ..._departments.map((dept) => DropdownMenuItem<int>(
                            value: dept.id,
                            child: Text(dept.name),
                          )),
                        ],
                        onChanged: _isLoadingDepartments
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedDepartmentId = value;
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Создать отдел',
                      onPressed: _isLoadingDepartments ? null : _showCreateDepartmentDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: widget.user == null
                        ? 'Пароль *'
                        : 'Новый пароль (оставьте пустым, чтобы не менять)',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (widget.user == null &&
                        (value == null || value.isEmpty)) {
                      return 'Пароль обязателен';
                    }
                    if (value != null && value.isNotEmpty && value.length < 8) {
                      return 'Пароль должен содержать минимум 8 символов';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text(
                    'Суперпользователь',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  value: _isSuperuser,
                  onChanged: (value) {
                    setState(() {
                      _isSuperuser = value;
                    });
                  },
                  activeColor: AppColors.accentOrange,
                ),
                SwitchListTile(
                  title: const Text(
                    'Активен',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  activeColor: AppColors.accentGreen,
                ),
                const SizedBox(height: 24),
                // Дополнительные действия для редактирования
                if (widget.user != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading || widget.onToggleStatus == null
                              ? null
                              : () {
                                  widget.onToggleStatus!();
                                  Navigator.pop(context);
                                },
                          icon: Icon(
                            _isActive ? Icons.lock : Icons.lock_open,
                            size: 18,
                          ),
                          label: Text(
                            _isActive ? 'Заблокировать' : 'Разблокировать',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentOrange,
                            side: BorderSide(color: AppColors.accentOrange),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading || widget.onDelete == null
                              ? null
                              : () {
                                  // #region agent log
                                  try {
                                    http.post(
                                      Uri.parse('http://127.0.0.1:7246/ingest/24c3c77a-8ab3-4ae6-afd3-7e3aad7b1941'),
                                      headers: {'Content-Type': 'application/json'},
                                      body: jsonEncode({
                                        'location': 'user_form_dialog.dart:delete_button:CLICKED',
                                        'message': 'Delete button clicked, calling onDelete',
                                        'data': {'userId': widget.user?.id, 'onDeleteNull': widget.onDelete == null},
                                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                                        'sessionId': 'debug-session',
                                        'runId': 'run1',
                                        'hypothesisId': 'A'
                                      }),
                                    ).catchError((_) => http.Response('', 200));
                                  } catch (_) {}
                                  // #endregion
                                  Navigator.pop(context);
                                  widget.onDelete!();
                                },
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Удалить'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentPink,
                            side: BorderSide(color: AppColors.accentPink),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveUser,
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

  /// Диалог создания нового отдела
  Future<void> _showCreateDepartmentDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final colorController = TextEditingController(text: '#000000');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Создать отдел',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  prefixIcon: Icon(Icons.business),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Цвет (HEX)',
                  prefixIcon: Icon(Icons.color_lens),
                  helperText: 'Например: #FF5733',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final deptResult = await ApiService.createDepartment(
        nameController.text.trim(),
        description: descriptionController.text.trim(),
        color: colorController.text.trim(),
      );

      if (mounted) {
        if (deptResult['success'] == true) {
          final newDept = DepartmentModel.fromJson(deptResult['data']);
          setState(() {
            _departments.add(newDept);
            _selectedDepartmentId = newDept.id;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Отдел успешно создан'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(deptResult['error'] ?? 'Ошибка создания отдела'),
              backgroundColor: AppColors.accentPink,
            ),
          );
        }
      }
    }

    nameController.dispose();
    descriptionController.dispose();
    colorController.dispose();
  }
}

