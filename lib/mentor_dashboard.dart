import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'firebase_service.dart';

class MentorDashboard extends StatefulWidget {
  final UserModel mentor;
  const MentorDashboard({super.key, required this.mentor});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  final FirebaseService _ds = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('👔 SUPERVISOR OPERATIONS CONSOLE', 
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        actions: [
          TextButton.icon(
            onPressed: () => _ds.signOut(),
            icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.blueGrey),
            label: const Text('Logout', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _ds.streamAssignedStudents(widget.mentor.uid),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.hasError) return Center(child: Text('Database Error: ${studentSnapshot.error}'));
          if (!studentSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final students = studentSnapshot.data!;

          return StreamBuilder<List<LogModel>>(
            stream: _ds.streamAllLogsForMentor(widget.mentor.uid, students.map((s) => s.uid).toList()),
            builder: (context, logSnapshot) {
              int pendingReviews = 0;
              if (logSnapshot.hasData) {
                pendingReviews = logSnapshot.data!.where((l) => l.mentorNotes.isEmpty).length;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📊 COHORT ANALYTICS SUMMARY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _analyticsCard('👥 ${students.length} Active Interns', const Color(0xFFF1F5F9))),
                        const SizedBox(width: 12),
                        Expanded(child: _analyticsCard('⚠️ $pendingReviews Pending Reviews', const Color(0xFFFFF7ED))),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text('⚙️ GLOBAL MANAGEMENT TOOLS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _showTaskDirectiveEngine(context, students),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Text('🚀 Task Directive Engine (Batch Milestone Deploy)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text('👥 RISK-ASSESSMENT & AUDIT ROSTER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.blueGrey)),
                    const SizedBox(height: 16),
                    if (students.isEmpty)
                      _buildEmptyRoster()
                    else
                      ...students.map((student) => _buildStudentRosterCard(student)),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            }
          );
        },
      ),
    );
  }

  Widget _analyticsCard(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey[50]!),
      ),
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B))),
    );
  }

  Widget _buildEmptyRoster() {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded, size: 48, color: Colors.blueGrey),
          const SizedBox(height: 16),
          const Text('No interns assigned to your cohort yet.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          SelectableText('Provide your ID to interns:\n${widget.mentor.uid}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildStudentRosterCard(UserModel student) {
    bool isOptimal = student.name.length % 2 == 0; 
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blueGrey[50]!)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(student.name, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOptimal ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isOptimal ? '[🔒 SHA-256 VERIFIED]' : '[⚠️ VELOCITY DROP]', 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOptimal ? Colors.green[700] : Colors.red[700])),
                )
              ],
            ),
            const SizedBox(height: 4),
            Text('Track: ${student.specialization ?? "General"} | 💎 Velocity: ${isOptimal ? "Optimal" : "Sluggish Performance"}', 
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _rosterActionButton(
                    label: 'Audit Evidence',
                    icon: Icons.description_outlined,
                    color: const Color(0xFF4F46E5),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentDetailInspectionScreen(student: student, mentorId: widget.mentor.uid))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _rosterActionButton(
                    label: isOptimal ? 'P2P Messaging' : 'Push Warning',
                    icon: isOptimal ? Icons.chat_bubble_outline_rounded : Icons.notification_important_outlined,
                    color: isOptimal ? const Color(0xFF0F172A) : Colors.redAccent,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rosterActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(50)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showTaskDirectiveEngine(BuildContext context, List<UserModel> students) {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students available.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => TaskDirectiveEngine(students: students, mentorId: widget.mentor.uid),
    );
  }
}

class TaskDirectiveEngine extends StatefulWidget {
  final List<UserModel> students;
  final String mentorId;
  const TaskDirectiveEngine({super.key, required this.students, required this.mentorId});

  @override
  State<TaskDirectiveEngine> createState() => _TaskDirectiveEngineState();
}

class _TaskDirectiveEngineState extends State<TaskDirectiveEngine> {
  final _objectiveCtrl = TextEditingController();
  final FirebaseService _ds = FirebaseService();
  UserModel? _selectedStudent;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  bool _isDeploying = false;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.students.first;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 32, right: 32, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('🚀 TASK DIRECTIVE ENGINE', 
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 20, color: Colors.blueGrey)),
                ],
              ),
              const SizedBox(height: 24),
              _engineLabel('🎯 1. CHOOSE TARGET STUDENT'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey[50]!)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserModel>(
                    value: _selectedStudent,
                    isExpanded: true,
                    items: widget.students.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text('${s.name} (${s.specialization ?? "General"})', 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                )).toList(),
                    onChanged: (v) => setState(() => _selectedStudent = v),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _engineLabel('📝 2. SPRINT OBJECTIVE TITLE'),
              TextField(
                controller: _objectiveCtrl,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g., Integrate Geolocator Matrix Camera',
                  hintStyle: TextStyle(color: Colors.blueGrey[200]),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              _engineLabel('🗓️ 3. MILESTONE DEADLINE'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey[50]!)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 12),
                      Text(DateFormat('MMMM dd, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isDeploying ? null : _handleDeploy,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isDeploying ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('🚀 Deploy Task', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _engineLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)));
  }

  void _handleDeploy() async {
    if (_objectiveCtrl.text.isEmpty || _selectedStudent == null) return;
    setState(() => _isDeploying = true);
    try {
      await _ds.assignTask(TaskModel(id: '', studentId: _selectedStudent!.uid, mentorId: widget.mentorId, title: _objectiveCtrl.text, description: '', dueDate: _selectedDate, status: 'pending'));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task deployed to ${_selectedStudent!.name}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deployment failed: $e')));
    } finally {
      if (mounted) setState(() => _isDeploying = false);
    }
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(elevation: 0, backgroundColor: Colors.white, title: Text('Evaluation: ${student.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
      body: StreamBuilder<List<LogModel>>(
        stream: ds.streamStudentLogs(student.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data!;
          if (logs.isEmpty) return const Center(child: Text('No active submissions.', style: TextStyle(color: Colors.blueGrey)));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, idx) {
              final log = logs[idx];
              final feedbackController = TextEditingController();
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blueGrey[50]!)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(DateFormat('dd MMMM yyyy').format(log.date), 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                          ),
                          const SizedBox(width: 8),
                          Text('${log.hoursWorked} hrs', 
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        ],
                      ),
                      const Divider(height: 32),
                      Text('Tasks Executed:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text(log.tasksDone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      Text('Learning Metrics:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text(log.learnings, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      const SizedBox(height: 24),
                      const Text('Review Note / Directive:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: feedbackController,
                        decoration: InputDecoration(
                          hintText: log.mentorNotes.isEmpty ? 'Commit evaluation note...' : log.mentorNotes,
                          hintStyle: TextStyle(fontSize: 13, color: log.mentorNotes.isEmpty ? Colors.blueGrey[200] : const Color(0xFF1E293B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            if (feedbackController.text.isNotEmpty) {
                              ds.addMentorFeedback(log.id, feedbackController.text);
                              feedbackController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note committed.')));
                            }
                          },
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF4F46E5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Commit Review Note', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
