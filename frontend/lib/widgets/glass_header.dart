import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Хедер с эффектом glassmorphism и темной темой
class GlassHeader extends StatefulWidget {
  final String username;
  final VoidCallback? onLogout;
  final VoidCallback? onMenuTap;

  const GlassHeader({
    super.key,
    required this.username,
    this.onLogout,
    this.onMenuTap,
  });

  @override
  State<GlassHeader> createState() => _GlassHeaderState();
}

class _GlassHeaderState extends State<GlassHeader> {
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Обновление времени каждую минуту
    final secondsUntilNextMinute = 60 - DateTime.now().second;
    Future.delayed(Duration(seconds: secondsUntilNextMinute), () {
      if (mounted) {
        _updateTime();
        _startTimer();
      }
    });
  }

  void _startTimer() {
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) {
        _updateTime();
        _startTimer();
      }
    });
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('h:mm a').format(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.transparent,
      child: Container(
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
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
                  bottom: BorderSide(
                    color: AppColors.accentBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (widget.onMenuTap != null)
                            IconButton(
                              icon: const Icon(
                                Icons.menu,
                                color: AppColors.textPrimary,
                              ),
                              onPressed: widget.onMenuTap,
                              tooltip: 'Меню',
                            ),
                          const Text(
                            'АСС',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _currentTime,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            widget.username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (widget.onLogout != null) ...[
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                              onPressed: widget.onLogout,
                              tooltip: 'Настройки',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
