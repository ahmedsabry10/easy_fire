# easy_fire 🔥

**The simplest way to do CRUD on Firestore.**  
One class. Any model. Any path. Infinite nesting. Zero boilerplate.

[![pub.dev](https://img.shields.io/badge/pub.dev-easy__fire-blue)](https://pub.dev/packages/easy_fire)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Why easy_fire?

Before easy_fire, every collection needed its own static methods:

```dart
// ❌ OLD WAY — 60+ lines per collection, hard to reuse
static CollectionReference<Task> getTasksCollection() { ... }
static Future<void> insertTask(Task task) { ... }
static Future<List<Task>> getTasks(DateTime dateTime) { ... }
static Future<void> deleteTask(Task task) { ... }
static Stream<QuerySnapshot<Task>> getTasksRealTimeUpdate(...) { ... }
static Future<void> markAsDone(Task task) { ... }
static Future<void> update(Task task, String title, ...) { ... }
```

With easy_fire, any collection is **3 lines of setup** then simple method calls:

```dart
// ✅ NEW WAY — 3 lines setup, works for any model
final tasks = FireCollection<Task>(
  path:    'tasks',
  fromMap: Task.fromMap,
  toMap:   (t) => t.toMap(),
);

await tasks.add(task, setId: (t, id) => t.id = id);   // insert
tasks.streamAll();                                      // real-time
await tasks.patch(id, {'isDone': true});               // edit 
await tasks.delete(id);                                // delete
```

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  easy_fire:
    git:
      url: https://github.com/ahmedsabry10/easy_fire.git
```

Then run:
```bash
flutter pub get
```

Single import in any file:
```dart
import 'package:easy_fire/easy_fire.dart';
```

---

## Complete CRUD cheat sheet

```dart
final col = FireCollection<MyModel>(
  path:    'myCollection',          // or nested: 'a/id1/b/id2/c'
  fromMap: MyModel.fromMap,
  toMap:   (m) => m.toMap(),
);

// ── CREATE ────────────────────────────────────────────────────────
await col.add(model, setId: (m, id) => m.id = id);  // auto ID
await col.set('custom-id', model);                   // specific ID

// ── READ (one-time) ───────────────────────────────────────────────
final one  = await col.getById('abc123');
final all  = await col.getAll();

// ── STREAM (real-time) ─── use inside StreamBuilder ───────────────
col.streamAll();                                      // all docs
col.streamWhere('field', value);                     // filtered
col.streamBetween('dateTime', from: ms1, to: ms2);  // date range

// ── UPDATE ────────────────────────────────────────────────────────
await col.update('abc123', model);                   // full overwrite
await col.patch('abc123', {'price': '99'});          // partial ✅

// ── DELETE ────────────────────────────────────────────────────────
await col.delete('abc123');

// ── SEARCH ───────────────────────────────────────────────────────
col.search('name', 'Sam');                           // starts with

// ── HELPERS ──────────────────────────────────────────────────────
await col.exists('email', 'a@b.com');               // true/false
await col.count('isDone', true);                    // int

// ── ADVANCED QUERY ────────────────────────────────────────────────
await col.query()
    .where('category', 'phones')
    .whereBetween('price', from: 100, to: 500)
    .orderBy('name')
    .limit(20)
    .fetch();                                        // or .stream()
```

---

## Nested collections with `.sub()`

Use `.sub(docId, collectionName)` to go deeper into any sub-collection.  
**You can nest as many levels as you need.**

```dart
// electronics/{catId}/products/{productId}/sub_products/...
final col = FireCollection<ElectronicCategory>(
  path: 'electronics', ...
);

// one level deeper
final products = col.sub('catId', 'products', fromMap: ..., toMap: ...);

// two levels deeper
final subProducts = products.sub('productId', 'sub_products', fromMap: ..., toMap: ...);
```

---

## Real-world example — E-commerce with 5 levels

### Your models

Each model only needs `fromMap` + `toMap` + `collectionName`:

```dart
class ElectronicCategory {
  static const collectionName = 'electronics';
  String id, name, imageUrl;

  ElectronicCategory({this.id = '', required this.name, this.imageUrl = ''});

  factory ElectronicCategory.fromMap(Map<String, dynamic> d) =>
      ElectronicCategory(id: d['id'] ?? '', name: d['name'] ?? '', imageUrl: d['imageUrl'] ?? '');

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'imageUrl': imageUrl};
}

class ElectronicProduct {
  static const collectionName = 'products';
  String id, name, price;

  ElectronicProduct({this.id = '', required this.name, required this.price});

  factory ElectronicProduct.fromMap(Map<String, dynamic> d) =>
      ElectronicProduct(id: d['id'] ?? '', name: d['name'] ?? '', price: d['price'] ?? '');

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'price': price};
}

