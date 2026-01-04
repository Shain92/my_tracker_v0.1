import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Экран задач
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
