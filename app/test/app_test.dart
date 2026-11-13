import 'package:easy_gst/app.dart';
import 'package:easy_gst/data/settings_store.dart';
import 'package:easy_gst/models/tax_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_repository.dart';

Future<SettingsStore> _settings([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsStore.load();
}

void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('feed shows updates and filters by topic', (tester) async {
    await tester.pumpWidget(EasyGstApp(repo: DemoRepository(), settings: await _settings()));
    await tester.pumpAndSettle();
    expect(find.textContaining('57th Meeting'), findsOneWidget);
    expect(find.textContaining('Lithium-Ion'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'GST rates'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lithium-Ion'), findsNothing);
    expect(find.textContaining('55th GST Council'), findsOneWidget);
  });

  testWidgets('updates collected since the last visit are labelled New', (tester) async {
    final items = [
      TaxUpdate(id: 'a', authority: 'DGFT', category: 'Notification', topics: const [], title: 'Older one', pdfUrl: 'x', listingUrl: 'x', firstSeenOn: DateTime(2026, 11, 10)),
      TaxUpdate(id: 'b', authority: 'DGFT', category: 'Notification', topics: const [], title: 'Fresh one', pdfUrl: 'x', listingUrl: 'x', firstSeenOn: DateTime(2026, 11, 13)),
    ];
    await tester.pumpWidget(EasyGstApp(repo: DemoRepository(items: items), settings: await _settings({'lastVisit': '2026-11-12'})));
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget);
    expect(find.ancestor(of: find.text('New'), matching: find.byType(Card)), findsOneWidget);
    expect(find.descendant(of: find.ancestor(of: find.text('New'), matching: find.byType(Card)), matching: find.text('Fresh one')), findsOneWidget);
  });

  testWidgets('saving an update puts it on the Saved tab', (tester) async {
    _phoneScreen(tester);
    final settings = await _settings();
    await tester.pumpWidget(EasyGstApp(repo: DemoRepository(), settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('57th Meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Open official PDF'), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(settings.isSaved('demo-gstc-pr-57'), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('57th Meeting'), findsWidgets);
  });

  testWidgets('chat asks for a key, then uses the saved one', (tester) async {
    _phoneScreen(tester);
    final repo = DemoRepository()
      ..answer = AskResult(answer: 'GSTR-3B is due on the 20th.', confident: true, sources: [AskSource.fromUpdate(sampleUpdates[2])]);
    final settings = await _settings();
    await tester.pumpWidget(EasyGstApp(repo: repo, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'When is GSTR-3B due?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Add your free Gemini API key'), findsOneWidget);

    await settings.setGeminiKey('  test-key ');
    await tester.enterText(find.byType(TextField), 'When is GSTR-3B due?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(repo.lastKey, 'test-key');
    expect(find.text('GSTR-3B is due on the 20th.'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
  });

  testWidgets('settings saves the Gemini key', (tester) async {
    _phoneScreen(tester);
    final settings = await _settings();
    await tester.pumpWidget(EasyGstApp(repo: DemoRepository(), settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'API key'), 'abc123');
    await tester.tap(find.text('Save key'));
    await tester.pumpAndSettle();
    expect(settings.geminiKey, 'abc123');
  });
}
