import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../features/profile/domain/entities/user_model.dart';

class ProfileRepository {
  final FirebaseFirestore _db;

  ProfileRepository(this._db);

  // ── User Profile ───────────────────────────────────────

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(
          user.toJson()..remove('uid'),
        );
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Points History ────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchPointsHistory(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('points_history')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> addPointsTransaction(
    String uid, {
    required String title,
    required String description,
    required double points,
    required String type,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('points_history')
        .add({
      'title': title,
      'description': description,
      'points': points,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Skills ────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchSkills(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('skills')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> addSkill(String uid, String name, String category) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('skills')
        .add({
      'name': name,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSkill(
      String uid, String skillId, String newName) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('skills')
        .doc(skillId)
        .update({'name': newName});
  }

  Future<void> deleteSkill(String uid, String skillId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('skills')
        .doc(skillId)
        .delete();
  }

  // ── Education ─────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchEducation(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('education')
        .orderBy('endYear', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> addEducation(
      String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('education')
        .add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateEducation(
      String uid, String id, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('education')
        .doc(id)
        .update(data);
  }

  Future<void> deleteEducation(String uid, String id) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('education')
        .doc(id)
        .delete();
  }

  // ── Experience ────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchExperience(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('experience')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> addExperience(
      String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('experience')
        .add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateExperience(
      String uid, String id, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('experience')
        .doc(id)
        .update(data);
  }

  Future<void> deleteExperience(String uid, String id) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('experience')
        .doc(id)
        .delete();
  }

  // ── Certifications ────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchCertifications(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('certifications')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> addCertification(
      String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('certifications')
        .add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateCertification(
      String uid, String id, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('certifications')
        .doc(id)
        .update(data);
  }

  Future<void> deleteCertification(String uid, String id) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('certifications')
        .doc(id)
        .delete();
  }

  // ── Achievements ──────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchAchievements(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> addAchievement(
      String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateAchievement(
      String uid, String id, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(id)
        .update(data);
  }

  Future<void> deleteAchievement(String uid, String id) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(id)
        .delete();
  }

  // ── Profile Completion Score ──────────────────────────

  /// One-shot fetch (kept for backward compatibility)
  Future<int> getProfileCompletionPercent(String uid) async {
    int score = 0;
    const maxScore = 100;

    final user = await getUser(uid);
    if (user == null) return 0;

    if (user.name.isNotEmpty) score += 10;
    if (user.email.isNotEmpty) score += 5;
    if (user.phone.isNotEmpty) score += 5;
    if (user.summary.isNotEmpty) score += 15;
    if (user.githubUrl.isNotEmpty) score += 5;
    if (user.linkedinUrl.isNotEmpty) score += 5;

    final skills = await _db
        .collection('users')
        .doc(uid)
        .collection('skills')
        .count()
        .get();
    if ((skills.count ?? 0) >= 5) score += 15;

    final edu = await _db
        .collection('users')
        .doc(uid)
        .collection('education')
        .count()
        .get();
    if ((edu.count ?? 0) >= 1) score += 15;

    final proj = await _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .count()
        .get();
    if ((proj.count ?? 0) >= 1) score += 15;
    if ((proj.count ?? 0) >= 3) score += 10;

    return (score * 100 / maxScore).round().clamp(0, 100);
  }

  /// Real-time stream — emits a fresh score whenever the user document,
  /// skills, education, or projects subcollection changes.
  /// Uses a pure-Dart [StreamController] to combine all 4 live Firestore
  /// streams without any extra packages.
  Stream<int> watchProfileCompletionPercent(String uid) {
    final userRef = _db.collection('users').doc(uid);
    final skillsRef = userRef.collection('skills');
    final eduRef = userRef.collection('education');
    final projRef = userRef.collection('projects');

    // Mutable holders for the latest snapshot from each stream
    DocumentSnapshot? latestUser;
    QuerySnapshot? latestSkills;
    QuerySnapshot? latestEdu;
    QuerySnapshot? latestProj;

    late StreamController<int> controller;

    // Compute score from whatever snapshots are currently available
    int compute() {
      int score = 0;
      if (latestUser != null && latestUser!.exists) {
        final d = latestUser!.data() as Map<String, dynamic>? ?? {};
        if ((d['name'] as String? ?? '').isNotEmpty) score += 10;
        if ((d['email'] as String? ?? '').isNotEmpty) score += 5;
        if ((d['phone'] as String? ?? '').isNotEmpty) score += 5;
        if ((d['summary'] as String? ?? '').isNotEmpty) score += 15;
        if ((d['githubUrl'] as String? ?? '').isNotEmpty) score += 5;
        if ((d['linkedinUrl'] as String? ?? '').isNotEmpty) score += 5;
      }
      final skillCount = latestSkills?.docs.length ?? 0;
      if (skillCount >= 5) score += 15;
      final eduCount = latestEdu?.docs.length ?? 0;
      if (eduCount >= 1) score += 15;
      final projCount = latestProj?.docs.length ?? 0;
      if (projCount >= 1) score += 15;
      if (projCount >= 3) score += 10;
      return score.clamp(0, 100);
    }

    // Subscriptions for each source stream
    StreamSubscription<DocumentSnapshot>? userSub;
    StreamSubscription<QuerySnapshot>? skillsSub;
    StreamSubscription<QuerySnapshot>? eduSub;
    StreamSubscription<QuerySnapshot>? projSub;

    void cancelAll() {
      userSub?.cancel();
      skillsSub?.cancel();
      eduSub?.cancel();
      projSub?.cancel();
    }

    controller = StreamController<int>.broadcast(
      onListen: () {
        userSub = userRef.snapshots().listen(
          (snap) {
            latestUser = snap;
            if (!controller.isClosed) controller.add(compute());
          },
          onError: (e) { if (!controller.isClosed) controller.addError(e); },
        );
        skillsSub = skillsRef.snapshots().listen(
          (snap) {
            latestSkills = snap;
            if (!controller.isClosed) controller.add(compute());
          },
          onError: (e) { if (!controller.isClosed) controller.addError(e); },
        );
        eduSub = eduRef.snapshots().listen(
          (snap) {
            latestEdu = snap;
            if (!controller.isClosed) controller.add(compute());
          },
          onError: (e) { if (!controller.isClosed) controller.addError(e); },
        );
        projSub = projRef.snapshots().listen(
          (snap) {
            latestProj = snap;
            if (!controller.isClosed) controller.add(compute());
          },
          onError: (e) { if (!controller.isClosed) controller.addError(e); },
        );
      },
      onCancel: () {
        cancelAll();
        controller.close();
      },
    );

    return controller.stream;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(firestoreProvider));
});
