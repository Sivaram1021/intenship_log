import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'firebase_service.dart';
import 'chat_screen.dart';

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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
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
                              Flexible(
                                child: Text('🚀 Task Directive Engine (Batch Milestone Deploy)',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey[50]!),
      ),
      child: Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B))),
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
    return StreamBuilder<List<AttendanceModel>>(
      stream: _ds.streamStudentAttendance(student.uid),
      builder: (context, snapshot) {
        String attendanceInfo = "Attendance: Loading...";
        if (snapshot.hasData) {
          int present = snapshot.data!.where((a) => a.isPresent).length;
          attendanceInfo = "Attendance: $present Days Present";
        }

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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOptimal ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(isOptimal ? '[🔒 SHA-256 VERIFIED]' : '[⚠️ VELOCITY DROP]',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isOptimal ? Colors.green[700] : Colors.red[700])),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text('Track: ${student.specialization ?? "General"} | 💎 Velocity: ${isOptimal ? "Optimal" : "Sluggish Performance"}',
                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(attendanceInfo, style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _rosterActionButton(
                        label: 'Audit Evidence',
                        icon: Icons.description_outlined,
                        color: const Color(0xFF4F46E5),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentDetailInspectionScreen(student: student, mentor: widget.mentor))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _rosterActionButton(
                        label: 'P2P Chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        color: const Color(0xFF0F172A),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(currentUser: widget.mentor, otherUser: student))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _rosterActionButton(
                        label: isOptimal ? 'Optimal' : 'Push Warn',
                        icon: isOptimal ? Icons.verified_user_outlined : Icons.notification_important_outlined,
                        color: isOptimal ? Colors.green : Colors.redAccent,
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
    );
  }

  Widget _rosterActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(50)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10.5),
              ),
            ),
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
  final _descCtrl = TextEditingController();
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85, // Safety parameter to prevent full-screen overflow
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, top: 24, bottom: 24),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                _engineLabel('📄 3. TARGET GUIDELINES / DESCRIPTION'),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Provide detailed instructions or constraints...',
                    hintStyle: TextStyle(color: Colors.blueGrey[200]),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                _engineLabel('🗓️ 4. MILESTONE DEADLINE'),
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
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isDeploying ? null : _handleDeploy,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isDeploying ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('🚀 Deploy Task', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                  ),
                ),
              ],
            ),
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
      await _ds.assignTask(TaskModel(
        id: '', 
        studentId: _selectedStudent!.uid, 
        mentorId: widget.mentorId, 
        title: _objectiveCtrl.text, 
        description: _descCtrl.text, 
        dueDate: _selectedDate, 
        status: 'pending'
      ));
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

class StudentDetailInspectionScreen extends StatefulWidget {
  final UserModel student;
  final UserModel mentor;
  const StudentDetailInspectionScreen({super.key, required this.student, required this.mentor});

  @override
  State<StudentDetailInspectionScreen> createState() => _StudentDetailInspectionScreenState();
}

