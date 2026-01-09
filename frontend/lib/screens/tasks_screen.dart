import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import 'package:intl/intl.dart';
import 'project_detail_screen.dart';
import 'site_projects_screen.dart';
import 'login_screen.dart';

/// Экран задач - список листов отдела пользователя
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // Выбранный чип
  String _selectedTab = 'sheets'; // 'sheets', 'stages' или 'projects'
  
  // Данные для листов (ИД)
  List<ProjectSheetModel> _sheets = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Данные для этапов
  List<ProjectStageModel> _stages = [];
  bool _isLoadingStages = false;
  String? _errorMessageStages;
  
  // Данные для проектов
  List<ProjectModel> _projects = [];
  bool _isLoadingProjects = false;
  String? _errorMessageProjects;
  
  // Пагинация для листов
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  
  // Пагинация для этапов
  int _currentPageStages = 1;
  int _totalPagesStages = 1;
  int _totalCountStages = 0;
  
  // Пагинация для проектов
  int _currentPageProjects = 1;
  int _totalPagesProjects = 1;
  int _totalCountProjects = 0;
  
  static const int _pageSize = 20;
  
  // Сортировка для листов
  String? _sortColumn;
  bool _sortAscending = true;
  
  // Сортировка для этапов
  String? _sortColumnStages;
  bool _sortAscendingStages = true;
  
  // Сортировка для проектов
  String? _sortColumnProjects;
  bool _sortAscendingProjects = true;
  
  // Фильтрация для листов
  Map<String, String> _columnFilters = {};
  Set<String> _activeFilterColumns = {};
  String? _completedFilter = 'not_completed'; // null, 'completed', 'not_completed'
  Map<String, TextEditingController> _searchControllers = {};
  
  // Фильтрация для этапов
  Map<String, String> _columnFiltersStages = {};
  Set<String> _activeFilterColumnsStages = {};
  Map<String, TextEditingController> _searchControllersStages = {};
  
  // Фильтрация для проектов
  Map<String, String> _columnFiltersProjects = {};
  Set<String> _activeFilterColumnsProjects = {};
  Map<String, TextEditingController> _searchControllersProjects = {};
  
  // Фильтр статусов для этапов
  List<StatusModel> _stageStatuses = [];
  Set<int> _selectedStatusIds = {};
  bool _isLoadingStatuses = false;

  @override
  void initState() {
    super.initState();
    _loadSheets();
  }
  
  @override
  void dispose() {
    // Освобождаем все контроллеры поиска для листов
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    _searchControllers.clear();
    
    // Освобождаем все контроллеры поиска для этапов
    for (final controller in _searchControllersStages.values) {
      controller.dispose();
    }
    _searchControllersStages.clear();
    
    // Освобождаем все контроллеры поиска для проектов
    for (final controller in _searchControllersProjects.values) {
      controller.dispose();
    }
    _searchControllersProjects.clear();
    
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

  /// Загрузка этапов
  Future<void> _loadStages({int? page}) async {
    setState(() {
      _isLoadingStages = true;
      _errorMessageStages = null;
    });

    try {
      final currentPage = page ?? _currentPageStages;
      final result = await ApiService.getUserResponsibleStages(
        page: currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _isLoadingStages = false;
          if (result['success'] == true) {
            final data = result['data'] as List;
            _stages = data
                .map((json) => ProjectStageModel.fromJson(json as Map<String, dynamic>))
                .toList();
            
            // Обновление информации о пагинации
            if (result['pagination'] != null) {
              final pagination = result['pagination'] as Map<String, dynamic>;
              _currentPageStages = pagination['currentPage'] as int? ?? 1;
              _totalPagesStages = pagination['totalPages'] as int? ?? 1;
              _totalCountStages = pagination['count'] as int? ?? 0;
            } else {
              _currentPageStages = 1;
              _totalPagesStages = 1;
              _totalCountStages = _stages.length;
            }
            
            // Применение сортировки
            _applySortingStages();
          } else {
            _errorMessageStages = result['error'] ?? 'Ошибка загрузки этапов';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStages = false;
          _errorMessageStages = 'Ошибка подключения: ${e.toString()}';
        });
      }
    }
  }

  /// Применение сортировки для этапов
  void _applySortingStages() {
    if (_sortColumnStages == null) return;
    
    _stages.sort((a, b) {
      int comparison = 0;
      
      switch (_sortColumnStages) {
        case 'status':
          comparison = (a.status?.name ?? '').compareTo(b.status?.name ?? '');
          break;
        case 'description':
          comparison = (a.description ?? '').compareTo(b.description ?? '');
          break;
        case 'project':
          comparison = (a.project?.name ?? '').compareTo(b.project?.name ?? '');
          break;
        case 'constructionSite':
          final aSite = a.project?.constructionSite?.name ?? '';
          final bSite = b.project?.constructionSite?.name ?? '';
          comparison = aSite.compareTo(bSite);
          break;
        case 'createdAt':
          final aDate = a.createdAt ?? '';
          final bDate = b.createdAt ?? '';
          comparison = aDate.compareTo(bDate);
          break;
      }
      
      return _sortAscendingStages ? comparison : -comparison;
    });
  }
  
  /// Применение фильтров для этапов
  List<ProjectStageModel> _applyFiltersStages() {
    List<ProjectStageModel> filtered = List.from(_stages);
    
    // Фильтр по статусам
    if (_selectedStatusIds.isNotEmpty) {
      filtered = filtered.where((stage) {
        if (stage.status == null && stage.statusId == null) {
          return false; // Не показываем этапы без статуса
        }
        final statusId = stage.status?.id ?? stage.statusId;
        return statusId != null && _selectedStatusIds.contains(statusId);
      }).toList();
    }
    
    // Фильтры по текстовым столбцам
    for (final entry in _columnFiltersStages.entries) {
      final column = entry.key;
      final filterText = entry.value.trim().toLowerCase();
      
      if (filterText.isEmpty) continue;
      
      filtered = filtered.where((stage) {
        String text = '';
        
        switch (column) {
          case 'description':
            text = (stage.description ?? '').toLowerCase();
            break;
          case 'project':
            text = (stage.project?.name ?? '').toLowerCase();
            break;
          case 'constructionSite':
            text = (stage.project?.constructionSite?.name ?? '').toLowerCase();
            break;
          case 'createdAt':
            text = stage.createdAt != null
                ? _formatDate(stage.createdAt!).toLowerCase()
                : '';
            break;
        }
        
        return text.contains(filterText);
      }).toList();
    }
    
    return filtered;
  }

  /// Обработка сортировки для этапов
  void _onSortStages(String column) {
    setState(() {
      if (_sortColumnStages == column) {
        _sortAscendingStages = !_sortAscendingStages;
      } else {
        _sortColumnStages = column;
        _sortAscendingStages = true;
      }
      _applySortingStages();
    });
  }

  /// Обновление списка этапов
  Future<void> _refreshStages() async {
    _currentPageStages = 1;
    await _loadStages(page: 1);
  }

  /// Загрузка статусов этапов
  Future<void> _loadStageStatuses() async {
    if (_stageStatuses.isNotEmpty) return; // Уже загружены
    
    setState(() {
      _isLoadingStatuses = true;
    });

    try {
      final result = await ApiService.getStatuses(statusType: 'stage');

      if (mounted) {
        setState(() {
          _isLoadingStatuses = false;
          if (result['success'] == true) {
            final data = result['data'] as List;
            _stageStatuses = data
                .map((json) => StatusModel.fromJson(json as Map<String, dynamic>))
                .toList();
            
            // По умолчанию выбрать все статусы кроме "Завершен"
            _selectedStatusIds = _stageStatuses
                .where((status) => status.name.toLowerCase() != 'завершен')
                .map((status) => status.id)
                .toSet();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStatuses = false;
        });
      }
    }
  }
  
  /// Переход на страницу для этапов
  void _goToPageStages(int page) {
    if (page >= 1 && page <= _totalPagesStages && page != _currentPageStages) {
      _loadStages(page: page);
    }
  }

  /// Загрузка проектов
  Future<void> _loadProjects({int? page}) async {
    setState(() {
      _isLoadingProjects = true;
      _errorMessageProjects = null;
    });

    try {
      final result = await ApiService.getProjects();

      if (mounted) {
        // Проверяем, требуется ли перелогин
        final requiresLogin = result['requiresLogin'] == true;
        
        setState(() {
          _isLoadingProjects = false;
          if (result['success'] == true) {
            try {
              final data = result['data'];
              if (data is List) {
                _projects = data
                    .map((json) {
                      try {
                        return ProjectModel.fromJson(json as Map<String, dynamic>);
                      } catch (e) {
                        // Пропускаем некорректные записи
                        return null;
                      }
                    })
                    .whereType<ProjectModel>()
                    .toList();
                
                // Обновление информации о пагинации
                // API getProjects не возвращает пагинацию, поэтому используем клиентскую
                _currentPageProjects = page ?? 1;
                _totalCountProjects = _projects.length;
                _totalPagesProjects = (_totalCountProjects / _pageSize).ceil();
                if (_totalPagesProjects == 0) _totalPagesProjects = 1;
                
                // Применение сортировки
                _applySortingProjects();
              } else {
                _errorMessageProjects = 'Неверный формат данных: ожидался список';
              }
            } catch (e) {
              _errorMessageProjects = 'Ошибка обработки данных: ${e.toString()}';
            }
          } else {
            _errorMessageProjects = result['error'] ?? 'Ошибка загрузки проектов';
          }
        });
        
        // Если требуется перелогин, перенаправляем на страницу входа
        if (requiresLogin && mounted) {
          await ApiService.logout();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
          _errorMessageProjects = 'Ошибка подключения: ${e.toString()}';
        });
      }
    }
  }

  /// Применение сортировки для проектов
  void _applySortingProjects() {
    if (_sortColumnProjects == null) return;
    
    _projects.sort((a, b) {
      int comparison = 0;
      
      switch (_sortColumnProjects) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'description':
          comparison = (a.description ?? '').compareTo(b.description ?? '');
          break;
        case 'completionPercentage':
          final aPercent = a.completionPercentage ?? 0.0;
          final bPercent = b.completionPercentage ?? 0.0;
          comparison = aPercent.compareTo(bPercent);
          break;
        case 'status':
          final aStatus = a.lastStageStatus?.name ?? '';
          final bStatus = b.lastStageStatus?.name ?? '';
          comparison = aStatus.compareTo(bStatus);
          break;
        case 'constructionSite':
          final aSite = a.constructionSite?.name ?? '';
          final bSite = b.constructionSite?.name ?? '';
          comparison = aSite.compareTo(bSite);
          break;
      }
      
      return _sortAscendingProjects ? comparison : -comparison;
    });
  }
  
  /// Применение фильтров для проектов
  List<ProjectModel> _applyFiltersProjects() {
    List<ProjectModel> filtered = List.from(_projects);
    
    // Фильтры по текстовым столбцам
    for (final entry in _columnFiltersProjects.entries) {
      final column = entry.key;
      final filterText = entry.value.trim().toLowerCase();
      
      if (filterText.isEmpty) continue;
      
      filtered = filtered.where((project) {
        String text = '';
        
        switch (column) {
          case 'name':
            text = project.name.toLowerCase();
            break;
          case 'description':
            text = (project.description ?? '').toLowerCase();
            break;
          case 'status':
            text = (project.lastStageStatus?.name ?? '').toLowerCase();
            break;
          case 'constructionSite':
            text = (project.constructionSite?.name ?? '').toLowerCase();
            break;
        }
        
        return text.contains(filterText);
      }).toList();
    }
    
    return filtered;
  }

  /// Обработка сортировки для проектов
  void _onSortProjects(String column) {
    setState(() {
      if (_sortColumnProjects == column) {
        _sortAscendingProjects = !_sortAscendingProjects;
      } else {
        _sortColumnProjects = column;
        _sortAscendingProjects = true;
      }
      _applySortingProjects();
    });
  }

  /// Обновление списка проектов
  Future<void> _refreshProjects() async {
    _currentPageProjects = 1;
    await _loadProjects(page: 1);
  }
  
  /// Переход на страницу для проектов
  void _goToPageProjects(int page) {
    if (page >= 1 && page <= _totalPagesProjects && page != _currentPageProjects) {
      setState(() {
        _currentPageProjects = page;
      });
      _applySortingProjects();
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
      child: Column(
        children: [
          Row(
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
                onPressed: _selectedTab == 'sheets' 
                    ? _refreshSheets 
                    : _selectedTab == 'stages' 
                        ? _refreshStages 
                        : _refreshProjects,
                tooltip: 'Обновить',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildChips(),
        ],
      ),
    );
  }

  /// Чипы для переключения между таблицами
  Widget _buildChips() {
    return Row(
      children: [
        _buildChip('ИД', 'sheets'),
        const SizedBox(width: 8),
        _buildChip('Этапы', 'stages'),
        const SizedBox(width: 8),
        _buildChip('Проекты', 'projects'),
      ],
    );
  }

  /// Отдельный чип
  Widget _buildChip(String label, String value) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = value;
          if (value == 'stages') {
            if (_stages.isEmpty && !_isLoadingStages) {
              _loadStages();
            }
            if (_stageStatuses.isEmpty && !_isLoadingStatuses) {
              _loadStageStatuses();
            }
          } else if (value == 'projects') {
            if (_projects.isEmpty && !_isLoadingProjects) {
              _loadProjects();
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentBlue.withOpacity(0.2)
              : AppColors.cardBackground.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.accentBlue
                : AppColors.borderColor.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.accentBlue
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Контент
  Widget _buildContent() {
    if (_selectedTab == 'sheets') {
      return _buildSheetsContent();
    } else if (_selectedTab == 'stages') {
      return _buildStagesContent();
    } else {
      return _buildProjectsContent();
    }
  }

  /// Контент для листов
  Widget _buildSheetsContent() {
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

  /// Контент для этапов
  Widget _buildStagesContent() {
    if (_isLoadingStages) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessageStages != null) {
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
              _errorMessageStages!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshStages,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_stages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Нет этапов',
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
      onRefresh: _refreshStages,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: _buildStagesTable(),
              ),
            ),
          ),
          _buildPaginationControlsStages(),
        ],
      ),
    );
  }

  /// Контент для проектов
  Widget _buildProjectsContent() {
    if (_isLoadingProjects) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessageProjects != null) {
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
              _errorMessageProjects!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshProjects,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Нет проектов',
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
      onRefresh: _refreshProjects,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: _buildProjectsTable(),
              ),
            ),
          ),
          _buildPaginationControlsProjects(),
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

  /// Построение таблицы этапов
  Widget _buildStagesTable() {
    final filteredStages = _applyFiltersStages();
    
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
          _buildDataColumnStages('Статус', 'status'),
          _buildDataColumnStages('Описание', 'description'),
          _buildDataColumnStages('Проект', 'project'),
          _buildDataColumnStages('Участок', 'constructionSite'),
          _buildDataColumnStages('Дата создания', 'createdAt'),
        ],
        rows: filteredStages.map((stage) => _buildDataRowStages(stage)).toList(),
      ),
    );
  }
  
  /// Построение колонки с сортировкой для этапов
  DataColumn _buildDataColumnStages(String label, String column) {
    final hasFilter = _columnFiltersStages[column]?.isNotEmpty ?? false;
    final isSearchActive = _activeFilterColumnsStages.contains(column);
    
    // Для столбца "Статус" показываем выпадающий список вместо поиска
    if (column == 'status') {
      final hasStatusFilter = _selectedStatusIds.isNotEmpty && 
          _selectedStatusIds.length < _stageStatuses.length;
      
      return DataColumn(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showStatusFilterDialog(),
              child: Icon(
                Icons.filter_list,
                size: 16,
                color: hasStatusFilter
                    ? AppColors.accentBlue
                    : AppColors.textSecondary,
              ),
            ),
            if (_sortColumnStages == column) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscendingStages ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: AppColors.accentBlue,
              ),
            ],
          ],
        ),
        onSort: (columnIndex, ascending) => _onSortStages(column),
      );
    }
    
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSearchActive) ...[
            SizedBox(
              width: 120,
              child: _buildSearchFieldInHeaderStages(column),
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
                  _activeFilterColumnsStages.add(column);
                  _columnFiltersStages[column] = '';
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
          if (_sortColumnStages == column && !isSearchActive) ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscendingStages ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppColors.accentBlue,
            ),
          ],
        ],
      ),
      onSort: (columnIndex, ascending) => _onSortStages(column),
    );
  }

  /// Показать диалог фильтра статусов
  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              title: const Text(
                'Фильтр по статусам',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 280,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: _stageStatuses.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _stageStatuses.length,
                        itemBuilder: (context, index) {
                          final status = _stageStatuses[index];
                          final isSelected = _selectedStatusIds.contains(status.id);
                          
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  _selectedStatusIds.remove(status.id);
                                } else {
                                  _selectedStatusIds.add(status.id);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setDialogState(() {
                                          if (value == true) {
                                            _selectedStatusIds.add(status.id);
                                          } else {
                                            _selectedStatusIds.remove(status.id);
                                          }
                                        });
                                      },
                                      activeColor: AppColors.accentBlue,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _parseColor(status.color),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      status.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      // Выбрать все
                      _selectedStatusIds = _stageStatuses
                          .map((s) => s.id)
                          .toSet();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: const Text(
                    'Все',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      // Снять все
                      _selectedStatusIds.clear();
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: const Text(
                    'Нет',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: const Text(
                    'Закрыть',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        // Обновляем UI после закрытия диалога
      });
    });
  }
  
  /// Поисковое поле в заголовке столбца для этапов
  Widget _buildSearchFieldInHeaderStages(String column) {
    // Создаём контроллер для этого столбца, если его ещё нет
    if (!_searchControllersStages.containsKey(column)) {
      _searchControllersStages[column] = TextEditingController(text: _columnFiltersStages[column] ?? '');
    }
    
    return TextField(
      key: ValueKey('search_header_stages_$column'),
      controller: _searchControllersStages[column],
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
              _activeFilterColumnsStages.remove(column);
              _columnFiltersStages.remove(column);
              _searchControllersStages[column]?.dispose();
              _searchControllersStages.remove(column);
            });
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _columnFiltersStages[column] = value;
        });
      },
    );
  }

  /// Построение строки таблицы этапов
  DataRow _buildDataRowStages(ProjectStageModel stage) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stage.status != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _parseColor(stage.status!.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  stage.status!.name,
                  style: TextStyle(
                    color: _parseColor(stage.status!.color),
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
            stage.description ?? '—',
            style: const TextStyle(color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          _buildClickableText(
            stage.project?.name ?? '—',
            null,
            () {
              if (stage.project != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailScreen(project: stage.project!),
                  ),
                );
              }
            },
          ),
        ),
        DataCell(
          _buildClickableText(
            stage.project?.constructionSite?.name ?? '—',
            null,
            () {
              if (stage.project?.constructionSite != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SiteProjectsScreen(
                      constructionSite: stage.project!.constructionSite!,
                    ),
                  ),
                );
              }
            },
          ),
        ),
        DataCell(
          Text(
            stage.createdAt != null
                ? _formatDate(stage.createdAt!)
                : '—',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  /// Построение таблицы проектов
  Widget _buildProjectsTable() {
    final filteredProjects = _applyFiltersProjects();
    
    // Обновляем общее количество для пагинации
    final totalFiltered = filteredProjects.length;
    final totalPages = (totalFiltered / _pageSize).ceil();
    if (totalPages > 0 && _currentPageProjects > totalPages) {
      // Если текущая страница больше доступных, сбрасываем на первую
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentPageProjects = 1;
          });
        }
      });
    }
    
    // Применяем клиентскую пагинацию
    final startIndex = ((_currentPageProjects - 1) * _pageSize).clamp(0, filteredProjects.length);
    final endIndex = (startIndex + _pageSize).clamp(0, filteredProjects.length);
    final paginatedProjects = startIndex < filteredProjects.length
        ? filteredProjects.sublist(startIndex, endIndex)
        : <ProjectModel>[];
    
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
          _buildDataColumnProjects('Наименование', 'name'),
          _buildDataColumnProjects('Описание', 'description'),
          _buildDataColumnProjects('ИД', 'completionPercentage'),
          _buildDataColumnProjects('Статус', 'status'),
          _buildDataColumnProjects('Строительный участок', 'constructionSite'),
        ],
        rows: paginatedProjects.map((project) => _buildDataRowProjects(project)).toList(),
      ),
    );
  }
  
  /// Построение колонки с сортировкой для проектов
  DataColumn _buildDataColumnProjects(String label, String column) {
    final hasFilter = _columnFiltersProjects[column]?.isNotEmpty ?? false;
    final isSearchActive = _activeFilterColumnsProjects.contains(column);
    
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (column == 'completionPercentage') ...[
            // Для колонки ИД не показываем поиск
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else if (isSearchActive) ...[
            SizedBox(
              width: 120,
              child: _buildSearchFieldInHeaderProjects(column),
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
                  _activeFilterColumnsProjects.add(column);
                  _columnFiltersProjects[column] = '';
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
          if (_sortColumnProjects == column && !isSearchActive && (column == 'completionPercentage' || column == 'status')) ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscendingProjects ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppColors.accentBlue,
            ),
          ] else if (_sortColumnProjects == column && !isSearchActive && column != 'completionPercentage' && column != 'status') ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscendingProjects ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppColors.accentBlue,
            ),
          ],
        ],
      ),
      onSort: (column == 'completionPercentage' || column == 'status' || !isSearchActive)
          ? (columnIndex, ascending) => _onSortProjects(column)
          : null,
    );
  }

  /// Поисковое поле в заголовке столбца для проектов
  Widget _buildSearchFieldInHeaderProjects(String column) {
    // Создаём контроллер для этого столбца, если его ещё нет
    if (!_searchControllersProjects.containsKey(column)) {
      _searchControllersProjects[column] = TextEditingController(text: _columnFiltersProjects[column] ?? '');
    }
    
    return TextField(
      key: ValueKey('search_header_projects_$column'),
      controller: _searchControllersProjects[column],
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
              _activeFilterColumnsProjects.remove(column);
              _columnFiltersProjects.remove(column);
              _searchControllersProjects[column]?.dispose();
              _searchControllersProjects.remove(column);
            });
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _columnFiltersProjects[column] = value;
        });
      },
    );
  }

  /// Построение строки таблицы проектов
  DataRow _buildDataRowProjects(ProjectModel project) {
    return DataRow(
      cells: [
        DataCell(
          _buildClickableText(
            project.name,
            null,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailScreen(project: project),
                ),
              );
            },
          ),
        ),
        DataCell(
          Text(
            project.description ?? '—',
            style: const TextStyle(color: AppColors.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Text(
            '${(project.completionPercentage ?? 0.0).toStringAsFixed(1)}%',
            style: TextStyle(
              color: _getPercentageColor(project.completionPercentage ?? 0.0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (project.lastStageStatus != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _parseColor(project.lastStageStatus!.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  project.lastStageStatus!.name,
                  style: TextStyle(
                    color: _parseColor(project.lastStageStatus!.color),
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
          _buildClickableText(
            project.constructionSite?.name ?? '—',
            null,
            () {
              if (project.constructionSite != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SiteProjectsScreen(
                      constructionSite: project.constructionSite!,
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  /// Построение элементов управления пагинацией для проектов
  Widget _buildPaginationControlsProjects() {
    final filteredProjects = _applyFiltersProjects();
    final totalFiltered = filteredProjects.length;
    final totalPages = (totalFiltered / _pageSize).ceil();
    
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final startItem = ((_currentPageProjects - 1) * _pageSize) + 1;
    final endItem = (_currentPageProjects * _pageSize).clamp(0, totalFiltered);

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
            'Показано $startItem-$endItem из $totalFiltered',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: _currentPageProjects > 1 ? AppColors.textPrimary : AppColors.textTertiary,
                onPressed: _currentPageProjects > 1 ? () => _goToPageProjects(_currentPageProjects - 1) : null,
                tooltip: 'Предыдущая',
              ),
              Text(
                '$_currentPageProjects / $totalPages',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: _currentPageProjects < totalPages ? AppColors.textPrimary : AppColors.textTertiary,
                onPressed: _currentPageProjects < totalPages ? () => _goToPageProjects(_currentPageProjects + 1) : null,
                tooltip: 'Следующая',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Построение элементов управления пагинацией для этапов
  Widget _buildPaginationControlsStages() {
    if (_totalPagesStages <= 1) {
      return const SizedBox.shrink();
    }

    final startItem = ((_currentPageStages - 1) * _pageSize) + 1;
    final endItem = (_currentPageStages * _pageSize).clamp(0, _totalCountStages);

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
            'Показано $startItem-$endItem из $_totalCountStages',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: _currentPageStages > 1 ? AppColors.textPrimary : AppColors.textTertiary,
                onPressed: _currentPageStages > 1 ? () => _goToPageStages(_currentPageStages - 1) : null,
                tooltip: 'Предыдущая',
              ),
              Text(
                '$_currentPageStages / $_totalPagesStages',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: _currentPageStages < _totalPagesStages ? AppColors.textPrimary : AppColors.textTertiary,
                onPressed: _currentPageStages < _totalPagesStages ? () => _goToPageStages(_currentPageStages + 1) : null,
                tooltip: 'Следующая',
              ),
            ],
          ),
        ],
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

  /// Получение цвета для процента выполнения (от красного 0% до зеленого 100%)
  Color _getPercentageColor(double percentage) {
    // Ограничиваем процент в диапазоне 0-100
    final clampedPercentage = percentage.clamp(0.0, 100.0);
    
    // Вычисляем компоненты цвета
    // Красный: от 255 (0%) до 0 (100%)
    final red = (255 * (1 - clampedPercentage / 100)).round();
    // Зеленый: от 0 (0%) до 255 (100%)
    final green = (255 * (clampedPercentage / 100)).round();
    // Синий: 0 для чистого красного/зеленого
    final blue = 0;
    
    return Color.fromRGBO(red, green, blue, 1.0);
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
