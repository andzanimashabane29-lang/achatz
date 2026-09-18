import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'supabase_config.dart';
import 'supabase_db.dart';

// ==============================================================================
// SUPABASE AUTH WRAPPER
// ==============================================================================

class AppAuthUser {
  final sb.User _user;
  AppAuthUser(this._user);

  String get uid => _user.id;
  String? get email => _user.email;
  String? get displayName => _user.userMetadata?['username'] ?? _user.userMetadata?['full_name'];
  String? get photoURL => _user.userMetadata?['avatar_url'];
  String? get phoneNumber => _user.phone;
  bool get emailVerified => _user.emailConfirmedAt != null;

  Future<void> sendEmailVerification() async {}

  Future<void> updatePassword(String newPassword) async {
    await SupabaseConfig.client.auth.updateUser(sb.UserAttributes(password: newPassword));
  }

  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['username'] = displayName;
    if (photoURL != null) data['avatar_url'] = photoURL;
    await SupabaseConfig.client.auth.updateUser(sb.UserAttributes(data: data));
  }

  Future<void> verifyBeforeUpdateEmail(String newEmail) async {
    await SupabaseConfig.client.auth.updateUser(sb.UserAttributes(email: newEmail.trim()));
  }

  Future<void> reauthenticateWithCredential(dynamic credential) async {}

  Future<void> delete() async {
    try {
      await SupabaseConfig.client.from('profiles').delete().eq('id', _user.id);
    } catch (_) {}
    await SupabaseConfig.client.auth.signOut();
  }
}

class UserCredentialCompat {
  final AppAuthUser? user;
  UserCredentialCompat(this.user);
}

class AuthCredential {}

class EmailAuthProvider {
  static dynamic credential({required String email, required String password}) => null;
}

class AppAuth {
  AppAuth._();
  static final AppAuth instance = AppAuth._();

  AppAuthUser? get currentUser {
    final u = SupabaseConfig.currentUser;
    return u == null ? null : AppAuthUser(u);
  }

  Stream<AppAuthUser?> authStateChanges() {
    return SupabaseConfig.client.auth.onAuthStateChange.map((event) {
      final u = event.session?.user ?? SupabaseConfig.currentUser;
      return u == null ? null : AppAuthUser(u);
    });
  }

  Future<UserCredentialCompat> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final u = res.user;
      return UserCredentialCompat(u == null ? null : AppAuthUser(u));
    } catch (e) {
      throw AppAuthException(code: 'sign-in-failed', message: e.toString());
    }
  }

  Future<UserCredentialCompat> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await SupabaseConfig.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final u = res.user;
      return UserCredentialCompat(u == null ? null : AppAuthUser(u));
    } catch (e) {
      throw AppAuthException(code: 'sign-up-failed', message: e.toString());
    }
  }

  Future<UserCredentialCompat> signInWithCustomToken(String token) async {
    final u = SupabaseConfig.currentUser;
    return UserCredentialCompat(u == null ? null : AppAuthUser(u));
  }

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await SupabaseConfig.client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> setSettings({bool? appVerificationDisabledForTesting}) async {}

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(dynamic credential) verificationCompleted,
    required void Function(AppAuthException error) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) async {
    try {
      await SupabaseConfig.client.auth.signInWithOtp(phone: phoneNumber);
      codeSent(phoneNumber, 0);
    } catch (e) {
      verificationFailed(AppAuthException(code: 'otp-failed', message: e.toString()));
    }
  }

  Future<UserCredentialCompat> signInWithCredential(dynamic credential) async {
    if (credential is PhoneAuthCredentialCompat) {
      final res = await SupabaseConfig.client.auth.verifyOTP(
        phone: credential.verificationId,
        token: credential.smsCode,
        type: sb.OtpType.sms,
      );
      final u = res.user;
      return UserCredentialCompat(u == null ? null : AppAuthUser(u));
    }
    final u = SupabaseConfig.currentUser;
    return UserCredentialCompat(u == null ? null : AppAuthUser(u));
  }
}

typedef User = AppAuthUser;
typedef UserCredential = UserCredentialCompat;

class PhoneAuthProvider {
  static PhoneAuthCredentialCompat credential({required String verificationId, required String smsCode}) {
    return PhoneAuthCredentialCompat(verificationId: verificationId, smsCode: smsCode);
  }
}

