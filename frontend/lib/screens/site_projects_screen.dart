import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/progress_bars.dart' as progress_bars;
import 'project_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProjects();
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
    }
  }

  /// Обновление списка
  Future<void> _refreshProjects() async {
    await _loadProjects();
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
          : ListView.builder(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12 : 16),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                return _ProjectCard(
                  project: _projects[index],
                  constructionSite: widget.constructionSite,
                  onRefresh: () => _refreshProjects(),
                  onProjectUpdated: (updatedProject) => _updateProject(updatedProject),
                );
              },
            ),
    );
  }
}

/// Карточка проекта
class _ProjectCard extends StatefulWidget {
  final ProjectModel project;
  final ConstructionSiteModel constructionSite;
  final VoidCallback? onRefresh;
  final Function(ProjectModel)? onProjectUpdated;

  const _ProjectCard({
    required this.project,
    required this.constructionSite,
    this.onRefresh,
    this.onProjectUpdated,
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
            // Иконка проекта
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
                  ),
                ],
              ),
            ),
            // Кнопка редактирования
            _ActionButton(
              icon: Icons.edit,
              color: AppColors.accentBlue,
              onTap: () => _showEditDialog(context),
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

