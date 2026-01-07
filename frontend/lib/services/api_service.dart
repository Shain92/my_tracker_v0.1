import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

/// Сервис для работы с API
class ApiService {
  // Для Web используем localhost, для мобильных устройств может потребоваться изменение
  static const String baseUrl = 'http://localhost:8000/api';
  
  /// Сохранение токена
  static Future<void> saveToken(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }
  
  /// Получение токена
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
  
  /// Получение refresh токена
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }
  
  /// Обновление токена через refresh token
  static Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access'], refreshToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Сохранение имени пользователя
  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }
  
  /// Получение имени пользователя
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }
  
  /// Сохранение статуса суперпользователя
  static Future<void> saveIsSuperuser(bool isSuperuser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_superuser', isSuperuser);
  }
  
  /// Получение статуса суперпользователя
  static Future<bool> getIsSuperuser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_superuser') ?? false;
  }
  
  /// Регистрация пользователя
  static Future<Map<String, dynamic>> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await saveToken(data['access'], data['refresh']);
        if (data['user'] != null) {
          if (data['user']['username'] != null) {
            await saveUsername(data['user']['username']);
          }
          if (data['user']['is_superuser'] != null) {
            await saveIsSuperuser(data['user']['is_superuser']);
          }
        }
        return {'success': true, 'user': data['user']};
      } else {
      final error = jsonDecode(response.body);
      return {'success': false, 'error': error['error'] ?? 'Ошибка регистрации'};
    }
  }
  
  /// Вход пользователя
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access'], data['refresh']);
        if (data['user'] != null) {
          if (data['user']['username'] != null) {
            await saveUsername(data['user']['username']);
          } else {
            await saveUsername(username);
          }
          if (data['user']['is_superuser'] != null) {
            await saveIsSuperuser(data['user']['is_superuser']);
          }
        }
        return {'success': true, 'user': data['user']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка входа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }
  
  /// Получение информации о текущем пользователе
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return null;
      }
      
      var response = await http.get(
        Uri.parse('$baseUrl/auth/me/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      // Если токен истек, пытаемся обновить
      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              Uri.parse('$baseUrl/auth/me/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['username'] != null) {
          await saveUsername(data['username']);
        }
        if (data['is_superuser'] != null) {
          await saveIsSuperuser(data['is_superuser']);
        }
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Выход пользователя
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('username');
    await prefs.remove('is_superuser');
    await prefs.remove('current_screen');
  }

  /// Получение списка пользователей с пагинацией
  static Future<Map<String, dynamic>> getUsers({int? page, int? pageSize}) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final queryParams = <String, String>{};
      if (page != null) queryParams['page'] = page.toString();
      if (pageSize != null) queryParams['page_size'] = pageSize.toString();

      final uri = Uri.parse('$baseUrl/auth/users/').replace(queryParameters: queryParams);
      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Если токен истек, пытаемся обновить
      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? error['detail'] ?? 'Ошибка получения списка пользователей'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Поиск пользователей с автодополнением
  static Future<Map<String, dynamic>> searchUsers(String query, {int? pageSize}) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final queryParams = <String, String>{
        'search': query,
      };
      if (pageSize != null) queryParams['page_size'] = pageSize.toString();

      final uri = Uri.parse('$baseUrl/auth/users/').replace(queryParameters: queryParams);
      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? error['detail'] ?? 'Ошибка поиска пользователей'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение пользователя по ID
  static Future<Map<String, dynamic>> getUser(int id) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/users/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения пользователя'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание пользователя
  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/users/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(userData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка создания пользователя'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление пользователя
  static Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> userData) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/auth/users/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка обновления пользователя'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Удаление пользователя
  static Future<Map<String, dynamic>> deleteUser(int id) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/auth/users/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка удаления пользователя'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Смена пароля пользователя
  static Future<Map<String, dynamic>> changeUserPassword(int id, String newPassword) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/users/$id/change_password/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'password': newPassword}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка смены пароля'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение списка отделов
  static Future<Map<String, dynamic>> getDepartments() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/departments/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения списка отделов'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание отдела
  static Future<Map<String, dynamic>> createDepartment(String name, {String? description, String? color}) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final requestBody = {
        'name': name,
        'description': description ?? '',
        'color': color ?? '#000000',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/auth/departments/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка создания отдела'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление отдела
  static Future<Map<String, dynamic>> updateDepartment(int id, Map<String, dynamic> data) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/auth/departments/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка обновления отдела'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Удаление отдела
  static Future<Map<String, dynamic>> deleteDepartment(int id) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/auth/departments/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final error = response.body.isNotEmpty ? jsonDecode(response.body) : {'error': 'Ошибка удаления отдела'};
        return {'success': false, 'error': error['error'] ?? 'Ошибка удаления отдела'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение матрицы прав доступа
  static Future<Map<String, dynamic>> getPagePermissions() async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.get(
        Uri.parse('$baseUrl/auth/page-permissions/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              Uri.parse('$baseUrl/auth/page-permissions/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        try {
          final error = jsonDecode(response.body);
          return {'success': false, 'error': error['error'] ?? 'Ошибка получения прав доступа'};
        } catch (_) {
          return {'success': false, 'error': 'Ошибка получения прав доступа: ${response.body}'};
        }
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление прав доступа
  static Future<Map<String, dynamic>> updatePagePermissions(List<Map<String, dynamic>> permissions) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.post(
        Uri.parse('$baseUrl/auth/page-permissions/update/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'permissions': permissions}),
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.post(
              Uri.parse('$baseUrl/auth/page-permissions/update/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'permissions': permissions}),
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка обновления прав доступа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение доступных страниц для текущего пользователя
  static Future<Map<String, dynamic>> getUserPagePermissions() async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.get(
        Uri.parse('$baseUrl/auth/user-permissions/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              Uri.parse('$baseUrl/auth/user-permissions/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения прав доступа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Сохранение текущего экрана
  static Future<void> saveCurrentScreen(String screen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_screen', screen);
  }

  /// Получение сохраненного экрана
  static Future<String?> getCurrentScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_screen');
  }

  /// Получение списка проектов
  static Future<Map<String, dynamic>> getProjects({int? constructionSiteId}) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var uri = Uri.parse('$baseUrl/projects/projects/');
      if (constructionSiteId != null) {
        uri = uri.replace(queryParameters: {'construction_site_id': constructionSiteId.toString()});
      }

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Обработка ответа с пагинацией
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          final results = data['results'] as List? ?? [];
          return {'success': true, 'data': results};
        } else if (data is List) {
          return {'success': true, 'data': data};
        } else {
          return {'success': true, 'data': [data]};
        }
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения списка проектов'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение проекта по ID
  static Future<Map<String, dynamic>> getProject(int id) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.get(
        Uri.parse('$baseUrl/projects/projects/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              Uri.parse('$baseUrl/projects/projects/$id/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения проекта'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание проекта
  static Future<Map<String, dynamic>> createProject(Map<String, dynamic> data) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.post(
        Uri.parse('$baseUrl/projects/projects/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.post(
              Uri.parse('$baseUrl/projects/projects/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data),
            );
          }
        }
      }

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка создания проекта'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление проекта
  static Future<Map<String, dynamic>> updateProject(int id, Map<String, dynamic> data) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.patch(
        Uri.parse('$baseUrl/projects/projects/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.patch(
              Uri.parse('$baseUrl/projects/projects/$id/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data),
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка обновления проекта'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Удаление проекта
  static Future<Map<String, dynamic>> deleteProject(int id) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.delete(
        Uri.parse('$baseUrl/projects/projects/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.delete(
              Uri.parse('$baseUrl/projects/projects/$id/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final error = response.body.isNotEmpty ? jsonDecode(response.body) : {'error': 'Ошибка удаления проекта'};
        return {'success': false, 'error': error['error'] ?? 'Ошибка удаления проекта'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение списка строительных участков
  static Future<Map<String, dynamic>> getConstructionSites() async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.get(
        Uri.parse('$baseUrl/projects/construction-sites/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              Uri.parse('$baseUrl/projects/construction-sites/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения списка участков'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение строительного участка по ID
  static Future<Map<String, dynamic>> getConstructionSite(int id) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.get(
        Uri.parse('$baseUrl/projects/construction-sites/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              Uri.parse('$baseUrl/projects/construction-sites/$id/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения участка'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание строительного участка
  static Future<Map<String, dynamic>> createConstructionSite(
    String name, {
    String? description,
    int? managerId,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final requestBody = {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
        if (managerId != null) 'manager_id': managerId,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/projects/construction-sites/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? error['detail'] ?? 'Ошибка создания участка'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление строительного участка
  static Future<Map<String, dynamic>> updateConstructionSite(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/projects/construction-sites/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? error['detail'] ?? 'Ошибка обновления участка'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Удаление строительного участка
  static Future<Map<String, dynamic>> deleteConstructionSite(int id) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/projects/construction-sites/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final error = response.body.isNotEmpty ? jsonDecode(response.body) : {'error': 'Ошибка удаления участка'};
        return {'success': false, 'error': error['error'] ?? error['detail'] ?? 'Ошибка удаления участка'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение списка статусов
  static Future<Map<String, dynamic>> getStatuses({String? statusType}) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var uri = Uri.parse('$baseUrl/projects/statuses/');
      if (statusType != null) {
        uri = uri.replace(queryParameters: {'status_type': statusType});
      }

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения статусов'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание статуса
  static Future<Map<String, dynamic>> createStatus(
    String name,
    String statusType, {
    String? color,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final requestBody = {
        'name': name,
        'status_type': statusType,
        'color': color ?? '#000000',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/projects/statuses/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? error['detail'] ?? 'Ошибка создания статуса'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление статуса
  static Future<Map<String, dynamic>> updateStatus(int id, Map<String, dynamic> data) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/projects/statuses/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? error['detail'] ?? 'Ошибка обновления статуса'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Удаление статуса
  static Future<Map<String, dynamic>> deleteStatus(int id) async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/projects/statuses/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final error = response.body.isNotEmpty ? jsonDecode(response.body) : {'error': 'Ошибка удаления статуса'};
        return {'success': false, 'error': error['error'] ?? error['detail'] ?? 'Ошибка удаления статуса'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение этапов проекта с пагинацией
  static Future<Map<String, dynamic>> getProjectStages(
    int projectId, {
    int page = 1,
    int pageSize = 5,
  }) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final queryParams = {
        'project_id': projectId.toString(),
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      final uri = Uri.parse('$baseUrl/projects/project-stages/').replace(
        queryParameters: queryParams,
      );

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Обработка ответа с пагинацией
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          final count = data['count'] as int? ?? 0;
          final results = data['results'] as List? ?? [];
          final next = data['next'] as String?;
          final previous = data['previous'] as String?;
          final totalPages = count > 0 ? (count / pageSize).ceil() : 1;
          
          return {
            'success': true,
            'data': results,
            'pagination': {
              'count': count,
              'currentPage': page,
              'totalPages': totalPages,
              'hasNext': next != null,
              'hasPrevious': previous != null,
            },
          };
        } else if (data is List) {
          // Обратная совместимость: если ответ - список без пагинации
          return {
            'success': true,
            'data': data,
            'pagination': {
              'count': data.length,
              'currentPage': 1,
              'totalPages': 1,
              'hasNext': false,
              'hasPrevious': false,
            },
          };
        } else {
          // Обратная совместимость: если ответ - объект
          return {
            'success': true,
            'data': [data],
            'pagination': {
              'count': 1,
              'currentPage': 1,
              'totalPages': 1,
              'hasNext': false,
              'hasPrevious': false,
            },
          };
        }
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения этапов'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание этапа проекта
  static Future<Map<String, dynamic>> createProjectStage(Map<String, dynamic> data) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.post(
        Uri.parse('$baseUrl/projects/project-stages/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.post(
              Uri.parse('$baseUrl/projects/project-stages/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data),
            );
          }
        }
      }

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        try {
          final error = jsonDecode(response.body);
          return {'success': false, 'error': error['error'] ?? 'Ошибка создания этапа'};
        } catch (e) {
          return {'success': false, 'error': 'Ошибка: ${response.statusCode}. Ответ не является JSON'};
        }
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление этапа проекта
  static Future<Map<String, dynamic>> updateProjectStage(int id, Map<String, dynamic> data) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.patch(
        Uri.parse('$baseUrl/projects/project-stages/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.patch(
              Uri.parse('$baseUrl/projects/project-stages/$id/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data),
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        try {
          final error = jsonDecode(response.body);
          return {'success': false, 'error': error['error'] ?? 'Ошибка обновления этапа'};
        } catch (e) {
          return {'success': false, 'error': 'Ошибка: ${response.statusCode}. Ответ не является JSON'};
        }
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Удаление этапа проекта
  static Future<Map<String, dynamic>> deleteProjectStage(int id) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.delete(
        Uri.parse('$baseUrl/projects/project-stages/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.delete(
              Uri.parse('$baseUrl/projects/project-stages/$id/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final error = response.body.isNotEmpty ? jsonDecode(response.body) : {'error': 'Ошибка удаления этапа'};
        return {'success': false, 'error': error['error'] ?? 'Ошибка удаления этапа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание этапа проекта с файлом
  static Future<Map<String, dynamic>> createProjectStageWithFile(
    Map<String, dynamic> data,
    PlatformFile? file,
  ) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final uri = Uri.parse('$baseUrl/projects/project-stages/');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Добавляем текстовые поля
      data.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty && key != 'file') {
          if (value is List) {
            // Для списков в multipart/form-data используем формат с индексами
            // Django REST Framework ожидает: field_name[0]=value1&field_name[1]=value2
            for (int i = 0; i < value.length; i++) {
              request.fields['$key[$i]'] = value[i].toString();
            }
          } else {
            request.fields[key] = value.toString();
          }
        }
      });

      // Добавляем файл, если есть
      if (file != null) {
        if (file.bytes != null) {
          // Для web
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (file.path != null) {
          // Для мобильных устройств
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path!,
            ),
          );
        }
      }
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            request = http.MultipartRequest('POST', uri);
            request.headers['Authorization'] = 'Bearer $token';
            data.forEach((key, value) {
              if (value != null && key != 'file') {
                if (value is List) {
                  // Для списков в multipart/form-data используем формат с квадратными скобками
                  for (var item in value) {
                    request.fields['$key[]'] = item.toString();
                  }
                } else {
                  request.fields[key] = value.toString();
                }
              }
            });
            if (file != null) {
              if (file.bytes != null) {
                request.files.add(
                  http.MultipartFile.fromBytes(
                    'file',
                    file.bytes!,
                    filename: file.name,
                  ),
                );
              } else if (file.path != null) {
                request.files.add(
                  await http.MultipartFile.fromPath(
                    'file',
                    file.path!,
                  ),
                );
              }
            }
            streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          }
        }
      }

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка создания этапа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление этапа проекта с файлом
  static Future<Map<String, dynamic>> updateProjectStageWithFile(
    int id,
    Map<String, dynamic> data,
    PlatformFile? file,
    bool deleteFile,
  ) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final uri = Uri.parse('$baseUrl/projects/project-stages/$id/');
      var request = http.MultipartRequest('PATCH', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Добавляем текстовые поля
      data.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty && key != 'file') {
          if (value is List) {
            // Для списков в multipart/form-data используем формат с индексами
            // Django REST Framework ожидает: field_name[0]=value1&field_name[1]=value2
            for (int i = 0; i < value.length; i++) {
              request.fields['$key[$i]'] = value[i].toString();
            }
          } else {
            request.fields[key] = value.toString();
          }
        }
      });

      // Если нужно удалить файл
      if (deleteFile) {
        request.fields['file'] = '';
      }

      // Добавляем новый файл, если есть
      if (file != null) {
        if (file.bytes != null) {
          // Для web
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (file.path != null) {
          // Для мобильных устройств
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path!,
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            request = http.MultipartRequest('PATCH', uri);
            request.headers['Authorization'] = 'Bearer $token';
            data.forEach((key, value) {
              if (value != null && key != 'file') {
                if (value is List) {
                  // Для списков в multipart/form-data используем формат с квадратными скобками
                  for (var item in value) {
                    request.fields['$key[]'] = item.toString();
                  }
                } else {
                  request.fields[key] = value.toString();
                }
              }
            });
            if (deleteFile) {
              request.fields['file'] = '';
            }
            if (file != null) {
              if (file.bytes != null) {
                request.files.add(
                  http.MultipartFile.fromBytes(
                    'file',
                    file.bytes!,
                    filename: file.name,
                  ),
                );
              } else if (file.path != null) {
                request.files.add(
                  await http.MultipartFile.fromPath(
                    'file',
                    file.path!,
                  ),
                );
              }
            }
            streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          }
        }
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка обновления этапа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение проектных листов с пагинацией
  static Future<Map<String, dynamic>> getProjectSheets(
    int projectId, {
    int page = 1,
    int pageSize = 5,
  }) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final queryParams = {
        'project_id': projectId.toString(),
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      final uri = Uri.parse('$baseUrl/projects/project-sheets/').replace(
        queryParameters: queryParams,
      );

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Обработка ответа с пагинацией
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          final count = data['count'] as int? ?? 0;
          final results = data['results'] as List? ?? [];
          final next = data['next'] as String?;
          final previous = data['previous'] as String?;
          final totalPages = count > 0 ? (count / pageSize).ceil() : 1;
          
          return {
            'success': true,
            'data': results,
            'pagination': {
              'count': count,
              'currentPage': page,
              'totalPages': totalPages,
              'hasNext': next != null,
              'hasPrevious': previous != null,
            },
          };
        } else if (data is List) {
          // Обратная совместимость: если ответ - список без пагинации
          return {
            'success': true,
            'data': data,
            'pagination': {
              'count': data.length,
              'currentPage': 1,
              'totalPages': 1,
              'hasNext': false,
              'hasPrevious': false,
            },
          };
        } else {
          // Обратная совместимость: если ответ - объект
          return {
            'success': true,
            'data': [data],
            'pagination': {
              'count': 1,
              'currentPage': 1,
              'totalPages': 1,
              'hasNext': false,
              'hasPrevious': false,
            },
          };
        }
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения листов'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание проектного листа
  static Future<Map<String, dynamic>> createProjectSheet(Map<String, dynamic> data) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.post(
        Uri.parse('$baseUrl/projects/project-sheets/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.post(
              Uri.parse('$baseUrl/projects/project-sheets/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data),
            );
          }
        }
      }

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка создания листа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление проектного листа
  static Future<Map<String, dynamic>> updateProjectSheet(int id, Map<String, dynamic> data) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.patch(
        Uri.parse('$baseUrl/projects/project-sheets/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.patch(
              Uri.parse('$baseUrl/projects/project-sheets/$id/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data),
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка обновления листа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Удаление проектного листа
  static Future<Map<String, dynamic>> deleteProjectSheet(int id) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      var response = await http.delete(
        Uri.parse('$baseUrl/projects/project-sheets/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.delete(
              Uri.parse('$baseUrl/projects/project-sheets/$id/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final error = response.body.isNotEmpty ? jsonDecode(response.body) : {'error': 'Ошибка удаления листа'};
        return {'success': false, 'error': error['error'] ?? 'Ошибка удаления листа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Переключение статуса выполнения проектного листа
  static Future<Map<String, dynamic>> toggleProjectSheetCompleted(int id, bool isCompleted) async {
    try {
      return await updateProjectSheet(id, {'is_completed': isCompleted});
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Скачивание файла проектного листа
  static Future<Map<String, dynamic>> downloadProjectSheetFile(int sheetId) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final uri = Uri.parse('$baseUrl/projects/project-sheets/$sheetId/download_file/');

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.bodyBytes,
          'headers': response.headers,
        };
      } else {
        final error = response.body.isNotEmpty 
            ? jsonDecode(response.body) 
            : {'error': 'Ошибка скачивания файла'};
        return {'success': false, 'error': error['error'] ?? 'Ошибка скачивания файла'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Скачивание файла этапа проекта
  static Future<Map<String, dynamic>> downloadProjectStageFile(int stageId) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final uri = Uri.parse('$baseUrl/projects/project-stages/$stageId/download_file/');

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.bodyBytes,
          'headers': response.headers,
        };
      } else {
        String errorMessage = 'Ошибка скачивания файла';
        if (response.body.isNotEmpty) {
          try {
            final contentType = response.headers['content-type'] ?? '';
            if (contentType.contains('application/json')) {
              final error = jsonDecode(response.body);
              errorMessage = error['error'] ?? errorMessage;
            } else {
              errorMessage = 'Сервер вернул неверный формат ответа (${response.statusCode})';
            }
          } catch (e) {
            errorMessage = 'Ошибка обработки ответа: ${response.statusCode}';
          }
        }
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Создание проектного листа с файлом
  static Future<Map<String, dynamic>> createProjectSheetWithFile(
    Map<String, dynamic> data,
    PlatformFile? file,
  ) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final uri = Uri.parse('$baseUrl/projects/project-sheets/');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Добавляем текстовые поля
      data.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty && key != 'file') {
          request.fields[key] = value.toString();
        }
      });

      // Добавляем файл, если есть
      if (file != null) {
        if (file.bytes != null) {
          // Для web
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (file.path != null) {
          // Для мобильных устройств
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path!,
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            request = http.MultipartRequest('POST', uri);
            request.headers['Authorization'] = 'Bearer $token';
            data.forEach((key, value) {
              if (value != null && key != 'file') {
                if (value is List) {
                  // Для списков в multipart/form-data используем формат с квадратными скобками
                  for (var item in value) {
                    request.fields['$key[]'] = item.toString();
                  }
                } else {
                  request.fields[key] = value.toString();
                }
              }
            });
            if (file != null) {
              if (file.bytes != null) {
                request.files.add(
                  http.MultipartFile.fromBytes(
                    'file',
                    file.bytes!,
                    filename: file.name,
                  ),
                );
              } else if (file.path != null) {
                request.files.add(
                  await http.MultipartFile.fromPath(
                    'file',
                    file.path!,
                  ),
                );
              }
            }
            streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          }
        }
      }

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка создания листа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Обновление проектного листа с файлом
  static Future<Map<String, dynamic>> updateProjectSheetWithFile(
    int id,
    Map<String, dynamic> data,
    PlatformFile? file,
    bool deleteFile,
  ) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final uri = Uri.parse('$baseUrl/projects/project-sheets/$id/');
      var request = http.MultipartRequest('PATCH', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Добавляем текстовые поля
      data.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty && key != 'file') {
          request.fields[key] = value.toString();
        }
      });

      // Если нужно удалить файл
      if (deleteFile) {
        request.fields['file'] = '';
      }

      // Добавляем новый файл, если есть
      if (file != null) {
        if (file.bytes != null) {
          // Для web
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (file.path != null) {
          // Для мобильных устройств
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path!,
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            request = http.MultipartRequest('PATCH', uri);
            request.headers['Authorization'] = 'Bearer $token';
            data.forEach((key, value) {
              if (value != null && key != 'file') {
                if (value is List) {
                  // Для списков в multipart/form-data используем формат с квадратными скобками
                  for (var item in value) {
                    request.fields['$key[]'] = item.toString();
                  }
                } else {
                  request.fields[key] = value.toString();
                }
              }
            });
            if (deleteFile) {
              request.fields['file'] = '';
            }
            if (file != null) {
              if (file.bytes != null) {
                request.files.add(
                  http.MultipartFile.fromBytes(
                    'file',
                    file.bytes!,
                    filename: file.name,
                  ),
                );
              } else if (file.path != null) {
                request.files.add(
                  await http.MultipartFile.fromPath(
                    'file',
                    file.path!,
                  ),
                );
              }
            }
            streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          }
        }
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка обновления листа'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение этапов текущего пользователя с фильтрами
  static Future<Map<String, dynamic>> getUserStages({
    int? constructionSiteId,
    int? projectId,
    bool? isCompleted,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (constructionSiteId != null) {
        queryParams['construction_site_id'] = constructionSiteId.toString();
      }
      if (projectId != null) {
        queryParams['project_id'] = projectId.toString();
      }

      final uri = Uri.parse('$baseUrl/projects/project-stages/').replace(
        queryParameters: queryParams,
      );

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        List<dynamic> results = [];
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          results = data['results'] as List? ?? [];
        } else if (data is List) {
          results = data;
        }

        // Фильтрация по is_completed на клиенте (если нужно)
        // Примечание: для этапов "выполнено" определяется через статус
        // Здесь мы просто возвращаем все этапы, фильтрация будет на frontend
        
        return {
          'success': true,
          'data': results,
        };
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения этапов пользователя'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }

  /// Получение листов отдела текущего пользователя с фильтрами
  static Future<Map<String, dynamic>> getDepartmentSheets({
    int? constructionSiteId,
    int? projectId,
    bool? isCompleted,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      var token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Не авторизован'};
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (constructionSiteId != null) {
        queryParams['construction_site_id'] = constructionSiteId.toString();
      }
      if (projectId != null) {
        queryParams['project_id'] = projectId.toString();
      }
      if (isCompleted != null) {
        queryParams['is_completed'] = isCompleted.toString();
      }

      final uri = Uri.parse('$baseUrl/projects/project-sheets/').replace(
        queryParameters: queryParams,
      );

      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          token = await getAccessToken();
          if (token != null) {
            response = await http.get(
              uri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        List<dynamic> results = [];
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          results = data['results'] as List? ?? [];
        } else if (data is List) {
          results = data;
        }
        
        return {
          'success': true,
          'data': results,
        };
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Ошибка получения листов отдела'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Ошибка подключения: ${e.toString()}'};
    }
  }
}

