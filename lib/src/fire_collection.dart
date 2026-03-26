import 'package:cloud_firestore/cloud_firestore.dart';

/// The only class you need from easy_fire.
///
/// Give it:
///  - [path]    → the Firestore collection path (simple or nested)
///  - [fromMap] → how to turn Firestore data into your model
///  - [toMap]   → how to turn your model into Firestore data
///
/// Then call .add() .getAll() .streamAll() .update() .patch() .delete()
/// on it — no extra setup, no static methods, no boilerplate.
class FireCollection<T> {
  final String _path;
  final T Function(Map<String, dynamic>) _fromMap;
  final Map<String, dynamic> Function(T) _toMap;

  FireCollection({
    required String path,
    required T Function(Map<String, dynamic> data) fromMap,
    required Map<String, dynamic> Function(T model) toMap,
  })  : _path = path,
        _fromMap = fromMap,
        _toMap = toMap;

  // ── internal: builds the typed CollectionReference from any path ────────────
  CollectionReference<T> get _col {
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();
    assert(segments.isNotEmpty && segments.length.isOdd,
        'path must end on a collection, e.g. "electronics" or '
        '"electronics/cat1/products"');

    CollectionReference? col;
    DocumentReference? doc;
    for (int i = 0; i < segments.length; i++) {
      if (i.isEven) {
        col = doc == null
            ? FirebaseFirestore.instance.collection(segments[i])
            : doc.collection(segments[i]);
      } else {
        doc = col!.doc(segments[i]);
      }
    }
    return col!.withConverter<T>(
      fromFirestore: (snap, _) => _fromMap(snap.data()!),
      toFirestore: (model, _) => _toMap(model),
    );
  }

  // ── sub-collection shortcut ─────────────────────────────────────────────────

