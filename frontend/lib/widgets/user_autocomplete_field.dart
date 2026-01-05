import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

/// Виджет для выбора пользователей с автодополнением
class UserAutocompleteField extends StatefulWidget {
  final List<UserModel> selectedUsers;
  final Function(List<UserModel>) onUsersChanged;
  final String labelText;

  const UserAutocompleteField({
    super.key,
    required this.selectedUsers,
    required this.onUsersChanged,
    this.labelText = 'Ответственные лица',
  });

  @override
  State<UserAutocompleteField> createState() => _UserAutocompleteFieldState();
}

class _UserAutocompleteFieldState extends State<UserAutocompleteField> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Поиск пользователей
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    final result = await ApiService.searchUsers(query, pageSize: 10);
    
    if (mounted && result['success'] == true) {
      final data = result['data'];
      List<UserModel> users = [];
      
      if (data is Map && data['results'] != null) {
        final usersList = data['results'] as List;
        users = usersList
            .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (data is List) {
        users = data
            .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      // Фильтруем по введенному тексту (клиентская фильтрация для надежности)
      final queryLower = query.toLowerCase().trim();
      users = users.where((user) {
        final username = user.username.toLowerCase();
        final firstName = (user.firstName ?? '').toLowerCase();
        final lastName = (user.lastName ?? '').toLowerCase();
        final fullName = '$firstName $lastName'.trim().toLowerCase();
        
        return username.contains(queryLower) ||
            firstName.contains(queryLower) ||
            lastName.contains(queryLower) ||
            fullName.contains(queryLower);
      }).toList();
      
      // Фильтруем уже выбранных пользователей
      final selectedIds = widget.selectedUsers.map((u) => u.id).toSet();
      users = users.where((u) => !selectedIds.contains(u.id)).toList();
      
      setState(() {
        _suggestions = users;
        _isLoading = false;
      });
    } else {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  /// Добавление пользователя
  void _addUser(UserModel user) {
    final updated = List<UserModel>.from(widget.selectedUsers)..add(user);
    widget.onUsersChanged(updated);
    _searchController.clear();
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  /// Удаление пользователя
  void _removeUser(UserModel user) {
    final updated = widget.selectedUsers.where((u) => u.id != user.id).toList();
    widget.onUsersChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Поле поиска
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: widget.labelText,
            prefixIcon: const Icon(Icons.person_search),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: (value) {
            _searchUsers(value);
          },
          onTap: () {
            if (_searchController.text.isNotEmpty) {
              setState(() {
                _showSuggestions = true;
              });
            }
          },
        ),
        // Список предложений
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final user = _suggestions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentBlue.withOpacity(0.2),
                    child: Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: AppColors.accentBlue),
                    ),
                  ),
                  title: Text(
                    user.username,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: user.firstName != null || user.lastName != null
                      ? Text(
                          '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                          style: const TextStyle(color: AppColors.textSecondary),
                        )
                      : null,
                  onTap: () => _addUser(user),
                );
              },
            ),
          ),
        // Выбранные пользователи
        if (widget.selectedUsers.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedUsers.map((user) {
              return Chip(
                label: Text(user.username),
                avatar: CircleAvatar(
                  backgroundColor: AppColors.accentBlue.withOpacity(0.2),
                  radius: 12,
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.accentBlue,
                      fontSize: 12,
                    ),
                  ),
                ),
                onDeleted: () => _removeUser(user),
                deleteIcon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                backgroundColor: AppColors.backgroundSecondary.withOpacity(0.5),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

