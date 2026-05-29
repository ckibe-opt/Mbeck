import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../lib/screens/shop_shell_screen.dart';
import '../lib/screens/relocation/relocation_booking_screen.dart';
import '../lib/screens/explore/explore_screen.dart';
import '../lib/screens/showcase/shop_showcase_screen.dart';
import '../lib/providers/shop_session_provider.dart';

void main() {
  testWidgets('ShopShellScreen renders and shows Connecting state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ShopSessionProvider()),
        ],
        child: const MaterialApp(
          home: ShopShellScreen(),
        ),
      ),
    );

    // Initial state is connecting
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Connecting to Keja Oasis...'), findsOneWidget);
  });

  testWidgets('RelocationBookingScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ShopSessionProvider()),
        ],
        child: const MaterialApp(
          home: RelocationBookingScreen(),
        ),
      ),
    );

    expect(find.text('Book a Mover'), findsOneWidget);
    expect(find.text('Tuko Mboka Relocations'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('ExploreScreen renders and displays search bar and filters', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ShopSessionProvider()),
        ],
        child: const MaterialApp(
          home: ExploreScreen(),
        ),
      ),
    );

    // Verify app name and top elements
    expect(find.text('MbeckGo'), findsOneWidget);
    expect(find.text('Nairobi'), findsOneWidget);

    // Verify search bar hint
    expect(find.text('Search products, dining, stays...'), findsOneWidget);

    // Verify key filter tabs
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Stores'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Housing'), findsOneWidget);
  });

  testWidgets('ShopShowcaseScreen renders and lists modules', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ShopSessionProvider()),
        ],
        child: const MaterialApp(
          home: ShopShowcaseScreen(
            shopId: 'shop_test_456',
            shopName: 'Keja Oasis Hub',
            coverUrl: 'https://images.unsplash.com/photo-1587061949409-02df41d5e562?q=80&w=1000&auto=format&fit=crop',
            displayTag: 'LODGE & BISTRO',
            location: 'Nairobi',
            rating: 4.9,
            modules: ['lodging', 'restaurant', 'entertainment', 'retail'],
            isVerified: true,
          ),
        ),
      ),
    );

    // Verify title and tags
    expect(find.text('Keja Oasis Hub'), findsOneWidget);
    expect(find.text('Tom Mboya St, Nairobi'), findsOneWidget);

    // Verify actions
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);

    // Verify experience
    expect(find.text('The Experience'), findsOneWidget);

    // Verify modules
    expect(find.text('Book Rooms'), findsOneWidget);
    expect(find.text('Dine with Us'), findsOneWidget);
    expect(find.text('Buy Tickets'), findsOneWidget);
    expect(find.text('Shop Products'), findsOneWidget);
  });
}