class ElectronicSubProduct {
  static const collectionName = 'sub_products';
  String id, name, color;

  ElectronicSubProduct({this.id = '', required this.name, required this.color});

  factory ElectronicSubProduct.fromMap(Map<String, dynamic> d) =>
      ElectronicSubProduct(id: d['id'] ?? '', name: d['name'] ?? '', color: d['color'] ?? '');

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'color': color};
}

class ElectronicSubSubProduct {
  static const collectionName = 'sub_sub_products';
  String id, storage, price;

  ElectronicSubSubProduct({this.id = '', required this.storage, required this.price});

  factory ElectronicSubSubProduct.fromMap(Map<String, dynamic> d) =>
      ElectronicSubSubProduct(id: d['id'] ?? '', storage: d['storage'] ?? '', price: d['price'] ?? '');

  Map<String, dynamic> toMap() => {'id': id, 'storage': storage, 'price': price};
}

class ElectronicVariant {
  static const collectionName = 'variants';
  String id, sku, stock;

  ElectronicVariant({this.id = '', required this.sku, required this.stock});

  factory ElectronicVariant.fromMap(Map<String, dynamic> d) =>
      ElectronicVariant(id: d['id'] ?? '', sku: d['sku'] ?? '', stock: d['stock'] ?? '');

  Map<String, dynamic> toMap() => {'id': id, 'sku': sku, 'stock': stock};
}
```

---

### MyDatabase — all 5 levels

```dart
import 'package:easy_fire/easy_fire.dart';

// Firestore structure:
// electronics/                              ← Level 1: Category   (e.g. Phones)
//   {catId}/
//     products/                             ← Level 2: Product    (e.g. Samsung)
//       {productId}/
//         sub_products/                     ← Level 3: SubProduct (e.g. Samsung S25)
//           {subProductId}/
//             sub_sub_products/             ← Level 4: Color variant (e.g. Black)
//               {subSubProductId}/
//                 variants/                 ← Level 5: Storage/SKU (e.g. 256GB)

class MyDatabase {

  // ── Level 1: Categories ───────────────────────────────────────────────────
  final electronics = FireCollection<ElectronicCategory>(
    path:    ElectronicCategory.collectionName,
    fromMap: ElectronicCategory.fromMap,
    toMap:   (c) => c.toMap(),
  );

  // ── Level 2: Products ─────────────────────────────────────────────────────
  FireCollection<ElectronicProduct> productsOf(String catId) =>
      electronics.sub(
        catId,
        ElectronicProduct.collectionName,
        fromMap: ElectronicProduct.fromMap,
        toMap:   (p) => p.toMap(),
      );

  // ── Level 3: SubProducts ──────────────────────────────────────────────────
  FireCollection<ElectronicSubProduct> subProductsOf(
          String catId, String productId) =>
      productsOf(catId).sub(
        productId,
        ElectronicSubProduct.collectionName,
        fromMap: ElectronicSubProduct.fromMap,
        toMap:   (s) => s.toMap(),
      );

  // ── Level 4: SubSubProducts ───────────────────────────────────────────────
  FireCollection<ElectronicSubSubProduct> subSubProductsOf(
          String catId, String productId, String subProductId) =>
      subProductsOf(catId, productId).sub(
        subProductId,
        ElectronicSubSubProduct.collectionName,
        fromMap: ElectronicSubSubProduct.fromMap,
        toMap:   (s) => s.toMap(),
      );

  // ── Level 5: Variants ─────────────────────────────────────────────────────
  FireCollection<ElectronicVariant> variantsOf(
          String catId, String productId,
          String subProductId, String subSubProductId) =>
      subSubProductsOf(catId, productId, subProductId).sub(
        subSubProductId,
        ElectronicVariant.collectionName,
        fromMap: ElectronicVariant.fromMap,
        toMap:   (v) => v.toMap(),
      );
}
```

---

### Full usage — INSERT / SHOW / EDIT / DELETE on every level

```dart
final db = MyDatabase();

// ════════════════════════════════════════════════════════════
//  LEVEL 1 — Categories
// ════════════════════════════════════════════════════════════

// INSERT
final phones = ElectronicCategory(name: 'Phones', imageUrl: 'https://...');
await db.electronics.add(phones, setId: (c, id) => c.id = id);

// SHOW all (one-time)
final allCats = await db.electronics.getAll();

