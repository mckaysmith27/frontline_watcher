class Job {
  final String id;
  final String confirmationNumber;
  final String teacher;
  final String title;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String duration;
  final String location;
  final bool isPast;

  Job({
    required this.id,
    required this.confirmationNumber,
    required this.teacher,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.location,
    this.isPast = false,
  });

  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: map['id'] ?? '',
      confirmationNumber: map['confirmationNumber'] ?? '',
      teacher: map['teacher'] ?? '',
      title: map['title'] ?? '',
      date: map['date'] is DateTime
          ? map['date']
          : DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      duration: map['duration'] ?? '',
      location: map['location'] ?? '',
      isPast: map['isPast'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'confirmationNumber': confirmationNumber,
      'teacher': teacher,
      'title': title,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
      'location': location,
      'isPast': isPast,
    };
  }
}




