import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/progress_bars.dart' as progress_bars;
import 'project_detail_screen.dart';

/// Фильтр по статусу выполнения
enum CompletionFilter {
  all,
  completed,
  incomplete,
}

/// Фильтр по листам
enum SheetsFilter {
  all,
  completed,
  incomplete,
}

/// Экран проектов строительного участка
class SiteProjectsScreen extends StatefulWidget {
  final ConstructionSiteModel constructionSite;

  const SiteProjectsScreen({
    super.key,
    required this.constructionSite,
  });

  @override
  State<SiteProjectsScreen> createState() => _SiteProjectsScreenState();
}

class _SiteProjectsScreenState extends State<SiteProjectsScreen> {
  List<ProjectModel> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Сводная статистика
  double? _averageCompletionPercentage;
  List<progress_bars.DepartmentCompletionStats> _summaryDepartmentStats = [];
  bool _isLoadingSummaryStats = false;
  
  // Фильтрация
  List<DepartmentModel> _departments = [];
  Map<int, int> _departmentTotalSheets = {}; // departmentId -> total sheets
  Map<int, int> _departmentIncompleteSheets = {}; // departmentId -> incomplete sheets
  Map<int, Set<int>> _departmentProjects = {}; // departmentId -> Set of projectIds
  int? _selectedDepartmentId;
  CompletionFilter _completionFilter = CompletionFilter.all;
  SheetsFilter _sheetsFilter = SheetsFilter.all;
  Map<int, bool> _projectHasCompletedSheets = {}; // projectId -> has completed sheets
  Map<int, bool> _projectHasIncompleteSheets = {}; // projectId -> has incomplete sheets
  bool _isLoadingDepartments = false;
  
