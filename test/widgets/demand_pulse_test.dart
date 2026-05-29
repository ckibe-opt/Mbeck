import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mbeck_business/widgets/demand_pulse_card.dart';
import 'package:mbeck_business/services/auth_service.dart';
import 'package:mbeck_business/services/analytics_service.dart';
import 'package:mbeck_shared/mbeck_shared.dart';

// Mock AuthService and AnalyticsService would be ideal here,
// but for a quick widget test, we can rely on the fact that
// `AuthService.getCurrentShop()` returns null or cached data.
// However, since they are static methods, they are hard to mock without
// a wrapper or a mocking library that supports statics.

// Strategy: We will just verify that the card builds without crashing.
// For true logic verification in widget tests, we'd need dependency injection.
// Given the current architecture uses static service calls, we'll write a 
// unit test for the Shop logic (already done) and a basic smoke test here.

void main() {
  testWidgets('DemandPulseCard builds successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DemandPulseCard(),
        ),
      ),
    );

    // It starts with loading state or empty
    expect(find.byType(DemandPulseCard), findsOneWidget);
  });
}
