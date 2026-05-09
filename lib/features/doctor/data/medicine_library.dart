class Medicine {
  final String category;
  final String name;
  final String defaultDosage;
  final String type;
  final String manufacturer;
  final String defaultFrequency;

  const Medicine({
    required this.category,
    required this.name,
    required this.defaultDosage,
    required this.type,
    required this.manufacturer,
    required this.defaultFrequency,
  });

  Map<String, dynamic> toFormData() => {
        'name': name,
        'dosage': defaultDosage,
        'frequency': defaultFrequency,
      };
}

const List<Medicine> medicineLibrary = [
  // ── Diabetes ──────────────────────────────────────────────────────────────
  Medicine(
    category: 'Diabetes',
    name: 'Metformin',
    defaultDosage: '500 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Twice daily',
  ),
  Medicine(
    category: 'Diabetes',
    name: 'Insulin Glargine',
    defaultDosage: '10 units',
    type: 'Injection',
    manufacturer: 'Sanofi',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Diabetes',
    name: 'Glipizide',
    defaultDosage: '5 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),

  // ── Blood Pressure ────────────────────────────────────────────────────────
  Medicine(
    category: 'Blood Pressure',
    name: 'Amlodipine',
    defaultDosage: '5 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Blood Pressure',
    name: 'Lisinopril',
    defaultDosage: '10 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Blood Pressure',
    name: 'Metoprolol',
    defaultDosage: '50 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Twice daily',
  ),

  // ── Vitamins ──────────────────────────────────────────────────────────────
  Medicine(
    category: 'Vitamins',
    name: 'Vitamin D3',
    defaultDosage: '1000 IU',
    type: 'Capsule',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Vitamins',
    name: 'Vitamin B12',
    defaultDosage: '500 mcg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Vitamins',
    name: 'Omega-3 Fish Oil',
    defaultDosage: '1000 mg',
    type: 'Capsule',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),

  // ── Heart Condition ───────────────────────────────────────────────────────
  Medicine(
    category: 'Heart Condition',
    name: 'Aspirin',
    defaultDosage: '75 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Heart Condition',
    name: 'Atorvastatin',
    defaultDosage: '20 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Heart Condition',
    name: 'Digoxin',
    defaultDosage: '0.25 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),

  // ── Pain Relief ───────────────────────────────────────────────────────────
  Medicine(
    category: 'Pain Relief',
    name: 'Paracetamol',
    defaultDosage: '500 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Three times daily',
  ),
  Medicine(
    category: 'Pain Relief',
    name: 'Ibuprofen',
    defaultDosage: '400 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Three times daily',
  ),
  Medicine(
    category: 'Pain Relief',
    name: 'Codeine',
    defaultDosage: '30 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'As needed',
  ),

  // ── Cholesterol ───────────────────────────────────────────────────────────
  Medicine(
    category: 'Cholesterol',
    name: 'Simvastatin',
    defaultDosage: '40 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Cholesterol',
    name: 'Rosuvastatin',
    defaultDosage: '10 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Cholesterol',
    name: 'Fenofibrate',
    defaultDosage: '145 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),

  // ── Thyroid ───────────────────────────────────────────────────────────────
  Medicine(
    category: 'Thyroid',
    name: 'Levothyroxine',
    defaultDosage: '50 mcg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Thyroid',
    name: 'Carbimazole',
    defaultDosage: '5 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Three times daily',
  ),
  Medicine(
    category: 'Thyroid',
    name: 'Propylthiouracil',
    defaultDosage: '50 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Three times daily',
  ),

  // ── Antibiotics ───────────────────────────────────────────────────────────
  Medicine(
    category: 'Antibiotics',
    name: 'Amoxicillin',
    defaultDosage: '500 mg',
    type: 'Capsule',
    manufacturer: 'Generic',
    defaultFrequency: 'Three times daily',
  ),
  Medicine(
    category: 'Antibiotics',
    name: 'Azithromycin',
    defaultDosage: '250 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Once daily',
  ),
  Medicine(
    category: 'Antibiotics',
    name: 'Ciprofloxacin',
    defaultDosage: '500 mg',
    type: 'Tablet',
    manufacturer: 'Generic',
    defaultFrequency: 'Twice daily',
  ),
];
