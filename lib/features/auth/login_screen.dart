import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/app_provider.dart';
import '../../shared/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  void _handleLogin(String username) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await Provider.of<AppProvider>(context, listen: false)
        .loginStaff(username.trim());

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!success) {
      setState(() {
        _error = "Identifiant incorrect ou utilisateur introuvable.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.resto;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Provider.of<AppProvider>(context, listen: false)
                .changeMode(AppMode.selection);
          },
        ),
        title: const Text('Connexion Personnel'),
        actions: [
          IconButton(
            tooltip: colors.isDark ? 'Thème clair' : 'Thème sombre',
            icon: Icon(
              colors.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () =>
                Provider.of<AppProvider>(context, listen: false).toggleTheme(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_person,
                  size: 80,
                  color: RestoTheme.secondary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Accès Sécurisé',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez votre identifiant pour accéder à votre espace de travail.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Identifiant',
                    prefixIcon: Icon(Icons.person, color: colors.textSecondary),
                    hintText: 'Ex: admin, caisse, cuisine...',
                  ),
                  onSubmitted: (val) => _handleLogin(val),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: RestoTheme.danger, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _handleLogin(_usernameController.text),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Se connecter'),
                ),
                const SizedBox(height: 40),
                Text(
                  'Identifiants de test :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildQuickLoginChip('admin', 'Administrateur'),
                    _buildQuickLoginChip('caisse', 'Caissier'),
                    _buildQuickLoginChip('cuisine', 'Cuisine'),
                    _buildQuickLoginChip('serveur', 'Serveur'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLoginChip(String username, String label) {
    final colors = context.resto;
    return ActionChip(
      backgroundColor: colors.surface,
      side: const BorderSide(color: RestoTheme.primary, width: 0.5),
      label: Text(
        label,
        style: const TextStyle(color: RestoTheme.primary, fontSize: 12),
      ),
      onPressed: () {
        _usernameController.text = username;
        _handleLogin(username);
      },
    );
  }
}
