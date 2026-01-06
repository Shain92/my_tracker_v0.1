import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/glass_header.dart';
import '../widgets/app_sidebar.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'tasks_screen.dart';
import 'settings_screen.dart';
import 'projects_list_screen.dart';

/// Главная страница приложения
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _username;
  bool _isLoading = true;
  String _selectedScreen = 'home';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSuperuser = false;
  Set<String> _allowedPages = {'home'};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Восстановление сохраненного экрана с проверкой прав доступа
  Future<void> _restoreScreen() async {
    final savedScreen = await ApiService.getCurrentScreen();
    if (savedScreen != null && mounted) {
      // Проверяем права доступа к сохраненному экрану
      if (_isSuperuser || _allowedPages.contains(savedScreen)) {
        setState(() {
          _selectedScreen = savedScreen;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    // Загружаем имя пользователя
    final userData = await ApiService.getCurrentUser();
    
    String? username;
    if (userData != null && userData['username'] != null) {
      username = userData['username'] as String;
    } else {
      username = await ApiService.getUsername();
    }
    
    // Загружаем статус суперпользователя
    bool isSuperuser = await ApiService.getIsSuperuser();
    if (userData != null && userData['is_superuser'] != null) {
      isSuperuser = userData['is_superuser'] as bool;
    }
    
    // Загружаем права доступа
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
        _username = username ?? 'Пользователь';
        _isSuperuser = isSuperuser;
        _isLoading = false;
      });
      // Восстанавливаем экран после загрузки данных
      await _restoreScreen();
    }
  }


  Future<void> _handleLogout(BuildContext context) async {
    await ApiService.logout();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _onMenuItemSelected(String item) {
    // Проверяем права доступа
    if (!_isSuperuser && !_allowedPages.contains(item)) {
      // Если нет доступа, переключаем на главную
      setState(() {
        _selectedScreen = 'home';
      });
      ApiService.saveCurrentScreen('home');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У вас нет доступа к этому разделу'),
          backgroundColor: AppColors.accentPink,
        ),
      );
      return;
    }
    
    setState(() {
      _selectedScreen = item;
    });
    ApiService.saveCurrentScreen(item);
    // Закрыть drawer на мобильных устройствах
    if (MediaQuery.of(context).size.width < 600) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  Widget _buildCurrentScreen() {
    switch (_selectedScreen) {
      case 'tasks':
        return const TasksScreen();
      case 'projects':
        return const ProjectsListScreen();
      case 'settings':
        return const SettingsScreen();
      case 'home':
      default:
        return _HomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile
          ? AppSidebar(
              selectedItem: _selectedScreen,
              onItemSelected: _onMenuItemSelected,
            )
          : null,
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
        child: Column(
          children: [
            GlassHeader(
              username: _username ?? 'Загрузка...',
              onLogout: _isLoading ? null : () => _handleLogout(context),
              onMenuTap: isMobile
                  ? () => _scaffoldKey.currentState?.openDrawer()
                  : null,
            ),
            Expanded(
              child: Row(
                children: [
                  if (!isMobile)
                    AppSidebar(
                      selectedItem: _selectedScreen,
                      onItemSelected: _onMenuItemSelected,
                    ),
                  Expanded(
                    child: _buildCurrentScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Контент главной страницы
class _HomeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: AppColors.accentGreen,
          ),
          const SizedBox(height: 24),
          const Text(
            'Добро пожаловать!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Вы успешно авторизованы',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

