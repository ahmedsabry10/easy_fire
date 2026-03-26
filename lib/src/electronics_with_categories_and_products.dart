import 'package:easy_fire/easy_fire.dart';

// ════════════════════════════════════════════════════════════════════════════
//  YOUR MODELS  (you already have these, just need fromMap + toMap)
// ════════════════════════════════════════════════════════════════════════════

class ElectronicCategory {
  String id;
  String name;
  String imageUrl;

  ElectronicCategory({this.id = '', required this.name, this.imageUrl = ''});

  factory ElectronicCategory.fromMap(Map<String, dynamic> d) =>
      ElectronicCategory(id: d['id'] ?? '', name: d['name'] ?? '', imageUrl: d['imageUrl'] ?? '');

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'imageUrl': imageUrl};
}

class ElectronicProduct {
  String id;
  String name;
  String price;
  String description;
  String imageUrl;

  ElectronicProduct({
    this.id = '',
    required this.name,
    required this.price,
    this.description = '',
    this.imageUrl = '',
  });

  factory ElectronicProduct.fromMap(Map<String, dynamic> d) => ElectronicProduct(
        id: d['id'] ?? '',
        name: d['name'] ?? '',
        price: d['price'] ?? '',
        description: d['description'] ?? '',
        imageUrl: d['imageUrl'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'description': description,
        'imageUrl': imageUrl,
      };
}

// ════════════════════════════════════════════════════════════════════════════
//  STEP 1 — CREATE YOUR COLLECTIONS  (just 3 lines each)
// ════════════════════════════════════════════════════════════════════════════

// top-level Electronics collection
// Firestore path →  electronics
final electronics = FireCollection<ElectronicCategory>(
  path:    'electronics',
  fromMap: ElectronicCategory.fromMap,
  toMap:   (c) => c.toMap(),
);

// products inside a category — use .sub() to go deeper
// Firestore path →  electronics/{catId}/products
FireCollection<ElectronicProduct> productsOf(String catId) =>
    electronics.sub(
      catId,
      'products',
      fromMap: ElectronicProduct.fromMap,
      toMap:   (p) => p.toMap(),
    );

// ════════════════════════════════════════════════════════════════════════════
//  STEP 2 — USE IT  (insert / show / edit / delete)
// ════════════════════════════════════════════════════════════════════════════

void exampleUsage() async {

  // ── CATEGORIES ─────────────────────────────────────────────────────────────

  // INSERT a category
  final phones = ElectronicCategory(name: 'Phones', imageUrl: 'https://...');
  await electronics.add(phones, setId: (c, id) => c.id = id);
  // ✅ Firestore: electronics/{auto-id}  →  {id, name: 'Phones', imageUrl}

  // INSERT another category
  final laptops = ElectronicCategory(name: 'Laptops');
  await electronics.add(laptops, setId: (c, id) => c.id = id);
  // ✅ Firestore: electronics/{auto-id}  →  {id, name: 'Laptops'}

  // SHOW all categories (one-time)
  final allCats = await electronics.getAll();
  print(allCats.map((c) => c.name)); // (Phones, Laptops)

  // SHOW all categories (real-time StreamBuilder)
  // electronics.streamAll()  ← use this in your StreamBuilder

  // EDIT a category (partial — only change what you need)
  await electronics.patch(phones.id, {'name': 'Smart Phones', 'imageUrl': 'https://new.png'});

  // DELETE a category
  await electronics.delete(laptops.id);


  // ── PRODUCTS inside a category ─────────────────────────────────────────────

  // INSERT a product inside 'Phones' category
  final samsung = ElectronicProduct(name: 'Samsung S24', price: '15000', description: '6.2 inch');
  await productsOf(phones.id).add(samsung, setId: (p, id) => p.id = id);
  // ✅ Firestore: electronics/{phonesId}/products/{auto-id}

  // INSERT another product
  final iphone = ElectronicProduct(name: 'iPhone 15', price: '25000');
  await productsOf(phones.id).add(iphone, setId: (p, id) => p.id = id);

  // SHOW all products in Phones (one-time)
  final allProducts = await productsOf(phones.id).getAll();
  print(allProducts.map((p) => p.name)); // (Samsung S24, iPhone 15)

  // SHOW products (real-time StreamBuilder)
  // productsOf(phones.id).streamAll()  ← use this in your StreamBuilder

  // EDIT a product (partial)
  await productsOf(phones.id).patch(samsung.id, {'price': '12000'});

  // EDIT a product (full)
  samsung.name  = 'Samsung S24 Ultra';
  samsung.price = '18000';
  await productsOf(phones.id).update(samsung.id, samsung);

  // DELETE a product
  await productsOf(phones.id).delete(iphone.id);

  // SEARCH products by name
  // productsOf(phones.id).search('name', 'Sam')  ← real-time stream

}

// ════════════════════════════════════════════════════════════════════════════
//  STEP 3 — USE IN STREAMBUILDER  (just swap streamAll() in)
// ════════════════════════════════════════════════════════════════════════════

// ── Categories screen ────────────────────────────────────────────────────────
//
// StreamBuilder<List<ElectronicCategory>>(
//   stream: electronics.streamAll(),          // ← from package
//   builder: (context, snapshot) {
//     if (!snapshot.hasData) return CircularProgressIndicator();
//     final cats = snapshot.data!;
//     return GridView.builder(
//       itemCount: cats.length,
//       itemBuilder: (_, i) => CategoryCard(cat: cats[i]),
//     );
//   },
// )

// ── Products screen ──────────────────────────────────────────────────────────
//
// StreamBuilder<List<ElectronicProduct>>(
//   stream: productsOf(selectedCategoryId).streamAll(),   // ← from package
//   builder: (context, snapshot) {
//     if (!snapshot.hasData) return CircularProgressIndicator();
//     final products = snapshot.data!;
//     return ListView.builder(
//       itemCount: products.length,
//       itemBuilder: (_, i) => ProductCard(product: products[i]),
//     );
//   },
// )

// ════════════════════════════════════════════════════════════════════════════
//  FULL CHEAT SHEET
// ════════════════════════════════════════════════════════════════════════════
//
//  INSERT   →  collection.add(model, setId: (m, id) => m.id = id)
//  GET ALL  →  collection.getAll()
//  GET ONE  →  collection.getById('id')
//  STREAM   →  collection.streamAll()                    ← for StreamBuilder
//  FILTER   →  collection.streamWhere('field', value)    ← real-time filter
//  SEARCH   →  collection.search('field', 'prefix')      ← real-time search
//  EDIT     →  collection.patch('id', {'field': value})  ← partial update
//  EDIT     →  collection.update('id', model)            ← full update
//  DELETE   →  collection.delete('id')
//  SUB-COL  →  collection.sub('docId', 'subName', fromMap:..., toMap:...)
