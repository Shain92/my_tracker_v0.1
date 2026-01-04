import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../widgets/construction_site_form_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    _loadConstructionSites();
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
                );
              },
            ),
    );
  }
}

/// Карточка строительного участка
class _ConstructionSiteCard extends StatelessWidget {
  final ConstructionSiteModel constructionSite;
  final VoidCallback? onRefresh;

  const _ConstructionSiteCard({
    required this.constructionSite,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SiteProjectsScreen(
                constructionSite: constructionSite,
              ),
            ),
          );
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
                        constructionSite.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (constructionSite.description != null &&
                          constructionSite.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          constructionSite.description!,
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
                          if (constructionSite.manager != null) ...[
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
                                  constructionSite.manager!.username,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (constructionSite.completionPercentage != null) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${constructionSite.completionPercentage!.toStringAsFixed(1)}%',
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
        constructionSite: constructionSite,
        onRefresh: onRefresh,
      ),
    );
    if (result != null && result['success'] == true && onRefresh != null) {
      onRefresh!();
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
