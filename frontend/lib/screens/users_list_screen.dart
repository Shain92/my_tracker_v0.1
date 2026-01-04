import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_form_dialog.dart';
import '../models/user_model.dart';

/// Экран списка пользователей
class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int? _totalPages;
  bool _hasNextPage = false;
  bool _hasPreviousPage = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// Загрузка списка пользователей
  Future<void> _loadUsers({int? page}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getUsers(
      page: page ?? _currentPage,
      pageSize: 20,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final data = result['data'];
          
          // Обработка пагинации
          if (data is Map && data.containsKey('results')) {
            _users = data['results'] as List;
            _currentPage = data['current_page'] ?? page ?? 1;
            _totalPages = data['total_pages'];
            _hasNextPage = data['next'] != null;
            _hasPreviousPage = data['previous'] != null;
          } else if (data is List) {
            // Если API вернул простой список без пагинации
            _users = data;
            _hasNextPage = false;
            _hasPreviousPage = false;
          }
        } else {
          _errorMessage = result['error'] ?? 'Ошибка загрузки пользователей';
        }
      });
    }
  }

  /// Обновление списка
  Future<void> _refreshUsers() async {
    await _loadUsers(page: 1);
  }

  /// Обновление после удаления пользователя
  Future<void> _refreshAfterDelete(int deletedUserId) async {
    // Сразу удаляем пользователя из локального списка
    setState(() {
      _users.removeWhere((u) => u['id'] == deletedUserId);
    });
    
    // Затем перезагружаем текущую страницу для синхронизации
    await _loadUsers(page: _currentPage);
    
    // Если страница стала пустой и есть предыдущая, переходим на неё
    if (mounted && _users.isEmpty && _hasPreviousPage && _currentPage > 1) {
      await _loadUsers(page: _currentPage - 1);
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

  /// Заголовок с адаптивным текстом и кнопкой добавления
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Фиксированные размеры элементов
          const backButtonWidth = 48.0;
          const iconWidth = 40.0;
          const spacing = 8.0 + 12.0;
          
          // Проверяем ширину текста
          final textPainter = TextPainter(
            text: const TextSpan(
              text: 'Список пользователей',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          final textWidth = textPainter.width;
          
          // Проверяем ширину кнопки с текстом
          final buttonTextPainter = TextPainter(
            text: const TextSpan(
              text: 'Добавить пользователя',
              style: TextStyle(fontSize: 14),
            ),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          );
          buttonTextPainter.layout();
          const buttonPadding = 16.0 * 2; // горизонтальные отступы
          const buttonIconWidth = 20.0 + 8.0; // иконка + отступ
          final buttonWithTextWidth = buttonIconWidth + buttonTextPainter.width + buttonPadding;
          
          // Доступная ширина для текста и кнопки
          final fixedWidth = backButtonWidth + spacing + iconWidth + spacing;
          final availableWidth = constraints.maxWidth - fixedWidth;
          
          // Проверяем, поместится ли текст заголовка
          final textFits = textWidth <= availableWidth;
          
          // Проверяем, поместится ли кнопка с текстом (с учетом текста заголовка или без него)
          final spaceForButton = availableWidth - (textFits ? textWidth + 12 : 0);
          final buttonWithTextFits = buttonWithTextWidth <= spaceForButton;
          
          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people,
                  color: AppColors.accentOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              if (textFits)
                const Text(
                  'Список пользователей',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              const Spacer(),
              if (buttonWithTextFits)
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Добавить пользователя'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                )
              else
                IconButton(
                  onPressed: () => _showAddUserDialog(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Добавить пользователя',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Показать диалог добавления пользователя
  Future<void> _showAddUserDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => const UserFormDialog(),
    );
    if (result != null && result['success'] == true) {
      _refreshUsers();
    }
  }

  Widget _buildContent() {
    if (_isLoading && _users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _users.isEmpty) {
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
              onPressed: _refreshUsers,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshUsers,
      child: Column(
        children: [
          Expanded(
            child: _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Пользователи не найдены',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      return _UserCard(
                        user: _users[index],
                        onRefresh: ([userId]) => userId != null 
                            ? _refreshAfterDelete(userId)
                            : _loadUsers(page: _currentPage),
                      );
                    },
                  ),
          ),
          if (_hasNextPage || _hasPreviousPage) _buildPagination(),
        ],
      ),
    );
  }

  /// Пагинация
  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.6),
        border: Border(
          top: BorderSide(
            color: AppColors.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_hasPreviousPage)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _loadUsers(page: _currentPage - 1),
              tooltip: 'Предыдущая страница',
            ),
          Text(
            'Страница $_currentPage${_totalPages != null ? ' из $_totalPages' : ''}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (_hasNextPage)
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _loadUsers(page: _currentPage + 1),
              tooltip: 'Следующая страница',
            ),
        ],
      ),
    );
  }
}

