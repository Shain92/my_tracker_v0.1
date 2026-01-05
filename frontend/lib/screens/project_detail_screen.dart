import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/project_stage_form_dialog.dart';
import '../widgets/project_sheet_form_dialog.dart';
import '../utils/web_utils.dart';

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
  
  // Ключи для независимых виджетов колонок
  final GlobalKey<_StagesColumnWidgetState> _stagesKey = GlobalKey<_StagesColumnWidgetState>();
  final GlobalKey<_SheetsColumnWidgetState> _sheetsKey = GlobalKey<_SheetsColumnWidgetState>();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadData();
  }

  /// Загрузка текущего пользователя
  Future<void> _loadCurrentUser() async {
    final user = await ApiService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUserId = user['id'] as int?;
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

  /// Обновление данных
  void _refreshData() {
    _stagesKey.currentState?.refresh();
    _sheetsKey.currentState?.refresh();
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

  /// Информация о проекте
  Widget _buildProjectInfo(bool isMobile) {
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
              Text(
                'Информация о проекте',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
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
          // Процент выполнения
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
                '${widget.project.completionPercentage?.toStringAsFixed(1) ?? 0.0}%',
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
            value: (widget.project.completionPercentage ?? 0.0) / 100,
            backgroundColor: AppColors.backgroundSecondary,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
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
      onSheetAdded: () {},
    );
  }

  /// Карточка этапа
  Widget _buildStageCard(ProjectStageModel stage, bool isMobile) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: AppColors.cardBackground,
      child: InkWell(
        onTap: () => _showStageDialog(stage),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Дата и время
              Text(
                '${stage.datetime.day.toString().padLeft(2, '0')}.${stage.datetime.month.toString().padLeft(2, '0')}.${stage.datetime.year} ${stage.datetime.hour.toString().padLeft(2, '0')}:${stage.datetime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Статус целиком
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
              // Ответственные пользователи
              if (stage.responsibleUsers != null && stage.responsibleUsers!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: stage.responsibleUsers!.map((user) {
                    final departmentColor = user.department?.color != null
                        ? _parseColor(user.department!.color)
                        : AppColors.textSecondary;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.username,
                          style: TextStyle(
                            color: departmentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
              if (stage.fileUrl != null && stage.fileUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _downloadStageFile(stage),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.download,
                        size: 16,
                        color: AppColors.accentBlue,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Скачать файл',
                        style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Карточка листа
  Widget _buildSheetCard(ProjectSheetModel sheet, bool isMobile) {
    final canToggleCompleted = _currentUserId != null &&
        sheet.createdById != null &&
        _currentUserId == sheet.createdById;

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
        onTap: () => _showSheetDialog(sheet),
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
                          ? (value) => _toggleSheetCompleted(sheet, value ?? false)
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
                      ],
                    ),
                  ),
                ],
              ),
              if (sheet.responsibleDepartment != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _parseColor(sheet.responsibleDepartment!.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sheet.responsibleDepartment!.name,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              if (sheet.description != null && sheet.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
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
              if (sheet.fileUrl != null && sheet.fileUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _downloadFile(sheet),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.download,
                        size: 16,
                        color: AppColors.accentBlue,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Скачать файл',
                        style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Показать диалог этапа
  Future<void> _showStageDialog(ProjectStageModel? stage) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ProjectStageFormDialog(
        stage: stage,
        project: widget.project,
        onRefresh: _refreshData,
      ),
    );

    if (result != null && result['success'] == true) {
      _refreshData();
    }
  }

  /// Показать диалог листа
  Future<void> _showSheetDialog(ProjectSheetModel? sheet) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ProjectSheetFormDialog(
        sheet: sheet,
        project: widget.project,
        onRefresh: _refreshData,
      ),
    );

    if (result != null && result['success'] == true) {
      _refreshData();
    }
  }


  /// Переключение статуса выполнения листа
  Future<void> _toggleSheetCompleted(ProjectSheetModel sheet, bool value) async {
    final result = await ApiService.toggleProjectSheetCompleted(sheet.id, value);
    if (result['success'] == true) {
      _refreshData();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка обновления'),
            backgroundColor: AppColors.accentPink,
          ),
        );
      }
    }
  }

  /// Скачивание файла проектного листа
  Future<void> _downloadFile(ProjectSheetModel sheet) async {
    if (sheet.fileUrl == null || sheet.fileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Файл не прикреплен'),
          backgroundColor: AppColors.accentPink,
        ),
      );
      return;
    }

    try {
      final result = await ApiService.downloadProjectSheetFile(sheet.id);
      if (result['success'] == true) {
        final bytes = result['data'] as List<int>;
        final headers = result['headers'] as Map<String, String>;
        
        // Получаем имя файла из заголовков или используем дефолтное
        String filename = sheet.fileUrl!.split('/').last;
        if (headers.containsKey('content-disposition')) {
          final contentDisposition = headers['content-disposition']!;
          // Парсим имя файла из заголовка Content-Disposition
          // Формат: attachment; filename="file.pdf" или attachment; filename=file.pdf
          final filenamePattern = RegExp(r'filename[^;=\n]*=([^;\n]*)');
          final match = filenamePattern.firstMatch(contentDisposition);
          if (match != null) {
            String? extracted = match.group(1);
            if (extracted != null && extracted.isNotEmpty) {
              extracted = extracted.trim();
              // Убираем кавычки
              if (extracted.startsWith('"') && extracted.endsWith('"')) {
                extracted = extracted.substring(1, extracted.length - 1);
              } else if (extracted.startsWith("'") && extracted.endsWith("'")) {
                extracted = extracted.substring(1, extracted.length - 1);
              }
              if (extracted.isNotEmpty) {
                filename = extracted;
              }
            }
          }
        }
        
        // Используем прямой URL файла для скачивания
        if (sheet.fileUrl != null && sheet.fileUrl!.isNotEmpty) {
          _downloadFileFromUrl(sheet.fileUrl!, filename);
        } else {
          // Если URL нет, используем blob для веб
          _downloadFileBytes(bytes, filename);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка скачивания файла'),
            backgroundColor: AppColors.accentPink,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: AppColors.accentPink,
        ),
      );
    }
  }

  /// Скачивание файла этапа проекта
  Future<void> _downloadStageFile(ProjectStageModel stage) async {
    if (stage.fileUrl == null || stage.fileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Файл не прикреплен'),
          backgroundColor: AppColors.accentPink,
        ),
      );
      return;
    }

    try {
      final result = await ApiService.downloadProjectStageFile(stage.id);
      if (result['success'] == true) {
        final bytes = result['data'] as List<int>;
        final headers = result['headers'] as Map<String, String>;
        
        // Получаем имя файла из заголовков или используем дефолтное
        String filename = stage.fileUrl!.split('/').last;
        if (headers.containsKey('content-disposition')) {
          final contentDisposition = headers['content-disposition']!;
          final filenamePattern = RegExp(r'filename[^;=\n]*=([^;\n]*)');
          final match = filenamePattern.firstMatch(contentDisposition);
          if (match != null) {
            String? extracted = match.group(1);
            if (extracted != null && extracted.isNotEmpty) {
              extracted = extracted.trim();
              if (extracted.startsWith('"') && extracted.endsWith('"')) {
                extracted = extracted.substring(1, extracted.length - 1);
              } else if (extracted.startsWith("'") && extracted.endsWith("'")) {
                extracted = extracted.substring(1, extracted.length - 1);
              }
              if (extracted.isNotEmpty) {
                filename = extracted;
              }
            }
          }
        }
        
        if (stage.fileUrl != null && stage.fileUrl!.isNotEmpty) {
          _downloadFileFromUrl(stage.fileUrl!, filename);
        } else {
          _downloadFileBytes(bytes, filename);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка скачивания файла'),
            backgroundColor: AppColors.accentPink,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: AppColors.accentPink,
        ),
      );
    }
  }

  /// Скачивание файла по URL
  void _downloadFileFromUrl(String url, String filename) {
    // Для веб открываем URL напрямую
    if (kIsWeb) {
      _openUrlWeb(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Файл открыт в новой вкладке'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Откройте файл: $url'),
          backgroundColor: AppColors.accentBlue,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Открытие URL для веб
  void _openUrlWeb(String url) {
    openUrlInNewTab(url);
  }

  /// Скачивание файла из байтов
  void _downloadFileBytes(List<int> bytes, String filename) {
    if (kIsWeb) {
      try {
        downloadFileFromBytes(bytes, filename);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл скачан'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка скачивания: ${e.toString()}'),
            backgroundColor: AppColors.accentPink,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Файл получен: $filename (${(bytes.length / 1024).toStringAsFixed(1)} KB)'),
          backgroundColor: AppColors.accentBlue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Парсинг цвета из HEX строки
  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', '0xFF')));
    } catch (e) {
      return AppColors.textSecondary;
    }
  }

  /// Виджет пагинации
  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalCount,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required bool hasPrevious,
    required bool hasNext,
  }) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final startItem = ((currentPage - 1) * 5) + 1;
    final endItem = (currentPage * 5).clamp(0, totalCount);

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
            'Показано $startItem-$endItem из $totalCount',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: hasPrevious ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
                color: hasPrevious
                    ? AppColors.accentBlue
                    : AppColors.textSecondary.withOpacity(0.3),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                '$currentPage / $totalPages',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: hasNext ? onNext : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
                color: hasNext
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
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;

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
            _stages = data
                .map((s) => ProjectStageModel.fromJson(s as Map<String, dynamic>))
                .toList();
          } else {
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
            _totalCount = _stages.length;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceAll('#', '0xFF')));
    } catch (e) {
      return AppColors.textSecondary;
    }
  }
}

/// Виджет колонки листов с независимым состоянием
class _SheetsColumnWidget extends StatefulWidget {
  final int projectId;
  final bool isMobile;
  final int? currentUserId;
  final VoidCallback onSheetAdded;

  const _SheetsColumnWidget({
    super.key,
    required this.projectId,
    required this.isMobile,
    this.currentUserId,
    required this.onSheetAdded,
  });

  @override
  State<_SheetsColumnWidget> createState() => _SheetsColumnWidgetState();
}

class _SheetsColumnWidgetState extends State<_SheetsColumnWidget> {
  List<ProjectSheetModel> _sheets = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;

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
            _sheets = data
                .map((s) => ProjectSheetModel.fromJson(s as Map<String, dynamic>))
                .toList();
          } else {
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
            _totalCount = _sheets.length;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
