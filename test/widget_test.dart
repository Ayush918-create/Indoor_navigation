import 'package:flutter_test/flutter_test.dart';

import 'package:indoor_navigation_app/main.dart';

void main() {
  testWidgets('shows role based login screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Indoor Navigation'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Faculty'), findsOneWidget);
  });
}