  /// Returns a child [FireCollection] nested under a document.
  ///
  /// ```dart
  /// // electronics → categories → products
  /// final electronics = FireCollection<Electronics>( path: 'electronics', ... );
  /// final cats  = electronics.sub('cat-id-123', 'categories', fromMap: ..., toMap: ...);
  /// final prods = cats.sub('cat-id-123', 'products', fromMap: ..., toMap: ...);
  /// ```
  FireCollection<S> sub<S>(
    String documentId,
    String subCollectionName, {
    required S Function(Map<String, dynamic>) fromMap,
    required Map<String, dynamic> Function(S) toMap,
  }) {
    return FireCollection<S>(
      path: '$_path/$documentId/$subCollectionName',
      fromMap: fromMap,
      toMap: toMap,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CREATE
  // ══════════════════════════════════════════════════════════════════════════

  /// Adds a document with an **auto-generated ID**.
  /// Pass [setId] to store the generated ID back in your model.
  ///
  /// ```dart
  /// await electronics.add(item, setId: (e, id) => e.id = id);
  /// ```
  Future<T> add(T model, {required void Function(T model, String id) setId}) async {
    final ref = _col.doc();
    setId(model, ref.id);
    await ref.set(model);
    return model;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  READ
  // ══════════════════════════════════════════════════════════════════════════

  /// Gets one document by ID. Returns null if not found.
  ///
  /// ```dart
  /// final item = await electronics.getById('abc123');
  /// ```
  Future<T?> getById(String id) async => (await _col.doc(id).get()).data();

  /// Gets all documents (one-time fetch).
  ///
  /// ```dart
  /// final all = await electronics.getAll();
  /// ```
  Future<List<T>> getAll() async =>
      (await _col.get()).docs.map((d) => d.data()).toList();

  // ══════════════════════════════════════════════════════════════════════════
  //  STREAM  (real-time)
  // ══════════════════════════════════════════════════════════════════════════

  /// Real-time stream of ALL documents. Use in StreamBuilder.
  ///
  /// ```dart
  /// electronics.streamAll().listen((list) { ... });
  /// ```
  Stream<List<T>> streamAll() =>
      _col.snapshots().map((s) => s.docs.map((d) => d.data()).toList());

  /// Real-time stream filtered by [field] == [value].
  ///
  /// ```dart
  /// electronics.streamWhere('category', 'phones').listen((list) { ... });
  /// ```
  Stream<List<T>> streamWhere(String field, dynamic value) => _col
      .where(field, isEqualTo: value)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  /// Real-time stream filtered between two values (great for dates).
  ///
  /// ```dart
  /// orders.streamBetween('dateTime', from: startMs, to: endMs)
  /// ```
  Stream<List<T>> streamBetween(String field,
          {required dynamic from, required dynamic to}) =>
      _col
          .where(field, isGreaterThanOrEqualTo: from)
          .where(field, isLessThanOrEqualTo: to)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());

  // ══════════════════════════════════════════════════════════════════════════
  //  UPDATE
  // ══════════════════════════════════════════════════════════════════════════

  /// Fully replaces a document (all fields overwritten).
  ///
  /// ```dart
  /// item.name = 'New name';
  /// await electronics.update(item.id, item);
  /// ```
  Future<void> update(String id, T model) => _col.doc(id).set(model);

  /// Partially updates only the fields you pass — no model needed.
  ///
  /// ```dart
  /// await electronics.patch('abc123', {'price': '999', 'name': 'TV'});
  /// ```
  Future<void> patch(String id, Map<String, dynamic> fields) =>
      _col.doc(id).update(fields);

  // ══════════════════════════════════════════════════════════════════════════
  //  DELETE
  // ══════════════════════════════════════════════════════════════════════════

  /// Deletes a document by ID.
  ///
  /// ```dart
  /// await electronics.delete('abc123');
  /// ```
  Future<void> delete(String id) => _col.doc(id).delete();

  // ══════════════════════════════════════════════════════════════════════════
  //  SEARCH & QUERY
  // ══════════════════════════════════════════════════════════════════════════

  /// Real-time search: finds documents where [field] starts with [prefix].
  ///
  /// ```dart
  /// electronics.search('name', 'Sam').listen((list) { ... });
  /// ```
  Stream<List<T>> search(String field, String prefix) {
    if (prefix.isEmpty) return streamAll();
    final end = prefix.substring(0, prefix.length - 1) +
        String.fromCharCode(prefix.codeUnitAt(prefix.length - 1) + 1);
    return _col
        .where(field, isGreaterThanOrEqualTo: prefix)
        .where(field, isLessThan: end)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  /// Advanced chained query. Call .fetch() or .stream() at the end.
  ///
  /// ```dart
  /// await electronics.query()
  ///     .where('category', 'phones')
  ///     .orderBy('price')
  ///     .limit(10)
  ///     .fetch();
  /// ```
  FireQuery<T> query() => FireQuery<T>(_col);

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns true if any document has [field] == [value].
  Future<bool> exists(String field, dynamic value) async =>
      (await _col.where(field, isEqualTo: value).limit(1).get()).docs.isNotEmpty;

  /// Counts documents where [field] == [value].
  Future<int> count(String field, dynamic value) async =>
      (await _col.where(field, isEqualTo: value).get()).docs.length;
}

// ─────────────────────────────────────────────────────────────────────────────
//  FireQuery — chained query builder
// ─────────────────────────────────────────────────────────────────────────────

class FireQuery<T> {
  Query<T> _q;
  FireQuery(CollectionReference<T> col) : _q = col;

  FireQuery<T> where(String field, dynamic value) {
    _q = _q.where(field, isEqualTo: value);
    return this;
  }

  FireQuery<T> whereNot(String field, dynamic value) {
    _q = _q.where(field, isNotEqualTo: value);
    return this;
  }

  FireQuery<T> whereBetween(String field,
      {required dynamic from, required dynamic to}) {
    _q = _q
        .where(field, isGreaterThanOrEqualTo: from)
        .where(field, isLessThanOrEqualTo: to);
    return this;
  }

  FireQuery<T> whereStartsWith(String field, String prefix) {
    if (prefix.isEmpty) return this;
    final end = prefix.substring(0, prefix.length - 1) +
        String.fromCharCode(prefix.codeUnitAt(prefix.length - 1) + 1);
    _q = _q
        .where(field, isGreaterThanOrEqualTo: prefix)
        .where(field, isLessThan: end);
    return this;
  }

  FireQuery<T> orderBy(String field, {bool descending = false}) {
    _q = _q.orderBy(field, descending: descending);
    return this;
  }

  FireQuery<T> limit(int count) {
    _q = _q.limit(count);
    return this;
  }

  Future<List<T>> fetch() async =>
      (await _q.get()).docs.map((d) => d.data()).toList();

  Stream<List<T>> stream() =>
      _q.snapshots().map((s) => s.docs.map((d) => d.data()).toList());
}
