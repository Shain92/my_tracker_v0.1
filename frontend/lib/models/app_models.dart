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

/// Модель проекта
class ProjectModel {
  final int id;
  final String name;
  final String? description;
  final String code;
  final String cipher;
  final ConstructionSiteModel? constructionSite;
  final int? constructionSiteId;
  final double? completionPercentage;
  final String? createdAt;
  final String? updatedAt;

  ProjectModel({
    required this.id,
    required this.name,
    this.description,
    required this.code,
    required this.cipher,
    this.constructionSite,
    this.constructionSiteId,
    this.completionPercentage,
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    ConstructionSiteModel? constructionSite;
    if (json['construction_site'] != null) {
      constructionSite = ConstructionSiteModel.fromJson(
        json['construction_site'] as Map<String, dynamic>,
      );
    }

    return ProjectModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      code: json['code'] as String,
      cipher: json['cipher'] as String,
      constructionSite: constructionSite,
      constructionSiteId: json['construction_site_id'] as int?,
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
      'code': code,
      'cipher': cipher,
      'construction_site': constructionSite?.toJson(),
      'construction_site_id': constructionSiteId,
      'completion_percentage': completionPercentage,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// Модель статуса
class StatusModel {
  final int id;
  final String name;
  final String color;
  final String statusType;
  final String? createdAt;

  StatusModel({
    required this.id,
    required this.name,
    required this.color,
    required this.statusType,
    this.createdAt,
  });

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      id: json['id'] as int,
      name: json['name'] as String,
      color: json['color'] as String,
      statusType: json['status_type'] as String,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'status_type': statusType,
      'created_at': createdAt,
    };
  }
}

/// Модель этапа проекта
class ProjectStageModel {
  final int id;
  final int projectId;
  final ProjectModel? project;
  final StatusModel? status;
  final int? statusId;
  final DateTime datetime;
  final UserModel? author;
  final int? authorId;
  final List<UserModel>? responsibleUsers;
  final List<int>? responsibleUserIds;
  final String? description;
  final String? fileUrl;
  final String? createdAt;

  ProjectStageModel({
    required this.id,
    required this.projectId,
    this.project,
    this.status,
    this.statusId,
    required this.datetime,
    this.author,
    this.authorId,
    this.responsibleUsers,
    this.responsibleUserIds,
    this.description,
    this.fileUrl,
    this.createdAt,
  });

  factory ProjectStageModel.fromJson(Map<String, dynamic> json) {
    ProjectModel? project;
    if (json['project'] != null) {
      project = ProjectModel.fromJson(json['project'] as Map<String, dynamic>);
    }

    StatusModel? status;
    if (json['status'] != null) {
      status = StatusModel.fromJson(json['status'] as Map<String, dynamic>);
    }

    UserModel? author;
    if (json['author'] != null) {
      author = UserModel.fromJson(json['author'] as Map<String, dynamic>);
    }

    List<UserModel>? responsibleUsers;
    if (json['responsible_users'] != null) {
      responsibleUsers = (json['responsible_users'] as List)
          .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
          .toList();
    }

    List<int>? responsibleUserIds;
    if (json['responsible_user_ids'] != null) {
      responsibleUserIds = (json['responsible_user_ids'] as List)
          .map((id) => id as int)
          .toList();
    } else if (responsibleUsers != null) {
      responsibleUserIds = responsibleUsers.map((u) => u.id).toList();
    }

    return ProjectStageModel(
      id: json['id'] as int,
      projectId: json['project_id'] as int? ?? (project?.id ?? 0),
      project: project,
      status: status,
      statusId: json['status_id'] as int?,
      datetime: DateTime.parse(json['datetime'] as String),
      author: author,
      authorId: json['author_id'] as int?,
      responsibleUsers: responsibleUsers,
      responsibleUserIds: responsibleUserIds,
      description: json['description'] as String?,
      fileUrl: json['file_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'project': project?.toJson(),
      'status_id': statusId,
      'datetime': datetime.toIso8601String(),
      'author_id': authorId,
      'responsible_users': responsibleUsers?.map((u) => u.toJson()).toList(),
      'responsible_user_ids': responsibleUserIds,
      'description': description,
      'file_url': fileUrl,
      'created_at': createdAt,
    };
  }
}

/// Модель проектного листа
class ProjectSheetModel {
  final int id;
  final String? name;
  final String? description;
  final int projectId;
  final ProjectModel? project;
  final StatusModel? status;
  final int? statusId;
  final bool isCompleted;
  final String? completedAt;
  final String? fileUrl;
  final List<UserModel> executors;
  final List<int> executorIds;
  final DepartmentModel? responsibleDepartment;
  final int? responsibleDepartmentId;
  final UserModel? createdBy;
  final int? createdById;
  final String? createdAt;
  final String? updatedAt;

  ProjectSheetModel({
    required this.id,
    this.name,
    this.description,
    required this.projectId,
    this.project,
    this.status,
    this.statusId,
    this.isCompleted = false,
    this.completedAt,
    this.fileUrl,
    this.executors = const [],
    this.executorIds = const [],
    this.responsibleDepartment,
    this.responsibleDepartmentId,
    this.createdBy,
    this.createdById,
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectSheetModel.fromJson(Map<String, dynamic> json) {
    ProjectModel? project;
    if (json['project'] != null) {
      project = ProjectModel.fromJson(json['project'] as Map<String, dynamic>);
    }

    StatusModel? status;
    if (json['status'] != null) {
      status = StatusModel.fromJson(json['status'] as Map<String, dynamic>);
    }

    List<UserModel> executors = [];
    if (json['executors'] != null) {
      executors = (json['executors'] as List)
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    UserModel? createdBy;
    if (json['created_by'] != null) {
      createdBy = UserModel.fromJson(json['created_by'] as Map<String, dynamic>);
    }

    DepartmentModel? responsibleDepartment;
    if (json['responsible_department'] != null) {
      responsibleDepartment = DepartmentModel.fromJson(json['responsible_department'] as Map<String, dynamic>);
    }

    return ProjectSheetModel(
      id: json['id'] as int,
      name: json['name'] as String?,
      description: json['description'] as String?,
      projectId: json['project_id'] as int? ?? (project?.id ?? 0),
      project: project,
      status: status,
      statusId: json['status_id'] as int?,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] as String?,
      fileUrl: json['file_url'] as String?,
      executors: executors,
      executorIds: (json['executor_ids'] as List?)?.map((e) => e as int).toList() ?? [],
      responsibleDepartment: responsibleDepartment,
      responsibleDepartmentId: json['responsible_department_id'] as int?,
      createdBy: createdBy,
      createdById: json['created_by_id'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'project_id': projectId,
      'status_id': statusId,
      'is_completed': isCompleted,
      'completed_at': completedAt,
      'file_url': fileUrl,
      'executor_ids': executorIds,
      'responsible_department_id': responsibleDepartmentId,
      'created_by_id': createdById,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}


