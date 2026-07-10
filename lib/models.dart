import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'student' or 'mentor'
  final List<String> mentorIds; // Support for multiple mentors
  final String? company;
  final String? location;
  final String? specialization;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.mentorIds = const [],
    this.company,
    this.location,
    this.specialization,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      mentorIds: List<String>.from(map['mentorIds'] ?? []),
      company: map['company'],
      location: map['location'],
      specialization: map['specialization'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'mentorIds': mentorIds,
      'company': company,
      'location': location,
      'specialization': specialization,
    };
  }
}

class LogModel {
  final String id;
  final String studentId;
  final DateTime date;
  final String tasksDone;
  final double hoursWorked;
  final String learnings;
  final int moodRating;
  final String mentorNotes;

  LogModel({
    required this.id,
    required this.studentId,
    required this.date,
    required this.tasksDone,
    required this.hoursWorked,
    required this.learnings,
    required this.moodRating,
    required this.mentorNotes,
  });

  factory LogModel.fromMap(Map<String, dynamic> map, String id) {
    return LogModel(
      id: id,
      studentId: map['studentId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      tasksDone: map['tasksDone'] ?? '',
      hoursWorked: (map['hoursWorked'] as num).toDouble(),
      learnings: map['learnings'] ?? '',
      moodRating: map['moodRating'] ?? 3,
      mentorNotes: map['mentorNotes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'date': Timestamp.fromDate(date),
      'tasksDone': tasksDone,
      'hoursWorked': hoursWorked,
      'learnings': learnings,
      'moodRating': moodRating,
      'mentorNotes': mentorNotes,
    };
  }
}

class TaskModel {
  final String id;
  final String studentId;
  final String mentorId;
  final String title;
  final String description;
  final DateTime dueDate;
  final String status; // 'pending' or 'completed'
  final String? submissionUrl;
  final String? submissionType; // 'file', 'image', 'link'

  TaskModel({
    required this.id,
    required this.studentId,
    required this.mentorId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.submissionUrl,
    this.submissionType,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      studentId: map['studentId'] ?? '',
      mentorId: map['mentorId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      submissionUrl: map['submissionUrl'],
      submissionType: map['submissionType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'mentorId': mentorId,
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'submissionUrl': submissionUrl,
      'submissionType': submissionType,
    };
  }
}
