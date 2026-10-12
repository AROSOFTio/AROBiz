import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'services/data_service.dart';
import 'screens/home_screen.dart';
import 'screens/invoice_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/password_security_screen.dart';
import 'screens/create_invoice_screen.dart';
import 'screens/products_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/saas_admin_screen.dart';
import 'services/saas_admin_service.dart';
import 'services/inventory_service.dart';
import 'screens/team_screen.dart';

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

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class InvoicingApp extends StatefulWidget {
  const InvoicingApp({super.key});
  @override
  State<InvoicingApp> createState()=>_InvoicingAppState();
}
class _InvoicingAppState extends State<InvoicingApp> {
  @override
  void initState(){
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data){
      if(data.event==AuthChangeEvent.passwordRecovery){
        WidgetsBinding.instance.addPostFrameCallback((_){
          appNavigatorKey.currentState?.push(MaterialPageRoute(
            builder:(_)=>const PasswordSecurityScreen(recovery:true)));
        });
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey:appNavigatorKey,
      title: 'ARODesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006FFF), // Deep Professional Blue
          secondary: const Color(0xFF009CFF),
          tertiary: const Color(0xFFDCEEFF),
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
      home: DataService().isLoggedIn
        ? FutureBuilder<bool>(
          future:Supabase.instance.client.rpc('arodesk_password_change_required')
            .then((v)=>v==true),
          builder:(context,snapshot){
            if(!snapshot.hasData && !snapshot.hasError){
              return const Scaffold(body:Center(child:CircularProgressIndicator()));
            }
            if(snapshot.hasError){
              return const Scaffold(body:Center(child:Text(
                'Unable to verify account security. Check your connection and reopen ARODesk.')));
            }
            return snapshot.data == true
              ? const PasswordSecurityScreen(forced:true)
              : const AppShell();
          })
        : const LoginScreen(),
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
  String? _role;
  String? _activeBusinessName;
  @override
  void initState(){super.initState();_loadRole();}
  Future<void> _loadRole()async{
    try{
      var memberships=await TeamService.instance.businesses();
      if(memberships.isEmpty){
        final profile=DataService().currentProfile;
        await InventoryService.instance.ensureBusiness(
          name:profile?.name??'My Business',category:profile?.category??'Other');
        memberships=await TeamService.instance.businesses();
      }
      final profile=DataService().currentProfile;
      final activeId=await InventoryService.instance.ensureBusiness(
        name:profile?.name??'My Business',category:profile?.category??'Other');
      final active=memberships.where((b)=>b['business_id'].toString()==activeId).toList();
      if(mounted)setState((){
        _role=active.isEmpty?null:active.first['role'].toString();
        _activeBusinessName=active.isEmpty?null:active.first['business_name'].toString();
      });
    }catch(_){if(mounted)setState(()=>_role=null);}
  }
  bool get _canManage => _role=='owner'||_role=='admin';
  bool get _canWrite => _canManage||_role=='staff';
  void _goToPage(int page){
    if((page==4&&!_canManage)||(page==3&&!_canWrite)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('You do not have access to this section.')));
      return;
    }
    setState(()=>_currentIndex=page);
  }

  List<Widget> get _screens => [
    HomeScreen(onNavigate:_goToPage),
    InvoiceListScreen(readOnly:!_canWrite),
    ProductsScreen(readOnly:!_canWrite),
    const SalesScreen(),
    SettingsScreen(onSaved: () {
      if (mounted) setState(() => _currentIndex = 0);
    }),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Documents',
    'Products',
    'Sales',
    'Settings',
  ];

