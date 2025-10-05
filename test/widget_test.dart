// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lis_parser/main.dart';

void main() {
  group('LIS Parser App Tests', () {
    testWidgets('App should start with home screen', (
      WidgetTester tester,
    ) async {
      // Build the app and trigger a frame
      await tester.pumpWidget(const MyApp());

      // Verify that the home screen is displayed
      expect(find.text('LIS File Parser'), findsAtLeastNWidgets(1));
      expect(find.text('Open LIS File'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets('Home screen should show description', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      // Check for description text
      expect(find.textContaining('Log Information Standard'), findsOneWidget);
      expect(
        find.textContaining('Russian LIS and Halliburton NTI'),
        findsOneWidget,
      );
    });

    testWidgets('Open file button should be present and tappable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      // Find the open file button by text
      final openButton = find.text('Open LIS File');
      expect(openButton, findsOneWidget);

      // Try to tap the button (it might show file picker dialog or error)
      await tester.tap(openButton);
      await tester.pump();

      // The test should not crash when tapping the button
    });
  });
}
