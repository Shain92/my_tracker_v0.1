import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';

/// Диалог формы создания/редактирования статуса
class StatusFormDialog extends StatefulWidget {
  final StatusModel? status;
  final String? initialStatusType;

  const StatusFormDialog({
    super.key,
    this.status,
    this.initialStatusType,
  });

  @override
  State<StatusFormDialog> createState() => _StatusFormDialogState();
}

class _StatusFormDialogState extends State<StatusFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  bool _isLoading = false;
  Color _selectedColor = Colors.blue;
  String _selectedStatusType = 'sheet';

  /// Предустановленные цвета для выбора
  final List<Color> _presetColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.status != null) {
      _nameController.text = widget.status!.name;
      _colorController.text = widget.status!.color;
      _selectedColor = _parseColor(widget.status!.color);
      _selectedStatusType = widget.status!.statusType;
    } else {
      _colorController.text = '#000000';
      _selectedColor = Colors.blue;
      if (widget.initialStatusType != null) {
        _selectedStatusType = widget.initialStatusType!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  /// Преобразовать HEX цвет в Color
  Color _parseColor(String hexColor) {
    try {
      if (hexColor.isEmpty) {
        return Colors.blue;
      }
      String hex = hexColor.trim().replaceAll('#', '').toUpperCase();
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      } else if (hex.length == 3) {
        final r = hex[0];
        final g = hex[1];
        final b = hex[2];
        hex = '$r$r$g$g$b$b';
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (e) {
      // Если не удалось распарсить, возвращаем цвет по умолчанию
    }
    return Colors.blue;
  }

  /// Преобразовать Color в HEX строку
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Обновить цвет из текстового поля
  void _updateColorFromText() {
    final color = _parseColor(_colorController.text);
    setState(() {
      _selectedColor = color;
    });
  }

  /// Обновить текстовое поле из выбранного цвета
  void _updateTextFromColor(Color color) {
    setState(() {
      _selectedColor = color;
      _colorController.text = _colorToHex(color);
    });
  }

  /// Сохранение статуса
  Future<void> _saveStatus() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final color = _colorController.text.trim().isEmpty
        ? _colorToHex(_selectedColor)
        : _colorController.text.trim();

    Map<String, dynamic> result;
    if (widget.status == null) {
      // Создание нового статуса
      result = await ApiService.createStatus(
        name,
        _selectedStatusType,
        color: color,
      );
    } else {
      // Обновление существующего статуса
      result = await ApiService.updateStatus(
        widget.status!.id,
        {
          'name': name,
          'color': color,
          'status_type': _selectedStatusType,
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
                  widget.status == null
                      ? 'Создание статуса'
                      : 'Редактирование статуса',
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
                    prefixIcon: Icon(Icons.label),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Название обязательно';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatusType,
                  decoration: const InputDecoration(
                    labelText: 'Тип статуса *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'sheet',
                      child: Text('Проектный лист'),
                    ),
                    DropdownMenuItem(
                      value: 'stage',
                      child: Text('Этап проекта'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatusType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _colorController,
                  decoration: InputDecoration(
                    labelText: 'Цвет (HEX)',
                    prefixIcon: Icon(Icons.color_lens, color: _selectedColor),
                    helperText: 'Например: #FF5733',
                    suffixIcon: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  onChanged: (_) => _updateColorFromText(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Выберите цвет:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetColors.map((color) {
                    final isSelected = color.value == _selectedColor.value;
                    return GestureDetector(
                      onTap: () => _updateTextFromColor(color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentOrange
                                : AppColors.borderColor,
                            width: isSelected ? 3 : 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
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
                      onPressed: _isLoading ? null : _saveStatus,
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

