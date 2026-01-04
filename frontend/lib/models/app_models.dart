import 'user_model.dart';

/// Базовые модели данных для приложения

/// Модель для данных графика
class ChartDataPoint {
  final double x;
  final double y;
  final DateTime? timestamp;

  ChartDataPoint({
    required this.x,
    required this.y,
    this.timestamp,
  });
}

/// Модель для метрики
class Metric {
  final String id;
  final String title;
  final double value;
  final String unit;
  final DateTime timestamp;

  Metric({
    required this.id,
    required this.title,
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  factory Metric.fromJson(Map<String, dynamic> json) {
    return Metric(
      id: json['id'] as String,
      title: json['title'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Модель для категории данных
class Category {
  final String id;
  final String name;
  final double value;
  final String color;

  Category({
    required this.id,
    required this.name,
    required this.value,
    required this.color,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      value: (json['value'] as num).toDouble(),
      color: json['color'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'color': color,
    };
  }
}

/// Модель для временного диапазона
enum TimeRange {
  day,
  week,
  month,
  year,
  all,
}

/// Модель для отчета
class Report {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String status;

  Report({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.status,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }
}

/// Модель для транзакции
class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime timestamp;
  final String category;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.timestamp,
    required this.category,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
    };
  }
}

/// Модель права доступа к странице
class PagePermission {
  final String pageName;
  final String pageLabel;
  final List<DepartmentPermission> departments;

  PagePermission({
    required this.pageName,
    required this.pageLabel,
    required this.departments,
  });

  factory PagePermission.fromJson(Map<String, dynamic> json) {
    return PagePermission(
      pageName: json['page_name'] as String,
      pageLabel: json['page_label'] as String,
      departments: (json['departments'] as List)
          .map((d) => DepartmentPermission.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Право доступа отдела к странице
class DepartmentPermission {
  final int departmentId;
  final String departmentName;
  final bool hasAccess;

  DepartmentPermission({
    required this.departmentId,
    required this.departmentName,
    required this.hasAccess,
  });

  factory DepartmentPermission.fromJson(Map<String, dynamic> json) {
    return DepartmentPermission(
      departmentId: json['department_id'] as int,
      departmentName: json['department_name'] as String,
      hasAccess: json['has_access'] as bool,
    );
  }
}

/// Модель строительного участка
class ConstructionSiteModel {
  final int id;
  final String name;
  final String? description;
  final UserModel? manager;
  final int? managerId;
  final double? completionPercentage;
  final String? createdAt;
  final String? updatedAt;

  ConstructionSiteModel({
    required this.id,
    required this.name,
    this.description,
    this.manager,
    this.managerId,
    this.completionPercentage,
    this.createdAt,
    this.updatedAt,
  });

  factory ConstructionSiteModel.fromJson(Map<String, dynamic> json) {
    UserModel? manager;
    if (json['manager'] != null) {
      manager = UserModel.fromJson(json['manager'] as Map<String, dynamic>);
    }

    return ConstructionSiteModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      manager: manager,
      managerId: json['manager_id'] as int?,
      completionPercentage: json['completion_percentage'] != null
          ? (json['completion_percentage'] as num).toDouble()
          : null,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'manager': manager?.toJson(),
      'manager_id': managerId,
      'completion_percentage': completionPercentage,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}