  // Отдел текущего пользователя
  int? _currentUserDepartmentId;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadDepartments();
    _loadCurrentUserDepartment();
  }

  /// Загрузка проектов участка
  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getProjects(
      constructionSiteId: widget.constructionSite.id,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'];
          if (data is List) {
            _projects = data
                .map((json) => ProjectModel.fromJson(json as Map<String, dynamic>))
                .toList();
          } else {
            _projects = [];
            _errorMessage = 'Неверный формат данных от сервера';
          }
        } else {
          _errorMessage = result['error'] ?? 'Ошибка загрузки проектов';
        }
      });
      // Загружаем статистику после загрузки проектов
      _loadSummaryStats();
    }
  }

  /// Обновление списка
  Future<void> _refreshProjects() async {
    await _loadProjects();
    _loadSummaryStats();
    _loadDepartments();
  }

  /// Загрузка отдела текущего пользователя
  Future<void> _loadCurrentUserDepartment() async {
    final user = await ApiService.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        if (user['department_id'] != null) {
          _currentUserDepartmentId = user['department_id'] as int;
        } else {
          _currentUserDepartmentId = null;
        }
      });
    }
  }

  /// Загрузка сводной статистики по всем проектам
  Future<void> _loadSummaryStats() async {
    if (mounted) {
      setState(() {
        _isLoadingSummaryStats = true;
      });
    }

    try {
      // Вычисляем средний процент выполнения
      double totalPercentage = 0.0;
      int projectsWithPercentage = 0;
      for (final project in _projects) {
        if (project.completionPercentage != null) {
          totalPercentage += project.completionPercentage!;
          projectsWithPercentage++;
        }
      }
      final averagePercentage = projectsWithPercentage > 0
          ? totalPercentage / projectsWithPercentage
          : 0.0;

      // Агрегируем статистику по отделам из всех проектов
      final Map<int, progress_bars.DepartmentCompletionStats> statsMap = {};
      final Map<int, Set<int>> departmentProjects = {}; // departmentId -> Set of projectIds
      final Map<int, bool> projectHasCompletedSheets = {}; // projectId -> has completed sheets
      final Map<int, bool> projectHasIncompleteSheets = {}; // projectId -> has incomplete sheets
      int totalIncompleteSheets = 0;

      for (final project in _projects) {
        int currentPage = 1;
        bool hasMore = true;
        bool hasCompleted = false;
        bool hasIncomplete = false;

        while (hasMore && mounted) {
          final result = await ApiService.getProjectSheets(
            project.id,
            page: currentPage,
            pageSize: 100,
          );

          if (result['success'] == true) {
            final data = result['data'];
            if (data is List) {
              final pageSheets = data
                  .map((s) => ProjectSheetModel.fromJson(s as Map<String, dynamic>))
                  .toList();

              for (final sheet in pageSheets) {
                // Отслеживаем наличие выполненных/невыполненных листов в проекте
                if (sheet.isCompleted) {
                  hasCompleted = true;
                } else {
                  hasIncomplete = true;
                }

                if (sheet.responsibleDepartment != null) {
                  final deptId = sheet.responsibleDepartment!.id;

                  // Сохраняем информацию о проекте для отдела
                  if (!departmentProjects.containsKey(deptId)) {
                    departmentProjects[deptId] = <int>{};
                  }
                  departmentProjects[deptId]!.add(project.id);

                  if (!statsMap.containsKey(deptId)) {
                    statsMap[deptId] = progress_bars.DepartmentCompletionStats(
                      departmentId: deptId,
                      departmentName: sheet.responsibleDepartment!.name,
                      departmentColor: sheet.responsibleDepartment!.color,
                      totalSheets: 0,
                      completedSheets: 0,
                      incompleteSheets: 0,
                      completionPercentage: 0.0,
                      incompletePercentage: 0.0,
                    );
                  }

                  final stats = statsMap[deptId]!;
                  final isCompleted = sheet.isCompleted;
                  final isIncomplete = !isCompleted;

                  statsMap[deptId] = progress_bars.DepartmentCompletionStats(
                    departmentId: stats.departmentId,
                    departmentName: stats.departmentName,
                    departmentColor: stats.departmentColor,
                    totalSheets: stats.totalSheets + 1,
                    completedSheets: stats.completedSheets + (isCompleted ? 1 : 0),
                    incompleteSheets: stats.incompleteSheets + (isIncomplete ? 1 : 0),
                    completionPercentage: 0.0,
                    incompletePercentage: 0.0,
                  );

                  if (isIncomplete) {
                    totalIncompleteSheets++;
                  }
                }
              }
            }

            final pagination = result['pagination'] as Map<String, dynamic>?;
            if (pagination != null) {
              hasMore = pagination['hasNext'] == true;
              currentPage++;
            } else {
              hasMore = false;
            }
          } else {
            hasMore = false;
          }
        }

        // Сохраняем информацию о листах проекта
        projectHasCompletedSheets[project.id] = hasCompleted;
        projectHasIncompleteSheets[project.id] = hasIncomplete;
      }

      // Вычисляем проценты
      final List<progress_bars.DepartmentCompletionStats> statsList = [];
      for (final stats in statsMap.values) {
        final completionPercentage = stats.totalSheets > 0
            ? (stats.completedSheets / stats.totalSheets) * 100
            : 0.0;

        final incompletePercentage = totalIncompleteSheets > 0
            ? (stats.incompleteSheets / totalIncompleteSheets) * 100
            : 0.0;

        statsList.add(progress_bars.DepartmentCompletionStats(
          departmentId: stats.departmentId,
          departmentName: stats.departmentName,
          departmentColor: stats.departmentColor,
          totalSheets: stats.totalSheets,
          completedSheets: stats.completedSheets,
          incompleteSheets: stats.incompleteSheets,
          completionPercentage: completionPercentage,
          incompletePercentage: incompletePercentage,
        ));
      }

      statsList.sort((a, b) => b.incompleteSheets.compareTo(a.incompleteSheets));

      if (mounted) {
        setState(() {
          _averageCompletionPercentage = averagePercentage;
          _summaryDepartmentStats = statsList;
          _departmentProjects = departmentProjects;
          _projectHasCompletedSheets = projectHasCompletedSheets;
          _projectHasIncompleteSheets = projectHasIncompleteSheets;
          _isLoadingSummaryStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _averageCompletionPercentage = null;
          _summaryDepartmentStats = [];
          _isLoadingSummaryStats = false;
        });
      }
    }
  }

  /// Загрузка отделов и подсчет статистики
  Future<void> _loadDepartments() async {
    if (mounted) {
      setState(() {
        _isLoadingDepartments = true;
      });
    }

    try {
      final result = await ApiService.getDepartments();
      if (mounted && result['success'] == true) {
        final data = result['data'] as List;
        final departments = data
            .map((d) => DepartmentModel.fromJson(d as Map<String, dynamic>))
            .toList();

        // Подсчитываем статистику по отделам
        final Map<int, int> totalSheets = {};
        final Map<int, int> incompleteSheets = {};

        for (final project in _projects) {
          int currentPage = 1;
          bool hasMore = true;

          while (hasMore && mounted) {
            final result = await ApiService.getProjectSheets(
              project.id,
              page: currentPage,
              pageSize: 100,
            );

            if (result['success'] == true) {
              final data = result['data'];
              if (data is List) {
                final pageSheets = data
                    .map((s) => ProjectSheetModel.fromJson(s as Map<String, dynamic>))
                    .toList();

                for (final sheet in pageSheets) {
                  if (sheet.responsibleDepartment != null) {
                    final deptId = sheet.responsibleDepartment!.id;
                    totalSheets[deptId] = (totalSheets[deptId] ?? 0) + 1;
                    if (!sheet.isCompleted) {
                      incompleteSheets[deptId] = (incompleteSheets[deptId] ?? 0) + 1;
                    }
                  }
                }
              }

              final pagination = result['pagination'] as Map<String, dynamic>?;
              if (pagination != null) {
                hasMore = pagination['hasNext'] == true;
                currentPage++;
              } else {
                hasMore = false;
              }
            } else {
              hasMore = false;
            }
          }
        }

        if (mounted) {
          setState(() {
            _departments = departments;
            _departmentTotalSheets = totalSheets;
            _departmentIncompleteSheets = incompleteSheets;
            _isLoadingDepartments = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingDepartments = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDepartments = false;
        });
      }
    }
  }

  /// Проверка соответствия проекта фильтру по статусу выполнения
  bool _projectMatchesCompletionFilter(ProjectModel project) {
    if (_completionFilter == CompletionFilter.all) {
      return true;
    }
    
    final percentage = project.completionPercentage;
    
    if (_completionFilter == CompletionFilter.completed) {
      // Проект выполнен, если процент равен 100
      return percentage != null && (percentage >= 100.0 || percentage >= 99.9);
    } else if (_completionFilter == CompletionFilter.incomplete) {
      // Проект не выполнен, если процент меньше 100 или null
      return percentage == null || percentage < 99.9;
    }
    
    return true;
  }

  /// Проверка соответствия проекта фильтру по листам
  bool _projectMatchesSheetsFilter(ProjectModel project) {
    if (_sheetsFilter == SheetsFilter.all) {
      return true;
    }

    // Если данные еще загружаются, не применяем фильтр
    if (_isLoadingSummaryStats) {
      return true;
    }

    // Если выбран отдел, проверяем листы этого отдела
    if (_selectedDepartmentId != null) {
      // Если данные отделов еще загружаются, не применяем фильтр
      if (_isLoadingDepartments) {
        return true;
      }
      
      if (_departmentProjects.isNotEmpty) {
        final projectIds = _departmentProjects[_selectedDepartmentId];
        
        // Проверяем, принадлежит ли проект отделу
        if (projectIds == null || !projectIds.contains(project.id)) {
          return false;
        }

        final totalSheets = _departmentTotalSheets[_selectedDepartmentId] ?? 0;
        final incompleteSheets = _departmentIncompleteSheets[_selectedDepartmentId] ?? 0;
        final completedSheets = totalSheets - incompleteSheets;

        if (_sheetsFilter == SheetsFilter.completed) {
          // Показываем только если у отдела есть выполненные листы
          return completedSheets > 0;
        } else if (_sheetsFilter == SheetsFilter.incomplete) {
          // Показываем только если у отдела есть невыполненные листы
          return incompleteSheets > 0;
        }
      }
      // Если данные отделов еще не загружены, не применяем фильтр
      return true;
    }

    // Если отдел не выбран, проверяем листы проекта в целом
    // Проверяем, есть ли данные для этого проекта
    final hasCompleted = _projectHasCompletedSheets[project.id];
    final hasIncomplete = _projectHasIncompleteSheets[project.id];
    
    // Если данных нет для проекта, показываем его (данные еще загружаются)
    // Данные должны быть загружены для всех проектов после завершения _loadSummaryStats
    if (hasCompleted == null || hasIncomplete == null) {
      // Если данные еще не загружены для этого проекта, показываем его
      return true;
    }

    if (_sheetsFilter == SheetsFilter.completed) {
      // Показываем проекты с выполненными листами
      return hasCompleted;
    } else if (_sheetsFilter == SheetsFilter.incomplete) {
      // Показываем проекты с невыполненными листами
      return hasIncomplete;
    }

    return true;
  }

  /// Проверка соответствия проекта фильтру по отделу с учетом статуса выполнения
  bool _projectMatchesDepartmentFilter(ProjectModel project) {
    // Если отдел не выбран, фильтр по отделу не применяется
    if (_selectedDepartmentId == null) {
      return true;
    }

    // Если данные еще загружаются, не применяем фильтр по отделу
    if (_isLoadingSummaryStats || _departmentProjects.isEmpty) {
      return true;
    }

    final projectIds = _departmentProjects[_selectedDepartmentId];
    
    // Если у отдела нет проектов, проект не проходит фильтр
    if (projectIds == null || projectIds.isEmpty) {
      return false;
    }

    // Проверяем, принадлежит ли проект отделу
    if (!projectIds.contains(project.id)) {
      return false;
    }

    // Если выбран отдел, дополнительно проверяем статус выполнения задач отдела
    // в зависимости от активного фильтра по статусу
    if (_completionFilter == CompletionFilter.incomplete) {
      // Для фильтра "Не выполнено": показываем только если у отдела есть невыполненные задачи
      final incompleteSheets = _departmentIncompleteSheets[_selectedDepartmentId] ?? 0;
      return incompleteSheets > 0;
    } else if (_completionFilter == CompletionFilter.completed) {
      // Для фильтра "Выполнено": показываем только если у отдела все задачи выполнены
      final totalSheets = _departmentTotalSheets[_selectedDepartmentId] ?? 0;
      final incompleteSheets = _departmentIncompleteSheets[_selectedDepartmentId] ?? 0;
      return totalSheets > 0 && incompleteSheets == 0;
    }

    // Для фильтра "Все" просто проверяем принадлежность проекту
    return true;
  }

  /// Получить отфильтрованные проекты
  List<ProjectModel> _getFilteredProjects() {
    // Если проекты еще не загружены, возвращаем пустой список
    if (_projects.isEmpty) {
      return [];
    }

    // Применяем все фильтры совместно
    return _projects.where((project) {
      // Проект должен соответствовать всем фильтрам
      return _projectMatchesCompletionFilter(project) && 
             _projectMatchesSheetsFilter(project) &&
             _projectMatchesDepartmentFilter(project);
    }).toList();
  }

  /// Обновление одного проекта в списке
  void _updateProject(ProjectModel updatedProject) {
    setState(() {
      final index = _projects.indexWhere((p) => p.id == updatedProject.id);
      if (index != -1) {
        _projects[index] = updatedProject;
      }
    });
  }

  /// Показать диалог добавления проекта
  Future<void> _showAddProjectDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ProjectFormDialog(
        constructionSite: widget.constructionSite,
        onRefresh: _refreshProjects,
      ),
    );
    
    if (result != null && result['success'] == true) {
      _refreshProjects();
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

  /// Заголовок
  Widget _buildHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            color: AppColors.textPrimary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Icon(
            Icons.folder,
            color: AppColors.accentBlue,
            size: isMobile ? 24 : 28,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Проекты участка',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.constructionSite.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (!isMobile) ...[
            ElevatedButton.icon(
              onPressed: () => _showAddProjectDialog(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Добавить проект'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: _refreshProjects,
            icon: Icon(Icons.refresh, size: isMobile ? 20 : 24),
            tooltip: 'Обновить',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: AppColors.textPrimary,
              padding: EdgeInsets.all(isMobile ? 8 : 12),
            ),
          ),
          if (isMobile) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _showAddProjectDialog(context),
              icon: const Icon(Icons.add),
              tooltip: 'Добавить проект',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _projects.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _projects.isEmpty) {
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
              onPressed: _refreshProjects,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final filteredProjects = _getFilteredProjects();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return RefreshIndicator(
      onRefresh: _refreshProjects,
      child: _projects.isEmpty
          ? Center(
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
                    'Проекты не найдены',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              children: [
                _buildSummaryBlock(isMobile),
                const SizedBox(height: 16),
                _buildFiltersBlock(isMobile),
                const SizedBox(height: 16),
                if (filteredProjects.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.filter_alt_off,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Нет проектов, соответствующих фильтрам',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredProjects.map((project) => _ProjectCard(
                        key: ValueKey(project.id),
                        project: project,
                        constructionSite: widget.constructionSite,
                        onRefresh: () => _refreshProjects(),
                        onProjectUpdated: (updatedProject) => _updateProject(updatedProject),
                        currentUserDepartmentId: _currentUserDepartmentId,
                      )),
              ],
            ),
    );
  }

  /// Сводный блок статистики
  Widget _buildSummaryBlock(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: AppColors.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Сводная информация',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            progress_bars.OverallProgressBar(
              completionPercentage: _averageCompletionPercentage,
              compact: false,
            ),
            const SizedBox(height: 16),
            progress_bars.DepartmentProgressBar(
              departmentStats: _summaryDepartmentStats,
              isLoading: _isLoadingSummaryStats,
              compact: false,
              showLegend: true,
              currentUserDepartmentId: _currentUserDepartmentId,
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: progress_bars.OverallProgressBar(
                    completionPercentage: _averageCompletionPercentage,
                    compact: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: progress_bars.DepartmentProgressBar(
                    departmentStats: _summaryDepartmentStats,
                    isLoading: _isLoadingSummaryStats,
                    compact: false,
                    showLegend: true,
                    currentUserDepartmentId: _currentUserDepartmentId,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Блок фильтров
  Widget _buildFiltersBlock(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompletionFilter(isMobile),
        const SizedBox(height: 12),
        _buildDepartmentFilter(isMobile),
      ],
    );
  }

  /// Фильтр по статусу выполнения и листам
  Widget _buildCompletionFilter(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildFilterGroup(
              title: 'Статусы',
              icon: Icons.filter_list,
              child: _buildStatusFilterRow(isMobile),
              isMobile: isMobile,
            ),
          ),
          Container(
            width: 1,
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
            color: AppColors.borderColor.withOpacity(0.3),
          ),
          Expanded(
            child: _buildFilterGroup(
              title: 'Листы',
              icon: Icons.description,
              child: _buildSheetsFilterRow(isMobile),
              isMobile: isMobile,
            ),
          ),
        ],
      ),
    );
  }

  /// Группа фильтров с заголовком
  Widget _buildFilterGroup({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: isMobile ? 18 : 20,
              color: AppColors.accentBlue,
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 12),
        child,
      ],
    );
  }

  /// Строка фильтра по статусу
  Widget _buildStatusFilterRow(bool isMobile) {
    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: isMobile ? 8 : 12,
      children: [
        _buildFilterIcon(
          icon: Icons.filter_list,
          label: 'Все',
          isSelected: _completionFilter == CompletionFilter.all,
          isMobile: isMobile,
          onTap: () {
            setState(() {
              _completionFilter = CompletionFilter.all;
            });
          },
        ),
        _buildFilterIcon(
          icon: Icons.check_circle,
          label: 'Выполнено',
          isSelected: _completionFilter == CompletionFilter.completed,
          isMobile: isMobile,
          onTap: () {
            setState(() {
              _completionFilter = CompletionFilter.completed;
            });
          },
        ),
        _buildFilterIcon(
          icon: Icons.cancel,
          label: 'Не выполнено',
          isSelected: _completionFilter == CompletionFilter.incomplete,
          isMobile: isMobile,
          onTap: () {
            setState(() {
              _completionFilter = CompletionFilter.incomplete;
            });
          },
        ),
      ],
    );
  }

  /// Строка фильтра по листам
  Widget _buildSheetsFilterRow(bool isMobile) {
    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: isMobile ? 8 : 12,
      children: [
        _buildFilterIcon(
          icon: Icons.filter_list,
          label: 'Все',
          isSelected: _sheetsFilter == SheetsFilter.all,
          isMobile: isMobile,
          onTap: () {
            setState(() {
              _sheetsFilter = SheetsFilter.all;
            });
          },
        ),
        _buildFilterIcon(
          icon: Icons.check_circle,
          label: 'Выполненные',
          isSelected: _sheetsFilter == SheetsFilter.completed,
          isMobile: isMobile,
          onTap: () {
            setState(() {
              _sheetsFilter = SheetsFilter.completed;
            });
          },
        ),
        _buildFilterIcon(
          icon: Icons.cancel,
          label: 'Не выполненные',
          isSelected: _sheetsFilter == SheetsFilter.incomplete,
          isMobile: isMobile,
          onTap: () {
            setState(() {
              _sheetsFilter = SheetsFilter.incomplete;
            });
          },
        ),
      ],
    );
  }

  /// Иконка фильтра
  Widget _buildFilterIcon({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isMobile = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentBlue.withOpacity(0.3)
              : AppColors.cardBackground.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentBlue : AppColors.borderColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: isMobile ? 20 : 22,
          color: isSelected ? AppColors.accentBlue : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Фильтр по отделам
  Widget _buildDepartmentFilter(bool isMobile) {
    if (_isLoadingDepartments) {
      return Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderColor.withOpacity(0.3),
          ),
        ),
        child: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text(
              'Загрузка отделов...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.business,
                color: AppColors.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Фильтр по отделам:',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Кнопка "Все отделы"
              _buildDepartmentChip(
                department: null,
                isSelected: _selectedDepartmentId == null,
                onTap: () {
                  setState(() {
                    _selectedDepartmentId = null;
                  });
                },
              ),
              // Отделы
              ..._departments.map((dept) {
                final totalSheets = _departmentTotalSheets[dept.id] ?? 0;
                final incompleteSheets = _departmentIncompleteSheets[dept.id] ?? 0;
                final deptId = dept.id;
                return _buildDepartmentChip(
                  department: dept,
                  totalSheets: totalSheets,
                  incompleteSheets: incompleteSheets,
                  isSelected: _selectedDepartmentId == deptId,
                  onTap: () {
                    setState(() {
                      _selectedDepartmentId = deptId;
                    });
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Чип отдела
  Widget _buildDepartmentChip({
    DepartmentModel? department,
    int totalSheets = 0,
    int incompleteSheets = 0,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = department != null
        ? _parseColor(department.color)
        : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.3)
              : AppColors.cardBackground.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.borderColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (department != null) ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              department?.name ?? 'Все отделы',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (department != null && totalSheets > 0) ...[
              const SizedBox(width: 6),
              Text(
                '($totalSheets/$incompleteSheets)',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? color.withOpacity(0.8) : AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
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

/// Карточка проекта
class _ProjectCard extends StatefulWidget {
  final ProjectModel project;
  final ConstructionSiteModel constructionSite;
  final VoidCallback? onRefresh;
  final Function(ProjectModel)? onProjectUpdated;
  final int? currentUserDepartmentId;

  const _ProjectCard({
    super.key,
    required this.project,
    required this.constructionSite,
    this.onRefresh,
    this.onProjectUpdated,
    this.currentUserDepartmentId,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _isLoadingDepartmentStats = false;
  List<progress_bars.DepartmentCompletionStats> _departmentStats = [];
  ProjectStageModel? _lastStage;

  @override
  void initState() {
    super.initState();
    _loadDepartmentStats();
    _loadLastStage();
  }

  /// Загрузка последнего этапа проекта
  Future<void> _loadLastStage() async {
    try {
      final result = await ApiService.getProjectStages(
        widget.project.id,
        page: 1,
        pageSize: 1,
      );

      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            final data = result['data'] as List?;
            if (data != null && data.isNotEmpty) {
              _lastStage = ProjectStageModel.fromJson(data[0] as Map<String, dynamic>);
            } else {
              _lastStage = null;
            }
          } else {
            _lastStage = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastStage = null;
        });
      }
    }
  }

  /// Загрузка статистики по отделам
  /// Загружает полные данные проекта независимо от фильтров на странице
  Future<void> _loadDepartmentStats() async {
    if (mounted) {
      setState(() {
        _isLoadingDepartmentStats = true;
      });
    }

    try {
      List<ProjectSheetModel> allSheets = [];
      int currentPage = 1;
      bool hasMore = true;
      
      // Загружаем все листы проекта напрямую из API
      // Это гарантирует, что карточка показывает полные данные проекта,
      // независимо от фильтров на странице
      while (hasMore && mounted) {
        final result = await ApiService.getProjectSheets(
          widget.project.id,
          page: currentPage,
          pageSize: 100,
        );

        if (result['success'] == true) {
          final data = result['data'];
          
          if (data is List) {
            final pageSheets = data
                .map((s) => ProjectSheetModel.fromJson(s as Map<String, dynamic>))
                .toList();
            allSheets.addAll(pageSheets);
          }
          
          final pagination = result['pagination'] as Map<String, dynamic>?;
          if (pagination != null) {
            hasMore = pagination['hasNext'] == true;
            currentPage++;
          } else {
            hasMore = false;
          }
        } else {
          hasMore = false;
        }
      }

      if (mounted) {
        final Map<int, progress_bars.DepartmentCompletionStats> statsMap = {};
        int totalIncompleteSheets = 0;
        
        for (final sheet in allSheets) {
          if (sheet.responsibleDepartment != null) {
            final deptId = sheet.responsibleDepartment!.id;
            
            if (!statsMap.containsKey(deptId)) {
              statsMap[deptId] = progress_bars.DepartmentCompletionStats(
                departmentId: deptId,
                departmentName: sheet.responsibleDepartment!.name,
                departmentColor: sheet.responsibleDepartment!.color,
                totalSheets: 0,
                completedSheets: 0,
                incompleteSheets: 0,
                completionPercentage: 0.0,
                incompletePercentage: 0.0,
              );
            }
            
            final stats = statsMap[deptId]!;
            final isCompleted = sheet.isCompleted;
            final isIncomplete = !isCompleted;
            
            statsMap[deptId] = progress_bars.DepartmentCompletionStats(
              departmentId: stats.departmentId,
              departmentName: stats.departmentName,
              departmentColor: stats.departmentColor,
              totalSheets: stats.totalSheets + 1,
              completedSheets: stats.completedSheets + (isCompleted ? 1 : 0),
              incompleteSheets: stats.incompleteSheets + (isIncomplete ? 1 : 0),
              completionPercentage: 0.0,
              incompletePercentage: 0.0,
            );
            
            if (isIncomplete) {
              totalIncompleteSheets++;
            }
          }
        }

        final List<progress_bars.DepartmentCompletionStats> statsList = [];
        for (final stats in statsMap.values) {
          final completionPercentage = stats.totalSheets > 0
              ? (stats.completedSheets / stats.totalSheets) * 100
              : 0.0;
          
          final incompletePercentage = totalIncompleteSheets > 0
              ? (stats.incompleteSheets / totalIncompleteSheets) * 100
              : 0.0;
          
          statsList.add(progress_bars.DepartmentCompletionStats(
            departmentId: stats.departmentId,
            departmentName: stats.departmentName,
            departmentColor: stats.departmentColor,
            totalSheets: stats.totalSheets,
            completedSheets: stats.completedSheets,
            incompleteSheets: stats.incompleteSheets,
            completionPercentage: completionPercentage,
            incompletePercentage: incompletePercentage,
          ));
        }

        statsList.sort((a, b) => b.incompleteSheets.compareTo(a.incompleteSheets));

        if (mounted) {
          setState(() {
            _departmentStats = statsList;
            _isLoadingDepartmentStats = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _departmentStats = [];
          _isLoadingDepartmentStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailScreen(
                project: widget.project,
              ),
            ),
          );
          
          // Обновляем проект после возврата из детального экрана
          if (widget.onProjectUpdated != null) {
            try {
              final projectResult = await ApiService.getProject(widget.project.id);
              if (projectResult['success'] == true) {
                final projectData = projectResult['data'] as Map<String, dynamic>;
                final updatedProject = ProjectModel.fromJson(projectData);
                widget.onProjectUpdated!(updatedProject);
                // Перезагружаем статистику по отделам и последний этап
                _loadDepartmentStats();
                _loadLastStage();
              }
            } catch (e) {
              // Игнорируем ошибки при обновлении
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                // Иконка проекта и кнопка редактирования
                Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentBlue,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.folder,
                        size: 32,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ActionButton(
                      icon: Icons.edit,
                      color: AppColors.accentBlue,
                      onTap: () => _showEditDialog(context),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Информация о проекте
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.project.description != null &&
                          widget.project.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.project.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.tag,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Код: ${widget.project.code}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.code,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Шифр: ${widget.project.cipher}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Общая шкала выполнения
                      progress_bars.OverallProgressBar(
                        completionPercentage: widget.project.completionPercentage,
                        compact: true,
                        status: _lastStage?.status,
                      ),
                      const SizedBox(height: 8),
                      // Шкала по отделам
                      progress_bars.DepartmentProgressBar(
                        departmentStats: _departmentStats,
                        isLoading: _isLoadingDepartmentStats,
                        compact: true,
                        showLegend: false,
                        currentUserDepartmentId: widget.currentUserDepartmentId,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Показать диалог редактирования
  Future<void> _showEditDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ProjectFormDialog(
        project: widget.project,
        constructionSite: widget.constructionSite,
        onRefresh: widget.onRefresh,
      ),
    );
    if (result != null && result['success'] == true && widget.onRefresh != null) {
      widget.onRefresh!();
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