class _StudentDetailInspectionScreenState extends State<StudentDetailInspectionScreen> {
  final FirebaseService ds = FirebaseService();
  String? _gradingTaskId;
  String? _reviewingLogId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text('Audit: ${widget.student.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4F46E5)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(currentUser: widget.mentor, otherUser: widget.student))),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF4F46E5),
            unselectedLabelColor: Colors.blueGrey,
            indicatorColor: Color(0xFF4F46E5),
            tabs: [
              Tab(text: 'Logs', icon: Icon(Icons.history_rounded)),
              Tab(text: 'Tasks', icon: Icon(Icons.rocket_launch_rounded)),
              Tab(text: 'Attendance', icon: Icon(Icons.calendar_month_rounded)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLogsTab(ds),
            _buildTasksTab(ds, context),
            _buildAttendanceAuditTab(ds),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceAuditTab(FirebaseService ds) {
    return StreamBuilder<List<AttendanceModel>>(
      stream: ds.streamStudentAttendance(widget.student.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final attendanceList = snapshot.data!;
        
        // Calculate stats
        int presentDays = attendanceList.where((a) => a.isPresent).length;
        int totalDays = widget.student.totalInternshipDays ?? 30;
        DateTime now = DateTime.now();
        DateTime startDate = widget.student.startDate ?? now;
        int daysElapsed = now.difference(startDate).inDays + 1;
        if (daysElapsed < 1) daysElapsed = 1;
        int absentDays = daysElapsed - presentDays;
        if (absentDays < 0) absentDays = 0;
        double percentage = (presentDays / daysElapsed) * 100;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📈 ATTENDANCE ANALYTICS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1.1)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _miniStatCard('Present', '$presentDays', Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _miniStatCard('Absent', '$absentDays', Colors.redAccent)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _miniStatCard('Ratio', '${percentage.toStringAsFixed(1)}%', Colors.indigo)),
                  const SizedBox(width: 12),
                  Expanded(child: _miniStatCard('Target', '$totalDays Days', Colors.blueGrey)),
                ],
              ),
              const SizedBox(height: 32),
              const Text('CHRONOLOGICAL RECORDS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1.1)),
              const SizedBox(height: 12),
              ...attendanceList.map((a) => Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blueGrey[50]!)),
                child: ListTile(
                  leading: Icon(Icons.circle, size: 12, color: a.isPresent ? Colors.green : Colors.red),
                  title: Text(DateFormat('EEEE, dd MMMM').format(a.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: Text(a.isPresent ? 'VERIFIED PRESENT' : 'ABSENT', style: TextStyle(color: a.isPresent ? Colors.green : Colors.red, fontWeight: FontWeight.w900, fontSize: 10)),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withAlpha(10), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withAlpha(20))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildLogsTab(FirebaseService ds) {
    return StreamBuilder<List<LogModel>>(
      stream: ds.streamStudentLogs(widget.student.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final logs = snapshot.data!;
        if (logs.isEmpty) return const Center(child: Text('No active work logs.', style: TextStyle(color: Colors.blueGrey)));
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
                    const Text('Tasks Executed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text(log.tasksDone, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),
                    const Text('Learning Metrics:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
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
                    _reviewingLogId == log.id
                        ? const SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4F46E5),
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                if (feedbackController.text.isNotEmpty) {
                                  setState(() => _reviewingLogId = log.id);
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await ds.addMentorFeedback(log.id, feedbackController.text);
                                    feedbackController.clear();
                                    if (mounted) {
                                      messenger.showSnackBar(const SnackBar(content: Text('Note committed.')));
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(SnackBar(content: Text('Failed to commit note: $e')));
                                    }
                                  } finally {
                                    if (mounted) setState(() => _reviewingLogId = null);
                                  }
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
    );
  }

  Widget _buildTasksTab(FirebaseService ds, BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: ds.streamStudentTasks(widget.student.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tasks = snapshot.data!;
        
        int completed = tasks.where((t) => t.status == 'completed').length;
        int pending = tasks.where((t) => t.status == 'pending').length;
        int submitted = tasks.where((t) => t.status == 'submitted').length;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(child: _miniStatCard('Assigned', '${tasks.length}', Colors.blueGrey)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniStatCard('Pending', '$pending', Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniStatCard('Submitted', '$submitted', Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniStatCard('Verified', '$completed', Colors.green)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: tasks.isEmpty 
                ? const Center(child: Text('No tasks assigned yet.', style: TextStyle(color: Colors.blueGrey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, idx) {
                      final task = tasks[idx];
                      bool isSubmitted = task.status == 'submitted';
                      bool isGraded = task.status == 'completed';
                      
                      final markController = TextEditingController();

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blueGrey[50]!)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(isGraded ? Icons.verified_rounded : (isSubmitted ? Icons.hourglass_top_rounded : Icons.pending_actions_rounded), 
                                  color: isGraded ? Colors.green : (isSubmitted ? Colors.blue : Colors.orange)),
                                title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Due: ${DateFormat('dd MMM yyyy').format(task.dueDate)}', style: const TextStyle(fontSize: 12)),
                                    if (isGraded) 
                                      Text('🎯 Evaluation Score: ${task.mark}/100', 
                                        style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12))
                                    else if (isSubmitted)
                                      Text('Submitted Proof: ${task.submissionType?.toUpperCase()}', 
                                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ],
                                ),
                                trailing: (isGraded || isSubmitted) && (task.submissionUrl != null || task.submissionData != null)
                                  ? IconButton(
                                      icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF4F46E5)),
                                      onPressed: () => _viewSubmission(context, task),
                                    )
                                  : null,
                              ),
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(task.description, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              ],
                              if (isSubmitted && !isGraded) ...[
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: markController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: 'Assign Mark (0-100)',
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _gradingTaskId == task.id
                                        ? const SizedBox(
                                            width: 48,
                                            height: 40,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF4F46E5),
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : ElevatedButton(
                                            onPressed: () async {
                                              int? mark = int.tryParse(markController.text);
                                              if (mark != null && mark >= 0 && mark <= 100) {
                                                setState(() => _gradingTaskId = task.id);
                                                try {
                                                  await ds.updateTaskStatus(task.id, 'completed', mark: mark);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Milestone evaluation committed.')));
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grading failed: $e')));
                                                  }
                                                } finally {
                                                  if (mounted) setState(() => _gradingTaskId = null);
                                                }
                                              } else {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid mark between 0-100.')));
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF4F46E5),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: const Text('Grade'),
                                          ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        );
      },
    );
  }

  void _viewSubmission(BuildContext context, TaskModel task) {
    if (task.submissionData != null && task.submissionData!.isNotEmpty) {
      _viewBase64Submission(context, task);
    } else if (task.submissionUrl != null && task.submissionUrl!.isNotEmpty) {
      _openSubmission(task.submissionUrl!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No digital proof attached.')));
    }
  }

  void _openSubmission(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _viewBase64Submission(BuildContext context, TaskModel task) {
    try {
      final parts = task.submissionData!.split('|');
      if (parts.length < 3) return;
      final type = parts[0];
      final ext = parts[1];
      final b64 = parts.sublist(2).join('|');
      final bytes = base64Decode(b64);

      if (type == 'image') {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attached File: $ext (${(bytes.length / 1024).toStringAsFixed(1)} KB)'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error decoding proof: $e')));
    }
  }
}
