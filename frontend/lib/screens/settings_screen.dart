import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'users_list_screen.dart';
import 'departments_list_screen.dart';
import 'statuses_list_screen.dart';

/// Страница настроек
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isSuperuser = false;
  Set<String> _allowedPages = {'home'};

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
  }

  /// Загрузка прав доступа пользователя
  Future<void> _loadUserPermissions() async {
    bool isSuperuser = await ApiService.getIsSuperuser();
    
    if (!isSuperuser) {
      final userData = await ApiService.getCurrentUser();
      if (userData != null && userData['is_superuser'] != null) {
        isSuperuser = userData['is_superuser'] as bool;
      }
    }
    
    if (!isSuperuser) {
      final permissionsResult = await ApiService.getUserPagePermissions();
      if (permissionsResult['success'] == true) {
        final data = permissionsResult['data'];
        if (data != null && data['pages'] != null) {
          final pages = data['pages'] as List;
          _allowedPages = pages.map((p) => p.toString()).toSet();
        }
      }
    } else {
      _allowedPages = {'home', 'tasks', 'projects', 'settings', 'users_list', 'departments_list', 'project_id', 'statuses_list'};
    }
    
    if (mounted) {
      setState(() {
        _isSuperuser = isSuperuser;
        _isLoading = false;
      });
    }
  }

  /// Проверка доступа к странице
  bool _hasAccess(String pageId) {
    if (_isSuperuser) return true;
    return _allowedPages.contains(pageId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings,
                color: AppColors.accentOrange,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'Настройки системы',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_hasAccess('users_list') || _hasAccess('departments_list'))
                          _SettingsSection(
                            title: 'Управление пользователями',
                            icon: Icons.people,
                            children: [
                              if (_hasAccess('users_list'))
                                _SettingsCard(
                                  title: 'Список пользователей',
                                  description: 'Просмотр и управление пользователями системы',
                                  icon: Icons.person,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UsersListScreen(),
                                      ),
                                    );
                                  },
                                ),
                              if (_hasAccess('departments_list'))
                                _SettingsCard(
                                  title: 'Отделы',
                                  description: 'Просмотр и управление отделами системы',
                                  icon: Icons.business,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const DepartmentsListScreen(),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                  const SizedBox(height: 24),
                  _SettingsSection(
                    title: 'Системные настройки',
                    icon: Icons.tune,
                    children: [
                      if (_hasAccess('statuses_list'))
                        _SettingsCard(
                          title: 'Статусы',
                          description: 'Просмотр и управление статусами проектных листов и этапов',
                          icon: Icons.label,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StatusesListScreen(),
                              ),
                            );
                          },
                        ),
                      _SettingsCard(
                        title: 'Конфигурация базы данных',
                        description: 'Настройки подключения к базе данных',
                        icon: Icons.storage,
                        onTap: () {
                          // TODO: Реализовать настройки БД
                        },
                      ),
                      _SettingsCard(
                        title: 'Резервное копирование',
                        description: 'Управление резервными копиями данных',
                        icon: Icons.backup,
                        onTap: () {
                          // TODO: Реализовать резервное копирование
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Секция настроек
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: AppColors.accentOrange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

/// Карточка настройки
class _SettingsCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.accentOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

