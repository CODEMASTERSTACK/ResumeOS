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
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(firestoreProvider));
});
