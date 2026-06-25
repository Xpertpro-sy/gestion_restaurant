import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/app_provider.dart';
import '../../shared/theme.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.resto;

    return Scaffold(
      backgroundColor: colors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.isDark
                ? const [
                    RestoTheme.darkBg,
                    Color(0xFF1A1525),
                    Color(0xFF241426),
                  ]
                : const [
                    RestoTheme.lightBg,
                    Color(0xFFFFFFFF),
                    Color(0xFFF0F2F8),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: RestoTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: RestoTheme.primary, width: 2),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: RestoTheme.primary,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'RESTO OFFLINE',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Portail Personnel — Gestion locale Wi-Fi',
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Les clients commandent via le QR code de leur table\n(navigateur web, sans application).',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 60),
                      _buildStaffCard(context),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 16,
                child: _ThemeToggleButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffCard(BuildContext context) {
    final colors = context.resto;

    return GestureDetector(
      onTap: () {
        Provider.of<AppProvider>(context, listen: false)
            .changeMode(AppMode.staffAuth);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: RestoTheme.secondary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.isDark
                  ? RestoTheme.secondary.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const _IconBox(),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portail Personnel',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Commandes, cuisine, encaissements et QR tables',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.resto;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: colors.isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () =>
            Provider.of<AppProvider>(context, listen: false).toggleTheme(),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                colors.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 20,
                color: colors.isDark ? RestoTheme.primary : RestoTheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                colors.isDark ? 'Clair' : 'Sombre',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RestoTheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.admin_panel_settings,
        color: RestoTheme.secondary,
        size: 32,
      ),
    );
  }
}
