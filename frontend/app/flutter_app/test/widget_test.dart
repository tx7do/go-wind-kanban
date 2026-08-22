// 冒烟测试：应用根组件可构建。
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/app.dart' show KanbanApp;

void main() {
  testWidgets('KanbanApp boots', (WidgetTester tester) async {
    await tester.pumpWidget(const KanbanApp());
    await tester.pumpAndSettle();
    expect(find.byType(KanbanApp), findsOneWidget);
  });
}
