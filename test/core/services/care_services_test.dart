import 'package:chronic_care_app/core/services/care_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nothing selected means every service', () {
    expect(CareServices.effective(const []), CareServices.all);
  });

  test('the selection is kept as chosen', () {
    expect(
      CareServices.effective(const ['medications', 'appointments']),
      {CareServices.medications, CareServices.appointments},
    );
  });

  test('unknown ids are dropped', () {
    expect(CareServices.effective(const ['measurements', 'yoga']),
        {CareServices.measurements});
    expect(CareServices.effective(const ['yoga']), CareServices.all);
  });
}
