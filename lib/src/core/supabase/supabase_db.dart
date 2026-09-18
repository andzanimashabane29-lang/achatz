import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Representation of a document snapshot for unified data access
class AppDocSnapshot {
  final String id;
  final Map<String, dynamic>? _data;
  final bool exists;

  AppDocSnapshot({required this.id, Map<String, dynamic>? data, required this.exists})
      : _data = data;

  Map<String, dynamic>? data() => _data;
  dynamic get(String field) => _data?[field];
}

/// Representation of a query snapshot for tables
class AppQuerySnapshot {
  final List<AppDocSnapshot> docs;
  AppQuerySnapshot(this.docs);

  bool get isEmpty => docs.isEmpty;
  bool get isNotEmpty => docs.isNotEmpty;
  int get size => docs.length;
}

/// Centralized Supabase Database & Realtime wrapper
class SupabaseDb {
  SupabaseDb._();
  static final SupabaseDb instance = SupabaseDb._();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Map legacy table names to normalized PostgreSQL table names
  String normalizeTable(String name) {
    switch (name) {
      case 'users':
        return 'profiles';
      case 'catalog':
        return 'catalog_items';
      case 'tokens':
        return 'user_push_tokens';
      case 'posts':
        return 'channel_posts';
      case 'candidates_offerer':
      case 'candidates_answerer':
        return 'call_candidates';
      case 'followers':
        return 'channel_followers';
      default:
        return name;
    }
  }

  /// Get a single record by table and ID
  Future<AppDocSnapshot> getDoc(String table, String id) async {
    final tableName = normalizeTable(table);
    try {
      final res = await _client
          .from(tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (res == null) {
        return AppDocSnapshot(id: id, data: null, exists: false);
      }
      return AppDocSnapshot(id: id, data: Map<String, dynamic>.from(res), exists: true);
    } catch (e) {
      debugPrint('SupabaseDb.getDoc error on $tableName/$id: $e');
      return AppDocSnapshot(id: id, data: null, exists: false);
    }
  }

  /// Listen to a single record in real-time
  Stream<AppDocSnapshot> watchDoc(String table, String id) {
    final tableName = normalizeTable(table);
    return _client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((list) {
          if (list.isEmpty) {
            return AppDocSnapshot(id: id, data: null, exists: false);
          }
          return AppDocSnapshot(
            id: id,
            data: Map<String, dynamic>.from(list.first),
            exists: true,
          );
        });
  }

  /// Listen to a table or filtered list in real-time
  Stream<List<Map<String, dynamic>>> watchCollection(
    String table, {
    String? field,
    dynamic isEqualTo,
  }) {
    final tableName = normalizeTable(table);
    var stream = _client.from(tableName).stream(primaryKey: ['id']);
    if (field != null && isEqualTo != null) {
      stream = stream.eq(field, isEqualTo);
    }
    return stream.map((list) => list.map((e) => Map<String, dynamic>.from(e)).toList());
  }

  /// Upsert or set document
  Future<void> setDoc(String table, String id, Map<String, dynamic> data, {bool merge = true}) async {
    final tableName = normalizeTable(table);
    final row = Map<String, dynamic>.from(data);
    row['id'] = id;
    row.removeWhere((k, v) => v == null && !merge);
    try {
      await _client.from(tableName).upsert(row);
    } catch (e) {
      debugPrint('SupabaseDb.setDoc error on $tableName/$id: $e');
      rethrow;
    }
  }

  /// Update document
  Future<void> updateDoc(String table, String id, Map<String, dynamic> data) async {
    final tableName = normalizeTable(table);
    try {
      await _client.from(tableName).update(data).eq('id', id);
    } catch (e) {
      debugPrint('SupabaseDb.updateDoc error on $tableName/$id: $e');
      rethrow;
    }
  }

  /// Delete document
  Future<void> deleteDoc(String table, String id) async {
    final tableName = normalizeTable(table);
    try {
      await _client.from(tableName).delete().eq('id', id);
    } catch (e) {
      debugPrint('SupabaseDb.deleteDoc error on $tableName/$id: $e');
      rethrow;
    }
  }

  /// Insert document and return generated ID
  Future<String> insertDoc(String table, Map<String, dynamic> data) async {
    final tableName = normalizeTable(table);
    try {
      final res = await _client.from(tableName).insert(data).select('id').single();
      return (res['id'] ?? '').toString();
    } catch (e) {
      debugPrint('SupabaseDb.insertDoc error on $tableName: $e');
      rethrow;
    }
  }

  /// Query multiple records once
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? field,
    dynamic isEqualTo,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    final tableName = normalizeTable(table);
    try {
      dynamic queryBuilder = _client.from(tableName).select();
      if (field != null && isEqualTo != null) {
        queryBuilder = queryBuilder.eq(field, isEqualTo);
      }
      if (orderBy != null) {
        queryBuilder = queryBuilder.order(orderBy, ascending: ascending);
      }
      if (limit != null) {
        queryBuilder = queryBuilder.limit(limit);
      }
      final res = await queryBuilder;
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('SupabaseDb.query error on $tableName: $e');
      return [];
    }
  }

  /// Upload file to Supabase Storage and return its public URL
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required dynamic file, // File, Uint8List, or String filePath
    String? contentType,
  }) async {
    try {
      final storage = _client.storage.from(bucket);
      if (file is Uint8List) {
        await storage.uploadBinary(
          path,
          file,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      } else if (file is File) {
        await storage.upload(
          path,
          file,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      } else if (file is String) {
        await storage.upload(
          path,
          File(file),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
      }
      return storage.getPublicUrl(path);
    } catch (e) {
      debugPrint('SupabaseDb.uploadFile error on $bucket/$path: $e');
      return _client.storage.from(bucket).getPublicUrl(path);
    }
  }
}
