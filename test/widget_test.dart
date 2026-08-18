import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_application/database_service.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabaseService extends DatabaseService {
  MockDatabaseService() : super.internal();

  @override
  Future<List<Map<String, dynamic>>> getCustomers() async {
    return [
      {
        'code': '001',
        'name': 'អតិថិជន តេស្តទី១',
        'old': 100.0,
        'old_value': 100.0,
        'new': 0.0,
        'new_value': '',
        'multiplier': 1.0,
        'area': 'តំបន់ ក',
        'pole': 'បង្គោល ខ',
        'box': 'ប្រអប់ គ',
        'date_checked': '2026-07-28',
      }
    ];
  }

  @override
  Future<Database> get database async {
    throw UnimplementedError('Database not available in testing');
  }
}

void main() {
  setUp(() {
    DatabaseService.instance = MockDatabaseService();
  });

  testWidgets('App loads and displays Mock Customer data', (WidgetTester tester) async {
    await tester.pumpWidget(const MeterReadingApp());
    await tester.pumpAndSettle();

    // Verify that the customer card name is found in the UI.
    expect(find.text('អតិថិជន តេស្តទី១'), findsOneWidget);
    expect(find.text('កូដ: 001'), findsOneWidget);
  });
}
