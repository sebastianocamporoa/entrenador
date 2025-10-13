import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:entrenador/main.dart'; // ajusta el nombre del paquete si difiere

void main() {
  testWidgets('smoke test: app arranca', (tester) async {
    await tester.pumpWidget(const EntrenadorApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