// SHOW real-time (use in StreamBuilder)
db.electronics.streamAll();

// EDIT (partial — only change what you need)
await db.electronics.patch(phones.id, {'name': 'Smart Phones'});

// EDIT (full — replace entire document)
phones.name     = 'Smart Phones';
phones.imageUrl = 'https://new.png';
await db.electronics.update(phones.id, phones);

// DELETE
await db.electronics.delete(phones.id);


// ════════════════════════════════════════════════════════════
//  LEVEL 2 — Products
// ════════════════════════════════════════════════════════════

// INSERT
final samsung = ElectronicProduct(name: 'Samsung', price: '10000');
await db.productsOf(phones.id).add(samsung, setId: (p, id) => p.id = id);

// SHOW real-time
db.productsOf(phones.id).streamAll();

// EDIT (partial)
await db.productsOf(phones.id).patch(samsung.id, {'price': '9000'});

// DELETE
await db.productsOf(phones.id).delete(samsung.id);

// SEARCH by name
db.productsOf(phones.id).search('name', 'Sam');


// ════════════════════════════════════════════════════════════
//  LEVEL 3 — SubProducts
// ════════════════════════════════════════════════════════════

// INSERT
final s25 = ElectronicSubProduct(name: 'Samsung S25', color: 'Black');
await db.subProductsOf(phones.id, samsung.id)
        .add(s25, setId: (s, id) => s.id = id);

// SHOW real-time
db.subProductsOf(phones.id, samsung.id).streamAll();

// EDIT
await db.subProductsOf(phones.id, samsung.id)
        .patch(s25.id, {'color': 'Titanium'});

// DELETE
await db.subProductsOf(phones.id, samsung.id).delete(s25.id);


// ════════════════════════════════════════════════════════════
//  LEVEL 4 — SubSubProducts
// ════════════════════════════════════════════════════════════

// INSERT
final black256 = ElectronicSubSubProduct(storage: '256GB', price: '15000');
await db.subSubProductsOf(phones.id, samsung.id, s25.id)
        .add(black256, setId: (s, id) => s.id = id);

// SHOW real-time
db.subSubProductsOf(phones.id, samsung.id, s25.id).streamAll();

// EDIT
await db.subSubProductsOf(phones.id, samsung.id, s25.id)
        .patch(black256.id, {'price': '13000'});

// DELETE
await db.subSubProductsOf(phones.id, samsung.id, s25.id)
        .delete(black256.id);


// ════════════════════════════════════════════════════════════
//  LEVEL 5 — Variants
// ════════════════════════════════════════════════════════════

// INSERT
final sku = ElectronicVariant(sku: 'SAM-S25-BLK-256', stock: '50');
await db.variantsOf(phones.id, samsung.id, s25.id, black256.id)
        .add(sku, setId: (v, id) => v.id = id);

// SHOW real-time
db.variantsOf(phones.id, samsung.id, s25.id, black256.id).streamAll();

// EDIT
await db.variantsOf(phones.id, samsung.id, s25.id, black256.id)
        .patch(sku.id, {'stock': '35'});

// DELETE
await db.variantsOf(phones.id, samsung.id, s25.id, black256.id)
        .delete(sku.id);
```

---

### Use in StreamBuilder

```dart
// ANY level — just plug .streamAll() into the stream parameter

StreamBuilder<List<ElectronicProduct>>(
  stream: db.productsOf(selectedCatId).streamAll(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    final products = snapshot.data!;
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (_, i) => ListTile(
        title:    Text(products[i].name),
        subtitle: Text(products[i].price),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => db.productsOf(selectedCatId).delete(products[i].id),
        ),
      ),
    );
  },
)
```

---

## FireCopy — copy documents between collections

```dart
// copy one document
await FireCopy.one(
  from: 'electronics/catId/products/productId',
  to:   'orders/productId',
);

// copy all documents (batched — fast)
await FireCopy.all(
  from: 'electronics/catId/products',
  to:   'archive/catId/products',
);
```

---

## The `.sub()` rule — memorize this

| What you pass | What it means |
|---|---|
| First param | Document ID of the current level |
| Second param | Collection name of the NEW level |
| `fromMap` | How to read the new level's model |
| `toMap` | How to write the new level's model |

Each new level adds **exactly one new ID parameter** to the method signature.

---

## Package structure

```
lib/
├── easy_fire.dart          ← single import
└── src/
    ├── fire_collection.dart   ← FireCollection + FireQuery
    └── fire_copy.dart         ← FireCopy
```

---

## License

MIT © Ahmed Sabry