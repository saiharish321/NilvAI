import 'package:flutter/material.dart';

import 'screens/dashboard.dart';
import 'screens/lookup.dart';
import 'screens/more.dart';
import 'screens/receipts.dart';
import 'screens/sale.dart';
import 'screens/stock.dart';
import 'state.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.refresh();
  runApp(const NilvaiApp());
}

class NilvaiApp extends StatelessWidget {
  const NilvaiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Nilvai',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: brand),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAF7F0),
          visualDensity: VisualDensity.standard,
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontSize: 17))),
        ),
        // Larger text throughout: the app is used at a shop counter.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.of(context).textScaler.clamp(minScaleFactor: 1.1)),
          child: child!,
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  static const _pages = [LookupScreen(), SaleScreen(), ReceiptsScreen(), StockScreen(), DashboardScreen()];

  Future<void> _toggleOwner() async {
    if (app.owner) {
      app.setOwner(false);
      return;
    }
    final pin = app.settings['pin'] ?? '';
    if (pin.isEmpty) {
      app.setOwner(true);
      return;
    }
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN'),
        content: TextField(controller: c, obscureText: true, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text == pin), child: const Text('OK')),
        ],
      ),
    );
    c.dispose();
    if (ok == true) {
      app.setOwner(true);
    } else if (ok == false && mounted) {
      toast(context, 'Wrong PIN');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            backgroundColor: brand,
            foregroundColor: Colors.white,
            title: Text(app.settings['shop_name'] ?? 'Nilvai'),
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _toggleOwner,
                icon: Icon(app.owner ? Icons.lock_open : Icons.lock),
                label: Text(app.owner ? 'Owner' : ''),
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'More',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoreScreen())),
              ),
            ],
          ),
          body: SafeArea(child: IndexedStack(index: _tab, children: _pages)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search), label: 'ధర Price'),
              NavigationDestination(icon: Icon(Icons.receipt_long), label: 'అమ్మకం Sale'),
              NavigationDestination(icon: Icon(Icons.photo_camera), label: 'రసీదు Bills'),
              NavigationDestination(icon: Icon(Icons.inventory_2), label: 'సరుకు Stock'),
              NavigationDestination(icon: Icon(Icons.insights), label: 'లెక్క Report'),
            ],
          ),
        ),
      );
}
