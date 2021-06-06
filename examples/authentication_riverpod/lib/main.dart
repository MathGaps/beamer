import 'package:authentication_riverpod/beamer_locations.dart';
import 'package:authentication_riverpod/providers/auth_notifier.dart';
import 'package:authentication_riverpod/providers/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends HookWidget {
  final routerDelegate = BeamerDelegate(
    guards: [
      /// if the user is authenticated
      /// else send them to /login
      BeamGuard(
          pathBlueprints: ['/home'],
          check: (context, state) =>
              context.read(authProvider).status == AuthStatus.authenticated,
          beamToNamed: '/login'),

      /// if the user is anything other than authenticated
      /// else send them to /home
      BeamGuard(
          pathBlueprints: ['/login'],
          check: (context, state) =>
              context.read(authProvider).status != AuthStatus.authenticated,
          beamToNamed: '/home'),
    ],
    initialPath: '/login',
    locationBuilder: (state) => BeamerLocations(state),
  );

  @override
  Widget build(BuildContext context) {
    /// this is required so the `BeamGuard` checks can be rechecked on
    /// auth state changes
    useProvider(authProvider);

    return BeamerProvider(
      routerDelegate: routerDelegate,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routeInformationParser: BeamerParser(),
        routerDelegate: routerDelegate,
      ),
    );
  }
}