  void _onItemTapped(int index) {
    if((index==4&&!_canManage)||(index==3&&!_canWrite)){
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Your role does not allow this action.')));
      return;
    }
    setState(() => _currentIndex = index);
    Navigator.pop(context); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    final profile = DataService().currentProfile;
    final businessName = _activeBusinessName ?? profile?.name ?? 'My Business';
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
                      // Display the selected company's identity, not the ARODesk wordmark.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: 70,
                            width: 70,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: logoPath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(File(logoPath),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          businessName.isNotEmpty
                                              ? businessName[0].toUpperCase() : 'B',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF006FFF),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      businessName.isNotEmpty
                                          ? businessName[0].toUpperCase() : 'B',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF006FFF),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(businessName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                if (businessCategory.isNotEmpty)
                                  Text(businessCategory,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                  ),
                                if (email.isNotEmpty)
                                  Text(email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
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
                  FutureBuilder<List<Map<String,dynamic>>>(
                    future: TeamService.instance.businesses(),
                    builder: (ctx,snapshot) {
                      final businesses=snapshot.data??[];
                      if(businesses.length<=1)return const SizedBox.shrink();
                      return PopupMenuButton<String>(
                        tooltip:'Switch business',
                        onSelected:(id) async {
                          try {
                            await InventoryService.instance.selectBusiness(id);
                            await _loadRole();
                            if(mounted)setState(()=>_currentIndex=0);
                            if(context.mounted)Navigator.pop(context);
                          } catch (_) {
                            if(mounted)ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content:Text('Could not switch business.')));
                          }
                        },
                        itemBuilder:(ctx)=>businesses.map((b)=>PopupMenuItem<String>(
                          value:b['business_id'].toString(),
                          child:Text(b['business_name'].toString()+' · '+b['role'].toString()),
                        )).toList(),
                        child:const ListTile(
                          leading:Icon(Icons.swap_horiz_outlined),
                          title:Text('Switch business'),
                          trailing:Icon(Icons.arrow_drop_down)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isSelected: _currentIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  // Top-level Documents aligns exactly with all _NavItem rows.
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: _currentIndex == 1
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      key: const PageStorageKey<String>('documents-navigation'),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.only(left: 24, right: 8, bottom: 6),
                      initiallyExpanded: _currentIndex == 1,
                      leading: Icon(Icons.description_rounded,
                        size: 24,
                        color: _currentIndex == 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade700),
                      title: Text('Documents',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _currentIndex == 1
                              ? FontWeight.bold : FontWeight.w500,
                          color: _currentIndex == 1
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade800,
                        )),
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: const Icon(Icons.folder_open_outlined, size: 20),
                          title: const Text('View documents'),
                          onTap: () => _onItemTapped(1),
                        ),
                        if (_canWrite)
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            leading: const Icon(Icons.note_add_outlined, size: 20),
                            title: const Text('Create document'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const CreateInvoiceScreen(),
                              )).then((_) {
                                if (mounted) setState(() => _currentIndex = 1);
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  _NavItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'Products & Inventory',
                    isSelected: _currentIndex == 2,
                    onTap: () => _onItemTapped(2),
                  ),
                  if (_canWrite) _NavItem(
                    icon: Icons.point_of_sale_outlined,
                    label: 'Sales & POS',
                    isSelected: _currentIndex == 3,
                    onTap: () => _onItemTapped(3),
                  ),
                  if (_canManage) _NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    isSelected: _currentIndex == 4,
                    onTap: () => _onItemTapped(4),
                  ),

                  if (_role == 'owner' || _role == 'admin')
                    _NavItem(
                      icon: Icons.groups_outlined,
                      label: 'Team & Permissions',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context,MaterialPageRoute(
                          builder: (_) => const TeamScreen())).then((_)=>_loadRole());
                      },
                    ),
                  if (!_canManage)
                    _NavItem(
                      icon: Icons.lock_outline,
                      label: 'Change password',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context,MaterialPageRoute(
                          builder: (_) => const PasswordSecurityScreen()));
                      },
                    ),
                  FutureBuilder<bool>(
                    future: SaaSAdminService.instance.isAdmin(),
                    builder: (context, snapshot) {
                      if(snapshot.data != true) return const SizedBox.shrink();
                      return _NavItem(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'SaaS Admin',
                        isSelected: false,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SaaSAdminScreen()));
                        },
                      );
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(),
                  ),

                  // Quick create button
                  if (_canWrite) Padding(
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