/// Карточка пользователя
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<void> Function([int?])? onRefresh;

  const _UserCard({
    required this.user,
    this.onRefresh,
  });

  /// Получить цвет аватара по первой букве
  Color _getAvatarColor(String text) {
    final colors = [
      AppColors.accentBlue,
      AppColors.accentOrange,
      AppColors.accentGreen,
      AppColors.accentPink,
      AppColors.accentPurple,
    ];
    final index = text.isEmpty ? 0 : text.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  /// Получить первую букву для аватара
  String _getAvatarLetter(String text) {
    if (text.isEmpty) return '?';
    return text[0].toUpperCase();
  }

  /// Преобразовать HEX цвет в Color
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
        // Короткий формат #RGB -> #RRGGBB
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
    final username = user['username'] ?? 'Неизвестно';
    final firstName = user['first_name'] ?? '';
    final lastName = user['last_name'] ?? '';
    final department = user['department'] as Map<String, dynamic>?;
    final departmentName = department?['name'] ?? '';
    final departmentColor = department?['color'] as String?;
    final fullName = '$firstName $lastName'.trim();
    final avatarColor = _getAvatarColor(username);
    final avatarLetter = _getAvatarLetter(username);
    final deptColor = departmentColor != null
        ? _parseColor(departmentColor)
        : AppColors.textSecondary;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Аватар
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  avatarLetter,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: avatarColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Информация о пользователе
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (fullName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (departmentName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 14,
                          color: deptColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            departmentName,
                            style: TextStyle(
                              fontSize: 14,
                              color: deptColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
    );
  }

  /// Показать диалог редактирования
  Future<void> _showEditDialog(BuildContext context) async {
    final userModel = UserModel.fromJson(user);
    final result = await showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        user: userModel,
        onToggleStatus: () => _toggleUserStatus(context),
        onDelete: () => _showDeleteDialog(context),
        onRefresh: onRefresh,
      ),
    );
    if (result != null && result['success'] == true && onRefresh != null) {
      onRefresh!();
    }
  }

  /// Переключить статус пользователя
  Future<void> _toggleUserStatus(BuildContext context) async {
    final userId = user['id'] as int;
    final currentStatus = user['is_active'] != false;
    final newStatus = !currentStatus;

    final result = await ApiService.updateUser(userId, {
      'is_active': newStatus,
    });

    if (context.mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Пользователь разблокирован'
                  : 'Пользователь заблокирован',
            ),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        if (onRefresh != null) {
          await onRefresh!();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка изменения статуса'),
            backgroundColor: AppColors.accentPink,
          ),
        );
      }
    }
  }

  /// Показать диалог удаления
  Future<void> _showDeleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'Удаление пользователя',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Вы уверены, что хотите удалить пользователя "${user['username']}"? Это действие нельзя отменить.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPink,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = user['id'] as int;
      final result = await ApiService.deleteUser(userId);
      
      // Проверяем результат независимо от context.mounted
      if (result['success'] == true) {
        // Показываем сообщение только если контекст еще активен
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пользователь удален'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
        
        // Вызываем onRefresh независимо от context.mounted, так как он обновляет родительский виджет
        if (onRefresh != null) {
          await onRefresh!(userId);
        }
      } else {
        // Показываем ошибку только если контекст еще активен
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Ошибка удаления'),
              backgroundColor: AppColors.accentPink,
            ),
          );
        }
      }
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
