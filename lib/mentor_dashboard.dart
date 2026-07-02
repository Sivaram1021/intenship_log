import 'package:flutter/material.dart';
import 'models.dart';
import 'firebase_service.dart';
import 'pdf_service.dart';

class MentorDashboard extends StatelessWidget {
  final UserModel mentor;
  const MentorDashboard({super.key, required this.mentor});

  @override
  Widget build(BuildContext context) {
    final FirebaseService ds = FirebaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Matrix Hub'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => ds.signOut())],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: ds.streamAssignedStudents(mentor.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Database Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final students = snapshot.data!;
          if (students.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SelectableText(
                  'Your Unique Supervisor Key Token is:\n${mentor.uid}\n\nProvide this key to your student interns so they can paste it when building their profile.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
              ),
            ));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.assignment_ind)),
                  title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(student.email),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentDetailInspectionScreen(student: student, mentorId: mentor.uid))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StudentDetailInspectionScreen extends StatelessWidget {
  final UserModel student;
  final String mentorId;
  const StudentDetailInspectionScreen({super.key, required this.student, required this.mentorId});

  @override
  Widget build(BuildContext context) {
    final FirebaseService ds = FirebaseService();

    return Scaffold(
      appBar: AppBar(title: Text('Evaluation: ${student.name}')),
      body: StreamBuilder<List<LogModel>>(
        stream: ds.streamStudentLogs(student.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddTaskDialog(context, ds),
                        icon: const Icon(Icons.add_task),
                        label: const Text('Assign Sprint Task'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: logs.isEmpty ? null : () {
                          PdfService.generateAndShareReport(
                            studentName: student.name,
                            studentEmail: student.email,
                            company: student.company,
                            location: student.location,
                            specialization: student.specialization,
                            logs: logs,
                            reportType: 'Supervisor Verification Log',
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Export Verified PDF'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('This student profile has no active submissions.'))
                    : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, idx) {
                    final log = logs[idx];
                    final feedbackController = TextEditingController();
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Log Date: ${log.date.toLocal()}'.split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Divider(),
                            Text('Reported Activities: ${log.tasksDone}'),
                            Text('Incurred Timelog: ${log.hoursWorked} hours'),
                            Text('Acquired Learning Metrics: ${log.learnings}'),
                            const SizedBox(height: 8),
                            Text('Active Verified Review Notes: ${log.mentorNotes.isEmpty ? "No notes added yet." : log.mentorNotes}', style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                            TextField(
                              controller: feedbackController,
                              decoration: const InputDecoration(labelText: 'Append Review Note / Directive'),
                            ),
                            TextButton(
                              onPressed: () {
                                if (feedbackController.text.isNotEmpty) {
                                  ds.addMentorFeedback(log.id, feedbackController.text);
                                  feedbackController.clear();
                                }
                              },
                              child: const Text('Commit Review Note'),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, FirebaseService ds) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Push New Performance Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Requirement Title')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Scope Guidelines / Context')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abort')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isNotEmpty) {
                await ds.assignTask(TaskModel(
                  id: '',
                  studentId: student.uid,
                  mentorId: mentorId,
                  title: titleCtrl.text,
                  description: descCtrl.text,
                  dueDate: DateTime.now().add(const Duration(days: 3)),
                  status: 'pending',
                ));
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Publish Requirement'),
          )
        ],
      ),
    );
  }
}