import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'models.dart';
import 'firebase_service.dart';
import 'pdf_service.dart';
import 'chat_screen.dart';

class StudentDashboard extends StatefulWidget {
  final UserModel student;
  const StudentDashboard({super.key, required this.student});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseService _ds = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('🌐 MAIN DASHBOARD WORKSPACE', 
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4F46E5)),
            onPressed: () => _showChatSelector(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded, color: Color(0xFF4F46E5)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(student: widget.student))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<LogModel>>(
        stream: _ds.streamStudentLogs(widget.student.uid),
        builder: (context, logSnapshot) {
          return StreamBuilder<List<TaskModel>>(
            stream: _ds.streamStudentTasks(widget.student.uid),
            builder: (context, taskSnapshot) {
              if (logSnapshot.hasError || taskSnapshot.hasError) return Center(child: Text('Error loading workspace data'));
              if (!logSnapshot.hasData || !taskSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              final logs = logSnapshot.data!;
              final tasks = taskSnapshot.data!;
              
              double totalHours = logs.fold(0, (sum, log) => sum + log.hoursWorked);
              int badgeCount = (totalHours > 0 ? 1 : 0) + (logs.length >= 5 ? 1 : 0) + (logs.any((l) => l.mentorNotes.isNotEmpty) ? 1 : 0);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 👋 Welcome & Domain Track
                    Text('👋 Welcome Back, ${widget.student.name}!', 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text('📊 Domain Track: ${widget.student.specialization ?? 'Unspecified Matrix'}', 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // [📅 Horizontal Status Ticker Ribbon]
                    _buildStatusTickerRibbon(logs),

                    const SizedBox(height: 32),

                    // ⚡ METRIC TRACKERS SUMMARY
                    const Text('⚡ METRIC TRACKERS SUMMARY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _metricCard('⏱️ ${totalHours.toStringAsFixed(1)} Total Hours', const Color(0xFFF1F5F9), onTap: null)),
                        const SizedBox(width: 12),
                        Expanded(child: _metricCard('🏅 $badgeCount Badges Unlocked', const Color(0xFFF1F5F9), 
                          onTap: () => _showBadgeDetails(context, logs))),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 🚀 INTERACTIVE WORKSPACE UTILITIES
                    const Text('🚀 INTERACTIVE WORKSPACE UTILITIES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _utilityButton(
                            label: 'Add Daily Log',
                            icon: Icons.add_circle_outline_rounded,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LogEntryScreen(student: widget.student))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _utilityButton(
                            label: 'Live Chat',
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: () => _showChatSelector(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _utilityButton(
                            label: 'Attendance Matrix',
                            icon: Icons.calendar_today_rounded,
                            onTap: () => _showAttendanceSheet(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _utilityButton(
                            label: 'Export PDF Report',
                            icon: Icons.picture_as_pdf_outlined,
                            onTap: logs.isEmpty ? null : () => _showPdfOptions(context, logs),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 📋 SUPERVISOR DIRECTIVES & ROADMAP
                    const Text('📋 SUPERVISOR DIRECTIVES & ROADMAP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.blueGrey)),
                    const SizedBox(height: 20),

                    // PENDING TARGETS
                    _buildTaskSection('⏳ PENDING TARGETS', tasks.where((t) => t.status != 'completed').toList(), false),
                    
                    const SizedBox(height: 24),

                    // COMPLETED TARGETS
                    _buildTaskSection('✅ COMPLETED TARGETS', tasks.where((t) => t.status == 'completed').toList(), true),

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusTickerRibbon(List<LogModel> logs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDates = {for (var log in logs) DateTime(log.date.year, log.date.month, log.date.day)};

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(5, (index) {
          final date = today.subtract(Duration(days: 2 - index));
          final isToday = date.isAtSameMomentAs(today);
          final hasLog = logDates.contains(date);
          
          String statusText = hasLog ? '[🟢 Done]' : '[⚪ Open]';
          if (isToday && hasLog) statusText = '[🟡 Active Log]';

          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFF4F46E5).withAlpha(10) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isToday ? const Color(0xFF4F46E5) : Colors.blueGrey[50]!),
            ),
            child: Column(
              children: [
                Text('${DateFormat('E').format(date)} ${date.day}', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? const Color(0xFF4F46E5) : const Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: hasLog ? Colors.green : Colors.blueGrey)),
                if (isToday) const Text('(Today)', style: TextStyle(fontSize: 8, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _metricCard(String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey[100]!),
        ),
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B))),
      ),
    );
  }

  void _showBadgeDetails(BuildContext context, List<LogModel> logs) {
    bool hasLog = logs.isNotEmpty;
    bool laborMax = logs.length >= 5;
    bool verified = logs.any((l) => l.mentorNotes.isNotEmpty);
    bool consistency = logs.length >= 10;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆 YOUR PERFORMANCE BADGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 32),
            _badgeDetailItem('🏅 First Step', 'Complete your very first internship log.', hasLog),
            _badgeDetailItem('⚡ Labor Max', 'Achieve a milestone of 5 daily work logs.', laborMax),
            _badgeDetailItem('✅ Verified', 'Receive your first professional evaluation from a mentor.', verified),
            _badgeDetailItem('🔥 Consistency', 'Maintain a long-term record with 10+ entries.', consistency),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _badgeDetailItem(String title, String desc, bool isUnlocked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked ? const Color(0xFF4F46E5) : Colors.white.withAlpha(10),
              shape: BoxShape.circle,
            ),
            child: Icon(isUnlocked ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, 
              color: isUnlocked ? Colors.white : Colors.white38, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isUnlocked ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(desc, style: TextStyle(color: isUnlocked ? Colors.blueGrey[100] : Colors.blueGrey[600], fontSize: 12)),
              ],
            ),
          ),
          if (isUnlocked) const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
        ],
      ),
    );
  }

  Widget _utilityButton({required String label, required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4F46E5).withAlpha(30)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4F46E5)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSection(String title, List<TaskModel> taskList, bool isCompleted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title (${taskList.length})', 
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isCompleted ? Colors.green[700] : Colors.orange[800], letterSpacing: 0.5)),
        const SizedBox(height: 12),
        if (taskList.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: Text('No targets in this category.', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontStyle: FontStyle.italic)),
          )
        else
          ...taskList.map((task) {
            bool isSubmitted = task.status == 'submitted';
            bool isGraded = task.status == 'completed';

            return InkWell(
              onTap: isGraded
                ? (task.submissionUrl != null ? () => _viewSubmission(task) : null)
                : () => _showTaskSubmissionDialog(context, task, isResubmission: isSubmitted),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey[50]!),
                ),
                child: Row(
                  children: [
                    Icon(isGraded ? Icons.verified_rounded : (isSubmitted ? Icons.hourglass_top_rounded : Icons.pending_rounded), 
                      color: isGraded ? Colors.green : (isSubmitted ? Colors.blue : Colors.orange)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, 
                            decoration: isGraded ? TextDecoration.lineThrough : null, color: const Color(0xFF1E293B))),
                          const SizedBox(height: 4),
                          if (isGraded && task.mark != null)
                            Text('🎯 Evaluation Score: ${task.mark}/100', 
                              style: const TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w900))
                          else
                            Text(isSubmitted ? 'Pending Supervisor Evaluation' : 'Due: ${DateFormat('MMMM dd, yyyy').format(task.dueDate)}', 
                              style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if ((isGraded || isSubmitted) && task.submissionUrl != null)
                      const Icon(Icons.attachment_rounded, size: 18, color: Color(0xFF4F46E5)),
                    if (!isGraded && !isSubmitted)
                      const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.blueGrey),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showTaskSubmissionDialog(BuildContext context, TaskModel task, {bool isResubmission = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isResubmission ? '♻️ RESUBMIT TASK: ${task.title}' : '🚀 SUBMIT TASK: ${task.title}', 
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 1)),
            if (isResubmission)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('You have already submitted once. Uploading a new file will replace your previous submission.', 
                  style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 24),
            _submissionOptionTile(
              context,
              icon: Icons.image_outlined,
              title: 'Upload Image / Screenshot',
              onTap: () => _handleTaskUpload(context, task, 'image'),
            ),
            _submissionOptionTile(
              context,
              icon: Icons.file_present_rounded,
              title: 'Upload Document / File',
              onTap: () => _handleTaskUpload(context, task, 'file'),
            ),
            _submissionOptionTile(
              context,
              icon: Icons.folder_zip_outlined,
              title: 'Upload Folder (Zip Format)',
              onTap: () => _handleTaskUpload(context, task, 'folder'),
            ),
            if (isResubmission)
              _submissionOptionTile(
                context,
                icon: Icons.visibility_outlined,
                title: 'View Current Submission',
                onTap: () {
                  Navigator.pop(context);
                  _viewSubmission(task);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _submissionOptionTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }

  void _handleTaskUpload(BuildContext context, TaskModel task, String type) async {
    File? file;
    try {
      if (type == 'image') {
        // High-speed optimization: 40% quality and 800px max
        final XFile? picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, 
          imageQuality: 40,
          maxWidth: 800,
          maxHeight: 800,
        );
        if (picked != null) file = File(picked.path);
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: type == 'folder' ? FileType.custom : FileType.any,
          allowedExtensions: type == 'folder' ? ['zip', 'rar', '7z'] : null,
        );
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      return;
    }

    if (file == null) return;
    if (context.mounted) Navigator.of(context).pop(); // Close selection menu

    // Clear the wait: Show confirmation FIRST before the long upload process starts
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (confirmContext) => AlertDialog(
        title: const Text('🚀 Ready to Submit?'),
        content: Text('Ready to upload and submit this evidence for supervisor evaluation?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(onPressed: () => Navigator.of(confirmContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(confirmContext).pop();
              _performFastUpload(context, task, file!, type);
            },
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );
  }

  void _performFastUpload(BuildContext context, TaskModel task, File file, String type) async {
    final uploadProgress = ValueNotifier<double>(0.0);
    
    // Show non-blocking progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: ValueListenableBuilder<double>(
          valueListenable: uploadProgress,
          builder: (context, progress, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                CircularProgressIndicator(
                  value: progress > 0 ? progress : null, 
                  color: const Color(0xFF4F46E5),
                  strokeWidth: 6,
                ),
                const SizedBox(height: 24),
                Text(progress > 0 ? 'Syncing: ${(progress * 100).toInt()}%' : 'Preparing cloud...', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
      ),
    );

    try {
      String extension = p.extension(file.path);
      String fileName = '${task.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final storageRef = FirebaseStorage.instance.ref().child('submissions/${task.id}/$fileName');
      
      final uploadTask = storageRef.putFile(file);
      uploadTask.snapshotEvents.listen((snap) {
        uploadProgress.value = snap.bytesTransferred / snap.totalBytes;
      });

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      
      // Auto-finalize in Firestore
      await _ds.updateTaskStatus(task.id, 'submitted', url: url, type: type);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close Progress Dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Task successfully synced to workspace!')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    } finally {
      uploadProgress.dispose();
    }
  }

  void _viewSubmission(TaskModel task) async {
    if (task.submissionUrl != null) {
      final Uri url = Uri.parse(task.submissionUrl!);
      if (!await launchUrl(url)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open submission link.')));
        }
      }
    }
  }

  void _showChatSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬 SELECT SUPERVISOR TO CHAT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1, color: Colors.blueGrey)),
            const SizedBox(height: 16),
            StreamBuilder<List<UserModel>>(
              stream: _ds.streamAllMentors(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final mentors = snapshot.data!.where((m) => widget.student.mentorIds.contains(m.uid)).toList();

                if (mentors.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No linked supervisors available for live chat.', textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: mentors.length,
                  itemBuilder: (context, index) {
                    final mentor = mentors[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: const CircleAvatar(backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.person_outline_rounded, color: Color(0xFF4F46E5))),
                      title: Text(mentor.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(mentor.specialization ?? 'Supervisor', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(currentUser: widget.student, otherUser: mentor)));
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => AttendanceSheet(student: widget.student),
    );
  }

  void _showPdfOptions(BuildContext context, List<LogModel> logs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📄 SELECT REPORT TYPE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 1)),
            const SizedBox(height: 24),
            _pdfOptionTile(
              context,
              icon: Icons.today_rounded,
              title: 'Daily Performance Log',
              subtitle: 'Generate a detailed report for today\'s activities.',
              onTap: () {
                final todayLogs = logs.where((l) => DateUtils.isSameDay(l.date, DateTime.now())).toList();
                _generatePdf(context, todayLogs, 'Daily Progress Report');
              },
            ),
            _pdfOptionTile(
              context,
              icon: Icons.date_range_rounded,
              title: 'Weekly Sprint Summary',
              subtitle: 'Generate a report for the last 7 days of work.',
              onTap: () {
                final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                final weeklyLogs = logs.where((l) => l.date.isAfter(weekAgo)).toList();
                _generatePdf(context, weeklyLogs, 'Weekly Sprint Summary');
              },
            ),
            _pdfOptionTile(
              context,
              icon: Icons.calendar_month_rounded,
              title: 'Monthly Performance Matrix',
              subtitle: 'Generate a complete report for the last 30 days.',
              onTap: () {
                final monthAgo = DateTime.now().subtract(const Duration(days: 30));
                final monthlyLogs = logs.where((l) => l.date.isAfter(monthAgo)).toList();
                _generatePdf(context, monthlyLogs, 'Monthly Performance Matrix');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _pdfOptionTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF4F46E5)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _generatePdf(BuildContext context, List<LogModel> filteredLogs, String type) {
    if (filteredLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No logs found for the selected period.')));
      return;
    }
    PdfService.generateAndShareReport(
      studentName: widget.student.name,
      studentEmail: widget.student.email,
      company: widget.student.company,
      location: widget.student.location,
      specialization: widget.student.specialization,
      logs: filteredLogs,
      reportType: type,
    );
  }
}

class LogEntryScreen extends StatefulWidget {
  final UserModel student;
  const LogEntryScreen({super.key, required this.student});

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  final _tasksCtrl = TextEditingController();
  final _learnCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _ds = FirebaseService();
  final _picker = ImagePicker();
  bool _isSubmitting = false;

  File? _screenshot;
  File? _geoPhoto;
  String _locationStatus = "GPS Status: Location Pending";

  Future<void> _pickImage(bool isScreenshot) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        if (isScreenshot) {
          _screenshot = File(pickedFile.path);
        } else {
          _geoPhoto = File(pickedFile.path);
          _fetchLocation(); // Fetch real GPS when geo-photo is selected
        }
      });
    }
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationStatus = "GPS Error: Location Services Disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationStatus = "GPS Error: Permission Denied");
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _locationStatus = "📌 GPS Fixed: ${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.toStringAsFixed(4)}° E";
      });
    } catch (e) {
      setState(() => _locationStatus = "GPS Error: Could not fetch location");
    }
  }

  void _handleSubmit() async {
    if (_tasksCtrl.text.isEmpty) return;
    
    setState(() => _isSubmitting = true);
    try {
      await _ds.addDailyLog(LogModel(
        id: '',
        studentId: widget.student.uid,
        date: DateTime.now(),
        tasksDone: _tasksCtrl.text,
        hoursWorked: double.tryParse(_hoursCtrl.text) ?? 0.0,
        learnings: _learnCtrl.text,
        moodRating: 5,
        mentorNotes: '',
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('➕ New Daily Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('📝 1. DAILY SUMMARY'),
            _buildLargeTextField(_tasksCtrl, 'Briefly explain what tasks you handled today...'),
            const SizedBox(height: 32),

            _sectionHeader('💻 2. PROJECT PROOF'),
            _buildUploadPlaceholder(
              Icons.camera_enhance_rounded, 
              'Upload Project Screenshot',
              _screenshot,
              () => _pickImage(true),
            ),
            const SizedBox(height: 32),

            _sectionHeader('📍 3. ATTENDANCE & VERIFICATION'),
            _buildUploadPlaceholder(
              Icons.location_on_rounded, 
              'Select Geo-Tagged Verification Photo',
              _geoPhoto,
              () => _pickImage(false),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 4),
              child: Text(_locationStatus, 
                style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 32),

            _sectionHeader('🎓 4. LEARNING OUTCOMES'),
            _buildLargeTextField(_learnCtrl, 'What key technical concepts did you learn today?...'),
            const SizedBox(height: 16),
            _inputField(_hoursCtrl, 'Total Hours Spent', Icons.timer_outlined, isNumber: true),
            const SizedBox(height: 32),

            _sectionHeader('🏆 5. UNLOCKED SKILL BADGES (Live Matrix View)'),
            _buildBadgeGrid(),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: const Color(0xFF4F46E5).withAlpha(100),
                ),
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('🚀 Submit Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 0.5)),
    );
  }

  Widget _buildLargeTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.blueGrey[200], fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.blueGrey[50]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.blueGrey[50]!)),
      ),
    );
  }

  Widget _buildUploadPlaceholder(IconData icon, String label, File? imageFile, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: imageFile == null ? const EdgeInsets.symmetric(vertical: 32) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueGrey[100]!, style: BorderStyle.solid),
        ),
        child: imageFile == null 
          ? Column(
              children: [
                Icon(icon, size: 40, color: const Color(0xFF4F46E5)),
                const SizedBox(height: 12),
                Text(label, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.file(imageFile, height: 200, width: double.infinity, fit: BoxFit.cover),
                  Container(
                    color: Colors.black26,
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.edit_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildBadgeGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          _badgeItem('🏅 First Step', true),
          _badgeItem('🔥 Consistency', false),
          _badgeItem('⚡ Labor Max', true),
          _badgeItem('✅ Verified', false),
        ],
      ),
    );
  }

  Widget _badgeItem(String label, bool isActive) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withAlpha(30) : Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? Colors.white24 : Colors.transparent),
      ),
      child: Center(
        child: Text(
          '$label ${isActive ? "[Active]" : "[Locked]"}',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final UserModel student;
  const ProfileScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final ds = FirebaseService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('👤 My Profile Matrix', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<UserModel?>(
        stream: ds.streamUserProfile(student.uid),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final user = userSnapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFE0E7FF),
                        child: Icon(Icons.person_rounded, size: 60, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(height: 16),
                      Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      Text('Account Level: ${user.role == 'student' ? 'Student / Intern' : 'Mentor'}', 
                        style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('⚙️ WORKSPACE CONTROLS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.blueGrey)),
                ),
                const SizedBox(height: 16),

                _controlTile(
                  icon: Icons.school_rounded,
                  title: '1. About My Internship',
                  subtitle: '(View Total Hours, Learned Skills & Badges)',
                  onTap: () => _showAboutInternship(context, user),
                ),
                
                _controlTile(
                  icon: Icons.people_rounded,
                  title: '2. Connect Registered Supervisor / Mentor',
                  subtitle: '(Choose from Verified System Faculty List)',
                  onTap: () => _showMentorSelection(context, user),
                ),
                
                // Display each connected mentor with a remove button
                if (user.mentorIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('   CURRENT SUPERVISORS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<UserModel>>(
                    stream: ds.streamAllMentors(),
                    builder: (context, mentorSnapshot) {
                      if (!mentorSnapshot.hasData) return const SizedBox.shrink();
                      final allMentors = mentorSnapshot.data!;
                      final myMentors = allMentors.where((m) => user.mentorIds.contains(m.uid)).toList();

                      return Column(
                        children: myMentors.map((m) => _controlTile(
                          icon: Icons.person_remove_rounded,
                          title: 'Remove: ${m.name}',
                          subtitle: '(Disconnect from ${m.name})',
                          isDestructive: true,
                          onTap: () => _handleRemoveMentor(context, user, m.uid),
                        )).toList(),
                      );
                    }
                  ),
                ],

                _controlTile(
                  icon: Icons.stop_circle_rounded,
                  title: '3. Conclude & End Internship',
                  subtitle: '(Upload Official Completion Certificate)',
                  onTap: () => _showEndInternship(context),
                ),
                
                _controlTile(
                  icon: Icons.logout_rounded,
                  title: '4. Terminate Current Session (Logout)',
                  subtitle: '',
                  isDestructive: true,
                  onTap: () {
                    ds.signOut();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _controlTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isDestructive = false}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blueGrey[50]!)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: isDestructive ? Colors.redAccent : const Color(0xFF4F46E5)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? Colors.redAccent : const Color(0xFF1E293B))),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.blueGrey),
        onTap: onTap,
      ),
    );
  }

  void _handleRemoveMentor(BuildContext context, UserModel user, String mentorUid) async {
    final ds = FirebaseService();
    await ds.removeMentor(user.uid, mentorUid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supervisor disconnected successfully.')));
    }
  }

  void _showAboutInternship(BuildContext context, UserModel user) {
    final ds = FirebaseService();
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<LogModel>>(
        stream: ds.streamStudentLogs(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data!;
          double totalHours = logs.fold(0, (sum, log) => sum + log.hoursWorked);
          Set<String> skills = logs.expand((l) => l.learnings.split(',')).map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();

          return AlertDialog(
            title: const Text('🎓 Internship Summary'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _summaryItem('Total Hours Invested', '${totalHours.toStringAsFixed(1)} Hrs'),
                  _summaryItem('Skills Acquired', skills.isEmpty ? 'None yet' : skills.join(', ')),
                  const SizedBox(height: 16),
                  const Text('Active Badges', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (totalHours > 0) const Chip(label: Text('🏅 First Step'), backgroundColor: Color(0xFFF0FDF4)),
                      if (logs.length >= 5) const Chip(label: Text('⚡ Labor Max'), backgroundColor: Color(0xFFF0FDF4)),
                    ],
                  )
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          );
        },
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showMentorSelection(BuildContext context, UserModel user) {
    final ds = FirebaseService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => StreamBuilder<List<UserModel>>(
          stream: ds.streamAllMentors(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final allMentors = snapshot.data!;
            final linkedMentors = allMentors.where((m) => user.mentorIds.contains(m.uid)).toList();
            final availableMentors = allMentors.where((m) => !user.mentorIds.contains(m.uid)).toList();

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text('👥 My Linked Supervisors & Faculty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Section 1: ACTIVE CONNECTED MENTORS
                      const Row(
                        children: [
                          Icon(Icons.link_rounded, color: Color(0xFF4F46E5), size: 18),
                          SizedBox(width: 8),
                          Text('🔗 ACTIVE CONNECTED MENTORS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Color(0xFF4F46E5))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (linkedMentors.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('No active mentors connected.', style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                        )
                      else
                        ...linkedMentors.map((m) => _mentorManagementCard(
                              context: context,
                              mentor: m,
                              isLinked: true,
                              onAction: () => _handleRemoveMentor(context, user, m.uid),
                              currentUser: user,
                            )),

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 32),

                      // Section 2: ATTACH NEW SUPERVISOR
                      const Text('➕ ATTACH NEW SUPERVISOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      const Text('Select an additional mentor from the registered pool:', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      const SizedBox(height: 16),
                      if (availableMentors.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('All registered mentors are already linked.', style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                        )
                      else
                        ...availableMentors.map((m) => _mentorManagementCard(
                              context: context,
                              mentor: m,
                              isLinked: false,
                              onAction: () async {
                                await ds.addMentor(user.uid, m.uid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to ${m.name}')));
                                }
                              },
                              currentUser: user,
                            )),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _mentorManagementCard({required BuildContext context, required UserModel mentor, required bool isLinked, required VoidCallback onAction, required UserModel currentUser}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isLinked ? const Color(0xFFE0E7FF) : const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.person_outline_rounded, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mentor.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                    Text(mentor.email, style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onAction,
                  icon: Icon(isLinked ? Icons.person_remove_rounded : Icons.person_add_rounded, size: 18),
                  label: Text(isLinked ? 'Disconnect' : 'Connect', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: TextButton.styleFrom(
                    backgroundColor: isLinked ? const Color(0xFFFFE4E6) : const Color(0xFFEEF2FF),
                    foregroundColor: isLinked ? Colors.redAccent : const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              if (isLinked) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(currentUser: currentUser, otherUser: mentor))),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Live Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showEndInternship(BuildContext context) {
    File? certificateFile;
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('🛑 Conclude Internship'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('To finalize your internship record, please upload your official completion certificate.'),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setDialogState(() => certificateFile = File(picked.path));
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: certificateFile == null ? const EdgeInsets.all(32) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueGrey[100]!, style: BorderStyle.solid),
                  ),
                  child: certificateFile == null
                      ? const Column(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 40, color: Color(0xFF4F46E5)),
                            SizedBox(height: 12),
                            Text('Upload Certificate', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.file(certificateFile!, height: 150, width: double.infinity, fit: BoxFit.cover),
                              Container(
                                color: Colors.black26,
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.edit_rounded, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: certificateFile == null ? null : () {
                // Handle final submission logic here
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Internship concluded successfully.')));
              }, 
              child: const Text('Submit & End'),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceSheet extends StatefulWidget {
  final UserModel student;
  const AttendanceSheet({super.key, required this.student});

  @override
  State<AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<AttendanceSheet> {
  final FirebaseService _ds = FirebaseService();
  bool _isMarking = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => StreamBuilder<List<AttendanceModel>>(
        stream: _ds.streamStudentAttendance(widget.student.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final attendanceList = snapshot.data!;
          
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final hasMarkedToday = attendanceList.any((a) => a.date.isAtSameMomentAs(today));
          
          // Stats calculation
          int presentDays = attendanceList.where((a) => a.isPresent).length;
          int totalInternshipDays = widget.student.totalInternshipDays ?? 30;
          DateTime startDate = widget.student.startDate ?? today;
          
          int daysElapsed = now.difference(startDate).inDays + 1;
          if (daysElapsed < 1) daysElapsed = 1;
          
          int absentDays = daysElapsed - presentDays;
          if (absentDays < 0) absentDays = 0;
          
          double attendancePercentage = (presentDays / daysElapsed) * 100;
          if (attendancePercentage > 100) attendancePercentage = 100;

          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: ListView(
              controller: scrollController,
              children: [
                const Text('📅 ATTENDANCE MATRIX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 1)),
                const SizedBox(height: 24),
                
                // Attendance Stats Cards
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _statCard('Present', '$presentDays Days', Colors.green),
                    _statCard('Absent', '$absentDays Days', Colors.redAccent),
                    _statCard('Percentage', '${attendancePercentage.toStringAsFixed(1)}%', Colors.indigo),
                    _statCard('Total Duration', '$totalInternshipDays Days', Colors.blueGrey),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                if (!hasMarkedToday)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _isMarking ? null : () async {
                        setState(() => _isMarking = true);
                        await _ds.markAttendance(widget.student.uid, true);
                        if (mounted) setState(() => _isMarking = false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isMarking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
                      label: const Text('Mark as Present Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withAlpha(50)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, color: Colors.green),
                        SizedBox(width: 12),
                        Text('Attendance Marked for Today', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  
                const SizedBox(height: 32),
                const Text('RECENT HISTORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 1.1)),
                const SizedBox(height: 12),
                ...attendanceList.take(10).map((a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today, size: 18, color: a.isPresent ? Colors.green : Colors.red),
                  title: Text(DateFormat('dd MMMM yyyy').format(a.date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: Text(a.isPresent ? 'Present' : 'Absent', style: TextStyle(color: a.isPresent ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
