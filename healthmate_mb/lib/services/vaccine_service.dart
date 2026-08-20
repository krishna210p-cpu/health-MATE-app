class VaccineService {
  /// Returns a list of vaccine recommendations for given age and gender.
  static List<Map<String, String>> recommendations({required int age, required String gender}) {
    final list = <Map<String,String>>[];
    if (age < 1) {
      list.add({'name':'BCG', 'age':'At birth', 'status':'⚠ due'});
      list.add({'name':'OPV/IPV', 'age':'Birth, 6, 10, 14 weeks', 'status':'⚠ due'});
      list.add({'name':'DPT', 'age':'6,10,14 weeks', 'status':'⚠ due'});
    } else if (age < 5) {
      list.add({'name':'Diphtheria/Tetanus/Pertussis (DPT)', 'age':'Booster as per schedule', 'status':'✔ taken'});
    }

    if (age >= 5 && age < 19) {
      list.add({'name':'Tetanus booster', 'age':'Every 10 years', 'status':'⚠ due'});
    }

    if (age >= 2) list.add({'name':'Typhoid', 'age':'From 2 years (as per state program)', 'status':'⚠ due'});

    if (gender == 'female' && age >= 9 && age <= 26) {
      list.add({'name':'HPV', 'age':'9–26 years', 'status':'⚠ due'});
    }

    if (age >= 60) list.add({'name':'Influenza (annual)', 'age':'Annually (60+)', 'status':'⚠ due'});

    if (list.isEmpty) list.add({'name':'No specific vaccines found', 'age':'—', 'status':'✔ up-to-date'});
    return list;
  }
}
