import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class StudyWorkspace {
  const StudyWorkspace({required this.snapshot, required this.revision});

  final Map<String, dynamic> snapshot;
  final int revision;
}

class StudySyncConflict implements Exception {
  const StudySyncConflict();
}

/// Optional account service. Local notebooks work with no Supabase setup.
class StudyAccount extends ChangeNotifier {
  StudyAccount._(this._client) {
    _subscription = _client?.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) recoveryPending = true;
      if (state.event == AuthChangeEvent.signedOut) recoveryPending = false;
      authError = null;
      notifyListeners();
    }, onError: (Object error) {
      authError = error;
      notifyListeners();
    });
  }

  static StudyAccount current = StudyAccount._(null);
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _webRedirect = String.fromEnvironment('STUDY_AUTH_WEB_REDIRECT');
  static const _bucket = 'study-sources';
  static const _maxUploadBytes = 10 * 1024 * 1024;
  static final _pathSegment = RegExp(r'^[A-Za-z0-9_-]{1,120}$');

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  bool recoveryPending = false;
  Object? authError;

  static Future<StudyAccount> initialize() async {
    if (current.enabled || _url.isEmpty || _publishableKey.isEmpty) return current;
    final supabase = await Supabase.initialize(url: _url, publishableKey: _publishableKey, debug: false);
    return current = StudyAccount._(supabase.client);
  }

  bool get enabled => _client != null;
  String? get accessToken => _client?.auth.currentSession?.accessToken;
  String? get userId => _client?.auth.currentSession?.user.id;
  String? get email => _client?.auth.currentUser?.email;
  String get displayName => _client?.auth.currentUser?.userMetadata?['display_name']?.toString() ?? '';
  Stream<AuthState> get authChanges => _client?.auth.onAuthStateChange ?? const Stream.empty();

  String get _redirect {
    if (!kIsWeb) return 'hocthongminh://auth-callback';
    if (_webRedirect.isNotEmpty) return _webRedirect;
    final currentUri = Uri.base;
    return Uri(scheme: currentUri.scheme, host: currentUri.host, port: currentUri.hasPort ? currentUri.port : null,
      path: currentUri.path.isEmpty ? '/' : currentUri.path).toString();
  }

  SupabaseClient get _configured => _client ?? (throw StateError('Dịch vụ tài khoản chưa được cấu hình.'));

  Future<void> signIn(String email, String password) async {
    await _configured.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> signUp(String email, String password) async {
    final response = await _configured.auth.signUp(email: email, password: password, emailRedirectTo: _redirect);
    return response.session != null;
  }

  Future<void> requestPasswordReset(String email) => _configured.auth.resetPasswordForEmail(email, redirectTo: _redirect);

  Future<void> setPassword(String password) async {
    await _configured.auth.updateUser(UserAttributes(password: password));
    recoveryPending = false;
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    await _configured.auth.updateUser(UserAttributes(data: {'display_name': name}));
    notifyListeners();
  }

  Future<void> signOut() => _configured.auth.signOut(scope: SignOutScope.local);

  Future<StudyWorkspace> loadWorkspace() async {
    final response = await _configured.rpc('study_load_workspace');
    final result = Map<String, dynamic>.from(response as Map);
    return StudyWorkspace(
      snapshot: Map<String, dynamic>.from(result['snapshot'] as Map),
      revision: (result['revision'] as num).toInt(),
    );
  }

  Future<int> saveWorkspace(Map<String, dynamic> snapshot, {required int expectedRevision}) async {
    try {
      final revision = await _configured.rpc('study_save_workspace', params: {
        'p_snapshot': snapshot,
        'p_expected_revision': expectedRevision,
      });
      return (revision as num).toInt();
    } on PostgrestException catch (error) {
      if (error.code == 'PT409') throw const StudySyncConflict();
      rethrow;
    }
  }

  Future<String> uploadSource({required String notebookId, required String sourceId, required Uint8List bytes, required String mimeType}) async {
    final owner = userId;
    if (owner == null) throw StateError('Hãy đăng nhập để tải tài liệu vào sổ.');
    if (!_pathSegment.hasMatch(notebookId) || !_pathSegment.hasMatch(sourceId)) {
      throw ArgumentError('Mã sổ hoặc nguồn không hợp lệ.');
    }
    if (bytes.isEmpty || bytes.length > _maxUploadBytes) {
      throw ArgumentError('Chọn tệp có dung lượng từ 1 byte đến 10 MB.');
    }
    if (!const {'application/pdf', 'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw ArgumentError('Chỉ hỗ trợ PDF và ảnh JPEG, PNG, WebP.');
    }
    final path = '$owner/$notebookId/$sourceId';
    await _configured.storage.from(_bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType));
    return path;
  }

  Future<String> sourceReadUrl(String path) {
    final owner = userId;
    if (owner == null || !path.startsWith('$owner/')) throw StateError('Nguồn này không thuộc tài khoản đang dùng.');
    return _configured.storage.from(_bucket).createSignedUrl(path, 300);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
