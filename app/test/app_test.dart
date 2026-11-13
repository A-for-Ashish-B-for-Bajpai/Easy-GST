import 'package:easy_gst/app.dart';
import 'package:easy_gst/data/demo_repository.dart';
import 'package:easy_gst/data/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsStore> _settings({bool seenNotice = true}) async {
  SharedPreferences.setMockInitialValues({'seenNotice': seenNotice});
  return SettingsStore.load();
}

void main() {
  testWidgets('first launch shows the not-affiliated notice once', (tester) async {
    final settings = await _settings(seenNotice: false);
    await tester.pumpWidget(EasyGstApp(repo: DemoRepository(), settings: settings));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Easy-GST'), findsOneWidget);
    expect(find.textContaining('not made by, or connected to'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(settings.seenNotice, isTrue);
  });

  testWidgets('feed shows updates and filters by topic', (tester) async {
    await tester.pumpWidget(EasyGstApp(repo: DemoRepository(), settings: await _settings()));
    await tester.pumpAndSettle();
    expect(find.text('Preview mode: sample updates only. Connect Firebase to get live updates and Gemini.'), findsOneWidget);
    expect(find.textContaining('57th Meeting'), findsOneWidget);
    expect(find.textContaining('Lithium-Ion'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'GST rates'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lithium-Ion'), findsNothing);
    expect(find.textContaining('55th GST Council'), findsOneWidget);
  });

  testWidgets('saving an update puts it on the Saved tab', (tester) async {
    // A phone-sized screen, so the whole detail page fits.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final settings = await _settings();
    await tester.pumpWidget(EasyGstApp(repo: DemoRepository(), settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('57th Meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Open official PDF'), findsOneWidget);
    expect(find.textContaining('summary is not ready yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(settings.isSaved('demo-gstc-pr-57'), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('57th Meeting'), findsWidgets);
  });

  testWidgets('chat explains that it needs the backend in preview mode', (tester) async {
    await tester.pumpWidget(EasyGstApp(repo: DemoRepository(), settings: await _settings()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'What is GSTR-3B?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.textContaining('turns on once the app is connected'), findsOneWidget);
  });
}
