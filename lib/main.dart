import 'package:flutter/material.dart';
import 'services/app_store.dart';
import 'services/app_scope.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/mfa_screen.dart';

void main() => runApp(const FoodieitApp());

class FoodieitApp extends StatefulWidget {
  const FoodieitApp({super.key});
  @override
  State<FoodieitApp> createState() => _FoodieitAppState();
}

class _FoodieitAppState extends State<FoodieitApp> {
  final store = AppStore();

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        store: store,
        child: MaterialApp(
          title: 'Foodieit',
          debugShowCheckedModeBanner: false,
          theme: FoodieitTheme.light,
          home: Builder(
            builder: (context) {
              final s = AppScope.of(context);
              final u = s.current;
              if (u != null) return HomeShell(key: ValueKey(u.id));
              // If MFA verification is pending, show MFA screen
              if (s.mfaPendingUser != null) return const MfaVerifyScreen();
              return const AuthScreen();
            },
          ),
        ),
      );
}
