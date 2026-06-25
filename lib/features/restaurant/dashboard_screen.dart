import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/storage/product_image_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/network/client_web_content.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/database/database_helper.dart';
import '../../core/voice/voice_announcer.dart';
import '../../core/voice/voice_settings_store.dart';
import '../../shared/providers/app_provider.dart';
import '../../shared/theme.dart';
import '../../shared/formatters.dart';
import '../../shared/models/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Non connecté")));
    }

    // Role-based view filtering
    List<Widget> views = [];
    List<BottomNavigationBarItem> navItems = [];

    if (user.role == 'admin') {
      views = [
        ServerAdminView(),
        const TablesAdminView(),
        const KitchenView(),
        const CashierView(),
        const CatalogAdminView(),
        const ReportsView(),
      ];
      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Paramètres',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.table_restaurant),
          label: 'Tables',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: 'Cuisine'),
        BottomNavigationBarItem(
          icon: Icon(Icons.monetization_on),
          label: 'Caisse',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_menu),
          label: 'Menu',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Rapports'),
      ];
    } else if (user.role == 'caissier') {
      views = [const TablesAdminView(), const CashierView(), ServerAdminView()];
      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.table_restaurant),
          label: 'Tables',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.monetization_on),
          label: 'Caisse',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Paramètres',
        ),
      ];
    } else if (user.role == 'cuisine') {
      views = [const KitchenView(), ServerAdminView()];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: 'Cuisine'),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Paramètres',
        ),
      ];
    } else {
      // Serveur
      views = [const TablesAdminView(), const KitchenView(), ServerAdminView()];
      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.table_restaurant),
          label: 'Tables',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: 'Commandes'),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Paramètres',
        ),
      ];
    }

    // Handle index bounds when switching users/roles
    if (_selectedTabIndex >= views.length) {
      _selectedTabIndex = 0;
    }

    return Scaffold(
      backgroundColor: context.resto.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: context.resto.appBarGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              user.role.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: context.resto.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.resto.isDark ? 'Thème clair' : 'Thème sombre',
            icon: Icon(
              context.resto.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: provider.toggleTheme,
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _showNotificationsPanel(context, provider),
              ),
              if (provider.unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: RestoTheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${provider.unreadNotificationCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.alertMessage != null)
            Material(
              color: RestoTheme.secondary,
              elevation: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.alertMessage!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => provider.clearAlert(),
                    ),
                  ],
                ),
              ),
            ),

          // Waiter Calls ticker banner (For Admin/Serveur/Caissier)
          if (provider.waiterCalls.isNotEmpty && user.role != 'cuisine')
            Container(
              color: RestoTheme.info.withOpacity(0.9),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.notification_important, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Appels serveurs en attente : ${provider.waiterCalls.map((c) => c.tableName).join(', ')}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _showWaiterCallsDialog(context, provider);
                    },
                    child: const Text(
                      "Gérer",
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(child: views[_selectedTabIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.resto.surface,
          border: Border(top: BorderSide(color: context.resto.borderSubtle)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          selectedItemColor: RestoTheme.primary,
          unselectedItemColor: context.resto.textSecondary,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _selectedTabIndex = index),
          items: navItems,
        ),
      ),
    );
  }

  void _showNotificationsPanel(BuildContext context, AppProvider provider) {
    provider.markAllNotificationsRead();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.resto.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final items = provider.notifications;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          provider.clearNotifications();
                          Navigator.pop(context);
                        },
                        child: const Text('Effacer'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucune notification',
                        style: TextStyle(color: context.resto.textSecondary),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final n = items[index];
                        final icon = n.type == 'waiter_call'
                            ? Icons.notifications_active
                            : Icons.receipt_long;
                        final color = n.type == 'waiter_call'
                            ? RestoTheme.info
                            : RestoTheme.primary;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(
                            n.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(n.body),
                          trailing: Text(
                            '${n.createdAt.hour.toString().padLeft(2, '0')}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: context.resto.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWaiterCallsDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Appels Serveur'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.waiterCalls.length,
              itemBuilder: (context, index) {
                final call = provider.waiterCalls[index];
                return ListTile(
                  title: Text(call.tableName),
                  subtitle: Text(
                    "Appelé à ${call.createdAt.substring(11, 16)}",
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      provider.completeWaiterCall(call.id!);
                      Navigator.pop(context);
                    },
                    child: const Text("Répondu"),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }
}

// -------------------------------------------------------------
// VIEW 1: SERVER ADMIN VIEW (CONFIG)
// -------------------------------------------------------------
class ServerAdminView extends StatefulWidget {
  const ServerAdminView({super.key});

  @override
  State<ServerAdminView> createState() => _ServerAdminViewState();
}

class _ServerAdminViewState extends State<ServerAdminView> {
  final _orderVoiceCtrl = TextEditingController();
  final _waiterVoiceCtrl = TextEditingController();
  bool _voiceSettingsLoaded = false;
  bool _voiceSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final role = Provider.of<AppProvider>(context, listen: false)
          .currentUser
          ?.role;
      if (role == 'admin') _loadVoiceSettings();
    });
  }

  @override
  void dispose() {
    _orderVoiceCtrl.dispose();
    _waiterVoiceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVoiceSettings() async {
    await VoiceSettingsStore.instance.load();
    if (!mounted) return;
    setState(() {
      _orderVoiceCtrl.text = VoiceSettingsStore.instance.orderTemplate;
      _waiterVoiceCtrl.text = VoiceSettingsStore.instance.waiterTemplate;
      _voiceSettingsLoaded = true;
    });
  }

  Future<void> _saveVoiceSettings() async {
    setState(() => _voiceSaving = true);
    await VoiceSettingsStore.instance.save(
      orderTemplate: _orderVoiceCtrl.text,
      waiterTemplate: _waiterVoiceCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _orderVoiceCtrl.text = VoiceSettingsStore.instance.orderTemplate;
      _waiterVoiceCtrl.text = VoiceSettingsStore.instance.waiterTemplate;
      _voiceSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Textes vocaux enregistrés')),
    );
  }

  Future<void> _resetVoiceSettings() async {
    await VoiceSettingsStore.instance.resetToDefaults();
    if (!mounted) return;
    setState(() {
      _orderVoiceCtrl.text = VoiceSettingsStore.instance.orderTemplate;
      _waiterVoiceCtrl.text = VoiceSettingsStore.instance.waiterTemplate;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Textes vocaux réinitialisés')),
    );
  }

  Widget _buildVoiceTestButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceTestButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 400;
        final orderBtn = SizedBox(
          width: narrow ? double.infinity : null,
          child: _buildVoiceTestButton(
            label: 'Tester commande',
            onPressed: () =>
                VoiceAnnouncer.instance.announceNewOrder('Table 2'),
          ),
        );
        final callBtn = SizedBox(
          width: narrow ? double.infinity : null,
          child: _buildVoiceTestButton(
            label: 'Tester appel',
            onPressed: () =>
                VoiceAnnouncer.instance.announceWaiterCall('Table 2'),
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              orderBtn,
              const SizedBox(height: 8),
              callBtn,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: orderBtn),
            const SizedBox(width: 8),
            Expanded(child: callBtn),
          ],
        );
      },
    );
  }

  String _serverErrorMessage(Object error, bool starting) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('address already in use') ||
        msg.contains('errno = 98') ||
        msg.contains('errno = 48') ||
        msg.contains('eaddrinuse')) {
      return 'Le port 8080 est occupé. Attendez 2 secondes puis réessayez.';
    }
    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Permission réseau refusée. Autorisez l\'accès réseau à l\'application.';
    }
    if (msg.contains('network is unreachable') || msg.contains('no route')) {
      return 'Réseau indisponible. Connectez l\'appareil au Wi-Fi du restaurant.';
    }
    return starting
        ? 'Impossible de démarrer le serveur. Vérifiez le Wi-Fi et réessayez.'
        : 'Impossible d\'arrêter le serveur. Réessayez dans quelques secondes.';
  }

  Future<void> _toggleServer(AppProvider provider, bool enable) async {
    if (provider.serverBusy) return;
    try {
      if (enable) {
        await provider.startLocalServer();
      } else {
        await provider.stopLocalServer();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_serverErrorMessage(e, enable)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.currentUser;
    final busy = provider.serverBusy;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Paramètres",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Serveur local, compte et session",
            style: TextStyle(color: context.resto.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          if (user != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: RestoTheme.primary.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: RestoTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.role.toUpperCase(),
                            style: TextStyle(
                              color: context.resto.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            "Serveur local",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Statut du Serveur",
                            style: TextStyle(
                              color: context.resto.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: provider.isServerRunning
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                busy
                                    ? "EN COURS..."
                                    : provider.isServerRunning
                                    ? "ACTIF"
                                    : "INACTIF",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      busy
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Switch(
                              value: provider.isServerRunning,
                              activeThumbColor: RestoTheme.primary,
                              onChanged: (val) => _toggleServer(provider, val),
                            ),
                    ],
                  ),
                  if (provider.isServerRunning) ...[
                    const Divider(height: 32),
                    _buildConfigRow("Adresse IP locale", provider.serverIp),
                    const SizedBox(height: 12),
                    _buildConfigRow(
                      "Port de connexion",
                      "${provider.serverPort}",
                    ),
                    // const SizedBox(height: 16),
                    // OutlinedButton.icon(
                    //   onPressed: () {
                    //     VoiceAnnouncer.instance.announceNewOrder('Table 2');
                    //   },
                    //   icon: const Icon(Icons.volume_up),
                    //   label: const Text('Tester l\'annonce vocale'),
                    // ),
                  ],
                ],
              ),
            ),
          ),
          // const SizedBox(height: 24),
          // const Text(
          //   "Guide client",
          //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          // ),
          // const SizedBox(height: 12),
          // const Card(
          //   child: Padding(
          //     padding: EdgeInsets.all(16),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text(
          //           "1. Les clients se connectent au Wi-Fi du restaurant.",
          //           style: TextStyle(fontSize: 14),
          //         ),
          //         SizedBox(height: 8),
          //         Text(
          //           "2. Générez les QR codes pour chaque table dans l'onglet « Tables ».",
          //           style: TextStyle(fontSize: 14),
          //         ),
          //         SizedBox(height: 8),
          //         Text(
          //           "3. Un scan ouvre le menu dans le navigateur (PWA) — aucune application à installer.",
          //           style: TextStyle(fontSize: 14),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          if (user?.role == 'admin') ...[
            const SizedBox(height: 24),
            const Text(
              "Annonces vocales",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Personnalisez les messages lus à voix haute. Utilisez ${VoiceSettingsStore.tablePlaceholder} pour le nom de la table.",
              style: TextStyle(color: context.resto.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _voiceSettingsLoaded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _orderVoiceCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Nouvelle commande',
                              hintText: VoiceSettingsStore.defaultOrderTemplate,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _waiterVoiceCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Appel serveur',
                              hintText: VoiceSettingsStore.defaultWaiterTemplate,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      _voiceSaving ? null : _resetVoiceSettings,
                                  child: const Text('Réinitialiser'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      _voiceSaving ? null : _saveVoiceSettings,
                                  child: _voiceSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Enregistrer'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildVoiceTestButtons(),
                        ],
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Text(
            "Session",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: RestoTheme.secondary),
              title: const Text(
                'Déconnexion',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Quitter le portail personnel'),
              trailing: Icon(
                Icons.chevron_right,
                color: context.resto.textSecondary,
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Déconnexion'),
                    content: const Text(
                      'Voulez-vous vraiment vous déconnecter ?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RestoTheme.secondary,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          provider.logoutStaff();
                        },
                        child: const Text('Déconnexion'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.resto.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.resto.textPrimary,
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// VIEW 2: TABLES ADMIN VIEW
// -------------------------------------------------------------
class TablesAdminView extends StatelessWidget {
  const TablesAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isAdmin = provider.currentUser?.role == 'admin';

    if (!provider.isServerRunning) {
      return const Center(
        child: Text("Activez le serveur local pour gérer les tables."),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${provider.tables.length} table${provider.tables.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showAddTableDialog(context, provider),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: RestoTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: provider.tables.length,
            itemBuilder: (context, index) {
              final table = provider.tables[index];
              final statusColor = RestoTheme.getStatusColor(table.status);

              return Card(
                child: InkWell(
                  onTap: () {
                    _showTableActions(
                      context,
                      table,
                      provider,
                      isAdmin: isAdmin,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          table.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Text(
                            RestoTheme.getStatusLabel(table.status),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddTableDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    final nextIndex = provider.tables.length + 1;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle table'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nom de la table',
            hintText: 'Table $nextIndex',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              await provider.addTable(name: nameCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTable(
    BuildContext context,
    RestaurantTable table,
    AppProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${table.name} ?'),
        content: const Text(
          'Cette action est irréversible. La table ne doit pas avoir de commande en cours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RestoTheme.secondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await provider.deleteTable(table.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${table.name} supprimée')),
        );
      }
    } on StateError catch (e) {
      if (!context.mounted) return;
      final message = switch (e.message) {
        'last_table' => 'Impossible de supprimer la dernière table.',
        'active_orders' => 'Cette table a des commandes en cours.',
        'pending_calls' => 'Cette table a un appel serveur en attente.',
        _ => 'Impossible de supprimer cette table.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showTableActions(
    BuildContext context,
    RestaurantTable table,
    AppProvider provider, {
    required bool isAdmin,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.resto.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final payload = ClientWebContent.tableMenuUrl(
          provider.serverIp,
          provider.serverPort,
          table.id,
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Gérer ${table.name}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.qr_code, color: RestoTheme.primary),
                  title: const Text("Afficher / Exporter le QR Code"),
                  onTap: () {
                    Navigator.pop(context);
                    _showQRCodeDialog(context, table.name, payload);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  title: const Text("Marquer Libre"),
                  onTap: () async {
                    await DatabaseHelper.instance.updateTableStatus(
                      table.id,
                      'libre',
                    );
                    await provider.refreshRestaurantData();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_dining, color: Colors.amber),
                  title: const Text("Marquer Occupée"),
                  onTap: () async {
                    await DatabaseHelper.instance.updateTableStatus(
                      table.id,
                      'occupee',
                    );
                    await provider.refreshRestaurantData();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.monetization_on,
                    color: Colors.purple,
                  ),
                  title: const Text("Marquer 'Addition Demandée'"),
                  onTap: () async {
                    await provider.markTableWaitingBill(table.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                if (isAdmin) ...[
                  const Divider(height: 24),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: RestoTheme.secondary),
                    title: const Text(
                      'Supprimer la table',
                      style: TextStyle(color: RestoTheme.secondary),
                    ),
                    onTap: () => _confirmDeleteTable(context, table, provider),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQRCodeDialog(
    BuildContext context,
    String tableName,
    String qrPayload,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('QR Code - $tableName'),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 200,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Les clients scannent ce QR : le menu s'ouvre directement dans le navigateur (Wi-Fi du restaurant requis).",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.resto.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _printQRCode(tableName, qrPayload);
              },
              child: const Text("Imprimer / PDF"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printQRCode(String tableName, String qrPayload) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  "RESTO OFFLINE",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(tableName, style: pw.TextStyle(fontSize: 18)),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrPayload,
                  width: 150,
                  height: 150,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Scannez pour commander",
                  style: pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
}

// -------------------------------------------------------------
// VIEW 3: KITCHEN VIEW (PREPARATION QUEUE)
// -------------------------------------------------------------
class KitchenView extends StatelessWidget {
  const KitchenView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Active orders in kitchen (not paid, not cancelled)
    final kitchenOrders = provider.orders
        .where((o) => o.status != 'payee' && o.status != 'annulee')
        .toList();

    if (kitchenOrders.isEmpty) {
      return const Center(child: Text("Aucune commande en cours en cuisine."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kitchenOrders.length,
      itemBuilder: (context, index) {
        final order = kitchenOrders[index];
        final statusColor = RestoTheme.getStatusColor(order.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Table ${order.tableId} - Commande #${order.id}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        RestoTheme.getStatusLabel(order.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Items list
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = order.items[itemIndex];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Text(
                            "${item.quantity}x",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: RestoTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item.productName)),
                          if (item.notes.isNotEmpty)
                            Text(
                              "(${item.notes})",
                              style: const TextStyle(
                                color: Colors.amber,
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (order.status == 'nouvelle')
                      ElevatedButton(
                        onPressed: () =>
                            provider.updateOrderStatus(order.id!, 'acceptee'),
                        child: const Text("Accepter"),
                      ),
                    if (order.status == 'acceptee')
                      ElevatedButton(
                        onPressed: () => provider.updateOrderStatus(
                          order.id!,
                          'enPreparation',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                        ),
                        child: const Text("Préparer"),
                      ),
                    if (order.status == 'enPreparation')
                      ElevatedButton(
                        onPressed: () =>
                            provider.updateOrderStatus(order.id!, 'prete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text("Prête"),
                      ),
                    if (order.status == 'prete')
                      ElevatedButton(
                        onPressed: () =>
                            provider.updateOrderStatus(order.id!, 'servie'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text("Servir"),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Extension to avoid compilation issues with Margin
extension on Card {
  Widget margin(EdgeInsetsGeometry val) {
    return Padding(padding: val, child: this);
  }
}

extension MarginCard on Widget {
  Widget bottomOffset(double val) {
    return Padding(
      padding: EdgeInsets.only(bottom: val),
      child: this,
    );
  }
}

// -------------------------------------------------------------
// VIEW 4: CASHIER VIEW (BILLING & CHECKOUT)
// -------------------------------------------------------------
class CashierView extends StatelessWidget {
  const CashierView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Filter orders waiting checkout or served/ready
    final unpaidOrders = provider.orders
        .where((o) => o.status != 'payee' && o.status != 'annulee')
        .toList();

    if (unpaidOrders.isEmpty) {
      return const Center(child: Text("Aucune addition en attente."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: unpaidOrders.length,
      itemBuilder: (context, index) {
        final order = unpaidOrders[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Table ${order.tableId} - Commande #${order.id}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatFcfa(order.totalAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: RestoTheme.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentButton(
                        context,
                        provider,
                        order,
                        "Espèces",
                        Icons.money,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentButton(
                        context,
                        provider,
                        order,
                        "Orange Money",
                        Icons.phone_android,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPaymentButton(
                        context,
                        provider,
                        order,
                        "Moov Money",
                        Icons.phonelink_setup,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _printReceipt(order),
                    icon: const Icon(Icons.print),
                    label: const Text("Imprimer le Ticket"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentButton(
    BuildContext context,
    AppProvider provider,
    RestaurantOrder order,
    String method,
    IconData icon,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: RestoTheme.success,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () async {
        await provider.payOrder(order.id!, method);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Paiement validé par $method")),
          );
        }
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(method, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt(RestaurantOrder order) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    "RESTO OFFLINE",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Center(child: pw.Text("Ticket de caisse")),
                pw.SizedBox(height: 10),
                pw.Text("Table: ${order.tableId}"),
                pw.Text("Commande"), // #: ${order.id}
                pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}"),
                pw.Divider(),
                ...order.items.map(
                  (item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("${item.quantity}x ${item.productName}"),
                      pw.Text(formatFcfa(item.quantity * item.unitPrice)),
                    ],
                  ),
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Total",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      formatFcfa(order.totalAmount),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text("Merci de votre visite et à bientôt !"),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
}

// -------------------------------------------------------------
// VIEW 5: CATALOG ADMIN VIEW (PRODUCT & CATEGORIES)
// -------------------------------------------------------------
class CatalogAdminView extends StatefulWidget {
  const CatalogAdminView({super.key});

  @override
  State<CatalogAdminView> createState() => _CatalogAdminViewState();
}

class _CatalogAdminViewState extends State<CatalogAdminView> {
  final _searchCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  int? _filterCategoryId;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filteredProducts(AppProvider provider) {
    return provider.products.where((p) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _filterCategoryId == null || p.categoryId == _filterCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _categoryName(AppProvider provider, int categoryId) {
    return provider.categories
        .firstWhere(
          (c) => c.id == categoryId,
          orElse: () =>
              Category(name: 'Sans catégorie', description: '', position: 0),
        )
        .name;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final products = _filteredProducts(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.resto.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.resto.borderSubtle),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: context.resto.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: const InputDecoration(
                            hintText: 'Rechercher un produit',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: context.resto.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.resto.borderSubtle),
                ),
                child: IconButton(
                  icon: const Icon(Icons.tune, size: 20),
                  onPressed: () => _showFilterSheet(provider),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('Tous', _filterCategoryId == null, () {
                setState(() => _filterCategoryId = null);
              }),
              ...provider.categories.map((cat) {
                return _buildFilterChip(
                  cat.name,
                  _filterCategoryId == cat.id,
                  () => setState(() => _filterCategoryId = cat.id),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${products.length} produit${products.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddProductSheet(provider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RestoTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      provider.categories.isEmpty
                          ? 'Menu vide.\nCréez des catégories via l\'icône filtre, puis ajoutez vos produits.'
                          : 'Aucun produit trouvé',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.resto.textSecondary),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final prod = products[index];
                    return _ProductGridCard(
                      product: prod,
                      categoryName: _categoryName(provider, prod.categoryId),
                      onTap: () => _showProductDetailSheet(provider, prod),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showFilterSheet(AppProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.resto.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _FilterSheet(
        onReset: () {
          setState(() {
            _searchCtrl.clear();
            _searchQuery = '';
            _filterCategoryId = null;
          });
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: RestoTheme.success,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : context.resto.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: context.resto.surface,
        side: BorderSide(
          color: selected ? RestoTheme.success : context.resto.borderSubtle,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showAddProductSheet(AppProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.resto.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _AddProductSheet(
        imagePicker: _imagePicker,
        categoryName: _categoryName,
        onOpenCategoryPicker: _showCategoryPickerSheet,
      ),
    );
  }

  void _showCategoryPickerSheet(
    BuildContext sheetContext,
    int? selectedCatId,
    void Function(int id) onSelected,
  ) {
    showModalBottomSheet(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: sheetContext.resto.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (pickerContext) => _CategoryPickerSheet(
        selectedCatId: selectedCatId,
        onSelected: onSelected,
      ),
    );
  }

  void _showProductDetailSheet(AppProvider provider, Product prod) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.resto.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final catName = _categoryName(provider, prod.categoryId);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.resto.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<File?>(
                  future: ProductImageStorage.fileFor(prod.imagePath),
                  builder: (context, snap) {
                    if (snap.data != null) {
                      return _NaturalProductImage(file: snap.data);
                    }
                    return Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: context.resto.placeholderBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.fastfood,
                        size: 64,
                        color: RestoTheme.primary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  prod.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: RestoTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        catName,
                        style: const TextStyle(
                          color: RestoTheme.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatFcfa(prod.price),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: RestoTheme.primary,
                      ),
                    ),
                  ],
                ),
                if (prod.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    prod.description,
                    style: TextStyle(
                      color: context.resto.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            imageQuality: 85,
                          );
                          if (picked != null && prod.id != null) {
                            await provider.setProductImage(
                              prod.id!,
                              File(picked.path),
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          }
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Photo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (prod.id == null) return;
                          await provider.deleteProduct(prod.id!);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RestoTheme.danger,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final VoidCallback onReset;

  const _FilterSheet({required this.onReset});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _catNameCtrl;

  @override
  void initState() {
    super.initState();
    _catNameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _catNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.resto.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filtres & catégories',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réinitialiser les filtres'),
              ),
              const SizedBox(height: 20),
              Text(
                'Catégories',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.resto.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _catNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Nouvelle catégorie',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      if (_catNameCtrl.text.isEmpty) return;
                      await provider.addCategory(_catNameCtrl.text, '');
                      _catNameCtrl.clear();
                    },
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: RestoTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (provider.categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Aucune catégorie',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.resto.textSecondary),
                  ),
                )
              else
                ...provider.categories.map((cat) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(cat.name),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: RestoTheme.danger,
                      ),
                      onPressed: () => provider.deleteCategory(cat.id!),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  final int? selectedCatId;
  final void Function(int id) onSelected;

  const _CategoryPickerSheet({
    required this.selectedCatId,
    required this.onSelected,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late final TextEditingController _newCatCtrl;

  @override
  void initState() {
    super.initState();
    _newCatCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _newCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final name = _newCatCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un nom de catégorie')),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final id = await provider.addCategory(name, '');
    if (!mounted) return;

    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSelected(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final categories = provider.categories;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.resto.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choisir une catégorie',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aucune catégorie pour le moment',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.resto.textSecondary),
                  ),
                )
              else
                ...categories.map((cat) {
                  final isSelected = cat.id == widget.selectedCatId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? RestoTheme.success
                          : context.resto.textSecondary,
                    ),
                    title: Text(cat.name),
                    onTap: () {
                      if (cat.id == null) return;
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        widget.onSelected(cat.id!);
                      });
                    },
                  );
                }),
              const Divider(height: 32),
              Text(
                'Ajouter une catégorie',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.resto.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newCatCtrl,
                decoration: const InputDecoration(
                  hintText: 'Nom de la catégorie',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _createCategory(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _createCategory,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter catégorie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RestoTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProductSheet extends StatefulWidget {
  final ImagePicker imagePicker;
  final String Function(AppProvider provider, int categoryId) categoryName;
  final void Function(
    BuildContext sheetContext,
    int? selectedCatId,
    void Function(int id) onSelected,
  )
  onOpenCategoryPicker;

  const _AddProductSheet({
    required this.imagePicker,
    required this.categoryName,
    required this.onOpenCategoryPicker,
  });

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  int? _selectedCatId;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.categories.isNotEmpty) {
      _selectedCatId = provider.categories.first.id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppProvider provider) async {
    if (_nameCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty ||
        _selectedCatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remplissez le nom, le prix et la catégorie'),
        ),
      );
      return;
    }
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    await provider.addProduct(
      _nameCtrl.text,
      _descCtrl.text,
      price,
      _selectedCatId!,
      imageFile: _pickedImage,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.resto.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nouveau produit',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final picked = await widget.imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1200,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() => _pickedImage = File(picked.path));
                }
              },
              child: _pickedImage != null
                  ? _NaturalProductImage(file: _pickedImage)
                  : Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: context.resto.placeholderBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.resto.borderSubtle),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: context.resto.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ajouter une photo',
                            style: TextStyle(
                              color: context.resto.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom du produit'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix (FCFA)'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => widget.onOpenCategoryPicker(
                context,
                _selectedCatId,
                (id) => setState(() => _selectedCatId = id),
              ),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _selectedCatId == null
                      ? 'Sélectionner une catégorie'
                      : widget.categoryName(provider, _selectedCatId!),
                  style: TextStyle(
                    color: _selectedCatId == null
                        ? context.resto.textSecondary
                        : context.resto.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _save(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: RestoTheme.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NaturalProductImage extends StatelessWidget {
  final File? file;
  final double borderRadius;

  const _NaturalProductImage({required this.file, this.borderRadius = 20});

  @override
  Widget build(BuildContext context) {
    if (file == null) return const SizedBox.shrink();

    final maxWidth = MediaQuery.sizeOf(context).width - 48;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(file!, width: maxWidth, fit: BoxFit.contain),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final Product product;
  final String categoryName;
  final VoidCallback onTap;

  const _ProductGridCard({
    required this.product,
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.resto;
    final isDark = colors.isDark;
    final overlayColor = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.94);
    final overlayBorder = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.08);
    final titleColor = isDark ? Colors.white : colors.textPrimary;
    final priceColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : colors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<File?>(
              future: ProductImageStorage.fileFor(product.imagePath),
              builder: (context, snap) {
                if (snap.data != null) {
                  return Image.file(snap.data!, fit: BoxFit.cover);
                }
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        RestoTheme.primary.withValues(alpha: 0.3),
                        context.resto.surface,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.fastfood,
                      size: 48,
                      color: RestoTheme.primary,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  product.isAvailable
                      ? Icons.check_circle
                      : Icons.remove_circle_outline,
                  size: 18,
                  color: product.isAvailable
                      ? RestoTheme.success
                      : context.resto.textSecondary,
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: overlayColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: overlayBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: RestoTheme.success.withValues(
                            alpha: 0.9,
                          ),
                          child: Text(
                            product.name.isNotEmpty
                                ? product.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  shadows: isDark
                                      ? const [
                                          Shadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              Text(
                                formatFcfa(product.price),
                                style: TextStyle(
                                  color: priceColor,
                                  fontSize: 11,
                                  fontWeight: isDark
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  shadows: isDark
                                      ? const [
                                          Shadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: priceColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// VIEW 6: REPORTS VIEW
// -------------------------------------------------------------
class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() async {
    final stats = await DatabaseHelper.instance.getStatistics();
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final revenue = _stats?['revenue'] as double? ?? 0.0;
    final totalOrders = _stats?['total_orders'] as int? ?? 0;
    final paymentMethods =
        _stats?['payment_methods'] as Map<String, double>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Rapports de ventes",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Chiffre d'affaires",
                  formatFcfa(revenue),
                  Icons.trending_up,
                  RestoTheme.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  "Commandes Payées",
                  "$totalOrders",
                  Icons.receipt_long,
                  RestoTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Répartition par Moyen de Paiement",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (paymentMethods.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text("Aucune vente enregistrée pour le moment."),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: paymentMethods.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.payment,
                                color: RestoTheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                entry.key,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Text(
                            formatFcfa(entry.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: context.resto.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.resto.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
