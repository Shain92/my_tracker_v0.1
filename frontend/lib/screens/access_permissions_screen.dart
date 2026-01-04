import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

/// Экран настройки прав доступа к страницам
class AccessPermissionsScreen extends StatefulWidget {
  const AccessPermissionsScreen({super.key});

  @override
  State<AccessPermissionsScreen> createState() => _AccessPermissionsScreenState();
}

class _AccessPermissionsScreenState extends State<AccessPermissionsScreen> {
  List<PagePermission> _permissions = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, Map<int, bool>> _permissionMap = {}; // page_name -> department_id -> has_access

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  /// Загрузка прав доступа
  Future<void> _loadPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getPagePermissions();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>;
          final pagesData = data['pages'] as List;
          _departments = List<Map<String, dynamic>>.from(data['departments'] ?? []);
          
          _permissions = pagesData
              .map((json) => PagePermission.fromJson(json as Map<String, dynamic>))
              .toList();
          
          // Создаем карту для быстрого доступа
          _permissionMap = {};
          for (var perm in _permissions) {
            _permissionMap[perm.pageName] = {};
            for (var deptPerm in perm.departments) {
              _permissionMap[perm.pageName]![deptPerm.departmentId] = deptPerm.hasAccess;
            }
          }
        } else {
          _errorMessage = result['error'] ?? 'Ошибка загрузки прав доступа';
        }
      });
    }
  }

  /// Переключение права доступа
  void _togglePermission(String pageName, int departmentId) {
    setState(() {
      if (_permissionMap[pageName] == null) {
        _permissionMap[pageName] = {};
      }
      final currentValue = _permissionMap[pageName]![departmentId] ?? false;
      _permissionMap[pageName]![departmentId] = !currentValue;
    });
  }

  /// Сохранение изменений
  Future<void> _savePermissions() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    // Формируем список изменений
    final permissionsToUpdate = <Map<String, dynamic>>[];
    for (var entry in _permissionMap.entries) {
      for (var deptEntry in entry.value.entries) {
        permissionsToUpdate.add({
          'page_name': entry.key,
          'department_id': deptEntry.key,
          'has_access': deptEntry.value,
        });
      }
    }

    final result = await ApiService.updatePagePermissions(permissionsToUpdate);

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Права доступа успешно сохранены'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
          _loadPermissions();
        } else {
          _errorMessage = result['error'] ?? 'Ошибка сохранения прав доступа';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage!),
              backgroundColor: AppColors.accentPink,
            ),
          );
        }
      });
    }
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

  /// Заголовок страницы
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
              Icons.security,
              color: AppColors.accentOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Настройки доступа',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (!_isLoading && _permissions.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePermissions,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 20),
              label: const Text('Сохранить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _permissions.isEmpty) {
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
              onPressed: _loadPermissions,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_permissions.isEmpty || _departments.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных для отображения',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth > 0 
                    ? constraints.maxWidth 
                    : MediaQuery.of(context).size.width,
              ),
              child: _buildTable(),
            ),
          ),
        );
      },
    );
  }

  /// Построение таблицы
  Widget _buildTable() {
    // Вычисляем ширины колонок
    final pageColumnWidth = 200.0;
    final departmentColumnWidth = 150.0;
    
    final columnWidths = <int, TableColumnWidth>{
      0: FixedColumnWidth(pageColumnWidth),
    };
    
    for (int i = 1; i <= _departments.length; i++) {
      columnWidths[i] = FixedColumnWidth(departmentColumnWidth);
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Table(
        columnWidths: columnWidths,
        border: TableBorder(
          horizontalInside: BorderSide(
            color: AppColors.borderColor.withOpacity(0.3),
            width: 1,
          ),
          verticalInside: BorderSide(
            color: AppColors.borderColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        children: [
          // Заголовок
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.2),
            ),
            children: [
              _buildHeaderCell('Страница'),
              ..._departments.map((dept) => _buildHeaderCell(dept['name'] as String)),
            ],
          ),
          // Строки данных
          ..._permissions.map((perm) => TableRow(
                children: [
                  _buildPageCell(perm.pageLabel),
                  ..._departments.map((dept) {
                    final deptId = dept['id'] as int;
                    final hasAccess = _permissionMap[perm.pageName]?[deptId] ?? false;
                    return _buildCheckboxCell(
                      hasAccess,
                      () => _togglePermission(perm.pageName, deptId),
                    );
                  }),
                ],
              )),
        ],
      ),
    );
  }

  /// Ячейка заголовка
  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Ячейка с названием страницы
  Widget _buildPageCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Ячейка с чекбоксом
  Widget _buildCheckboxCell(bool value, VoidCallback onChanged) {
    return Center(
      child: Checkbox(
        value: value,
        onChanged: (_) => onChanged(),
        activeColor: AppColors.accentGreen,
        checkColor: AppColors.textPrimary,
      ),
    );
  }
}

