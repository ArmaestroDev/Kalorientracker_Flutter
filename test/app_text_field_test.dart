import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalorientracker_flutter/ui/widgets/app_text_field.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

void main() {
  const text = 'Skyr natur mit Beeren';

  Future<void> tapAt(WidgetTester tester, double dx) async {
    final rect = tester.getRect(find.byType(EditableText));
    await tester.tapAt(Offset(rect.left + dx, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<int> offsetOfNormalTap(WidgetTester tester, double dx) async {
    final controller = TextEditingController(text: text);
    await tester.pumpWidget(_host(TextField(controller: controller)));
    await tapAt(tester, 20);
    await tapAt(tester, dx);
    final offset = controller.selection.baseOffset;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    return offset;
  }

  Future<TextSelection> tapWithStuckShift(
    WidgetTester tester,
    Widget Function(TextEditingController) build,
  ) async {
    final controller = TextEditingController(text: text);
    await tester.pumpWidget(_host(build(controller)));
    await tapAt(tester, 20);
    await tester.pump(const Duration(seconds: 1));
    await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tapAt(tester, 150);
    await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    return controller.selection;
  }

  testWidgets('stuck Shift makes a plain TextField select text (the bug)', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final selection = await tapWithStuckShift(
      tester,
      (c) => TextField(controller: c),
    );
    expect(selection.isCollapsed, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('AppTextField puts the cursor at the tap even with stuck Shift', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final expected = await offsetOfNormalTap(tester, 150);
    final selection = await tapWithStuckShift(
      tester,
      (c) => AppTextField(controller: c),
    );
    expect(selection.isCollapsed, isTrue);
    expect(selection.baseOffset, expected);
    expect(expected, inExclusiveRange(0, text.length));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('AppTextField normal taps move the cursor', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = TextEditingController(text: text);
    await tester.pumpWidget(_host(AppTextField(controller: controller)));
    await tapAt(tester, 20);
    await tester.pump(const Duration(seconds: 1));
    await tapAt(tester, 60);
    final first = controller.selection;
    await tester.pump(const Duration(seconds: 1));
    await tapAt(tester, 150);
    expect(first.isCollapsed, isTrue);
    expect(controller.selection.isCollapsed, isTrue);
    expect(controller.selection.baseOffset, greaterThan(first.baseOffset));
    debugDefaultTargetPlatformOverride = null;
  });
}
