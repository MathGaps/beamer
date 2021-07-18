import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_locations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final delegate = BeamerDelegate(
    locationBuilder: (routeInformation) {
      if (routeInformation.location?.contains('l1') ?? false) {
        return Location1(routeInformation);
      }
      if (routeInformation.location?.contains('l2') ?? false) {
        return Location2(routeInformation);
      }
      if (CustomStateLocation()
          .canHandle(Uri.parse(routeInformation.location ?? '/'))) {
        return CustomStateLocation(routeInformation);
      }
      return NotFound(path: routeInformation.location ?? '/');
    },
  );
  delegate.setNewRoutePath(const RouteInformation(location: '/l1'));

  group('initialization & beaming', () {
    test('initialLocation is set', () {
      expect(delegate.currentBeamLocation, isA<Location1>());
    });

    test('beamTo changes locations', () {
      delegate.beamTo(Location2(const RouteInformation(location: '/l2')));
      expect(delegate.currentBeamLocation, isA<Location2>());
    });

    test('beamToNamed updates locations with correct parameters', () {
      delegate.beamToNamed('/l2/2?q=t', data: {'x': 'y'});
      final location = delegate.currentBeamLocation;
      expect(location, isA<Location2>());
      expect(
          (location.state as BeamState).pathParameters.containsKey('id'), true);
      expect((location.state as BeamState).pathParameters['id'], '2');
      expect(
          (location.state as BeamState).queryParameters.containsKey('q'), true);
      expect((location.state as BeamState).queryParameters['q'], 't');
      expect((location.state as BeamState).data, {'x': 'y'});
    });

    test(
        'beaming to the same location type will not add it to history but will update current location',
        () {
      final historyLength = delegate.beamLocationHistory.length;
      delegate.beamToNamed('/l2/2?q=t&r=s', data: {'x': 'z'});
      final location = delegate.currentBeamLocation;
      expect(delegate.beamLocationHistory.length, historyLength);
      expect(
          (location.state as BeamState).pathParameters.containsKey('id'), true);
      expect((location.state as BeamState).pathParameters['id'], '2');
      expect(
          (location.state as BeamState).queryParameters.containsKey('q'), true);
      expect((location.state as BeamState).queryParameters['q'], 't');
      expect(
          (location.state as BeamState).queryParameters.containsKey('r'), true);
      expect((location.state as BeamState).queryParameters['r'], 's');
      expect((location.state as BeamState).data, {'x': 'z'});
    });

    test(
        'popBeamLocation leads to previous location and all helpers are correct',
        () {
      expect(delegate.canPopBeamLocation, true);
      expect(delegate.popBeamLocation(), true);
      expect(delegate.currentBeamLocation, isA<Location1>());

      expect(delegate.canPopBeamLocation, false);
      expect(delegate.popBeamLocation(), false);
      expect(delegate.currentBeamLocation, isA<Location1>());
    });

    test('duplicate locations are removed from history', () {
      expect(delegate.beamLocationHistory.length, 1);
      expect(delegate.beamLocationHistory[0], isA<Location1>());
      delegate.beamToNamed('/l2');
      expect(delegate.beamLocationHistory.length, 2);
      expect(delegate.beamLocationHistory[0], isA<Location1>());
      delegate.beamToNamed('/l1');
      expect(delegate.beamLocationHistory.length, 2);
      expect(delegate.beamLocationHistory[0], isA<Location2>());
    });

    test(
        'beamTo replaceCurrent removes previous history state before appending new',
        () {
      expect(delegate.beamLocationHistory.length, 2);
      expect(delegate.beamLocationHistory[0], isA<Location2>());
      expect(delegate.currentBeamLocation, isA<Location1>());
      delegate.beamTo(
        Location2(const RouteInformation(location: '/l2')),
        replaceCurrent: true,
      );
      expect(delegate.beamLocationHistory.length, 1);
      expect(delegate.currentBeamLocation, isA<Location2>());
    });
  });

  testWidgets('stacked beam takes just last page for currentPages',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationParser: BeamerParser(),
        routerDelegate: delegate,
      ),
    );
    delegate.beamToNamed('/l1/one', stacked: false);
    await tester.pump();
    expect(delegate.currentPages.length, 1);
  });

  test('custom state can be updated', () {
    delegate.beamToNamed('/custom/test');
    expect(
        (delegate.currentBeamLocation as CustomStateLocation).state.customVar,
        'test');
    (delegate.currentBeamLocation as CustomStateLocation)
        .update((state) => CustomState(customVar: 'test-ok'));
    expect(
        (delegate.currentBeamLocation as CustomStateLocation).state.customVar,
        'test-ok');
  });

  test('beamTo works without setting the BeamState explicitly', () {
    delegate.beamTo(NoStateLocation());
    expect(delegate.currentBeamLocation.state, isNotNull);
    delegate.beamBack();
  });

  test('clearHistory removes all but last entry (current location)', () {
    final currentBeamLocation = delegate.currentBeamLocation;
    expect(delegate.beamLocationHistory.length, greaterThan(1));
    delegate.clearBeamLocationHistory();
    expect(delegate.beamLocationHistory.length, equals(1));
    expect(delegate.currentBeamLocation, currentBeamLocation);
  });

  testWidgets('popToNamed forces pop to specified location', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationParser: BeamerParser(),
        routerDelegate: delegate,
      ),
    );
    delegate.beamToNamed('/l1/one', popToNamed: '/l2');
    await tester.pump();
    final historyLength = delegate.beamLocationHistory.length;
    expect(delegate.currentBeamLocation, isA<Location1>());
    await delegate.popRoute();
    await tester.pump();
    expect(delegate.currentBeamLocation, isA<Location2>());
    expect(delegate.beamLocationHistory.length, equals(historyLength));
  });

  test('beamBack leads to previous beam state and all helpers are correct', () {
    delegate.clearRouteHistory();
    expect(delegate.routeHistory.length, 1);
    expect(delegate.currentBeamLocation, isA<Location2>());

    delegate.beamToNamed('/l1');
    delegate.beamToNamed('/l2');

    expect(delegate.routeHistory.length, 3);
    expect(delegate.currentBeamLocation, isA<Location2>());
    expect(delegate.canBeamBack, true);

    delegate.beamToNamed('/l1/one');
    delegate.beamToNamed('/l1/two');
    expect(delegate.routeHistory.length, 5);
    expect(delegate.currentBeamLocation, isA<Location1>());

    delegate.beamToNamed('/l1/two');
    expect(delegate.routeHistory.length, 5);
    expect(delegate.currentBeamLocation, isA<Location1>());

    expect(delegate.beamBack(), true);
    expect(delegate.currentBeamLocation, isA<Location1>());
    expect((delegate.currentBeamLocation.state as BeamState).uri.path,
        equals('/l1/one'));
    expect(delegate.routeHistory.length, 4);

    expect(delegate.beamBack(), true);
    expect(delegate.currentBeamLocation, isA<Location2>());
    expect(delegate.routeHistory.length, 3);
  });

  test('beamBack keeps data and can override it', () {
    delegate.clearRouteHistory();
    expect(delegate.routeHistory.length, 1);
    expect(delegate.currentBeamLocation, isA<Location2>());

    delegate.beamToNamed('/l1', data: {'x': 'y'});
    delegate.beamToNamed('/l2');

    expect(delegate.beamBack(), true);
    expect(delegate.configuration.location,
        delegate.currentBeamLocation.state.routeInformation.location);
    expect(delegate.configuration.location, '/l1');
    expect((delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});

    delegate.beamToNamed('/l2');

    expect(delegate.beamBack(), true);
    expect(delegate.configuration.location,
        delegate.currentBeamLocation.state.routeInformation.location);
    expect(delegate.configuration.location, '/l1');
    expect((delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});

    delegate.beamToNamed('/l2');

    expect(delegate.beamBack(data: {'xx': 'yy'}), true);
    expect(delegate.configuration.location,
        delegate.currentBeamLocation.state.routeInformation.location);
    expect(delegate.configuration.location, '/l1');
    expect(
        (delegate.currentBeamLocation.state as BeamState).data, {'xx': 'yy'});
  });

  testWidgets('popToNamed() beams correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationParser: BeamerParser(),
        routerDelegate: delegate,
      ),
    );
    delegate.popToNamed('/l1/one');
    await tester.pump();
    expect(delegate.currentBeamLocation, isA<Location1>());
  });

  testWidgets('notFoundRedirect works', (tester) async {
    final delegate = BeamerDelegate(
      locationBuilder: BeamerLocationBuilder(
        beamLocations: [
          Location1(),
          CustomStateLocation(),
        ],
      ),
      notFoundRedirect: Location1(const RouteInformation()),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationParser: BeamerParser(),
        routerDelegate: delegate,
      ),
    );
    delegate.beamToNamed('/xxx');
    await tester.pump();
    expect(delegate.currentBeamLocation, isA<Location1>());
    expect(delegate.configuration.location, '/');
  });

  testWidgets('notFoundRedirectNamed works', (tester) async {
    final delegate = BeamerDelegate(
      locationBuilder: BeamerLocationBuilder(
        beamLocations: [
          Location1(),
          CustomStateLocation(),
        ],
      ),
      notFoundRedirectNamed: '/',
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationParser: BeamerParser(),
        routerDelegate: delegate,
      ),
    );
    delegate.beamToNamed('/xxx');
    await tester.pump();
    expect(delegate.currentBeamLocation, isA<Location1>());
    expect(delegate.configuration.location, '/');
  });

  testWidgets("popping drawer doesn't change BeamState", (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final delegate = BeamerDelegate(
      locationBuilder: SimpleLocationBuilder(
        routes: {
          '/': (context, state) => Container(),
          '/test': (context, state) => Scaffold(
                key: scaffoldKey,
                drawer: const Drawer(),
                body: Container(),
              ),
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationParser: BeamerParser(),
        routerDelegate: delegate,
      ),
    );
    delegate.beamToNamed('/test');
    await tester.pump();
    expect(scaffoldKey.currentState?.isDrawerOpen, isFalse);
    expect(delegate.configuration.location, '/test');

    scaffoldKey.currentState?.openDrawer();
    await tester.pump();
    expect(scaffoldKey.currentState?.isDrawerOpen, isTrue);
    expect(delegate.configuration.location, '/test');

    delegate.navigatorKey.currentState?.pop();
    await tester.pump();
    expect(scaffoldKey.currentState?.isDrawerOpen, isFalse);
    expect(delegate.configuration.location, '/test');
  });

  group('Keeping data', () {
    final delegate = BeamerDelegate(
      locationBuilder: (routeInformation) {
        if (routeInformation.location?.contains('l1') ?? false) {
          return Location1(routeInformation);
        }
        if (routeInformation.location?.contains('l2') ?? false) {
          return Location2(routeInformation);
        }
        return NotFound(path: routeInformation.location ?? '/');
      },
    );
    testWidgets('pop keeps data', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationParser: BeamerParser(),
          routerDelegate: delegate,
        ),
      );
      delegate.beamToNamed('/l1/one', data: {'x': 'y'});
      await tester.pump();
      expect((delegate.currentBeamLocation.state as BeamState).uri.path,
          '/l1/one');
      expect(
          (delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});

      delegate.navigatorKey.currentState!.pop();
      await tester.pump();
      expect((delegate.currentBeamLocation.state as BeamState).uri.path, '/l1');
      expect(
          (delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});
    });

    test('single location keeps data', () {
      delegate.beamToNamed('/l1', data: {'x': 'y'});
      expect(
          (delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});

      delegate.beamToNamed('/l1/one');
      expect(
          (delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});
    });

    test('data is kept throughout locations if not overwritten', () {
      delegate.beamToNamed('/l1', data: {'x': 'y'});
      expect(
          (delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});

      delegate.beamToNamed('/l2');
      expect(
          (delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});
    });

    test('data is not kept if overwritten', () {
      delegate.beamToNamed('/l1', data: {'x': 'y'});
      expect(
          (delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});
      delegate.beamToNamed('/l1/one', data: {});
      expect((delegate.currentBeamLocation.state as BeamState).data, {});

      delegate.beamToNamed('/l1', data: {'x': 'y'});
      expect(
          (delegate.currentBeamLocation.state as BeamState).data, {'x': 'y'});
      delegate.beamToNamed('/l2', data: {});
      expect((delegate.currentBeamLocation.state as BeamState).data, {});
    });
  });

  group('Updating from parent', () {
    testWidgets('navigation on parent updates nested Beamer', (tester) async {
      final childDelegate = BeamerDelegate(
        locationBuilder: SimpleLocationBuilder(
          routes: {
            '/': (context, state) => Container(),
            '/test': (context, state) => Container(),
            '/test2': (context, state) => Container(),
          },
        ),
      );
      final rootDelegate = BeamerDelegate(
        locationBuilder: SimpleLocationBuilder(
          routes: {
            '*': (context, state) => BeamPage(
                  key: const ValueKey('always-the-same'),
                  child: Beamer(
                    routerDelegate: childDelegate,
                  ),
                ),
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationParser: BeamerParser(),
          routerDelegate: rootDelegate,
        ),
      );

      rootDelegate.beamToNamed('/test');
      await tester.pump();
      expect(rootDelegate.configuration.location, '/test');
      expect(childDelegate.configuration.location, '/test');
      expect(childDelegate.routeHistory.length, 1);

      rootDelegate.beamToNamed('/test2');
      await tester.pump();
      expect(rootDelegate.configuration.location, '/test2');
      expect(childDelegate.configuration.location, '/test2');
      expect(childDelegate.routeHistory.length, 2);
    });

    testWidgets("navigation on parent doesn't update nested Beamer",
        (tester) async {
      final childDelegate = BeamerDelegate(
        updateFromParent: false,
        locationBuilder: SimpleLocationBuilder(
          routes: {
            '/': (context, state) => Container(),
            '/test': (context, state) => Container(),
            '/test2': (context, state) => Container(),
          },
        ),
      );
      final rootDelegate = BeamerDelegate(
        locationBuilder: SimpleLocationBuilder(
          routes: {
            '*': (context, state) => BeamPage(
                  key: const ValueKey('always-the-same'),
                  child: Beamer(
                    routerDelegate: childDelegate,
                  ),
                ),
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationParser: BeamerParser(),
          routerDelegate: rootDelegate,
        ),
      );

      rootDelegate.beamToNamed('/test'); // initial will update
      await tester.pump();
      expect(rootDelegate.configuration.location, '/test');
      expect(childDelegate.configuration.location, '/test');
      expect(childDelegate.routeHistory.length, 1);

      rootDelegate.beamToNamed('/test2');
      await tester.pump();
      expect(rootDelegate.configuration.location, '/test2');
      expect(childDelegate.configuration.location, '/test');
      expect(childDelegate.routeHistory.length, 1);
    });
  });
}
