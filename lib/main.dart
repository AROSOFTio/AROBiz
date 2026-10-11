import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'services/data_service.dart';
import 'screens/home_screen.dart';
import 'screens/invoice_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_invoice_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
  }
  await DataService().init();
  runApp(const InvoicingApp());
}

class InvoicingApp extends StatelessWidget {
  const InvoicingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARODesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C75), // Deep Professional Blue
          secondary: const Color(0xFF3282B8),
          tertiary: const Color(0xFFBBE1FA),
          background: const Color(0xFFF9F9F9),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F4C75),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF3282B8),
          foregroundColor: Colors.white,
        ),
      ),
      home: DataService().isLoggedIn ? const AppShell() : const LoginScreen(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    const HomeScreen(),
    const InvoiceListScreen(),
    SettingsScreen(onSaved: () {
      if (mounted) setState(() => _currentIndex = 0);
    }),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Documents',
    'Settings',
  ];

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    final profile = DataService().currentProfile;
    final businessName = profile?.name ?? 'My Business';
    final businessCategory = profile?.category ?? '';
    final email = profile?.email ?? profile?.phone ?? '';
    final logoPath = profile?.logoPath;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Colors.white24,
              backgroundImage: logoPath != null ? FileImage(File(logoPath)) : null,
              child: logoPath == null
                  ? Text(businessName.isNotEmpty ? businessName[0].toUpperCase() : 'A',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Text(_titles[_currentIndex]),
          ],
        ),
      ),

      drawer: Drawer(
        width: 290,
        child: Column(
          children: [
            // ── Branded Header ─────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ARODesk is the app brand. The selected company appears below.
                      const Text(
                        'ARODesk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Business avatar + info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage: logoPath != null
                                ? FileImage(File(logoPath)) as ImageProvider
                                : null,
                            child: logoPath == null
                                ? Text(
                                    businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  businessName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (businessCategory.isNotEmpty)
                                  Text(
                                    businessCategory,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Navigation Items ───────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const SizedBox(height: 8),

                  _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isSelected: _currentIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  _NavItem(
                    icon: Icons.description_rounded,
                    label: 'Documents',
                    isSelected: _currentIndex == 1,
                    onTap: () => _onItemTapped(1),
                  ),
                  _NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: _currentIndex == 2,
                    onTap: () => _onItemTapped(2),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(),
                  ),

                  // Quick create button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                        ).then((_) => setState(() {}));
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer with logout ─────────────────────────────────
            const Divider(height: 1),
            _NavItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              isSelected: false,
              iconColor: Colors.redAccent,
              labelColor: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context);
                await DataService().logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12, top: 4),
              child: Text(
                'Powered by ARODesk  •  AROSOFT Innovations',
                style: TextStyle(color: Colors.grey, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),

      body: _screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          child: Text(
            'Powered by ARODesk  •  AROSOFT Innovations',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable Nav Item Widget ───────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveIcon = iconColor ?? (isSelected ? primary : Colors.grey.shade700);
    final effectiveLabel = labelColor ?? (isSelected ? primary : Colors.grey.shade800);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: effectiveIcon, size: 24),
        title: Text(
          label,
          style: TextStyle(
            color: effectiveLabel,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}

