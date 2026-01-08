import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import 'package:intl/intl.dart';
import 'project_detail_screen.dart';
import 'site_projects_screen.dart';

/// Экран задач - список листов отдела пользователя
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<ProjectSheetModel> _sheets = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Пагинация
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  static const int _pageSize = 20;
  
  // Сортировка
  String? _sortColumn;
  bool _sortAscending = true;
  
  // Фильтрация
  Map<String, String> _columnFilters = {};
  Set<String> _activeFilterColumns = {};
  String? _completedFilter = 'not_completed'; // null, 'completed', 'not_completed'
  Map<String, TextEditingController> _searchControllers = {};

  @override
  void initState() {
    super.initState();
    _loadSheets();
  }
  
  @override
  void dispose() {
    // Освобождаем все контроллеры поиска
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    _searchControllers.clear();
    super.dispose();
  }

  /// Загрузка листов отдела
  Future<void> _loadSheets({int? page}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentPage = page ?? _currentPage;
      final result = await ApiService.getDepartmentSheets(
        page: currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            final data = result['data'] as List;
            _sheets = data
                .map((json) => ProjectSheetModel.fromJson(json as Map<String, dynamic>))
                .toList();
            
            // Обновление информации о пагинации
            if (result['pagination'] != null) {
              final pagination = result['pagination'] as Map<String, dynamic>;
              _currentPage = pagination['currentPage'] as int? ?? 1;
              _totalPages = pagination['totalPages'] as int? ?? 1;
              _totalCount = pagination['count'] as int? ?? 0;
            } else {
              _currentPage = 1;
              _totalPages = 1;
              _totalCount = _sheets.length;
            }
            
            // Применение сортировки
            _applySorting();
          } else {
            _errorMessage = result['error'] ?? 'Ошибка загрузки задач';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка подключения: ${e.toString()}';
        });
      }
    }
  }

  /// Применение сортировки
  void _applySorting() {
    if (_sortColumn == null) return;
    
    _sheets.sort((a, b) {
      int comparison = 0;
      
      switch (_sortColumn) {
        case 'isCompleted':
          comparison = a.isCompleted == b.isCompleted ? 0 : (a.isCompleted ? 1 : -1);
          break;
        case 'name':
          comparison = (a.name ?? '').compareTo(b.name ?? '');
          break;
        case 'project':
          comparison = (a.project?.name ?? '').compareTo(b.project?.name ?? '');
          break;
        case 'constructionSite':
          final aSite = a.project?.constructionSite?.name ?? '';
          final bSite = b.project?.constructionSite?.name ?? '';
          comparison = aSite.compareTo(bSite);
          break;
        case 'status':
          comparison = (a.status?.name ?? '').compareTo(b.status?.name ?? '');
          break;
        case 'createdAt':
          final aDate = a.createdAt ?? '';
          final bDate = b.createdAt ?? '';
          comparison = aDate.compareTo(bDate);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
  }
  
  /// Применение фильтров
  List<ProjectSheetModel> _applyFilters() {
    List<ProjectSheetModel> filtered = List.from(_sheets);
    
    // Фильтр по "Выполнено"
    if (_completedFilter != null) {
      filtered = filtered.where((sheet) {
        if (_completedFilter == 'completed') {
          return sheet.isCompleted;
        } else if (_completedFilter == 'not_completed') {
          return !sheet.isCompleted;
        }
        return true;
      }).toList();
    }
    
    // Фильтры по текстовым столбцам
    for (final entry in _columnFilters.entries) {
      final column = entry.key;
      final filterText = entry.value.trim().toLowerCase();
      
      if (filterText.isEmpty) continue;
      
      filtered = filtered.where((sheet) {
        String text = '';
        
        switch (column) {
          case 'name':
            text = (sheet.name ?? '').toLowerCase();
            break;
          case 'project':
            text = (sheet.project?.name ?? '').toLowerCase();
            break;
          case 'constructionSite':
            text = (sheet.project?.constructionSite?.name ?? '').toLowerCase();
            break;
          case 'status':
            text = (sheet.status?.name ?? '').toLowerCase();
            break;
          case 'createdAt':
            text = sheet.createdAt != null
                ? _formatDate(sheet.createdAt!).toLowerCase()
                : '';
            break;
        }
        
        return text.contains(filterText);
      }).toList();
    }
    
    return filtered;
  }

  /// Обработка сортировки
  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _applySorting();
    });
  }

  /// Обновление списка
  Future<void> _refreshSheets() async {
    _currentPage = 1;
    await _loadSheets(page: 1);
  }
  
  /// Переход на страницу
  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages && page != _currentPage) {
      _loadSheets(page: page);
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
              _buildHeader(),
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
  Widget _buildHeader() {
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.task_alt,
              color: AppColors.accentOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Задачи',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.textPrimary,
            onPressed: _refreshSheets,
            tooltip: 'Обновить',
          ),
        ],
      ),
    );
  }

  /// Контент
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
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
              onPressed: _refreshSheets,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_sheets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Нет задач',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshSheets,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: _buildTable(),
              ),
            ),
          ),
          _buildPaginationControls(),
        ],
      ),
    );
  }

  /// Построение таблицы
  Widget _buildTable() {
    final filteredSheets = _applyFilters();
    
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
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          AppColors.cardBackground.withOpacity(0.8),
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentBlue.withOpacity(0.2);
          }
          return null;
        }),
        columns: [
          _buildDataColumn('Выполнено', 'isCompleted'),
          _buildDataColumn('Название', 'name'),
          _buildDataColumn('Проект', 'project'),
          _buildDataColumn('Участок', 'constructionSite'),
          _buildDataColumn('Статус', 'status'),
          _buildDataColumn('Дата создания', 'createdAt'),
        ],
        rows: filteredSheets.map((sheet) => _buildDataRow(sheet)).toList(),
      ),
    );
  }
  
  /// Построение колонки с сортировкой
  DataColumn _buildDataColumn(String label, String column) {
    final hasFilter = _columnFilters[column]?.isNotEmpty ?? false;
    final isSearchActive = _activeFilterColumns.contains(column);
    
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (column == 'isCompleted') ...[
            _buildCompletedDropdown(),
          ] else if (isSearchActive) ...[
            SizedBox(
              width: 120,
              child: _buildSearchFieldInHeader(column),
            ),
          ] else ...[
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _activeFilterColumns.add(column);
                  _columnFilters[column] = '';
                });
              },
              child: Icon(
                Icons.search,
                size: 16,
                color: hasFilter
                    ? AppColors.accentBlue
                    : AppColors.textSecondary,
              ),
            ),
          ],
          if (_sortColumn == column && !isSearchActive) ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppColors.accentBlue,
            ),
          ],
        ],
      ),
      onSort: (columnIndex, ascending) => _onSort(column),
    );
  }
  
  /// Поисковое поле в заголовке столбца
  Widget _buildSearchFieldInHeader(String column) {
    // Создаём контроллер для этого столбца, если его ещё нет
    if (!_searchControllers.containsKey(column)) {
      _searchControllers[column] = TextEditingController(text: _columnFilters[column] ?? '');
    }
    
    return TextField(
      key: ValueKey('search_header_$column'),
      controller: _searchControllers[column],
      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Поиск...',
        hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.accentBlue),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, size: 16),
          onPressed: () {
            setState(() {
              _activeFilterColumns.remove(column);
              _columnFilters.remove(column);
              _searchControllers[column]?.dispose();
              _searchControllers.remove(column);
            });
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _columnFilters[column] = value;
        });
      },
    );
  }
  
  /// Выпадающий список для фильтра "Выполнено"
  Widget _buildCompletedDropdown() {
    return DropdownButton<String>(
      value: _completedFilter,
      isDense: true,
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.arrow_drop_down, size: 16),
      items: const [
        DropdownMenuItem(value: null, child: Text('Все', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'completed', child: Text('Выполнено', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'not_completed', child: Text('Не выполнено', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (value) {
        setState(() {
          _completedFilter = value;
        });
      },
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Построение строки таблицы
  DataRow _buildDataRow(ProjectSheetModel sheet) {
    return DataRow(
      cells: [
        DataCell(
          Center(
            child: sheet.isCompleted
                ? const Icon(Icons.check_box, color: AppColors.accentGreen, size: 18)
                : const Icon(Icons.check_box_outline_blank, color: AppColors.textSecondary, size: 18),
          ),
        ),
        DataCell(
          _buildClickableText(
            sheet.name ?? 'Без названия',
            sheet.isCompleted ? TextDecoration.lineThrough : null,
            () {
              if (sheet.project != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailScreen(project: sheet.project!),
                  ),
                );
              }
            },
          ),
        ),
        DataCell(
          _buildClickableText(
            sheet.project?.name ?? '—',
            null,
            () {
              if (sheet.project != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailScreen(project: sheet.project!),
                  ),
                );
              }
            },
          ),
        ),
        DataCell(
          _buildClickableText(
            sheet.project?.constructionSite?.name ?? '—',
            null,
            () {
              if (sheet.project?.constructionSite != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SiteProjectsScreen(
                      constructionSite: sheet.project!.constructionSite!,
                    ),
                  ),
                );
              }
            },
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sheet.status != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _parseColor(sheet.status!.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  sheet.status!.name,
                  style: TextStyle(
                    color: _parseColor(sheet.status!.color),
                  ),
                ),
              ] else
                const Text(
                  '—',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        DataCell(
          Text(
            sheet.createdAt != null
                ? _formatDate(sheet.createdAt!)
                : '—',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  /// Форматирование даты
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  /// Построение кликабельного текста
  Widget _buildClickableText(
    String text,
    TextDecoration? decoration,
    VoidCallback onTap,
  ) {
    final isLink = text != '—';
    final List<TextDecoration> decorations = [];
    
    if (decoration != null) {
      decorations.add(decoration);
    }
    if (isLink) {
      decorations.add(TextDecoration.underline);
    }
    
    return InkWell(
      onTap: isLink ? onTap : null,
      child: Text(
        text,
        style: TextStyle(
          color: isLink ? AppColors.accentBlue : AppColors.textPrimary,
          decoration: decorations.isEmpty 
              ? null 
              : decorations.length == 1 
                  ? decorations.first 
                  : TextDecoration.combine(decorations),
          decorationColor: AppColors.accentBlue,
        ),
      ),
    );
  }

  /// Построение элементов управления пагинацией
  Widget _buildPaginationControls() {
    if (_totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final startItem = ((_currentPage - 1) * _pageSize) + 1;
    final endItem = (_currentPage * _pageSize).clamp(0, _totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: AppColors.borderColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Показано $startItem-$endItem из $_totalCount',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: _currentPage > 1 ? AppColors.textPrimary : AppColors.textTertiary,
                onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                tooltip: 'Предыдущая',
              ),
              Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: _currentPage < _totalPages ? AppColors.textPrimary : AppColors.textTertiary,
                onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
                tooltip: 'Следующая',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Преобразование HEX цвета в Color
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
}
