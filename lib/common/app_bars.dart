import 'package:flutter/material.dart';
import 'package:aracfilo/common/theme/app_colors.dart';

class PrimaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrimaryAppBar({super.key, required this.title, this.actions, this.centerTitle = true});

  final String title;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: centerTitle,
  backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: actions,
    );
  }
}