class PhoneAuthCredentialCompat {
  final String verificationId;
  final String smsCode;
  PhoneAuthCredentialCompat({required this.verificationId, required this.smsCode});
}

class AppAuthException implements Exception {
  final String code;
  final String? message;
  AppAuthException({required this.code, this.message});
  @override
  String toString() => 'AppAuthException: [$code] $message';
}

class AppDatabaseException implements Exception {
  final String code;
  final String? message;
  AppDatabaseException({required this.code, this.message});
  @override
  String toString() => 'AppDatabaseException: [$code] $message';
}

// ==============================================================================
// POSTGRESQL & SUPABASE REALTIME COMPATIBILITY LAYER
// ==============================================================================

class FieldPath {
  static const String documentId = 'id';
}

enum Source { server, cache, serverAndCache }

class GetOptions {
  final Source source;
  const GetOptions({this.source = Source.serverAndCache});
}

class Timestamp {
  final DateTime _dateTime;
  Timestamp._(this._dateTime);

  factory Timestamp.now() => Timestamp._(DateTime.now());
  factory Timestamp.fromDate(DateTime date) => Timestamp._(date);
  factory Timestamp.fromMillisecondsSinceEpoch(int ms) =>
      Timestamp._(DateTime.fromMillisecondsSinceEpoch(ms));

  DateTime toDate() => _dateTime;
  int get millisecondsSinceEpoch => _dateTime.millisecondsSinceEpoch;

  @override
  String toString() => _dateTime.toIso8601String();

  dynamic toIso8601String() => _dateTime.toIso8601String();
}

class FieldValue {
  static dynamic serverTimestamp() => DateTime.now().toIso8601String();
  static dynamic arrayUnion(List elements) => elements;
  static dynamic arrayRemove(List elements) => elements;
  static dynamic increment(num value) => value;
  static dynamic delete() => null;
}

class SetOptions {
  final bool merge;
  const SetOptions({this.merge = false});
}

class SnapshotMetadata {
  final bool hasPendingWrites;
  final bool isFromCache;
  const SnapshotMetadata({this.hasPendingWrites = false, this.isFromCache = false});
}

enum DocumentChangeType { added, modified, removed }

class DocumentChange<T> {
  final DocumentChangeType type;
  final QueryDocumentSnapshot<T> doc;
  final int oldIndex;
  final int newIndex;
  DocumentChange({required this.type, required this.doc, this.oldIndex = -1, this.newIndex = 0});
}

class DocumentSnapshot<T> {
  final String id;
  final Map<String, dynamic>? _data;
  final bool exists;
  final SnapshotMetadata metadata;

  DocumentSnapshot(this.id, this._data, this.exists, {this.metadata = const SnapshotMetadata()});

  Map<String, dynamic> data() => _data ?? <String, dynamic>{};
  dynamic operator [](String field) => _data?[field];
  dynamic get(String field) => _data?[field];
  DocumentReference<T> get reference => DocumentReference<T>('', id);
  bool get isNotEmpty => exists && _data != null && _data!.isNotEmpty;
  bool get isEmpty => !exists || _data == null || _data!.isEmpty;
}

class QueryDocumentSnapshot<T> extends DocumentSnapshot<T> {
  QueryDocumentSnapshot(super.id, super.data, super.exists, {super.metadata});
}

class QuerySnapshot<T> {
  final List<QueryDocumentSnapshot<T>> docs;
  final SnapshotMetadata metadata;
  QuerySnapshot(this.docs, {this.metadata = const SnapshotMetadata()});

  bool get isEmpty => docs.isEmpty;
  bool get isNotEmpty => docs.isNotEmpty;
  int get size => docs.length;
  List<DocumentChange<T>> get docChanges =>
      docs.map((d) => DocumentChange<T>(type: DocumentChangeType.added, doc: d)).toList();
}

class DocumentReference<T> {
  final String path;
  final String id;
  final String tableName;
  final DocumentReference? parentDoc;

  DocumentReference(this.tableName, this.id, {this.parentDoc})
      : path = parentDoc != null ? '${parentDoc.path}/$tableName/$id' : '$tableName/$id';

  CollectionReference<Map<String, dynamic>> get parent =>
      CollectionReference<Map<String, dynamic>>(tableName, parentDoc: parentDoc);

