import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/laundry_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/catalog/entity_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/staff/staff_screen.dart';
import 'widgets/common.dart';

class LaundryApp extends StatefulWidget {
  final LaundryRepository? repository;
  const LaundryApp({super.key, this.repository});
  @override
  State<LaundryApp> createState() => _LaundryAppState();
}

class _LaundryAppState extends State<LaundryApp> with WidgetsBindingObserver {
  var _navigator = GlobalKey<NavigatorState>();
  StaffSession? _staff;
  bool _loading = true, _denied = false;
  String? _error;
  int _section = 0, _generation = 0;
  StreamSubscription<bool>? _subscription;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _subscription = widget.repository?.sessions.listen((_) => (_refresh()));
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_staff != null) _refresh(background: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(background: true);
  }

  Future<void> _refresh({bool background = false}) async {
    final token = ++_generation, repo = widget.repository;
    if (repo == null || !repo.hasSession) {
      if (mounted) {
        _clearSession(denied: false);
      }
      return;
    }
    try {
      final staff = await repo.profile();
      if (mounted && token == _generation) {
        setState(() {
          if (_staff != null && _staff!.role != staff.role) {
            _navigator = GlobalKey<NavigatorState>();
            _section = 0;
          }
          _staff = staff;
          _loading = false;
          _denied = false;
          _error = null;
          if (!staff.isAdmin && _section == 4) _section = 0;
        });
      }
    } on AccessDenied {
      if (mounted && token == _generation) _deny();
    } catch (e) {
      if (mounted && token == _generation && isAccessError(e)) {
        _deny();
        return;
      }
      if (mounted && token == _generation && !background) {
        setState(() {
          _loading = false;
          _error = errorText(e);
        });
      }
    }
  }

  void _clearSession({required bool denied}) {
    _generation++;
    setState(() {
      // Replacing the navigator disposes all protected routes, including busy
      // dialogs whose PopScope intentionally blocks ordinary back navigation.
      _navigator = GlobalKey<NavigatorState>();
      _staff = null;
      _denied = denied;
      _loading = false;
      _error = null;
      _section = 0;
    });
  }

  void _deny() => _clearSession(denied: true);

  Future<void> _logout() async {
    try {
      await widget.repository!.signOut();
      if (mounted) {
        _clearSession(denied: false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cerrar la sesión. Reintenta.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => SessionScope(
    onDenied: _deny,
    child: MaterialApp(
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      title: 'Lavandería · Gestión',
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff146b64)),
        scaffoldBackgroundColor: const Color(0xfff5f7fa),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          ),
        ),
      ),
      home: _home(),
    ),
  );
  Widget _home() {
    final repo = widget.repository;
    if (repo == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_laundry_service_outlined,
                  size: 64,
                  color: Color(0xff146b64),
                ),
                SizedBox(height: 20),
                Text(
                  'Lavandería · Gestión',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Conecta tu lavandería para comenzar',
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(height: 8),
                Text(
                  'El administrador debe configurar la conexión a Supabase siguiendo el README del proyecto.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_denied) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Acceso no disponible. Consulta con el administrador.',
              ),
              TextButton(
                onPressed: _logout,
                child: const Text('Volver al inicio de sesión'),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null && _staff == null) {
      return Scaffold(body: LoadError(retry: _refresh));
    }
    if (_staff == null) {
      return LoginScreen(repository: repo, onSignedIn: _refresh);
    }
    return _shell(repo, _staff!);
  }

  Widget _shell(LaundryRepository repo, StaffSession staff) {
    const names = ['Resumen', 'Pedidos', 'Clientes', 'Servicios', 'Personal'];
    const icons = [
      Icons.dashboard_outlined,
      Icons.receipt_long_outlined,
      Icons.people_outline,
      Icons.local_laundry_service_outlined,
      Icons.badge_outlined,
    ];
    final count = staff.isAdmin ? 5 : 4;
    final pages = <Widget>[
      DashboardScreen(
        repository: repo,
        navigate: (i) => setState(() => _section = i),
      ),
      OrdersScreen(repository: repo),
      EntityScreen(repository: repo, table: 'clients', isAdmin: staff.isAdmin),
      EntityScreen(repository: repo, table: 'services', isAdmin: staff.isAdmin),
      StaffScreen(repository: repo),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Lavandería',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              if (wide)
                Text(
                  '${staff.name} · ${staff.isAdmin ? 'Administrador' : 'Empleado'}',
                ),
              IconButton(
                onPressed: _logout,
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: _section,
                  onDestinationSelected: (i) => setState(() => _section = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (var i = 0; i < count; i++)
                      NavigationRailDestination(
                        icon: Icon(icons[i]),
                        label: Text(names[i]),
                      ),
                  ],
                ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey(_section),
                  child: pages[_section],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _section,
                  onDestinationSelected: (i) => setState(() => _section = i),
                  destinations: [
                    for (var i = 0; i < count; i++)
                      NavigationDestination(
                        icon: Icon(icons[i]),
                        label: names[i],
                      ),
                  ],
                ),
          bottomSheet: _error == null
              ? null
              : Material(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                ),
        );
      },
    );
  }
}
