/// Response of GET /patients/{file_number} (docs/api.md).
class Patient {
  final int id;
  final String fileNumber;
  final String name;
  final int age; // calculated by the server from date_of_birth
  final String room;
  final String diagnosisCode;

  const Patient({
    required this.id,
    required this.fileNumber,
    required this.name,
    required this.age,
    required this.room,
    required this.diagnosisCode,
  });

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'] as int,
        fileNumber: json['file_number'] as String,
        name: json['name'] as String,
        age: json['age'] as int,
        room: json['room'] as String,
        diagnosisCode: json['diagnosis_code'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'file_number': fileNumber,
        'name': name,
        'age': age,
        'room': room,
        'diagnosis_code': diagnosisCode,
      };
}