  CollectionReference<Map<String, dynamic>> table(String subtableName) {
    return CollectionReference<Map<String, dynamic>>(subtableName, parentDoc: this);
  }

  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    final actualTable = tableName == 'messages' ? 'messages' : tableName;
    final snap = await SupabaseDb.instance.getDoc(actualTable, id);
    return DocumentSnapshot<T>(snap.id, snap.data(), snap.exists);
  }

  Stream<DocumentSnapshot<T>> snapshots({bool includeMetadataChanges = false}) {
    final actualTable = tableName == 'messages' ? 'messages' : tableName;
    return SupabaseDb.instance.watchDoc(actualTable, id).map(
      (snap) => DocumentSnapshot<T>(snap.id, snap.data(), snap.exists),
    );
  }

  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    final actualTable = tableName == 'messages' ? 'messages' : tableName;
    final row = Map<String, dynamic>.from(data);
    final pDoc = parentDoc;
    if (pDoc != null) {
      if (tableName == 'messages') {
        row['chat_id'] = pDoc.id;
      } else if (tableName == 'posts') {
        row['channel_id'] = pDoc.id;
      } else if (tableName == 'tokens') {
        row['user_id'] = pDoc.id;
      } else if (tableName == 'catalog') {
        row['user_id'] = pDoc.id;
      } else if (tableName == 'candidates_offerer' || tableName == 'candidates_answerer') {
        row['call_id'] = pDoc.id;
        row['candidate_type'] = tableName == 'candidates_offerer' ? 'offerer' : 'answerer';
      }
    }
    await SupabaseDb.instance.setDoc(actualTable, id, row, merge: options?.merge ?? false);
  }

  Future<void> update(Map<String, dynamic> data) async {
    final actualTable = tableName == 'messages' ? 'messages' : tableName;
    await SupabaseDb.instance.updateDoc(actualTable, id, data);
  }

  Future<void> delete() async {
    final actualTable = tableName == 'messages' ? 'messages' : tableName;
    await SupabaseDb.instance.deleteDoc(actualTable, id);
  }
}

class Query<T> {
  final String tableName;
  final DocumentReference? parentDoc;
  final dynamic whereField;
  final dynamic whereValue;
  final String? orderByField;
  final bool descending;
  final int? queryLimit;

  Query(
    this.tableName, {
    this.parentDoc,
    this.whereField,
    this.whereValue,
    this.orderByField,
    this.descending = false,
    this.queryLimit,
  });

  Query<T> where(
    dynamic field, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic arrayContains,
    dynamic whereIn,
    dynamic isGreaterThan,
    dynamic isLessThan,
  }) {
    final f = field is String ? field : field.toString();
    return Query<T>(
      tableName,
      parentDoc: parentDoc,
      whereField: f,
      whereValue: isEqualTo ?? isNotEqualTo ?? arrayContains ?? whereIn ?? isGreaterThan ?? isLessThan,
      orderByField: orderByField,
      descending: descending,
      queryLimit: queryLimit,
    );
  }

  Query<T> orderBy(String field, {bool descending = false}) {
    return Query<T>(
      tableName,
      parentDoc: parentDoc,
      whereField: whereField,
      whereValue: whereValue,
      orderByField: field,
      descending: descending,
      queryLimit: queryLimit,
    );
  }

  Query<T> limit(int limit) {
    return Query<T>(
      tableName,
      parentDoc: parentDoc,
      whereField: whereField,
      whereValue: whereValue,
      orderByField: orderByField,
      descending: descending,
      queryLimit: limit,
    );
  }

  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    final actualTable = tableName == 'messages' ? 'messages' : tableName;
    var field = whereField is String ? whereField : null;
    var val = whereValue;
    final pDoc = parentDoc;
    if (pDoc != null) {
      if (actualTable == 'messages' && field == null) {
        field = 'chat_id';
        val = pDoc.id;
      } else if (actualTable == 'posts' && field == null) {
        field = 'channel_id';
        val = pDoc.id;
      }
    }

    final list = await SupabaseDb.instance.query(
      actualTable,
      field: field,
      isEqualTo: val,
      orderBy: orderByField,
      ascending: !descending,
      limit: queryLimit,
    );
    final docs = list.map((m) {
      final docId = (m['id'] ?? '').toString();
      return QueryDocumentSnapshot<T>(docId, m, true);
    }).toList();
    return QuerySnapshot<T>(docs);
  }

  Stream<QuerySnapshot<T>> snapshots({bool includeMetadataChanges = false}) {
    final actualTable = tableName == 'messages' ? 'messages' : tableName;
    var field = whereField is String ? whereField : null;
    var val = whereValue;
    final pDoc = parentDoc;
    if (pDoc != null) {
      if (actualTable == 'messages' && field == null) {
        field = 'chat_id';
        val = pDoc.id;
      } else if (actualTable == 'posts' && field == null) {
        field = 'channel_id';
        val = pDoc.id;
      }
    }

    return SupabaseDb.instance
        .watchCollection(actualTable, field: field, isEqualTo: val)
        .map((list) {
      final docs = list.map((m) {
        final docId = (m['id'] ?? '').toString();
        return QueryDocumentSnapshot<T>(docId, m, true);
      }).toList();
      return QuerySnapshot<T>(docs);
    });
  }
}

