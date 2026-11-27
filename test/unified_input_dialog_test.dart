import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalorientracker_flutter/ui/widgets/dialogs/unified_input_dialog.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    String initialName = '',
    String initialDescription = '',
    VoidCallback? onClear,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedInputDialog(
            initialName: initialName,
            initialDescription: initialDescription,
            onClear: onClear,
            onSubmit: (name, description) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openDialog(
    WidgetTester tester, {
    void Function(String name, String description)? onSubmit,
    void Function(String name, String description)? onDraftChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => UnifiedInputDialog(
                    onSubmit: onSubmit ?? (name, description) {},
                    onDraftChanged: onDraftChanged,
                  ),
                ),
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the prefilled draft text', (tester) async {
    await pumpDialog(
      tester,
      initialName: 'Reis 200 g',
      initialDescription: 'Mensa',
    );

    expect(find.text('Reis 200 g'), findsOneWidget);
    expect(find.text('Mensa'), findsOneWidget);
  });

  testWidgets('Leeren clears both fields and calls onClear', (tester) async {
    var cleared = false;
    await pumpDialog(
      tester,
      initialName: 'Reis 200 g',
      initialDescription: 'Mensa',
      onClear: () => cleared = true,
    );

    expect(find.text('Leeren'), findsOneWidget);
    await tester.tap(find.text('Leeren'));
    await tester.pump();

    expect(cleared, isTrue);
    expect(find.text('Reis 200 g'), findsNothing);
    expect(find.text('Mensa'), findsNothing);
    expect(find.text('Leeren'), findsNothing);
  });

  testWidgets('Abbrechen keeps the draft', (tester) async {
    String? draftName;
    String? draftDescription;
    await openDialog(
      tester,
      onDraftChanged: (name, description) {
        draftName = name;
        draftDescription = description;
      },
    );

    await tester.enterText(find.byType(TextField).first, 'Reis');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(draftName, 'Reis');
    expect(draftDescription, '');
  });

  testWidgets('Hinzufügen does not write the draft back', (tester) async {
    String? submittedName;
    var draftCalls = 0;
    await openDialog(
      tester,
      onSubmit: (name, description) => submittedName = name,
      onDraftChanged: (name, description) => draftCalls++,
    );

    await tester.enterText(find.byType(TextField).first, 'Reis');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();

    expect(submittedName, 'Reis');
    expect(draftCalls, 0);
  });
}
