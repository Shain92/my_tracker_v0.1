import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../widgets/construction_site_form_dialog.dart';
import '../widgets/progress_bars.dart' as progress_bars;
import 'site_projects_screen.dart';

/// Экран изыскательских данных (ИД) - список строительных участков
class ProjectIdScreen extends StatefulWidget {
  const ProjectIdScreen({super.key});

  @override
  State<ProjectIdScreen> createState() => _ProjectIdScreenState();
}

class _ProjectIdScreenState extends State<ProjectIdScreen> {
  List<ConstructionSiteModel> _constructionSites = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentUserDepartmentId;

  @override
  void initState() {
    super.initState();
    _loadConstructionSites();
    _loadCurrentUserDepartment();
  }

  /// Загрузка списка строительных участков
  Future<void> _loadConstructionSites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getConstructionSites();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'] as List;
          _constructionSites = data
              .map((json) => ConstructionSiteModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          _errorMessage = result['error'] ?? 'Ошибка загрузки участков';
        }
      });
    }
  }

  /// Обновление списка
  Future<void> _refreshConstructionSites() async {
    await _loadConstructionSites();
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

  /// Обновление одного участка в списке
  void _updateConstructionSite(ConstructionSiteModel updatedSite) {
    setState(() {
      final index = _constructionSites.indexWhere((s) => s.id == updatedSite.id);
      if (index != -1) {
        _constructionSites[index] = updatedSite;
      }
    });
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
            Icons.construction,
            color: AppColors.accentBlue,
            size: isMobile ? 24 : 28,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              'Строительные участки',
              style: TextStyle(
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (!isMobile) ...[
            ElevatedButton.icon(
              onPressed: () => _showAddConstructionSiteDialog(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Добавить участок'),
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
            onPressed: _refreshConstructionSites,
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
              onPressed: () => _showAddConstructionSiteDialog(context),
              icon: const Icon(Icons.add),
              tooltip: 'Добавить участок',
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

  /// Показать диалог добавления участка
  Future<void> _showAddConstructionSiteDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => const ConstructionSiteFormDialog(),
    );
    
    if (result != null && result['success'] == true) {
      _refreshConstructionSites();
    }
  }

  Widget _buildContent() {
    if (_isLoading && _constructionSites.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _constructionSites.isEmpty) {
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
              onPressed: _refreshConstructionSites,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshConstructionSites,
      child: _constructionSites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.construction_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Строительные участки не найдены',
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
              itemCount: _constructionSites.length,
              itemBuilder: (context, index) {
                return _ConstructionSiteCard(
                  constructionSite: _constructionSites[index],
                  onRefresh: () => _refreshConstructionSites(),
                  onConstructionSiteUpdated: (updatedSite) => _updateConstructionSite(updatedSite),
                  currentUserDepartmentId: _currentUserDepartmentId,
                );
              },
            ),
    );
  }
}

/// Карточка строительного участка
class _ConstructionSiteCard extends StatefulWidget {
  final ConstructionSiteModel constructionSite;
  final VoidCallback? onRefresh;
  final Function(ConstructionSiteModel)? onConstructionSiteUpdated;
  final int? currentUserDepartmentId;

  const _ConstructionSiteCard({
    required this.constructionSite,
    this.onRefresh,
    this.onConstructionSiteUpdated,
    this.currentUserDepartmentId,
  });

  @override
  State<_ConstructionSiteCard> createState() => _ConstructionSiteCardState();
}

class _ConstructionSiteCardState extends State<_ConstructionSiteCard> {
  bool _isLoadingDepartmentStats = false;
  List<progress_bars.DepartmentCompletionStats> _departmentStats = [];

  @override
  void initState() {
    super.initState();
    _loadDepartmentStats();
  }

  /// Загрузка статистики по отделам для всех проектов участка
  Future<void> _loadDepartmentStats() async {
    if (mounted) {
      setState(() {
        _isLoadingDepartmentStats = true;
      });
    }

    try {
      // Получаем все проекты участка
      final projectsResult = await ApiService.getProjects(
        constructionSiteId: widget.constructionSite.id,
      );

      if (projectsResult['success'] != true) {
        if (mounted) {
          setState(() {
            _departmentStats = [];
            _isLoadingDepartmentStats = false;
          });
        }
        return;
      }

      final projectsData = projectsResult['data'];
      if (projectsData is! List) {
        if (mounted) {
          setState(() {
            _departmentStats = [];
            _isLoadingDepartmentStats = false;
          });
        }
        return;
      }

      final projects = projectsData
          .map((json) => ProjectModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Загружаем все листы всех проектов
      List<ProjectSheetModel> allSheets = [];
      
      for (final project in projects) {
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
              builder: (context) => SiteProjectsScreen(
                constructionSite: widget.constructionSite,
              ),
            ),
          );
          
          // Обновляем участок после возврата из экрана проектов
          if (widget.onConstructionSiteUpdated != null) {
            try {
              final siteResult = await ApiService.getConstructionSite(widget.constructionSite.id);
              if (siteResult['success'] == true) {
                final siteData = siteResult['data'] as Map<String, dynamic>;
                final updatedSite = ConstructionSiteModel.fromJson(siteData);
                widget.onConstructionSiteUpdated!(updatedSite);
                // Перезагружаем статистику по отделам
                _loadDepartmentStats();
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
                // Иконка участка
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
                    Icons.construction,
                    size: 32,
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(width: 16),
                // Информация об участке
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.constructionSite.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.constructionSite.description != null &&
                          widget.constructionSite.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.constructionSite.description!,
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
                          if (widget.constructionSite.manager != null) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.constructionSite.manager!.username,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Общая шкала выполнения
                      progress_bars.OverallProgressBar(
                        completionPercentage: widget.constructionSite.completionPercentage,
                        compact: true,
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
      builder: (context) => ConstructionSiteFormDialog(
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
