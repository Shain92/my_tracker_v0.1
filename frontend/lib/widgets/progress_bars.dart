import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

/// Статистика выполнения по отделу
class DepartmentCompletionStats {
  final int departmentId;
  final String departmentName;
  final String departmentColor;
  final int totalSheets;
  final int completedSheets;
  final int incompleteSheets;
  final double completionPercentage;
  final double incompletePercentage;

  DepartmentCompletionStats({
    required this.departmentId,
    required this.departmentName,
    required this.departmentColor,
    required this.totalSheets,
    required this.completedSheets,
    required this.incompleteSheets,
    required this.completionPercentage,
    required this.incompletePercentage,
  });
}

/// Общая шкала выполнения
class OverallProgressBar extends StatelessWidget {
  final double? completionPercentage;
  final bool compact;
  final StatusModel? status;

  const OverallProgressBar({
    super.key,
    required this.completionPercentage,
    this.compact = false,
    this.status,
  });

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
    final percentage = completionPercentage ?? 0.0;
    final iconSize = compact ? 16.0 : 20.0;
    final fontSize = compact ? 12.0 : 14.0;
    final valueFontSize = compact ? 14.0 : 16.0;
    final barHeight = compact ? 6.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up,
              color: AppColors.accentGreen,
              size: iconSize,
            ),
            SizedBox(width: compact ? 6 : 8),
            Text(
              'Выполнение: ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: fontSize,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: AppColors.accentGreen,
                fontSize: valueFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (status != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _parseColor(status!.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status!.name,
                style: TextStyle(
                  color: _parseColor(status!.color),
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: compact ? 6 : 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: AppColors.backgroundSecondary,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
          minHeight: barHeight,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

/// Шкала выполнения по отделам
class DepartmentProgressBar extends StatelessWidget {
  final List<DepartmentCompletionStats> departmentStats;
  final bool isLoading;
  final bool compact;
  final bool showLegend;
  final int? currentUserDepartmentId;

  const DepartmentProgressBar({
    super.key,
    required this.departmentStats,
    this.isLoading = false,
    this.compact = false,
    this.showLegend = true,
    this.currentUserDepartmentId,
  });

  /// Преобразование HEX цвета в Color
  static Color _parseColor(String hexColor) {
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

  /// Получение скругления углов для сегмента
  static BorderRadius _getBorderRadiusForSegment(int index, int total) {
    if (total == 1) {
      return BorderRadius.circular(4);
    }
    
    if (index == 0) {
      return const BorderRadius.only(
        topLeft: Radius.circular(4),
        bottomLeft: Radius.circular(4),
      );
    } else if (index == total - 1) {
      return const BorderRadius.only(
        topRight: Radius.circular(4),
        bottomRight: Radius.circular(4),
      );
    } else {
      return BorderRadius.zero;
    }
  }

  /// Создание эффекта неона для отдела пользователя
  BoxDecoration _buildNeonDecoration(Color color, BorderRadius borderRadius) {
    return BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      boxShadow: [
        // Внутренняя тень с небольшим размытием
        BoxShadow(
          color: color.withOpacity(0.8),
          blurRadius: 4,
          spreadRadius: 0,
        ),
        // Средняя тень для усиления свечения
        BoxShadow(
          color: color.withOpacity(0.6),
          blurRadius: 8,
          spreadRadius: 1,
        ),
        // Внешняя тень с большим размытием для эффекта свечения
        BoxShadow(
          color: color.withOpacity(0.4),
          blurRadius: 12,
          spreadRadius: 2,
        ),
        // Дополнительная тень для более сильного эффекта
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: 16,
          spreadRadius: 3,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 16.0 : 20.0;
    final fontSize = compact ? 12.0 : 14.0;
    final barHeight = compact ? 6.0 : 8.0;

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business,
                color: AppColors.accentBlue,
                size: iconSize,
              ),
              SizedBox(width: compact ? 6 : 8),
              Text(
                'По отделам: ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          SizedBox(
            height: barHeight,
            child: const LinearProgressIndicator(),
          ),
        ],
      );
    }

    if (departmentStats.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business,
                color: AppColors.accentBlue,
                size: iconSize,
              ),
              SizedBox(width: compact ? 6 : 8),
              Text(
                'По отделам: ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            'Нет данных по отделам',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: compact ? 10 : 12,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.business,
              color: AppColors.accentBlue,
              size: iconSize,
            ),
            SizedBox(width: compact ? 6 : 8),
            Text(
              compact ? 'По отделам: ' : 'Невыполненные листы по отделам: ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 6 : 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            
            final totalIncompleteSheets = departmentStats.fold<int>(
              0,
              (sum, stats) => sum + stats.incompleteSheets,
            );
            
            if (totalIncompleteSheets == 0) {
              return Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'Все листы выполнены',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: compact ? 9 : 11,
                    ),
                  ),
                ),
              );
            }
            
            final departmentsWithIncomplete = departmentStats
                .where((stats) => stats.incompleteSheets > 0)
                .toList();
            
            if (departmentsWithIncomplete.isEmpty) {
              return Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'Все листы выполнены',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: compact ? 9 : 11,
                    ),
                  ),
                ),
              );
            }
            
            final segmentWidths = <double>[];
            
            for (final stats in departmentsWithIncomplete) {
              final segmentWidth = (stats.incompleteSheets / totalIncompleteSheets) * totalWidth;
              segmentWidths.add(segmentWidth);
            }
            
            return Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: departmentsWithIncomplete.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stats = entry.value;
                  final color = _parseColor(stats.departmentColor);
                  final segmentWidth = segmentWidths[index];
                  final isUserDepartment = currentUserDepartmentId != null && 
                                           stats.departmentId == currentUserDepartmentId;
                  final borderRadius = _getBorderRadiusForSegment(
                    index,
                    departmentsWithIncomplete.length,
                  );
                  
                  return Container(
                    width: segmentWidth,
                    decoration: isUserDepartment
                        ? _buildNeonDecoration(color, borderRadius)
                        : BoxDecoration(
                            color: color,
                            borderRadius: borderRadius,
                          ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        if (showLegend && !compact) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: departmentStats.map((stats) {
              final color = _parseColor(stats.departmentColor);
              final totalIncomplete = departmentStats.fold<int>(
                0,
                (sum, s) => sum + s.incompleteSheets,
              );
              final isUserDepartment = currentUserDepartmentId != null && 
                                       stats.departmentId == currentUserDepartmentId;
              
              final percentageText = totalIncomplete > 0
                  ? ' (${stats.incompletePercentage.toStringAsFixed(1)}%)'
                  : '';
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: isUserDepartment
                        ? BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 3,
                              ),
                            ],
                          )
                        : BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${stats.departmentName}: ${stats.incompleteSheets}$percentageText',
                    style: TextStyle(
                      color: isUserDepartment ? color : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isUserDepartment ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

