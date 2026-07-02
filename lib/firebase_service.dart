import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
      
      // Check if user exists in Firestore
      final userDoc = await _db.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        UserModel newUser = UserModel(
          uid: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? 'New User',
          email: userCredential.user!.email ?? '',
          role: 'student', // Default
          mentorIds: [],
        );
        await _db.collection('users').doc(userCredential.user!.uid).set(newUser.toMap());
      }
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
    await _db.collection('users').doc(uid).update(data);
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

  Future<void> updateTaskStatus(String taskId, String status) async {
    await _db.collection('tasks').doc(taskId).update({'status': status});
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

  Stream<List<UserModel>> streamAssignedStudents(String mentorId) {
    return _db.collection('users')
        .where('role', isEqualTo: 'student')
        .where('mentorIds', arrayContains: mentorId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
  }
}
