import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'project_detail_screen.dart';

/// Экран задач
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ProjectsColumnWidget(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SheetsColumnWidget(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Узел иерархии для строительного участка
class _ConstructionSiteNode {
  final ConstructionSiteModel site;
  final Map<int, _ProjectNode> projects = {};
  bool isExpanded = true;

  _ConstructionSiteNode(this.site);
}

/// Узел иерархии для проекта
class _ProjectNode {
  final ProjectModel project;
  final List<ProjectStageModel> stages = [];
  bool isExpanded = true;

  _ProjectNode(this.project);
}

/// Узел иерархии для листа
class _SheetNode {
  final ProjectSheetModel sheet;
  bool isExpanded = true;

  _SheetNode(this.sheet);
}

/// Столбец "Проекты" с этапами пользователя
class _ProjectsColumnWidget extends StatefulWidget {
  @override
  State<_ProjectsColumnWidget> createState() => _ProjectsColumnWidgetState();
}

class _ProjectsColumnWidgetState extends State<_ProjectsColumnWidget> {
  bool _isLoading = false;
  List<ProjectStageModel> _allStages = [];
  Map<int, _ConstructionSiteNode> _hierarchy = {};
  
  // Фильтры
  int? _selectedConstructionSiteId;
  int? _selectedProjectId;
  Set<int> _selectedStatusIds = {}; // Множественный выбор статусов
  
  List<ConstructionSiteModel> _constructionSites = [];
  List<ProjectModel> _projects = [];
  List<StatusModel> _stageStatuses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadConstructionSites();
    _loadStageStatuses();
  }

  /// Загрузка статусов этапов
  Future<void> _loadStageStatuses() async {
    try {
      final result = await ApiService.getStatuses(statusType: 'stage');
      if (result['success'] == true && mounted) {
        final data = result['data'] as List?;
        if (data != null) {
          setState(() {
            _stageStatuses = data
                .map((s) => StatusModel.fromJson(s as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (e) {
      // Игнорируем ошибки
    }
  }

  /// Загрузка строительных участков
  Future<void> _loadConstructionSites() async {
    try {
      final result = await ApiService.getConstructionSites();
      if (result['success'] == true && mounted) {
        final data = result['data'] as List?;
        if (data != null) {
          setState(() {
            _constructionSites = data
                .map((s) => ConstructionSiteModel.fromJson(s as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (e) {
      // Игнорируем ошибки
    }
  }

  /// Загрузка проектов для выбранного участка
  Future<void> _loadProjects() async {
    if (_selectedConstructionSiteId == null) {
      setState(() {
        _projects = [];
      });
      return;
    }

    try {
      final result = await ApiService.getProjects(
        constructionSiteId: _selectedConstructionSiteId,
      );
      if (result['success'] == true && mounted) {
        final data = result['data'] as List?;
        if (data != null) {
          setState(() {
            _projects = data
                .map((p) => ProjectModel.fromJson(p as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (e) {
      // Игнорируем ошибки
    }
  }

  /// Загрузка этапов пользователя
  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Загружаем все страницы
      List<ProjectStageModel> allStages = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final result = await ApiService.getUserStages(
          constructionSiteId: _selectedConstructionSiteId,
          projectId: _selectedProjectId,
          page: page,
          pageSize: 100,
        );

        if (result['success'] == true) {
          final data = result['data'] as List?;
          if (data != null && data.isNotEmpty) {
            final pageStages = data
                .map((s) => ProjectStageModel.fromJson(s as Map<String, dynamic>))
                .toList();
            allStages.addAll(pageStages);
            page++;
            hasMore = data.length >= 100;
          } else {
            hasMore = false;
          }
        } else {
          hasMore = false;
        }
      }

      if (mounted) {
        setState(() {
          _allStages = allStages;
          _buildHierarchy();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Построение иерархии
  void _buildHierarchy() {
    _hierarchy.clear();

    for (final stage in _allStages) {
      // Применяем фильтр по статусам
      if (_selectedStatusIds.isNotEmpty) {
        final stageStatusId = stage.status?.id ?? stage.statusId;
        if (stageStatusId == null || !_selectedStatusIds.contains(stageStatusId)) {
          continue;
        }
      }

      final project = stage.project;
      if (project == null) continue;

      final site = project.constructionSite;
      if (site == null) continue;

      // Получаем или создаем узел участка
      if (!_hierarchy.containsKey(site.id)) {
        _hierarchy[site.id] = _ConstructionSiteNode(site);
      }
      final siteNode = _hierarchy[site.id]!;

      // Получаем или создаем узел проекта
      if (!siteNode.projects.containsKey(project.id)) {
        siteNode.projects[project.id] = _ProjectNode(project);
      }
      final projectNode = siteNode.projects[project.id]!;

      // Добавляем этап
      projectNode.stages.add(stage);
    }
  }

  /// Применение фильтров
  void _applyFilters() {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Проекты',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildHierarchyList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Построение панели фильтров
  Widget _buildFilters() {
    return Column(
      children: [
        // Фильтр по статусам этапов (множественный выбор)
        InkWell(
          onTap: () => _showStatusSelectionDialog(),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Статус Этапа',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              _selectedStatusIds.isEmpty
                  ? 'Все статусы'
                  : _selectedStatusIds.length == 1
                      ? _stageStatuses
                          .firstWhere((s) => _selectedStatusIds.contains(s.id),
                              orElse: () => _stageStatuses.isNotEmpty ? _stageStatuses.first : StatusModel(
                                id: 0,
                                name: 'Неизвестный',
                                color: '#808080',
                                statusType: 'stage',
                              ))
                          .name
                      : 'Выбрано: ${_selectedStatusIds.length}',
              style: TextStyle(
                color: _selectedStatusIds.isEmpty
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
        // Отображение выбранных статусов
        if (_selectedStatusIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedStatusIds.map((statusId) {
              final status = _stageStatuses.firstWhere(
                (s) => s.id == statusId,
                orElse: () => StatusModel(
                  id: statusId,
                  name: 'Неизвестный',
                  color: '#808080',
                  statusType: 'stage',
                ),
              );
              return Chip(
                label: Text(status.name),
                backgroundColor: _parseColor(status.color).withOpacity(0.2),
                deleteIcon: Icon(
                  Icons.close,
                  size: 18,
                  color: _parseColor(status.color),
                ),
                onDeleted: () {
                  setState(() {
                    _selectedStatusIds.remove(statusId);
                  });
                  _applyFilters();
                },
                labelStyle: TextStyle(
                  color: _parseColor(status.color),
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        // Фильтр по строительному участку
        DropdownButtonFormField<int?>(
          value: _selectedConstructionSiteId,
          decoration: InputDecoration(
            labelText: 'Строительный участок',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Все')),
            ..._constructionSites.map((site) => DropdownMenuItem<int?>(
              value: site.id,
              child: Text(site.name),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedConstructionSiteId = value;
              _selectedProjectId = null;
            });
            _loadProjects();
            _applyFilters();
          },
        ),
        const SizedBox(height: 12),
        // Фильтр по проекту
        DropdownButtonFormField<int?>(
          value: _selectedProjectId,
          decoration: InputDecoration(
            labelText: 'Проект',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Все')),
            ..._projects.map((project) => DropdownMenuItem<int?>(
              value: project.id,
              child: Text(project.name),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedProjectId = value;
            });
            _applyFilters();
          },
        ),
      ],
    );
  }

  /// Построение списка карточек этапов
  Widget _buildHierarchyList() {
    // Собираем все этапы в плоский список
    List<ProjectStageModel> allStages = [];
    for (final siteNode in _hierarchy.values) {
      for (final projectNode in siteNode.projects.values) {
        allStages.addAll(projectNode.stages);
      }
    }

    if (allStages.isEmpty) {
      return Center(
        child: Text(
          'Нет этапов',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: allStages.length,
      itemBuilder: (context, index) {
        final stage = allStages[index];
        return _buildStageCard(stage);
      },
    );
  }

  /// Построение карточки этапа
  Widget _buildStageCard(ProjectStageModel stage) {
    final description = stage.description ?? '';
    final shortDescription = description.length > 100
        ? '${description.substring(0, 100)}...'
        : description;
    
    final project = stage.project;
    final site = project?.constructionSite;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        color: AppColors.cardBackground.withOpacity(0.6),
        child: InkWell(
          onTap: () {
            if (project != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailScreen(
                    project: project,
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Строительный участок
                if (site != null) ...[
                  Text(
                    site.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // Проект
                if (project != null) ...[
                  Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Дата и время
                Text(
                  '${stage.datetime.day}.${stage.datetime.month}.${stage.datetime.year} ${stage.datetime.hour}:${stage.datetime.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                // Описание
                if (shortDescription.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    shortDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                // Статус
                if (stage.status != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _parseColor(stage.status!.color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stage.status!.name,
                      style: TextStyle(
                        color: _parseColor(stage.status!.color),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Парсинг цвета из строки
  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.textSecondary;
    }
  }

  /// Показ диалога выбора статусов
  Future<void> _showStatusSelectionDialog() async {
    final Set<int> tempSelectedStatusIds = Set<int>.from(_selectedStatusIds);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Выберите статусы этапов'),
          content: SizedBox(
            width: double.maxFinite,
            child: _stageStatuses.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _stageStatuses.length,
                    itemBuilder: (context, index) {
                      final status = _stageStatuses[index];
                      final isSelected = tempSelectedStatusIds.contains(status.id);
                      final statusColor = _parseColor(status.color);

                      return CheckboxListTile(
                        title: Text(status.name),
                        value: isSelected,
                        activeColor: statusColor,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              tempSelectedStatusIds.add(status.id);
                            } else {
                              tempSelectedStatusIds.remove(status.id);
                            }
                          });
                        },
                        secondary: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  tempSelectedStatusIds.clear();
                });
              },
              child: const Text('Очистить'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedStatusIds = tempSelectedStatusIds;
                });
                Navigator.of(context).pop();
                _applyFilters();
              },
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Столбец "Листы ИД" с листами отдела пользователя
class _SheetsColumnWidget extends StatefulWidget {
  @override
  State<_SheetsColumnWidget> createState() => _SheetsColumnWidgetState();
}

class _SheetsColumnWidgetState extends State<_SheetsColumnWidget> {
  bool _isLoading = false;
  List<ProjectSheetModel> _allSheets = [];
  Map<int, _ConstructionSiteNodeForSheets> _hierarchy = {};
  
  // Фильтры
  int? _selectedConstructionSiteId;
  int? _selectedProjectId;
  String _completionFilter = 'all'; // 'all', 'completed', 'incomplete'
  
  List<ConstructionSiteModel> _constructionSites = [];
  List<ProjectModel> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadConstructionSites();
  }

  /// Загрузка строительных участков
  Future<void> _loadConstructionSites() async {
    try {
      final result = await ApiService.getConstructionSites();
      if (result['success'] == true && mounted) {
        final data = result['data'] as List?;
        if (data != null) {
          setState(() {
            _constructionSites = data
                .map((s) => ConstructionSiteModel.fromJson(s as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (e) {
      // Игнорируем ошибки
    }
  }

  /// Загрузка проектов для выбранного участка
  Future<void> _loadProjects() async {
    if (_selectedConstructionSiteId == null) {
      setState(() {
        _projects = [];
      });
      return;
    }

    try {
      final result = await ApiService.getProjects(
        constructionSiteId: _selectedConstructionSiteId,
      );
      if (result['success'] == true && mounted) {
        final data = result['data'] as List?;
        if (data != null) {
          setState(() {
            _projects = data
                .map((p) => ProjectModel.fromJson(p as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (e) {
      // Игнорируем ошибки
    }
  }

  /// Загрузка листов отдела
  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Загружаем все страницы
      List<ProjectSheetModel> allSheets = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final result = await ApiService.getDepartmentSheets(
          constructionSiteId: _selectedConstructionSiteId,
          projectId: _selectedProjectId,
          isCompleted: _completionFilter == 'all'
              ? null
              : _completionFilter == 'completed',
          page: page,
          pageSize: 100,
        );

        if (result['success'] == true) {
          final data = result['data'] as List?;
          if (data != null && data.isNotEmpty) {
            final pageSheets = data
                .map((s) => ProjectSheetModel.fromJson(s as Map<String, dynamic>))
                .toList();
            allSheets.addAll(pageSheets);
            page++;
            hasMore = data.length >= 100;
          } else {
            hasMore = false;
          }
        } else {
          hasMore = false;
        }
      }

      if (mounted) {
        setState(() {
          _allSheets = allSheets;
          _buildHierarchy();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Построение иерархии
  void _buildHierarchy() {
    _hierarchy.clear();

    for (final sheet in _allSheets) {
      // Применяем фильтр по выполнению
      if (_completionFilter == 'completed' && !sheet.isCompleted) {
        continue;
      } else if (_completionFilter == 'incomplete' && sheet.isCompleted) {
        continue;
      }

      final project = sheet.project;
      if (project == null) continue;

      final site = project.constructionSite;
      if (site == null) continue;

      // Получаем или создаем узел участка
      if (!_hierarchy.containsKey(site.id)) {
        _hierarchy[site.id] = _ConstructionSiteNodeForSheets(site);
      }
      final siteNode = _hierarchy[site.id]!;

      // Получаем или создаем узел проекта
      if (!siteNode.projects.containsKey(project.id)) {
        siteNode.projects[project.id] = _ProjectNodeForSheets(project);
      }
      final projectNode = siteNode.projects[project.id]!;

      // Добавляем лист
      projectNode.sheets.add(_SheetNode(sheet));
    }
  }

  /// Применение фильтров
  void _applyFilters() {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Листы ИД',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildHierarchyList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Построение панели фильтров
  Widget _buildFilters() {
    return Column(
      children: [
        // Фильтр по статусу выполнения
        DropdownButtonFormField<String>(
          value: _completionFilter,
          decoration: InputDecoration(
            labelText: 'Статус выполнения',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Все')),
            DropdownMenuItem(value: 'completed', child: Text('Выполнено')),
            DropdownMenuItem(value: 'incomplete', child: Text('Не выполнено')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _completionFilter = value;
              });
              _applyFilters();
            }
          },
        ),
        const SizedBox(height: 12),
        // Фильтр по строительному участку
        DropdownButtonFormField<int?>(
          value: _selectedConstructionSiteId,
          decoration: InputDecoration(
            labelText: 'Строительный участок',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Все')),
            ..._constructionSites.map((site) => DropdownMenuItem<int?>(
              value: site.id,
              child: Text(site.name),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedConstructionSiteId = value;
              _selectedProjectId = null;
            });
            _loadProjects();
            _applyFilters();
          },
        ),
        const SizedBox(height: 12),
        // Фильтр по проекту
        DropdownButtonFormField<int?>(
          value: _selectedProjectId,
          decoration: InputDecoration(
            labelText: 'Проект',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Все')),
            ..._projects.map((project) => DropdownMenuItem<int?>(
              value: project.id,
              child: Text(project.name),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedProjectId = value;
            });
            _applyFilters();
          },
        ),
      ],
    );
  }

  /// Построение иерархического списка
  Widget _buildHierarchyList() {
    if (_hierarchy.isEmpty) {
      return Center(
        child: Text(
          'Нет листов',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _hierarchy.length,
      itemBuilder: (context, index) {
        final siteNode = _hierarchy.values.elementAt(index);
        return _buildSiteNode(siteNode);
      },
    );
  }

  /// Построение узла строительного участка
  Widget _buildSiteNode(_ConstructionSiteNodeForSheets siteNode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              siteNode.isExpanded = !siteNode.isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(
                  siteNode.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  siteNode.site.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (siteNode.isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Column(
              children: siteNode.projects.values.map((projectNode) {
                return _buildProjectNode(projectNode);
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// Построение узла проекта
  Widget _buildProjectNode(_ProjectNodeForSheets projectNode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              projectNode.isExpanded = !projectNode.isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(
                  projectNode.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectDetailScreen(
                            project: projectNode.project,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      projectNode.project.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.accentBlue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (projectNode.isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Column(
              children: projectNode.sheets.map((sheetNode) {
                return _buildSheetItem(sheetNode.sheet);
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// Построение элемента листа
  Widget _buildSheetItem(ProjectSheetModel sheet) {
    final description = sheet.description ?? '';
    final shortDescription = description.length > 100
        ? '${description.substring(0, 100)}...'
        : description;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Card(
        color: AppColors.cardBackground.withOpacity(0.3),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectDetailScreen(
                  project: sheet.project ?? ProjectModel(
                    id: sheet.projectId,
                    name: '',
                    code: '',
                    cipher: '',
                  ),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sheet.name ?? 'Без названия',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.accentBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (sheet.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Выполнено',
                          style: TextStyle(
                            color: AppColors.accentGreen,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (shortDescription.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    shortDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (sheet.status != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _parseColor(sheet.status!.color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sheet.status!.name,
                      style: TextStyle(
                        color: _parseColor(sheet.status!.color),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Парсинг цвета из строки
  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.textSecondary;
    }
  }
}

/// Узел иерархии для строительного участка (для листов)
class _ConstructionSiteNodeForSheets {
  final ConstructionSiteModel site;
  final Map<int, _ProjectNodeForSheets> projects = {};
  bool isExpanded = true;

  _ConstructionSiteNodeForSheets(this.site);
}

/// Узел иерархии для проекта (для листов)
class _ProjectNodeForSheets {
  final ProjectModel project;
  final List<_SheetNode> sheets = [];
  bool isExpanded = true;

  _ProjectNodeForSheets(this.project);
}
