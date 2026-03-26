# Changelog

All notable changes to `easy_fire` will be documented in this file.

---

## [1.0.0] - 2024-03-26

### 🎉 Initial Release

#### Added
- **`FireCollection<T>`** — the core class. One instance per Firestore collection.
  - `add(model, setId)` — insert with auto-generated ID
  - `set(id, model)` — insert with specific ID
  - `getById(id)` — fetch one document
  - `getAll()` — fetch all documents (one-time)
  - `streamAll()` — real-time stream of all documents
  - `streamWhere(field, value)` — real-time filtered stream
  - `streamBetween(field, from, to)` — real-time date range stream
  - `update(id, model)` — full document overwrite
  - `patch(id, fields)` — partial update (only the fields you pass)
  - `delete(id)` — delete a document
  - `search(field, prefix)` — real-time prefix search
  - `exists(field, value)` — check if document exists
  - `count(field, value)` — count matching documents
  - `query()` — returns a `FireQuery` for advanced chaining
  - `sub(docId, collectionName, fromMap, toMap)` — navigate into any sub-collection

- **`FireQuery<T>`** — fluent chainable query builder
  - `.where(field, value)` — equality filter
  - `.whereNot(field, value)` — not-equal filter
  - `.whereBetween(field, from, to)` — range filter
  - `.whereStartsWith(field, prefix)` — prefix text search
  - `.orderBy(field, descending)` — sort results
  - `.limit(count)` — limit number of results
  - `.fetch()` — one-time fetch
  - `.stream()` — real-time stream

- **`FireCopy`** — copy documents between Firestore collections
  - `FireCopy.one(from, to)` — copy a single document
  - `FireCopy.all(from, to)` — batch-copy all documents in a collection

#### Supported Firestore path formats
- Simple: `'tasks'`
- Nested: `'countries/eg/cities/cairo/products'`
- Deeply nested via `.sub()`: unlimited levels

---

## [Unreleased]

### Planned
- `addAll(List<T>)` — batch insert multiple documents
- `deleteWhere(field, value)` — delete all matching documents
- `onError` callback support for streams
- Offline persistence helpers
- Unit test coverage