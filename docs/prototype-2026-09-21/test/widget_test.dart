import 'package:flutter_test/flutter_test.dart';

import 'package:pacta/main.dart';

void main() {
  testWidgets('Pacta ana ekranı anlaşmaları gösterir', (tester) async {
    await tester.pumpWidget(const PactaApp());
    await tester.pumpAndSettle();

    expect(find.text('Pacta'), findsOneWidget);
    expect(find.text('Eylül ev harcamaları'), findsOneWidget);
  });
}
