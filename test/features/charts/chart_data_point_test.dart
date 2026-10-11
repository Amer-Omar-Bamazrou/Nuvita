import 'package:chronic_care_app/features/charts/models/chart_data_point.dart';
import 'package:flutter_test/flutter_test.dart';

ChartDataPoint _point({String? context, String? note}) => ChartDataPoint(
      date: DateTime(2026, 6, 1),
      value: 110,
      status: 'Normal',
      context: context,
      note: note,
    );

void main() {
  test('tooltip detail joins the glucose context and the chip', () {
    expect(_point(context: 'Fasting', note: 'Just woke up').detail,
        'Fasting · Just woke up');
  });

  test('either part on its own', () {
    expect(_point(context: 'After meal').detail, 'After meal');
    expect(_point(note: 'Resting').detail, 'Resting');
  });

  test('nothing to show gives null', () {
    expect(_point().detail, isNull);
    expect(_point(note: '').detail, isNull);
  });
}
