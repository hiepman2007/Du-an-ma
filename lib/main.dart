import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/study_account_screen.dart';
import 'services/study_account.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final account = await StudyAccount.initialize();
  runApp(ChangeNotifierProvider(create: (_) => AppState(account: account)..load(), child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Học Thông Minh',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<AppState>().refreshWorkspace();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final account = s.account;
    if (account == null) return const HomeScreen();
    return ListenableBuilder(listenable: account, builder: (_, _) =>
      account.recoveryPending ? const StudyAccountScreen() : const HomeScreen());
  }
}
