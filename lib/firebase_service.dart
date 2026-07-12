import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ... (signUp, signInWithGoogle, etc. remain the same)

  Future<UserCredential?> signUp(String email, String password, String name, String role, {String? mentorId}) async {
    UserCredential? creds;
    try {
      creds = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        creds = await _auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        rethrow;
      }
    }

    if (creds.user != null) {
      UserModel newUser = UserModel(
        uid: creds.user!.uid,
        name: name,
        email: email,
        role: role,
        mentorIds: (mentorId == null || mentorId.isEmpty) ? [] : [mentorId],
      );
      await _db.collection('users').doc(creds.user!.uid).set(newUser.toMap());
    }
    return creds;
  }
  
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// RESET PASSWORD: Sends a reset link to the registered email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> addMentor(String studentUid, String mentorUid) async {
    await _db.collection('users').doc(studentUid).update({
      'mentorIds': FieldValue.arrayUnion([mentorUid])
    });
  }

  Future<void> removeMentor(String studentUid, String mentorUid) async {
    await _db.collection('users').doc(studentUid).update({
      'mentorIds': FieldValue.arrayRemove([mentorUid])
    });
  }

  Future<UserModel?> getUserProfile(String uid) async {
    var snapshot = await _db.collection('users').doc(uid).get();
    return snapshot.exists ? UserModel.fromMap(snapshot.data()!, snapshot.id) : null;
  }

  Stream<UserModel?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      return snapshot.exists ? UserModel.fromMap(snapshot.data()!, snapshot.id) : null;
    });
  }

  Future<void> addDailyLog(LogModel log) async {
    await _db.collection('logs').add(log.toMap());
  }

  Future<void> addMentorFeedback(String logId, String feedback) async {
    await _db.collection('logs').doc(logId).update({'mentorNotes': feedback});
  }

  Stream<List<LogModel>> streamStudentLogs(String studentId) {
    return _db.collection('logs')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
          final logs = snap.docs.map((doc) => LogModel.fromMap(doc.data(), doc.id)).toList();
          logs.sort((a, b) => b.date.compareTo(a.date));
          return logs;
        });
  }

  Future<void> assignTask(TaskModel task) async {
    await _db.collection('tasks').add(task.toMap());
  }

  Future<void> updateTaskStatus(String taskId, String status, {String? url, String? type, int? mark}) async {
    Map<String, dynamic> data = {'status': status};
    if (url != null) data['submissionUrl'] = url;
    if (type != null) data['submissionType'] = type;
    if (mark != null) data['mark'] = mark;
    await _db.collection('tasks').doc(taskId).update(data);
  }

  Future<String> uploadTaskFile(String taskId, File file, String type) async {
    String extension = p.extension(file.path);
    String fileName = '${taskId}_${DateTime.now().millisecondsSinceEpoch}$extension';
    Reference ref = _storage.ref().child('submissions/$taskId/$fileName');
    UploadTask uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Stream<List<TaskModel>> streamStudentTasks(String studentId) {
    return _db.collection('tasks')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) {
          final tasks = snap.docs.map((doc) => TaskModel.fromMap(doc.data(), doc.id)).toList();
          tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return tasks;
        });
  }

  Stream<List<UserModel>> streamAllMentors() {
    return _db.collection('users')
        .where('role', isEqualTo: 'mentor')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<LogModel>> streamAllLogsForMentor(String mentorId, List<String> studentIds) {
    if (studentIds.isEmpty) return Stream.value([]);
    return _db.collection('logs')
        .where('studentId', whereIn: studentIds)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => LogModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<UserModel>> streamAssignedStudents(String mentorId) {
    return _db.collection('users')
        .where('role', isEqualTo: 'student')
        .where('mentorIds', arrayContains: mentorId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> markAttendance(String studentId, bool isPresent) async {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    var snap = await _db.collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .get();
        
    if (snap.docs.isEmpty) {
      await _db.collection('attendance').add({
        'studentId': studentId,
        'date': Timestamp.fromDate(today),
        'isPresent': isPresent,
      });
    }
  }

  Stream<List<AttendanceModel>> streamStudentAttendance(String studentId) {
    return _db.collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AttendanceModel.fromMap(doc.data(), doc.id)).toList());
  }

  String getChatRoomId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> sendMessage(String senderId, String receiverId, String message) async {
    String roomId = getChatRoomId(senderId, receiverId);
    await _db.collection('chat_rooms').doc(roomId).collection('messages').add({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ChatMessageModel>> streamMessages(String uid1, String uid2) {
    String roomId = getChatRoomId(uid1, uid2);
    return _db.collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id)).toList());
  }
}
