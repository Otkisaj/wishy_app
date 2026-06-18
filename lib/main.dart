import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: WishyApp()));
}

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final wishesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('wishes')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
    final data = doc.data();
    data['docId'] = doc.id;
    return data;
  }).toList());
});

final currencyProvider = FutureProvider<double>((ref) async {
  try {
    final dio = Dio();
    (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
    final response = await dio.get('https://api.nbp.pl/api/exchangerates/rates/a/usd/?format=json');
    return (response.data['rates'][0]['mid'] as num).toDouble();
  } catch (e) {
    return 0.0;
  }
});

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthGateway()),
    GoRoute(path: '/add', builder: (context, state) => const AddWishScreen()),
    GoRoute(
      path: '/edit',
      builder: (context, state) {
        final wish = state.extra as Map<String, dynamic>;
        return EditWishScreen(wish: wish);
      },
    ),
  ],
);

class WishyApp extends ConsumerWidget {
  const WishyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: themeMode,
      theme: FlexThemeData.light(
        scheme: FlexScheme.mango,
        useMaterial3: true,
        subThemesData: const FlexSubThemesData(cardRadius: 16),
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.mango,
        useMaterial3: true,
        subThemesData: const FlexSubThemesData(cardRadius: 16),
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      ),
    );
  }
}

class AuthGateway extends ConsumerWidget {
  const AuthGateway({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars_rounded, size: 80, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Wishy', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Text('Twoja lista marzeń', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: () => FirebaseAuth.instance.signInAnonymously(),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Zacznij teraz'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishesAsync = ref.watch(wishesStreamProvider);
    final currencyAsync = ref.watch(currencyProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Marzenia'),
        actions: [
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
              themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: Column(
        children: [
          currencyAsync.when(
            data: (rate) => Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.attach_money, size: 18),
                  Text('API Kurs NBP: 1 USD = $rate PLN', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox(),
          ),
          Expanded(
            child: wishesAsync.when(
              data: (wishes) => wishes.isEmpty
                  ? const Center(child: Text('Lista jest pusta'))
                  : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: wishes.length,
                itemBuilder: (context, index) {
                  final wish = wishes[index];
                  DateTime? date;
                  if (wish['date'] != null) date = DateTime.parse(wish['date']);
                  return Card(
                    child: ListTile(
                      onTap: () => context.push('/edit', extra: wish),
                      leading: const CircleAvatar(child: Icon(Icons.card_giftcard)),
                      title: Text(wish['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${wish['price']} PLN ${date != null ? "| Do: " + DateFormat('dd.MM.yyyy').format(date) : ""}'),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
      ),
    );
  }
}

class AddWishScreen extends ConsumerStatefulWidget {
  const AddWishScreen({super.key});
  @override
  _AddWishScreenState createState() => _AddWishScreenState();
}

class _AddWishScreenState extends ConsumerState<AddWishScreen> {
  final _t = TextEditingController();
  final _p = TextEditingController();
  DateTime? _d;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nowe marzenie')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _t, decoration: const InputDecoration(labelText: 'Co to za marzenie?', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cena (PLN)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceVariant,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.calendar_today),
              title: Text(_d == null ? 'Kiedy?' : DateFormat('dd.MM.yyyy').format(_d!)),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (date != null) setState(() => _d = date);
              },
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && _t.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('wishes').add({
                    'title': _t.text,
                    'price': _p.text,
                    'date': _d?.toIso8601String(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  context.pop();
                }
              },
              child: const Text('Zapisz marzenie'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditWishScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> wish;
  const EditWishScreen({super.key, required this.wish});
  @override
  _EditWishScreenState createState() => _EditWishScreenState();
}

class _EditWishScreenState extends ConsumerState<EditWishScreen> {
  late TextEditingController _t;
  late TextEditingController _p;
  DateTime? _d;

  @override
  void initState() {
    super.initState();
    _t = TextEditingController(text: widget.wish['title']);
    _p = TextEditingController(text: widget.wish['price']);
    if (widget.wish['date'] != null) _d = DateTime.parse(widget.wish['date']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edytuj marzenie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('wishes')
                  .doc(widget.wish['docId'])
                  .delete();
              context.pop();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _t, decoration: const InputDecoration(labelText: 'Nazwa', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cena (PLN)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceVariant,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.calendar_today),
              title: Text(_d == null ? 'Kiedy?' : DateFormat('dd.MM.yyyy').format(_d!)),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: _d ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (date != null) setState(() => _d = date);
              },
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && _t.text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('wishes')
                      .doc(widget.wish['docId'])
                      .update({
                    'title': _t.text,
                    'price': _p.text,
                    'date': _d?.toIso8601String(),
                  });
                  context.pop();
                }
              },
              child: const Text('Zaktualizuj marzenie'),
            ),
          ],
        ),
      ),
    );
  }
}