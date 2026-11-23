// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:crop_disease_app/main.dart';

void main() {
  testWidgets('home screen shows the crop selection and image actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CropDiseaseApp());

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('Select Crop'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Corn'), findsOneWidget);
    expect(find.text('Potato'), findsOneWidget);
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('Open Camera'), findsOneWidget);
    expect(find.text('Upload Image'), findsOneWidget);
  });
}
