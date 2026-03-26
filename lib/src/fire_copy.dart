import 'package:cloud_firestore/cloud_firestore.dart';

/// Copy documents between Firestore collections.
class FireCopy {
  FireCopy._();

  /// Copy one document from [from] path to [to] path.
  static Future<void> one({required String from, required String to}) async {
    final snap = await FirebaseFirestore.instance.doc(from).get();
    if (!snap.exists) return;
    await FirebaseFirestore.instance.doc(to).set(snap.data()!);
  }

  /// Copy all documents from collection [from] to collection [to].
  static Future<void> all({required String from, required String to}) async {
    final db = FirebaseFirestore.instance;
    final snap = await db.collection(from).get();
    final batch = db.batch();
    for (final doc in snap.docs) {
      batch.set(db.collection(to).doc(doc.id), doc.data(), SetOptions(merge: true));
    }
    await batch.commit();
  }
}
