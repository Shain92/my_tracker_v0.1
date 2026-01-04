import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/department_form_dialog.dart';
import '../models/user_model.dart';
import 'access_permissions_screen.dart';

/// Экран списка отделов
class DepartmentsListScreen extends StatefulWidget {
  const DepartmentsListScreen({super.key});

  @override
  State<DepartmentsListScreen> createState() => _DepartmentsListScreenState();
}

class _DepartmentsListScreenState extends State<DepartmentsListScreen> {
  List<DepartmentModel> _departments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  /// Загрузка списка отделов
  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getDepartments();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'] as List;
          _departments = data
              .map((json) => DepartmentModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          _errorMessage = result['error'] ?? 'Ошибка загрузки отделов';
        }
      });
    }
  }

  /// Обновление списка
  Future<void> _refreshDepartments() async {
    await _loadDepartments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              AppColors.backgroundSecondary,
              AppColors.backgroundDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Заголовок с кнопкой добавления
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const backButtonWidth = 48.0;
          const iconWidth = 40.0;
          const spacing = 8.0 + 12.0;

          final textPainter = TextPainter(
            text: const TextSpan(
              text: 'Список отделов',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          final textWidth = textPainter.width;

          final buttonTextPainter = TextPainter(
            text: const TextSpan(
              text: 'Добавить отдел',
              style: TextStyle(fontSize: 14),
            ),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          );
          buttonTextPainter.layout();
          const buttonPadding = 16.0 * 2;
          const buttonIconWidth = 20.0 + 8.0;
          final buttonWithTextWidth = buttonIconWidth + buttonTextPainter.width + buttonPadding;

          final fixedWidth = backButtonWidth + spacing + iconWidth + spacing;
          final availableWidth = constraints.maxWidth - fixedWidth;

          final textFits = textWidth <= availableWidth;
          final spaceForButton = availableWidth - (textFits ? textWidth + 12 : 0);
          final buttonWithTextFits = buttonWithTextWidth <= spaceForButton;

          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.business,
                  color: AppColors.accentOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              if (textFits)
                const Text(
                  'Список отделов',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              const Spacer(),
              if (buttonWithTextFits) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccessPermissionsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.security, size: 20),
                  label: const Text('Настройки доступа'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddDepartmentDialog(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Добавить отдел'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ] else ...[
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccessPermissionsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.security),
                  tooltip: 'Настройки доступа',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showAddDepartmentDialog(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Добавить отдел',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Показать диалог добавления отдела
  Future<void> _showAddDepartmentDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => const DepartmentFormDialog(),
    );
    
    if (result != null && result['success'] == true) {
      _refreshDepartments();
    }
  }

  Widget _buildContent() {
    if (_isLoading && _departments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _departments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.accentPink,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshDepartments,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshDepartments,
      child: _departments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Отделы не найдены',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _departments.length,
              itemBuilder: (context, index) {
                return _DepartmentCard(
                  department: _departments[index],
                  onRefresh: () => _refreshDepartments(),
                );
              },
            ),
    );
  }
}

/// Карточка отдела
class _DepartmentCard extends StatelessWidget {
  final DepartmentModel department;
  final VoidCallback? onRefresh;

  const _DepartmentCard({
    required this.department,
    this.onRefresh,
  });

  /// Преобразовать HEX цвет в Color
  Color _parseColor(String hexColor) {
    try {
      if (hexColor.isEmpty) {
        return AppColors.textSecondary;
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
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final deptColor = _parseColor(department.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Индикатор цвета
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: deptColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: deptColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.business,
                  size: 32,
                  color: deptColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Информация об отделе
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (department.description != null &&
                      department.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      department.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Кнопка редактирования
            _ActionButton(
              icon: Icons.edit,
              color: AppColors.accentBlue,
              onTap: () => _showEditDialog(context),
            ),
            const SizedBox(width: 8),
            // Кнопка удаления
            _ActionButton(
              icon: Icons.delete,
              color: AppColors.accentPink,
              onTap: () => _showDeleteDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Показать диалог редактирования
  Future<void> _showEditDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => DepartmentFormDialog(
        department: department,
      ),
    );
    if (result != null && result['success'] == true && onRefresh != null) {
      onRefresh!();
    }
  }

  /// Показать диалог удаления
  Future<void> _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Удаление отдела',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Вы уверены, что хотите удалить отдел "${department.name}"? Это действие нельзя отменить.',
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

    if (confirmed == true && context.mounted) {
      final result = await ApiService.deleteDepartment(department.id);

      if (context.mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Отдел удален'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
          if (onRefresh != null) {
            onRefresh!();
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
}

/// Кнопка действия
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: color,
        ),
      ),
    );
  }
}