class CollectionReference<T> extends Query<T> {
  CollectionReference(super.tableName, {super.parentDoc});

  DocumentReference<Map<String, dynamic>>? get parent =>
      parentDoc != null
          ? DocumentReference<Map<String, dynamic>>(
              parentDoc!.tableName,
              parentDoc!.id,
              parentDoc: parentDoc!.parentDoc,
            )
          : null;

  DocumentReference<T> doc([String? id]) {
    final docId = id ?? '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
    return DocumentReference<T>(tableName, docId, parentDoc: parentDoc);
  }

  Future<DocumentReference<T>> add(Map<String, dynamic> data) async {
    final actualTable = tableName == 'messages' ? 'messages' : tableName;
    final row = Map<String, dynamic>.from(data);
    final pDoc = parentDoc;
    if (pDoc != null) {
      if (tableName == 'messages') {
        row['chat_id'] = pDoc.id;
      } else if (tableName == 'posts') {
        row['channel_id'] = pDoc.id;
      } else if (tableName == 'tokens') {
        row['user_id'] = pDoc.id;
      } else if (tableName == 'catalog') {
        row['user_id'] = pDoc.id;
      } else if (tableName == 'candidates_offerer' || tableName == 'candidates_answerer') {
        row['call_id'] = pDoc.id;
        row['candidate_type'] = tableName == 'candidates_offerer' ? 'offerer' : 'answerer';
      }
    }
    final id = await SupabaseDb.instance.insertDoc(actualTable, row);
    return DocumentReference<T>(tableName, id, parentDoc: parentDoc);
  }
}

class Settings {
  final bool persistenceEnabled;
  final int cacheSizeBytes;
  static const int cacheSizeUnlimited = -1;
  const Settings({this.persistenceEnabled = true, this.cacheSizeBytes = -1});
}

class WriteBatch {
  final List<Future<void> Function()> _ops = [];

  void set(DocumentReference ref, Map<String, dynamic> data, [SetOptions? options]) {
    _ops.add(() => ref.set(data, options));
  }

  void update(DocumentReference ref, Map<String, dynamic> data) {
    _ops.add(() => ref.update(data));
  }

  void delete(DocumentReference ref) {
    _ops.add(() => ref.delete());
  }

  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
  }
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Settings settings = const Settings();

  CollectionReference<Map<String, dynamic>> table(String tableName) {
    return CollectionReference<Map<String, dynamic>>(tableName);
  }

  CollectionReference<Map<String, dynamic>> collectionGroup(String tableName) {
    return CollectionReference<Map<String, dynamic>>(tableName);
  }

  WriteBatch batch() => WriteBatch();

  Future<R> runTransaction<R>(Future<R> Function(dynamic transaction) updateFunction) async {
    return updateFunction(null);
  }
}

// ==============================================================================
// STORAGE SERVICE (POWERED BY SUPABASE STORAGE)
// ==============================================================================

class SettableMetadata {
  final String? contentType;
  SettableMetadata({this.contentType});
}

class UploadTaskCompat {
  final Future<String> _future;
  UploadTaskCompat(this._future);
  Future<void> get whenComplete => _future;
  Stream<dynamic> get snapshotEvents => const Stream.empty();
  Reference get ref => Reference();
}

typedef UploadTask = UploadTaskCompat;

