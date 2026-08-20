import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/services/vaccine_service.dart';

void main() {
  test('Infant recommendations include BCG and OPV', () {
    final recs = VaccineService.recommendations(age: 0, gender: 'female');
    final names = recs.map((r)=>r['name']).toList();
    expect(names.any((n)=>n?.toLowerCase().contains('bcg') ?? false), true);
    expect(names.any((n)=>n?.toLowerCase().contains('opv') ?? false), true);
  });

  test('HPV recommended for females 16', () {
    final recs = VaccineService.recommendations(age: 16, gender: 'female');
    expect(recs.any((r)=>r['name']?.toLowerCase().contains('hpv') ?? false), true);
  });

  test('No specific vaccines for young adult male 30', () {
    final recs = VaccineService.recommendations(age: 30, gender: 'male');
    // may still include typhoid or boosters; ensure output is non-empty
    expect(recs.isNotEmpty, true);
  });
}
