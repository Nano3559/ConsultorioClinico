import 'package:cloud_firestore/cloud_firestore.dart';

/// Capa de acceso a Cloud Firestore.
///
/// Los documentos se guardan con la MISMA forma que el JSON que devolvía el
/// backend (snake_case: `paciente_id`, `medico_id`, `fecha`, `hora`, etc.) para
/// poder reutilizar los `fromApi` de los modelos sin modificarlos.
///
/// Para que los modelos parseen fechas correctamente, los `Timestamp` de
/// Firestore se convierten a cadenas ISO antes de entregarlos.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getList(
    String collection, {
    String? scopeField,
    String? scopeValue,
    String? orderBy,
    bool desc = false,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(collection);
    if (scopeField != null && scopeValue != null) {
      q = q.where(scopeField, isEqualTo: scopeValue);
    }
    if (orderBy != null) q = q.orderBy(orderBy, descending: desc);
    final snap = await q.get();
    return snap.docs.map(_normalize).toList();
  }

  Map<String, dynamic> _normalize(DocumentSnapshot<Map<String, dynamic>> doc) {
    final raw = doc.data() ?? {};
    final data = <String, dynamic>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      data[entry.key] = v is Timestamp ? v.toDate().toIso8601String() : v;
    }
    data['id'] = doc.id;
    return data;
  }

  Future<Map<String, dynamic>> getById(String collection, String id) async {
    final doc = await _db.collection(collection).doc(id).get();
    if (!doc.exists) return {};
    return _normalize(doc);
  }

  Future<String> add(String collection, Map<String, dynamic> data) async {
    final ref = await _db.collection(collection).add(_strip(data));
    return ref.id;
  }

  Future<void> set(String collection, String id, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(id).set(_strip(data));
  }

  Future<void> update(String collection, String id, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(id).update(_strip(data));
  }

  Future<void> delete(String collection, String id) async {
    await _db.collection(collection).doc(id).delete();
  }

  Map<String, dynamic> _strip(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((k, v) {
      if (k == 'id') return;
      if (v != null) out[k] = v;
    });
    return out;
  }
}
