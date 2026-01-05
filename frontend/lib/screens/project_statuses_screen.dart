import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_form_dialog.dart';
import '../models/app_models.dart';

/// Экран статусов проектов
class ProjectStatusesScreen extends StatefulWidget {
  const ProjectStatusesScreen({super.key});

  @override
  State<ProjectStatusesScreen> createState() => _ProjectStatusesScreenState();
}

class _ProjectStatusesScreenState extends State<ProjectStatusesScreen> {
  List<StatusModel> _statuses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  /// Загрузка списка статусов
  Future<void> _loadStatuses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getStatuses();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'] as List;
          _statuses = data
              .map((json) => StatusModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          _errorMessage = result['error'] ?? 'Ошибка загрузки статусов';
        }
      });
    }
  }

  /// Обновление списка
  Future<void> _refreshStatuses() async {
    await _loadStatuses();
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

  /// Заголовок
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
      child: Row(
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
              Icons.label,
              color: AppColors.accentOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Статусы (Проекты)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _statuses.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _statuses.isEmpty) {
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
              onPressed: _refreshStatuses,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    // Группировка статусов по типу
    final sheetStatuses = _statuses.where((s) => s.statusType == 'sheet').toList();
    final stageStatuses = _statuses.where((s) => s.statusType == 'stage').toList();

    return RefreshIndicator(
      onRefresh: _refreshStatuses,
      child: _statuses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Статусы не найдены',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusSectionCard(
                  title: 'Проектные листы',
                  icon: Icons.description,
                  statuses: sheetStatuses,
                  statusType: 'sheet',
                  onRefresh: _refreshStatuses,
                ),
                const SizedBox(height: 16),
                _StatusSectionCard(
                  title: 'Этапы проекта',
                  icon: Icons.timeline,
                  statuses: stageStatuses,
                  statusType: 'stage',
                  onRefresh: _refreshStatuses,
                ),
              ],
            ),
    );
  }
}

/// Карточка секции статусов
class _StatusSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<StatusModel> statuses;
  final String statusType;
  final VoidCallback onRefresh;

  const _StatusSectionCard({
    required this.title,
    required this.icon,
    required this.statuses,
    required this.statusType,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.accentOrange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showAddStatusDialog(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Добавить статус',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (statuses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Статусы не найдены',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...statuses.map((status) => _StatusCard(
                  status: status,
                  onRefresh: onRefresh,
                )),
        ],
      ),
    );
  }

  /// Показать диалог добавления статуса
  Future<void> _showAddStatusDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => StatusFormDialog(
        initialStatusType: statusType,
      ),
    );
    
    if (result != null && result['success'] == true) {
      onRefresh();
    }
  }
}

/// Карточка статуса
class _StatusCard extends StatelessWidget {
  final StatusModel status;
  final VoidCallback? onRefresh;

  const _StatusCard({
    required this.status,
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
    final statusColor = _parseColor(status.color);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.borderColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Индикатор цвета
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusColor,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.label,
                size: 24,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Информация о статусе
          Expanded(
            child: Text(
              status.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
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
    );
  }

  /// Показать диалог редактирования
  Future<void> _showEditDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => StatusFormDialog(
        status: status,
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
          'Удаление статуса',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Вы уверены, что хотите удалить статус "${status.name}"? Это действие нельзя отменить.',
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
      final result = await ApiService.deleteStatus(status.id);

      if (context.mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Статус удален'),
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

