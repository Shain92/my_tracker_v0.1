import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Сайдбар с эффектом glassmorphism и темной темой
class AppSidebar extends StatefulWidget {
  final String selectedItem;
  final Function(String) onItemSelected;

  const AppSidebar({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isSuperuser = false;
  bool _isLoading = true;
  Set<String> _allowedPages = {'home'}; // По умолчанию доступна только главная

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
  }

  Future<void> _loadUserPermissions() async {
    // Загружаем статус суперпользователя
    bool isSuperuser = await ApiService.getIsSuperuser();
    
    if (!isSuperuser) {
      final userData = await ApiService.getCurrentUser();
      if (userData != null && userData['is_superuser'] != null) {
        isSuperuser = userData['is_superuser'] as bool;
      }
    }
    
    // Если не суперпользователь, загружаем права доступа
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
      // Суперпользователь имеет доступ ко всем страницам
      _allowedPages = {'home', 'tasks', 'projects', 'settings', 'users_list', 'departments_list'};
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
    return Material(
      elevation: 4,
      color: Colors.transparent,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cardBackground.withOpacity(0.8),
              AppColors.cardBackground.withOpacity(0.6),
            ],
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withOpacity(0.3),
                border: Border(
                  right: BorderSide(
                    color: AppColors.accentBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    if (_hasAccess('home'))
                      _MenuItem(
                        title: 'Главная',
                        icon: Icons.home,
                        isSelected: widget.selectedItem == 'home',
                        onTap: () => widget.onItemSelected('home'),
                      ),
                    if (_hasAccess('tasks'))
                      _MenuItem(
                        title: 'Задачи',
                        icon: Icons.task_alt,
                        isSelected: widget.selectedItem == 'tasks',
                        onTap: () => widget.onItemSelected('tasks'),
                      ),
                    if (_hasAccess('projects'))
                      _MenuItem(
                        title: 'Проекты',
                        icon: Icons.folder,
                        isSelected: widget.selectedItem == 'projects',
                        onTap: () => widget.onItemSelected('projects'),
                      ),
                    if (!_isLoading && _hasAccess('settings')) ...[
                      const SizedBox(height: 8),
                      const Divider(
                        color: AppColors.borderColor,
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      const SizedBox(height: 8),
                      _MenuItem(
                        title: 'Настройки',
                        icon: Icons.settings,
                        isSelected: widget.selectedItem == 'settings',
                        onTap: () => widget.onItemSelected('settings'),
                        isSpecial: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пункт меню сайдбара
class _MenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isSpecial;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isSpecial ? AppColors.accentOrange : AppColors.accentBlue;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: accentColor,
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? accentColor
                  : (isSpecial ? AppColors.accentOrange.withOpacity(0.7) : AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.textPrimary
                    : (isSpecial ? AppColors.accentOrange.withOpacity(0.9) : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

