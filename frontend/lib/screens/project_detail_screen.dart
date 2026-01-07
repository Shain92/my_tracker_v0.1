import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/project_stage_form_dialog.dart';
import '../widgets/project_sheet_form_dialog.dart';

/// Статистика выполнения по отделу
class DepartmentCompletionStats {
  final int departmentId;
  final String departmentName;
  final String departmentColor;
  final int totalSheets;
  final int completedSheets;
  final int incompleteSheets; // Невыполненные листы
  final double completionPercentage;
  final double incompletePercentage; // Процент невыполненных листов от общего количества невыполненных

  DepartmentCompletionStats({
    required this.departmentId,
    required this.departmentName,
    required this.departmentColor,
    required this.totalSheets,
    required this.completedSheets,
    required this.incompleteSheets,
    required this.completionPercentage,
    required this.incompletePercentage,
  });
}

/// Экран деталей проекта
class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({
    super.key,
    required this.project,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _isLoading = true;
  int? _currentUserId;
  int? _currentUserDepartmentId;
  bool _isLoadingDepartmentStats = false;
  List<DepartmentCompletionStats> _departmentStats = [];
  ProjectModel? _currentProject;
  bool _showFilters = false; // Переключение между блоком информации и фильтрами
  
  // Ключи для независимых виджетов колонок
  final GlobalKey<_StagesColumnWidgetState> _stagesKey = GlobalKey<_StagesColumnWidgetState>();
  final GlobalKey<_SheetsColumnWidgetState> _sheetsKey = GlobalKey<_SheetsColumnWidgetState>();

  @override
  void initState() {
    super.initState();
    _currentProject = widget.project;
    _loadCurrentUser();
    _loadData();
    _loadDepartmentStats();
  }

  /// Загрузка текущего пользователя
  Future<void> _loadCurrentUser() async {
    final user = await ApiService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUserId = user['id'] as int?;
        if (user['department_id'] != null) {
          _currentUserDepartmentId = user['department_id'] as int;
        } else {
          _currentUserDepartmentId = null;
        }
      });
    }
  }

  /// Загрузка данных
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Виджеты загрузят данные самостоятельно при инициализации
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Обновление проекта с сервера
  Future<void> _updateProject() async {
    try {
      final result = await ApiService.getProject(widget.project.id);
      if (mounted && result['success'] == true) {
        final projectData = result['data'] as Map<String, dynamic>;
        setState(() {
          _currentProject = ProjectModel.fromJson(projectData);
        });
      }
    } catch (e) {
      // Игнорируем ошибки при обновлении
    }
  }

  /// Загрузка статистики по отделам
  Future<void> _loadDepartmentStats() async {
    // #region agent log
    _debugLog('project_detail_screen.dart:108', '_loadDepartmentStats entry', {'projectId': widget.project.id}, 'A,C,E');
    // #endregion
    
    if (mounted) {
      setState(() {
        _isLoadingDepartmentStats = true;
      });
    }

    try {
      // Загружаем все листы проекта, проходя по всем страницам
      List<ProjectSheetModel> allSheets = [];
      int currentPage = 1;
      bool hasMore = true;
      
      while (hasMore && mounted) {
        final result = await ApiService.getProjectSheets(
          widget.project.id,
          page: currentPage,
          pageSize: 100, // Загружаем по 100 листов за раз
        );

        // #region agent log
        _debugLog('project_detail_screen.dart:121', 'API response received', {
          'success': result['success'],
          'hasData': result.containsKey('data'),
          'pagination': result['pagination'],
          'currentPage': currentPage,
        }, 'A,C');
        // #endregion

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

      // #region agent log
      _debugLog('project_detail_screen.dart:149', 'All pages loaded', {
        'totalSheets': allSheets.length,
        'totalPages': currentPage - 1,
      }, 'A,C');
      // #endregion

      if (mounted) {

        // #region agent log
        _debugLog('project_detail_screen.dart:133', 'Sheets parsed', {
          'totalSheets': allSheets.length,
          'sheetsWithDept': allSheets.where((s) => s.responsibleDepartment != null).length,
          'sheetsWithoutDept': allSheets.where((s) => s.responsibleDepartment == null).length,
        }, 'B,E');
        // #endregion

        // Группируем невыполненные листы по отделам
        final Map<int, DepartmentCompletionStats> statsMap = {};
        int totalIncompleteSheets = 0;
        final Set<int> seenDeptIds = {};
        
        for (final sheet in allSheets) {
          // #region agent log
          _debugLog('project_detail_screen.dart:145', 'Processing sheet', {
            'sheetId': sheet.id,
            'hasDept': sheet.responsibleDepartment != null,
            'deptId': sheet.responsibleDepartment?.id,
            'deptName': sheet.responsibleDepartment?.name,
            'isCompleted': sheet.isCompleted,
          }, 'B,D');
          // #endregion
          
          if (sheet.responsibleDepartment != null) {
            final deptId = sheet.responsibleDepartment!.id;
            
            if (!statsMap.containsKey(deptId)) {
              seenDeptIds.add(deptId);
              // #region agent log
              _debugLog('project_detail_screen.dart:151', 'New department found', {
                'deptId': deptId,
                'deptName': sheet.responsibleDepartment!.name,
                'deptColor': sheet.responsibleDepartment!.color,
              }, 'D');
              // #endregion
              
              statsMap[deptId] = DepartmentCompletionStats(
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
            
            statsMap[deptId] = DepartmentCompletionStats(
              departmentId: stats.departmentId,
              departmentName: stats.departmentName,
              departmentColor: stats.departmentColor,
              totalSheets: stats.totalSheets + 1,
              completedSheets: stats.completedSheets + (isCompleted ? 1 : 0),
              incompleteSheets: stats.incompleteSheets + (isIncomplete ? 1 : 0),
              completionPercentage: 0.0, // Вычислим ниже
              incompletePercentage: 0.0, // Вычислим ниже
            );
            
            if (isIncomplete) {
              totalIncompleteSheets++;
            }
          }
        }

        // #region agent log
        _debugLog('project_detail_screen.dart:187', 'After grouping departments', {
          'totalDepartments': statsMap.length,
          'deptIds': seenDeptIds.toList(),
          'deptNames': statsMap.values.map((s) => s.departmentName).toList(),
          'totalIncompleteSheets': totalIncompleteSheets,
        }, 'B,D');
        // #endregion

        // Вычисляем проценты
        final List<DepartmentCompletionStats> statsList = [];
        for (final stats in statsMap.values) {
          // Процент выполнения отдела
          final completionPercentage = stats.totalSheets > 0
              ? (stats.completedSheets / stats.totalSheets) * 100
              : 0.0;
          
          // Процент невыполненных листов отдела от общего количества невыполненных
          final incompletePercentage = totalIncompleteSheets > 0
              ? (stats.incompleteSheets / totalIncompleteSheets) * 100
              : 0.0;
          
          // Добавляем все отделы, которые есть в проектных листах
          statsList.add(DepartmentCompletionStats(
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

        // Сортируем по количеству невыполненных листов (по убыванию)
        statsList.sort((a, b) => b.incompleteSheets.compareTo(a.incompleteSheets));

        // #region agent log
        _debugLog('project_detail_screen.dart:213', 'Final stats list', {
          'finalCount': statsList.length,
          'deptIds': statsList.map((s) => s.departmentId).toList(),
          'deptNames': statsList.map((s) => s.departmentName).toList(),
          'incompleteCounts': statsList.map((s) => s.incompleteSheets).toList(),
        }, 'A,B,C,D,E');
        // #endregion

        if (mounted) {
          setState(() {
            _departmentStats = statsList;
            _isLoadingDepartmentStats = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _departmentStats = [];
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

  /// Вспомогательная функция для логирования отладки
  void _debugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
    try {
      final logData = {
        'location': location,
        'message': message,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sessionId': 'debug-session',
        'runId': 'run1',
        'hypothesisId': hypothesisId,
      };
      http.post(
        Uri.parse('http://127.0.0.1:7246/ingest/24c3c77a-8ab3-4ae6-afd3-7e3aad7b1941'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(logData),
      ).catchError((_) => http.Response('', 500));
    } catch (e) {
      // Игнорируем ошибки логирования
    }
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
              _buildHeader(context, isMobile),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(isMobile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Заголовок
  Widget _buildHeader(BuildContext context, bool isMobile) {
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
                  widget.project.name,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile && widget.project.code.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Код: ${widget.project.code}',
                    style: const TextStyle(
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
        ],
      ),
    );
  }

  /// Основной контент
  Widget _buildContent(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProjectInfo(isMobile),
          const SizedBox(height: 24),
          isMobile
              ? _buildMobileLayout()
              : _buildDesktopLayout(),
        ],
      ),
    );
  }

  /// Проверка наличия активных фильтров в любой из колонок
  bool _hasAnyActiveFilters() {
    final stagesState = _stagesKey.currentState;
    final sheetsState = _sheetsKey.currentState;
    return (stagesState != null && stagesState.hasActiveFilters()) ||
           (sheetsState != null && sheetsState.hasActiveFilters());
  }

  /// Информация о проекте
  Widget _buildProjectInfo(bool isMobile) {
    if (_showFilters) {
      return _buildFiltersBlock(isMobile);
    }

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
                Icons.info_outline,
                color: AppColors.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Информация',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showFilters = true;
                  });
                },
                icon: Stack(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: _hasAnyActiveFilters()
                          ? AppColors.accentBlue
                          : AppColors.textSecondary,
                    ),
                    if (_hasAnyActiveFilters())
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.cardBackground,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: 'Фильтры',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Код', widget.project.code, Icons.tag),
          if (widget.project.cipher.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Шифр', widget.project.cipher, Icons.code),
          ],
          if (widget.project.constructionSite != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Участок',
              widget.project.constructionSite!.name,
              Icons.construction,
            ),
          ],
          const SizedBox(height: 12),
          // Процент выполнения и выполнение по отделам
          if (isMobile) ...[
            // На мобильных: вертикальная раскладка
            _buildOverallProgress(),
            const SizedBox(height: 12),
            _buildDepartmentProgressBar(isMobile),
          ] else ...[
            // На десктопе: горизонтальная раскладка
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildOverallProgress()),
                const SizedBox(width: 16),
                Expanded(child: _buildDepartmentProgressBar(isMobile)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Блок фильтров
  Widget _buildFiltersBlock(bool isMobile) {
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
                Icons.filter_list,
                color: AppColors.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Фильтры',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showFilters = false;
                  });
                },
                icon: const Icon(
                  Icons.info_outline,
                  size: 18,
                ),
                label: const Text('Инфо'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isMobile) ...[
            // На мобильных: вертикальная раскладка
            _buildStagesFiltersPanel(),
            const SizedBox(height: 20),
            _buildSheetsFiltersPanel(),
          ] else ...[
            // На десктопе: горизонтальная раскладка
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStagesFiltersPanel()),
                const SizedBox(width: 16),
                Expanded(child: _buildSheetsFiltersPanel()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Панель фильтров этапов
  Widget _buildStagesFiltersPanel() {
    final stagesState = _stagesKey.currentState;
    if (stagesState == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline,
                color: AppColors.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Фильтры этапов',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    stagesState.resetFilters();
                  });
                },
                child: const Text(
                  'Сбросить',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StatefulBuilder(
            builder: (context, setDialogState) {
              return _buildStagesFiltersContent(stagesState, setDialogState);
            },
          ),
        ],
      ),
    );
  }

  /// Контент фильтров этапов
  Widget _buildStagesFiltersContent(_StagesColumnWidgetState stagesState, StateSetter setDialogState) {
    final filtersState = stagesState.getFiltersState();
    final selectedUserIds = filtersState['selectedResponsibleUserIds'] as Set<int>?;
    final selectedStatusIds = filtersState['selectedStatusIds'] as Set<int>?;
    final dateFrom = filtersState['dateFrom'] as DateTime?;
    final dateTo = filtersState['dateTo'] as DateTime?;
    final hasFileFilter = filtersState['hasFileFilter'] as bool? ?? false;

    final availableUsers = stagesState._getAvailableUsers();
    final allStages = stagesState.getAllStages();

    // Получаем уникальные статусы из загруженных этапов
    final statusesMap = <int, StatusModel>{};
    for (final stage in allStages) {
      if (stage.status != null) {
        statusesMap[stage.status!.id] = stage.status!;
      }
    }
    final availableStatuses = statusesMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ответственные
        if (availableUsers.isNotEmpty) ...[
          const Text(
            'Ответственные:',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableUsers.map((user) {
              final isSelected = selectedUserIds?.contains(user.id) ?? false;
              final userColor = user.department?.color ?? '#808080';
              final deptColor = _parseColor(userColor);
              return InkWell(
                onTap: () {
                  setDialogState(() {
                    final newSet = Set<int>.from(selectedUserIds ?? {});
                    if (isSelected) {
                      newSet.remove(user.id);
                    } else {
                      newSet.add(user.id);
                    }
                    stagesState.setFiltersState(selectedResponsibleUserIds: newSet);
                  });
                  setState(() {}); // Обновляем родительский виджет
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: deptColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: deptColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: deptColor.withOpacity(0.8),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: deptColor.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: deptColor.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: deptColor.withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        )
                      : BoxDecoration(
                          color: deptColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: deptColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                  child: Text(
                    user.firstName != null && user.lastName != null
                        ? '${user.firstName} ${user.lastName}'
                        : user.username,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // Статусы
        if (availableStatuses.isNotEmpty) ...[
          const Text(
            'Статусы:',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableStatuses.map((status) {
              final isSelected = selectedStatusIds?.contains(status.id) ?? false;
              final statusColor = _parseColor(status.color);
              return InkWell(
                onTap: () {
                  setDialogState(() {
                    final newSet = Set<int>.from(selectedStatusIds ?? {});
                    if (isSelected) {
                      newSet.remove(status.id);
                    } else {
                      newSet.add(status.id);
                    }
                    stagesState.setFiltersState(selectedStatusIds: newSet);
                  });
                  setState(() {}); // Обновляем родительский виджет
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.8),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: statusColor.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: statusColor.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: statusColor.withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        )
                      : BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                  child: Text(
                    status.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // Период
        const Text(
          'Период:',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dateFrom ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.accentBlue,
                            onPrimary: Colors.white,
                            surface: AppColors.cardBackground,
                            onSurface: AppColors.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() {
                      stagesState.setFiltersState(dateFrom: picked);
                    });
                    setState(() {}); // Обновляем родительский виджет
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.borderColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateFrom != null
                              ? '${dateFrom.day.toString().padLeft(2, '0')}.${dateFrom.month.toString().padLeft(2, '0')}.${dateFrom.year}'
                              : 'От',
                          style: TextStyle(
                            color: dateFrom != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dateTo ?? DateTime.now(),
                    firstDate: dateFrom ?? DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.accentBlue,
                            onPrimary: Colors.white,
                            surface: AppColors.cardBackground,
                            onSurface: AppColors.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() {
                      stagesState.setFiltersState(dateTo: picked);
                    });
                    setState(() {}); // Обновляем родительский виджет
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.borderColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateTo != null
                              ? '${dateTo.day.toString().padLeft(2, '0')}.${dateTo.month.toString().padLeft(2, '0')}.${dateTo.year}'
                              : 'До',
                          style: TextStyle(
                            color: dateTo != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // С файлом
        Row(
          children: [
            Checkbox(
              value: hasFileFilter,
              onChanged: (value) {
                setDialogState(() {
                  stagesState.setFiltersState(hasFileFilter: value ?? false);
                });
                setState(() {}); // Обновляем родительский виджет
              },
              activeColor: AppColors.accentBlue,
            ),
            const Expanded(
              child: Text(
                'Только с файлом',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Панель фильтров листов
  Widget _buildSheetsFiltersPanel() {
    final sheetsState = _sheetsKey.currentState;
    if (sheetsState == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description,
                color: AppColors.accentGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Фильтры листов',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    sheetsState.resetFilters();
                  });
                },
                child: const Text(
                  'Сбросить',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StatefulBuilder(
            builder: (context, setDialogState) {
              return _buildSheetsFiltersContent(sheetsState, setDialogState);
            },
          ),
        ],
      ),
    );
  }

  /// Контент фильтров листов
  Widget _buildSheetsFiltersContent(_SheetsColumnWidgetState sheetsState, StateSetter setDialogState) {
    final filtersState = sheetsState.getFiltersState();
    final selectedDepartmentIds = filtersState['selectedDepartmentIds'] as Set<int>?;
    final completionFilter = filtersState['completionFilter'] as String?;

    // Используем отделы из загруженных листов
    final allSheets = sheetsState.getAllSheets();
    final departmentsMap = <int, DepartmentModel>{};
    for (final sheet in allSheets) {
      if (sheet.responsibleDepartment != null) {
        departmentsMap[sheet.responsibleDepartment!.id] = sheet.responsibleDepartment!;
      }
    }
    final availableDepartments = departmentsMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // По отделам
        if (availableDepartments.isNotEmpty) ...[
          const Text(
            'По отделам:',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableDepartments.map((dept) {
              final isSelected = selectedDepartmentIds?.contains(dept.id) ?? false;
              final deptColor = _parseColor(dept.color);
              return InkWell(
                onTap: () {
                  setDialogState(() {
                    final newSet = Set<int>.from(selectedDepartmentIds ?? {});
                    if (isSelected) {
                      newSet.remove(dept.id);
                    } else {
                      newSet.add(dept.id);
                    }
                    sheetsState.setFiltersState(selectedDepartmentIds: newSet);
                  });
                  setState(() {}); // Обновляем родительский виджет
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: deptColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: deptColor,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: deptColor.withOpacity(0.8),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: deptColor.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: deptColor.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: deptColor.withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        )
                      : BoxDecoration(
                          color: deptColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: deptColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                  child: Text(
                    dept.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // По выполнению
        const Text(
          'По выполнению:',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildCompletionFilterChip(
              label: 'Все',
              value: 'all',
              selectedValue: completionFilter ?? 'all',
              color: AppColors.textSecondary,
              onTap: () {
                setDialogState(() {
                  sheetsState.setFiltersState(completionFilter: 'all');
                });
                setState(() {}); // Обновляем родительский виджет
              },
            ),
            _buildCompletionFilterChip(
              label: 'Выполнено',
              value: 'completed',
              selectedValue: completionFilter ?? 'all',
              color: AppColors.accentGreen,
              onTap: () {
                setDialogState(() {
                  sheetsState.setFiltersState(completionFilter: 'completed');
                });
                setState(() {}); // Обновляем родительский виджет
              },
            ),
            _buildCompletionFilterChip(
              label: 'Не выполнено',
              value: 'incomplete',
              selectedValue: completionFilter ?? 'all',
              color: AppColors.accentBlue,
              onTap: () {
                setDialogState(() {
                  sheetsState.setFiltersState(completionFilter: 'incomplete');
                });
                setState(() {}); // Обновляем родительский виджет
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Создание чипа для фильтра выполнения
  Widget _buildCompletionFilterChip({
    required String label,
    required String value,
    required String? selectedValue,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.8),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                ],
              )
            : BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Общая шкала выполнения
  Widget _buildOverallProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.trending_up,
              color: AppColors.accentGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Выполнение: ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
              Text(
                '${(_currentProject?.completionPercentage ?? widget.project.completionPercentage)?.toStringAsFixed(1) ?? 0.0}%',
                style: const TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ((_currentProject?.completionPercentage ?? widget.project.completionPercentage) ?? 0.0) / 100,
          backgroundColor: AppColors.backgroundSecondary,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  /// Шкала выполнения по отделам
  Widget _buildDepartmentProgressBar(bool isMobile) {
    if (_isLoadingDepartmentStats) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.business,
                color: AppColors.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'По отделам: ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(
            height: 8,
            child: LinearProgressIndicator(),
          ),
        ],
      );
    }

    if (_departmentStats.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.business,
                color: AppColors.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'По отделам: ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Нет данных по отделам',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.business,
              color: AppColors.accentBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Невыполненные листы по отделам: ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Горизонтальная шкала с сегментами невыполненных листов
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            
            // #region agent log
            _debugLog('project_detail_screen.dart:643', 'LayoutBuilder entry', {
              'totalWidth': totalWidth,
              'totalDepartments': _departmentStats.length,
            }, 'A,B,D');
            // #endregion
            
            // Вычисляем общее количество невыполненных листов
            final totalIncompleteSheets = _departmentStats.fold<int>(
              0,
              (sum, stats) => sum + stats.incompleteSheets,
            );
            
            // #region agent log
            _debugLog('project_detail_screen.dart:650', 'Total incomplete sheets calculated', {
              'totalIncompleteSheets': totalIncompleteSheets,
              'departmentStats': _departmentStats.map((s) => {
                'id': s.departmentId,
                'name': s.departmentName,
                'incomplete': s.incompleteSheets,
              }).toList(),
            }, 'A,C');
            // #endregion
            
            if (totalIncompleteSheets == 0) {
              // Если нет невыполненных листов, показываем сообщение
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'Все листы выполнены',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }
            
            // Фильтруем отделы с невыполненными листами для отображения на шкале
            final departmentsWithIncomplete = _departmentStats
                .where((stats) => stats.incompleteSheets > 0)
                .toList();
            
            // #region agent log
            _debugLog('project_detail_screen.dart:675', 'Departments with incomplete filtered', {
              'departmentsWithIncompleteCount': departmentsWithIncomplete.length,
              'departmentsWithIncomplete': departmentsWithIncomplete.map((s) => {
                'id': s.departmentId,
                'name': s.departmentName,
                'incomplete': s.incompleteSheets,
              }).toList(),
            }, 'A,B');
            // #endregion
            
            if (departmentsWithIncomplete.isEmpty) {
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'Все листы выполнены',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }
            
            // Вычисляем ширины всех сегментов
            final segmentWidths = <double>[];
            double totalSegmentWidth = 0.0;
            
            for (final stats in departmentsWithIncomplete) {
              final segmentWidth = (stats.incompleteSheets / totalIncompleteSheets) * totalWidth;
              segmentWidths.add(segmentWidth);
              totalSegmentWidth += segmentWidth;
            }
            
            // #region agent log
            _debugLog('project_detail_screen.dart:710', 'Segment widths calculated', {
              'totalWidth': totalWidth,
              'totalIncompleteSheets': totalIncompleteSheets,
              'segmentWidths': segmentWidths,
              'totalSegmentWidth': totalSegmentWidth,
              'difference': totalWidth - totalSegmentWidth,
              'segmentCount': departmentsWithIncomplete.length,
            }, 'A,B');
            // #endregion
            
            return Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: departmentsWithIncomplete.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stats = entry.value;
                  final color = _parseColor(stats.departmentColor);
                  final isUserDepartment = _currentUserDepartmentId != null && 
                                           stats.departmentId == _currentUserDepartmentId;
                  
                  // Используем предвычисленную ширину
                  final segmentWidth = segmentWidths[index];
                  final borderRadius = _getBorderRadiusForSegment(
                    index,
                    departmentsWithIncomplete.length,
                  );
                  
                  return Container(
                    width: segmentWidth,
                    decoration: isUserDepartment
                        ? BoxDecoration(
                            color: color,
                            borderRadius: borderRadius,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 3,
                              ),
                            ],
                          )
                        : BoxDecoration(
                            color: color,
                            borderRadius: borderRadius,
                          ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        // Легенда с названиями всех отделов, количеством и процентами невыполненных листов
        if (!isMobile) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _departmentStats.map((stats) {
              final color = _parseColor(stats.departmentColor);
              final totalIncomplete = _departmentStats.fold<int>(
                0,
                (sum, s) => sum + s.incompleteSheets,
              );
              final isUserDepartment = _currentUserDepartmentId != null && 
                                       stats.departmentId == _currentUserDepartmentId;
              
              // Показываем процент только если есть невыполненные листы
              final percentageText = totalIncomplete > 0
                  ? ' (${stats.incompletePercentage.toStringAsFixed(1)}%)'
                  : '';
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: isUserDepartment
                        ? BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 3,
                              ),
                            ],
                          )
                        : BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${stats.departmentName}: ${stats.incompleteSheets}$percentageText',
                    style: TextStyle(
                      color: isUserDepartment ? color : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isUserDepartment ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  /// Получение скругления углов для сегмента
  BorderRadius _getBorderRadiusForSegment(int index, int total) {
    if (total == 1) {
      return BorderRadius.circular(4);
    }
    
    if (index == 0) {
      return const BorderRadius.only(
        topLeft: Radius.circular(4),
        bottomLeft: Radius.circular(4),
      );
    } else if (index == total - 1) {
      return const BorderRadius.only(
        topRight: Radius.circular(4),
        bottomRight: Radius.circular(4),
      );
    } else {
      return BorderRadius.zero;
    }
  }

  /// Строка информации
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Раскладка для мобильных устройств
  Widget _buildMobileLayout() {
    return Column(
      children: [
        RepaintBoundary(
          child: _buildStagesColumn(true),
        ),
        const SizedBox(height: 24),
        RepaintBoundary(
          child: _buildSheetsColumn(true),
        ),
      ],
    );
  }

  /// Раскладка для десктопа
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildStagesColumn(false)),
        const SizedBox(width: 16),
        Expanded(child: _buildSheetsColumn(false)),
      ],
    );
  }

  /// Колонка этапов
  Widget _buildStagesColumn(bool isMobile) {
    return _StagesColumnWidget(
      key: _stagesKey,
      projectId: widget.project.id,
      isMobile: isMobile,
      currentUserId: _currentUserId,
      onStageAdded: () {},
    );
  }

  /// Колонка листов
  Widget _buildSheetsColumn(bool isMobile) {
    return _SheetsColumnWidget(
      key: _sheetsKey,
      projectId: widget.project.id,
      isMobile: isMobile,
      currentUserId: _currentUserId,
      onSheetAdded: () {
        // Обновляем статистику по отделам при изменении листов
        _loadDepartmentStats();
      },
      onProjectUpdated: _updateProject,
    );
  }
}

/// Виджет колонки этапов с независимым состоянием
class _StagesColumnWidget extends StatefulWidget {
  final int projectId;
  final bool isMobile;
  final int? currentUserId;
  final VoidCallback onStageAdded;

  const _StagesColumnWidget({
    super.key,
    required this.projectId,
    required this.isMobile,
    this.currentUserId,
    required this.onStageAdded,
  });

  @override
  State<_StagesColumnWidget> createState() => _StagesColumnWidgetState();
}

class _StagesColumnWidgetState extends State<_StagesColumnWidget> {
  List<ProjectStageModel> _stages = [];
  List<ProjectStageModel> _allStages = []; // Все загруженные этапы без фильтрации
  
  /// Получение всех загруженных этапов (публичный метод для доступа из родителя)
  List<ProjectStageModel> getAllStages() => _allStages;
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  
  // Состояние фильтров
  Set<int>? _selectedResponsibleUserIds;
  Set<int>? _selectedStatusIds;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _hasFileFilter = false;

  @override
  void initState() {
    super.initState();
    _loadStages();
  }

  /// Загрузка этапов
  Future<void> _loadStages({int? page}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final currentPage = page ?? _currentPage;
      final result = await ApiService.getProjectStages(
        widget.projectId,
        page: currentPage,
        pageSize: 5,
      );
      if (mounted && result['success'] == true) {
        setState(() {
          _isLoading = false;
          final data = result['data'];
          if (data is List) {
            _allStages = data
                .map((s) => ProjectStageModel.fromJson(s as Map<String, dynamic>))
                .toList();
            _stages = _applyFilters(_allStages.isNotEmpty ? _allStages : []);
          } else {
            _allStages = [];
            _stages = [];
          }

          if (result['pagination'] != null) {
            final pagination = result['pagination'] as Map<String, dynamic>;
            _currentPage = pagination['currentPage'] as int? ?? 1;
            _totalPages = pagination['totalPages'] as int? ?? 1;
            _totalCount = pagination['count'] as int? ?? 0;
          } else {
            _currentPage = 1;
            _totalPages = 1;
            _totalCount = _allStages.length;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allStages = [];
          _stages = [];
          _currentPage = 1;
          _totalPages = 1;
          _totalCount = 0;
        });
      }
    }
  }

  void refresh() {
    _currentPage = 1;
    _loadStages();
  }

  /// Проверка наличия активных фильтров (публичный метод для доступа из родителя)
  bool hasActiveFilters() {
    return (_selectedResponsibleUserIds != null && _selectedResponsibleUserIds!.isNotEmpty) ||
           (_selectedStatusIds != null && _selectedStatusIds!.isNotEmpty) ||
           _dateFrom != null ||
           _dateTo != null ||
           _hasFileFilter;
  }
  
  /// Получение состояния фильтров (для доступа из родителя)
  Map<String, dynamic> getFiltersState() {
    return {
      'selectedResponsibleUserIds': _selectedResponsibleUserIds,
      'selectedStatusIds': _selectedStatusIds,
      'dateFrom': _dateFrom,
      'dateTo': _dateTo,
      'hasFileFilter': _hasFileFilter,
    };
  }
  
  /// Установка состояния фильтров (для доступа из родителя)
  void setFiltersState({
    Set<int>? selectedResponsibleUserIds,
    Set<int>? selectedStatusIds,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? hasFileFilter,
  }) {
    setState(() {
      if (selectedResponsibleUserIds != null) {
        _selectedResponsibleUserIds = selectedResponsibleUserIds.isEmpty ? null : selectedResponsibleUserIds;
      }
      if (selectedStatusIds != null) {
        _selectedStatusIds = selectedStatusIds.isEmpty ? null : selectedStatusIds;
      }
      if (dateFrom != null) _dateFrom = dateFrom;
      if (dateTo != null) _dateTo = dateTo;
      if (hasFileFilter != null) _hasFileFilter = hasFileFilter;
      _updateFilters();
    });
  }
  
  /// Сброс всех фильтров
  void resetFilters() {
    setState(() {
      _selectedResponsibleUserIds = null;
      _selectedStatusIds = null;
      _dateFrom = null;
      _dateTo = null;
      _hasFileFilter = false;
      _updateFilters();
    });
  }

  /// Получение списка уникальных ответственных из загруженных этапов (публичный метод)
  List<UserModel> _getAvailableUsers() {
    final usersMap = <int, UserModel>{};
    for (final stage in _allStages) {
      if (stage.responsibleUsers != null) {
        for (final user in stage.responsibleUsers!) {
          usersMap[user.id] = user;
        }
      }
    }
    return usersMap.values.toList()..sort((a, b) => a.username.compareTo(b.username));
  }

  /// Применение фильтров к списку этапов
  List<ProjectStageModel> _applyFilters(List<ProjectStageModel> stages) {
    if (stages.isEmpty || stages.length == 0) return [];
    try {
      return stages.where((stage) {
        // Фильтр по ответственным
        if (_selectedResponsibleUserIds != null && _selectedResponsibleUserIds!.isNotEmpty) {
          final stageUserIds = stage.responsibleUserIds ?? [];
          if (!stageUserIds.any((id) => _selectedResponsibleUserIds!.contains(id))) {
            return false;
          }
        }
        // Фильтр по статусам
        if (_selectedStatusIds != null && _selectedStatusIds!.isNotEmpty) {
          final stageStatusId = stage.status?.id ?? stage.statusId;
          if (stageStatusId == null || !_selectedStatusIds!.contains(stageStatusId)) {
            return false;
          }
        }
        // Фильтр по периоду
        if (_dateFrom != null && stage.datetime.isBefore(_dateFrom!)) return false;
        if (_dateTo != null) {
          final dateToEnd = _dateTo!.add(const Duration(days: 1));
          if (stage.datetime.isAfter(dateToEnd)) return false;
        }
        // Фильтр по файлу
        if (_hasFileFilter && (stage.fileUrl == null || stage.fileUrl!.isEmpty)) return false;
        return true;
      }).toList();
    } catch (e) {
      // В случае ошибки возвращаем пустой список
      return [];
    }
  }

  /// Обновление фильтров и применение их к списку
  void _updateFilters() {
    setState(() {
      _stages = _applyFilters(_allStages.isNotEmpty ? _allStages : []);
    });
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

  /// Показ модального окна фильтров
  Future<void> _showFilterDialog() async {
    List<UserModel> availableUsers = _getAvailableUsers();
    List<StatusModel> allStatuses = [];
    bool isLoadingStatuses = true;

    // Загружаем все статусы типа 'stage'
    final statusResult = await ApiService.getStatuses(statusType: 'stage');
    if (statusResult['success'] == true) {
      final data = statusResult['data'] as List;
      allStatuses = data
          .map((s) => StatusModel.fromJson(s as Map<String, dynamic>))
          .toList();
      isLoadingStatuses = false;
    }

    Set<int> tempSelectedUserIds = _selectedResponsibleUserIds != null
        ? Set<int>.from(_selectedResponsibleUserIds!)
        : <int>{};
    Set<int> tempSelectedStatusIds = _selectedStatusIds != null
        ? Set<int>.from(_selectedStatusIds!)
        : <int>{};
    DateTime? tempDateFrom = _dateFrom;
    DateTime? tempDateTo = _dateTo;
    bool tempHasFileFilter = _hasFileFilter;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text(
              'Фильтры',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Фильтр по ответственным
                    const Text(
                      'Ответственные:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (availableUsers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Нет ответственных',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableUsers.map((user) {
                          final isSelected = tempSelectedUserIds.contains(user.id);
                          final userColor = user.department?.color ?? '#808080';
                          final deptColor = _parseColor(userColor);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  tempSelectedUserIds.remove(user.id);
                                } else {
                                  tempSelectedUserIds.add(user.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: deptColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: deptColor,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: deptColor.withOpacity(0.8),
                                          blurRadius: 4,
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: deptColor.withOpacity(0.6),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                        BoxShadow(
                                          color: deptColor.withOpacity(0.4),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: deptColor.withOpacity(0.3),
                                          blurRadius: 16,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    )
                                  : BoxDecoration(
                                      color: deptColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: deptColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                              child: Text(
                                user.firstName != null && user.lastName != null
                                    ? '${user.firstName} ${user.lastName}'
                                    : user.username,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    // Фильтр по статусам
                    const Text(
                      'Статусы:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingStatuses)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (allStatuses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Нет статусов',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allStatuses.map((status) {
                          final isSelected = tempSelectedStatusIds.contains(status.id);
                          final statusColor = _parseColor(status.color);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  tempSelectedStatusIds.remove(status.id);
                                } else {
                                  tempSelectedStatusIds.add(status.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: statusColor,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.8),
                                          blurRadius: 4,
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.6),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.4),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.3),
                                          blurRadius: 16,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    )
                                  : BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: statusColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                              child: Text(
                                status.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    // Фильтр по периоду
                    const Text(
                      'Период:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempDateFrom ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppColors.accentBlue,
                                        onPrimary: Colors.white,
                                        surface: AppColors.cardBackground,
                                        onSurface: AppColors.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  tempDateFrom = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.borderColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tempDateFrom != null
                                          ? '${tempDateFrom!.day.toString().padLeft(2, '0')}.${tempDateFrom!.month.toString().padLeft(2, '0')}.${tempDateFrom!.year}'
                                          : 'От',
                                      style: TextStyle(
                                        color: tempDateFrom != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempDateTo ?? DateTime.now(),
                                firstDate: tempDateFrom ?? DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppColors.accentBlue,
                                        onPrimary: Colors.white,
                                        surface: AppColors.cardBackground,
                                        onSurface: AppColors.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  tempDateTo = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.borderColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tempDateTo != null
                                          ? '${tempDateTo!.day.toString().padLeft(2, '0')}.${tempDateTo!.month.toString().padLeft(2, '0')}.${tempDateTo!.year}'
                                          : 'До',
                                      style: TextStyle(
                                        color: tempDateTo != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Фильтр по файлу
                    Row(
                      children: [
                        Checkbox(
                          value: tempHasFileFilter,
                          onChanged: (value) {
                            setDialogState(() {
                              tempHasFileFilter = value ?? false;
                            });
                          },
                          activeColor: AppColors.accentBlue,
                        ),
                        const Expanded(
                          child: Text(
                            'Только с файлом',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempSelectedUserIds.clear();
                    tempSelectedStatusIds.clear();
                    tempDateFrom = null;
                    tempDateTo = null;
                    tempHasFileFilter = false;
                  });
                },
                child: const Text(
                  'Сбросить',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Отмена',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedResponsibleUserIds = tempSelectedUserIds.isEmpty
                        ? null
                        : Set<int>.from(tempSelectedUserIds);
                    _selectedStatusIds = tempSelectedStatusIds.isEmpty
                        ? null
                        : Set<int>.from(tempSelectedStatusIds);
                    _dateFrom = tempDateFrom;
                    _dateTo = tempDateTo;
                    _hasFileFilter = tempHasFileFilter;
                    _updateFilters();
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                ),
                child: const Text(
                  'Применить',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.timeline,
                  color: AppColors.accentBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Этапы проекта',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showFilterDialog,
                  icon: Stack(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: hasActiveFilters()
                            ? AppColors.accentBlue
                            : AppColors.textSecondary,
                      ),
                      if (hasActiveFilters())
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.cardBackground,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Фильтры',
                ),
                FloatingActionButton.small(
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (context) => ProjectStageFormDialog(
                        stage: null,
                        project: ProjectModel(id: widget.projectId, name: '', code: '', cipher: ''),
                        onRefresh: refresh,
                      ),
                    );
                    if (result != null && result['success'] == true) {
                      refresh();
                      widget.onStageAdded();
                    }
                  },
                  backgroundColor: AppColors.accentBlue,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 510, // Фиксированная высота для 5 карточек (600px - 15%)
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _stages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Нет этапов',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _stages.length,
                        itemBuilder: (context, index) {
                          return _buildStageCard(_stages[index]);
                        },
                      ),
          ),
          _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildStageCard(ProjectStageModel stage) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: AppColors.cardBackground,
      child: InkWell(
        onTap: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => ProjectStageFormDialog(
              stage: stage,
              project: ProjectModel(id: widget.projectId, name: '', code: '', cipher: ''),
              onRefresh: refresh,
            ),
          );
          if (result != null && result['success'] == true) {
            refresh();
            widget.onStageAdded();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stage.datetime.day.toString().padLeft(2, '0')}.${stage.datetime.month.toString().padLeft(2, '0')}.${stage.datetime.year} ${stage.datetime.hour.toString().padLeft(2, '0')}:${stage.datetime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (stage.status != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _parseColor(stage.status!.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stage.status!.name,
                        style: TextStyle(
                          color: _parseColor(stage.status!.color),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (stage.description != null && stage.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  stage.description!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (stage.responsibleUsers != null && stage.responsibleUsers!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: stage.responsibleUsers!.map((user) {
                    final departmentColor = user.department?.color ?? '#808080';
                    final userName = user.firstName != null && user.lastName != null
                        ? '${user.firstName} ${user.lastName}'
                        : user.username;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _parseColor(departmentColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _parseColor(departmentColor).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _parseColor(departmentColor),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            userName,
                            style: TextStyle(
                              color: _parseColor(departmentColor),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final startItem = ((_currentPage - 1) * 5) + 1;
    final endItem = (_currentPage * 5).clamp(0, _totalCount);

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
                onPressed: _currentPage > 1 && !_isLoading
                    ? () => _loadStages(page: _currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
                color: _currentPage > 1
                    ? AppColors.accentBlue
                    : AppColors.textSecondary.withOpacity(0.3),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentPage < _totalPages && !_isLoading
                    ? () => _loadStages(page: _currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
                color: _currentPage < _totalPages
                    ? AppColors.accentBlue
                    : AppColors.textSecondary.withOpacity(0.3),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Виджет колонки листов с независимым состоянием
class _SheetsColumnWidget extends StatefulWidget {
  final int projectId;
  final bool isMobile;
  final int? currentUserId;
  final VoidCallback onSheetAdded;
  final VoidCallback? onProjectUpdated;

  const _SheetsColumnWidget({
    super.key,
    required this.projectId,
    required this.isMobile,
    this.currentUserId,
    required this.onSheetAdded,
    this.onProjectUpdated,
  });

  @override
  State<_SheetsColumnWidget> createState() => _SheetsColumnWidgetState();
}

class _SheetsColumnWidgetState extends State<_SheetsColumnWidget> {
  List<ProjectSheetModel> _sheets = [];
  List<ProjectSheetModel> _allSheets = []; // Все загруженные листы без фильтрации
  
  /// Получение всех загруженных листов (публичный метод для доступа из родителя)
  List<ProjectSheetModel> getAllSheets() => _allSheets;
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  
  // Состояние фильтров
  Set<int>? _selectedDepartmentIds;
  String? _completionFilter; // 'all', 'completed', 'incomplete'

  @override
  void initState() {
    super.initState();
    _loadSheets();
  }

  /// Загрузка листов
  Future<void> _loadSheets({int? page}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final currentPage = page ?? _currentPage;
      final result = await ApiService.getProjectSheets(
        widget.projectId,
        page: currentPage,
        pageSize: 5,
      );
      if (mounted && result['success'] == true) {
        setState(() {
          _isLoading = false;
          final data = result['data'];
          if (data is List) {
            _allSheets = data
                .map((s) => ProjectSheetModel.fromJson(s as Map<String, dynamic>))
                .toList();
            _sheets = _applyFilters(_allSheets.isNotEmpty ? _allSheets : []);
          } else {
            _allSheets = [];
            _sheets = [];
          }

          if (result['pagination'] != null) {
            final pagination = result['pagination'] as Map<String, dynamic>;
            _currentPage = pagination['currentPage'] as int? ?? 1;
            _totalPages = pagination['totalPages'] as int? ?? 1;
            _totalCount = pagination['count'] as int? ?? 0;
          } else {
            _currentPage = 1;
            _totalPages = 1;
            _totalCount = _allSheets.length;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _allSheets = [];
          _sheets = [];
          _currentPage = 1;
          _totalPages = 1;
          _totalCount = 0;
        });
      }
    }
  }

  void refresh() {
    _currentPage = 1;
    _loadSheets();
  }

  /// Проверка наличия активных фильтров (публичный метод для доступа из родителя)
  bool hasActiveFilters() {
    return (_selectedDepartmentIds != null && _selectedDepartmentIds!.isNotEmpty) ||
           (_completionFilter != null && _completionFilter != 'all');
  }
  
  /// Получение состояния фильтров (для доступа из родителя)
  Map<String, dynamic> getFiltersState() {
    return {
      'selectedDepartmentIds': _selectedDepartmentIds,
      'completionFilter': _completionFilter,
    };
  }
  
  /// Установка состояния фильтров (для доступа из родителя)
  void setFiltersState({
    Set<int>? selectedDepartmentIds,
    String? completionFilter,
  }) {
    setState(() {
      if (selectedDepartmentIds != null) {
        _selectedDepartmentIds = selectedDepartmentIds.isEmpty ? null : selectedDepartmentIds;
      }
      if (completionFilter != null) {
        _completionFilter = completionFilter == 'all' ? null : completionFilter;
      }
      _updateFilters();
    });
  }
  
  /// Сброс всех фильтров
  void resetFilters() {
    setState(() {
      _selectedDepartmentIds = null;
      _completionFilter = null;
      _updateFilters();
    });
  }

  /// Применение фильтров к списку листов
  List<ProjectSheetModel> _applyFilters(List<ProjectSheetModel> sheets) {
    if (sheets.isEmpty || sheets.length == 0) return [];
    try {
      return sheets.where((sheet) {
        // Фильтр по отделам
        if (_selectedDepartmentIds != null && _selectedDepartmentIds!.isNotEmpty) {
          // Получаем ID отдела из responsibleDepartmentId или из объекта responsibleDepartment
          final departmentId = sheet.responsibleDepartmentId ?? 
                               sheet.responsibleDepartment?.id;
          
          // Если у листа нет отдела, исключаем его из результатов
          if (departmentId == null) {
            return false;
          }
          
          // Проверяем, есть ли ID отдела в выбранных
          if (!_selectedDepartmentIds!.contains(departmentId)) {
            return false;
          }
        }
        // Фильтр по выполнению
        if (_completionFilter == 'completed' && !sheet.isCompleted) return false;
        if (_completionFilter == 'incomplete' && sheet.isCompleted) return false;
        return true;
      }).toList();
    } catch (e) {
      // В случае ошибки возвращаем пустой список
      return [];
    }
  }

  /// Обновление фильтров и применение их к списку
  void _updateFilters() {
    setState(() {
      _sheets = _applyFilters(_allSheets.isNotEmpty ? _allSheets : []);
    });
  }

  /// Создание чипа для фильтра выполнения
  Widget _buildCompletionFilterChip({
    required String label,
    required String value,
    required String? selectedValue,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.8),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                ],
              )
            : BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Показ модального окна фильтров
  Future<void> _showFilterDialog() async {
    List<DepartmentModel> departments = [];
    bool isLoadingDepartments = true;
    Set<int> tempSelectedDepartmentIds = _selectedDepartmentIds != null
        ? Set<int>.from(_selectedDepartmentIds!)
        : <int>{};
    String? tempCompletionFilter = _completionFilter ?? 'all';

    // Загружаем отделы
    final deptResult = await ApiService.getDepartments();
    if (deptResult['success'] == true) {
      final data = deptResult['data'] as List;
      departments = data
          .map((d) => DepartmentModel.fromJson(d as Map<String, dynamic>))
          .toList();
      isLoadingDepartments = false;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text(
              'Фильтры',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Фильтр по отделам
                    const Text(
                      'По отделам:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingDepartments)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (departments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Нет отделов',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: departments.map((dept) {
                          final isSelected = tempSelectedDepartmentIds.contains(dept.id);
                          final deptColor = _parseColor(dept.color);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  tempSelectedDepartmentIds.remove(dept.id);
                                } else {
                                  tempSelectedDepartmentIds.add(dept.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: deptColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: deptColor,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: deptColor.withOpacity(0.8),
                                          blurRadius: 4,
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: deptColor.withOpacity(0.6),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                        BoxShadow(
                                          color: deptColor.withOpacity(0.4),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: deptColor.withOpacity(0.3),
                                          blurRadius: 16,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    )
                                  : BoxDecoration(
                                      color: deptColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: deptColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                              child: Text(
                                dept.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),
                    // Фильтр по выполнению
                    const Text(
                      'По выполнению:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildCompletionFilterChip(
                          label: 'Все',
                          value: 'all',
                          selectedValue: tempCompletionFilter,
                          color: AppColors.textSecondary,
                          onTap: () {
                            setDialogState(() {
                              tempCompletionFilter = 'all';
                            });
                          },
                        ),
                        _buildCompletionFilterChip(
                          label: 'Выполнено',
                          value: 'completed',
                          selectedValue: tempCompletionFilter,
                          color: AppColors.accentGreen,
                          onTap: () {
                            setDialogState(() {
                              tempCompletionFilter = 'completed';
                            });
                          },
                        ),
                        _buildCompletionFilterChip(
                          label: 'Не выполнено',
                          value: 'incomplete',
                          selectedValue: tempCompletionFilter,
                          color: AppColors.accentBlue,
                          onTap: () {
                            setDialogState(() {
                              tempCompletionFilter = 'incomplete';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempSelectedDepartmentIds.clear();
                    tempCompletionFilter = 'all';
                  });
                },
                child: const Text(
                  'Сбросить',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Отмена',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    // Создаем новый Set для избежания проблем с ссылками
                    _selectedDepartmentIds = tempSelectedDepartmentIds.isEmpty
                        ? null
                        : Set<int>.from(tempSelectedDepartmentIds);
                    _completionFilter = tempCompletionFilter == 'all'
                        ? null
                        : tempCompletionFilter;
                    _updateFilters();
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                ),
                child: const Text(
                  'Применить',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.description,
                  color: AppColors.accentGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Проектные листы',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showFilterDialog,
                  icon: Stack(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: hasActiveFilters()
                            ? AppColors.accentBlue
                            : AppColors.textSecondary,
                      ),
                      if (hasActiveFilters())
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.cardBackground,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Фильтры',
                ),
                FloatingActionButton.small(
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (context) => ProjectSheetFormDialog(
                        sheet: null,
                        project: ProjectModel(id: widget.projectId, name: '', code: '', cipher: ''),
                        onRefresh: refresh,
                      ),
                    );
                    if (result != null && result['success'] == true) {
                      refresh();
                      widget.onSheetAdded();
                    }
                  },
                  backgroundColor: AppColors.accentGreen,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 510, // Фиксированная высота для 5 карточек (600px - 15%)
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _sheets.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Нет листов',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _sheets.length,
                        itemBuilder: (context, index) {
                          return _buildSheetCard(_sheets[index]);
                        },
                      ),
          ),
          _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildSheetCard(ProjectSheetModel sheet) {
    final canToggleCompleted = widget.currentUserId != null &&
        sheet.createdById != null &&
        widget.currentUserId == sheet.createdById;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: sheet.isCompleted
              ? AppColors.accentGreen
              : AppColors.borderColor.withOpacity(0.3),
          width: sheet.isCompleted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await showDialog(
            context: context,
            builder: (context) => ProjectSheetFormDialog(
              sheet: sheet,
              project: ProjectModel(id: widget.projectId, name: '', code: '', cipher: ''),
              onRefresh: refresh,
            ),
          );
          if (result != null && result['success'] == true) {
            refresh();
            widget.onSheetAdded();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!sheet.isCompleted)
                    Checkbox(
                      value: sheet.isCompleted,
                      onChanged: canToggleCompleted
                          ? (value) async {
                              final result = await ApiService.toggleProjectSheetCompleted(
                                sheet.id,
                                value ?? false,
                              );
                              if (result['success'] == true) {
                                refresh();
                                widget.onSheetAdded();
                                widget.onProjectUpdated?.call();
                              }
                            }
                          : null,
                      activeColor: AppColors.accentGreen,
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheet.name ?? 'Без названия',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: sheet.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (sheet.status != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (sheet.responsibleDepartment != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.business,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  sheet.responsibleDepartment!.name,
                                  style: TextStyle(
                                    color: _parseColor(sheet.responsibleDepartment!.color),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (sheet.description != null && sheet.description!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            sheet.description!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final startItem = ((_currentPage - 1) * 5) + 1;
    final endItem = (_currentPage * 5).clamp(0, _totalCount);

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
                onPressed: _currentPage > 1 && !_isLoading
                    ? () => _loadSheets(page: _currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
                color: _currentPage > 1
                    ? AppColors.accentBlue
                    : AppColors.textSecondary.withOpacity(0.3),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentPage < _totalPages && !_isLoading
                    ? () => _loadSheets(page: _currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
                color: _currentPage < _totalPages
                    ? AppColors.accentBlue
                    : AppColors.textSecondary.withOpacity(0.3),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', '0xFF')));
    } catch (e) {
      return AppColors.textSecondary;
    }
  }
}