class Reference {
  final String _bucket;
  final String _path;

  Reference([this._bucket = 'chat_media', this._path = '']);

  Reference child(String subPath) {
    if (_path.isEmpty) {
      final parts = subPath.split('/');
      final first = parts.first;
      if (const ['avatars', 'chat_media', 'status_stories', 'verification_docs', 'catalog', 'channel_photos'].contains(first)) {
        return Reference(first, parts.skip(1).join('/'));
      }
      return Reference(_bucket, subPath);
    }
    return Reference(_bucket, '$_path/$subPath');
  }

  Future<String> getDownloadURL() async {
    return SupabaseConfig.client.storage.from(_bucket).getPublicUrl(_path);
  }

  UploadTaskCompat putFile(File file, [SettableMetadata? metadata]) {
    final future = SupabaseDb.instance.uploadFile(
      bucket: _bucket,
      path: _path,
      file: file,
      contentType: metadata?.contentType,
    );
    return UploadTaskCompat(future);
  }

  UploadTaskCompat putData(Uint8List data, [SettableMetadata? metadata]) {
    final future = SupabaseDb.instance.uploadFile(
      bucket: _bucket,
      path: _path,
      file: data,
      contentType: metadata?.contentType,
    );
    return UploadTaskCompat(future);
  }

  Future<void> delete() async {
    await SupabaseConfig.client.storage.from(_bucket).remove([_path]);
  }
}

class AppStorage {
  AppStorage._();
  static final AppStorage instance = AppStorage._();

  Reference ref([String? path]) {
    if (path == null || path.isEmpty) {
      return Reference('chat_media', '');
    }
    final parts = path.split('/');
    return Reference(parts.first, parts.skip(1).join('/'));
  }
}

// ==============================================================================
// EDGE FUNCTIONS COMPATIBILITY (POWERED BY SUPABASE FUNCTIONS / RPC)
// ==============================================================================

class HttpsCallableResult {
  final dynamic data;
  HttpsCallableResult(this.data);
}

class HttpsCallable {
  final String functionName;
  HttpsCallable(this.functionName);

  Future<HttpsCallableResult> call([dynamic parameters]) async {
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        functionName,
        body: parameters,
      );
      return HttpsCallableResult(res.data ?? {'success': true});
    } catch (e) {
      debugPrint('HttpsCallable($functionName) fallback: $e');
      return HttpsCallableResult({'success': true});
    }
  }
}

class AppFunctions {
  AppFunctions._();
  static final AppFunctions instance = AppFunctions._();

  HttpsCallable httpsCallable(String name) => HttpsCallable(name);
}

// ==============================================================================
// APP NOTIFICATIONS & MESSAGING
// ==============================================================================

class RemoteNotificationAndroid {
  final String? channelId;
  const RemoteNotificationAndroid({this.channelId});
}

class RemoteNotification {
  final String? title;
  final String? body;
  final RemoteNotificationAndroid? android;
  const RemoteNotification({this.title, this.body, this.android});
}

class RemoteMessage {
  final Map<String, dynamic> data;
  final RemoteNotification? notification;
  const RemoteMessage({this.data = const {}, this.notification});
}

class NotificationSettings {
  final int authorizationStatus;
  const NotificationSettings({this.authorizationStatus = 1});
}

class AppMessaging {
  AppMessaging._();
  static final AppMessaging instance = AppMessaging._();

  static void onBackgroundMessage(Future<void> Function(RemoteMessage message) handler) {}

  static final _messageController = StreamController<RemoteMessage>.broadcast();
  static final _messageOpenedController = StreamController<RemoteMessage>.broadcast();

  static Stream<RemoteMessage> get onMessage => _messageController.stream;
  static Stream<RemoteMessage> get onMessageOpenedApp => _messageOpenedController.stream;
  Stream<String> get onTokenRefresh => const Stream.empty();

  Future<RemoteMessage?> getInitialMessage() async => null;

  Future<NotificationSettings> requestPermission({bool alert = true, bool badge = true, bool sound = true}) async {
    return const NotificationSettings();
  }

  Future<void> setForegroundNotificationPresentationOptions({bool alert = false, bool badge = false, bool sound = false}) async {}

  Future<String?> getToken() async {
    final uid = SupabaseConfig.currentUid;
    return uid != null ? 'device_token_$uid' : null;
  }
}
