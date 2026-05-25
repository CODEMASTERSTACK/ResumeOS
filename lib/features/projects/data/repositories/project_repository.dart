import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/firebase_providers.dart';
import '../../../../features/projects/domain/entities/project_model.dart';

class ProjectRepository {
  final FirebaseFirestore _db;

  ProjectRepository(this._db);

  Stream<List<ProjectModel>> watchProjects(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProjectModel.fromFirestore(d))
            .toList());
  }

  Future<ProjectModel?> getProject(String uid, String projectId) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .doc(projectId)
        .get();
    if (!doc.exists) return null;
    return ProjectModel.fromFirestore(doc);
  }

  Future<List<ProjectModel>> getAllProjects(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => ProjectModel.fromFirestore(d)).toList();
  }

  Future<String> addProject(
      String uid, ProjectModel project) async {
    final ref = await _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .add({
      ...project.toJson()..remove('id')..remove('uid'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateProject(
      String uid, String projectId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .doc(projectId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteProject(String uid, String projectId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .doc(projectId)
        .delete();
  }

  Future<void> saveAiSummary(
      String uid, String projectId, String summary, List<String> bullets) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('projects')
        .doc(projectId)
        .update({
      'aiSummary': summary,
      'bulletPoints': bullets,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(firestoreProvider));
});
