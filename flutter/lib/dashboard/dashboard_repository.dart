import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'heuristic_scanner.dart';
import '../supabase_config.dart';

String mfaErrorMessage(Object error) {
  if (error is AuthException) {
    final message = error.message.trim();
    final normalized = message.toLowerCase();
    if (normalized.contains('rate') ||
        normalized.contains('too many') ||
        normalized.contains('429')) {
      return 'Too many verification requests. Wait a few minutes before trying again.';
    }
    if (normalized.contains('expired') ||
        normalized.contains('challenge') && normalized.contains('invalid')) {
      return 'This verification code expired. Request a new code and try again.';
    }
    if (normalized.contains('network') ||
        normalized.contains('timeout') ||
        normalized.contains('connection')) {
      return 'The verification service could not be reached. Check your connection and try again.';
    }
    return message.isEmpty ? 'The verification request failed.' : message;
  }
  return error.toString();
}

class DashboardSummary {
  const DashboardSummary({
    required this.scansToday,
    required this.warningScansToday,
    required this.lowRiskScansToday,
  });

  factory DashboardSummary.fromRiskLevels(Iterable<Object?> riskLevels) {
    var scansToday = 0;
    var warningScansToday = 0;
    var lowRiskScansToday = 0;

    for (final riskLevel in riskLevels) {
      scansToday++;
      if (riskLevel == 'high' || riskLevel == 'review') {
        warningScansToday++;
      } else if (riskLevel == 'low') {
        lowRiskScansToday++;
      }
    }

    return DashboardSummary(
      scansToday: scansToday,
      warningScansToday: warningScansToday,
      lowRiskScansToday: lowRiskScansToday,
    );
  }

  final int scansToday;
  final int warningScansToday;
  final int lowRiskScansToday;
}

class PrivacySettings {
  const PrivacySettings({
    this.shareProtectionStatus = false,
    this.shareScanResults = false,
    this.shareSecurityAlerts = false,
    this.familyActivityNotifications = false,
    this.pushNotificationsEnabled = false,
  });

  final bool shareProtectionStatus;
  final bool shareScanResults;
  final bool shareSecurityAlerts;
  final bool familyActivityNotifications;
  final bool pushNotificationsEnabled;

  PrivacySettings copyWith({
    bool? shareProtectionStatus,
    bool? shareScanResults,
    bool? shareSecurityAlerts,
    bool? familyActivityNotifications,
    bool? pushNotificationsEnabled,
  }) {
    return PrivacySettings(
      shareProtectionStatus:
          shareProtectionStatus ?? this.shareProtectionStatus,
      shareScanResults: shareScanResults ?? this.shareScanResults,
      shareSecurityAlerts: shareSecurityAlerts ?? this.shareSecurityAlerts,
      familyActivityNotifications:
          familyActivityNotifications ?? this.familyActivityNotifications,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
    );
  }
}

class AccountSecurityFactor {
  const AccountSecurityFactor({
    required this.id,
    required this.type,
    required this.status,
    this.friendlyName,
  });

  final String id;
  final String type;
  final String status;
  final String? friendlyName;

  bool get isVerified => status == 'verified';
  bool get isPhone => type == 'phone';
}

class PhoneFactorChallenge {
  const PhoneFactorChallenge({required this.id, required this.expiresAt});

  final String id;
  final DateTime expiresAt;
}

class FamilyGroup {
  const FamilyGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.isOwner,
    required this.shareReports,
    required this.members,
    required this.pendingInvites,
    required this.reports,
  });

  final String id;
  final String name;
  final String ownerId;
  final bool isOwner;
  final bool shareReports;
  final List<FamilyMember> members;
  final List<FamilyInvite> pendingInvites;
  final List<SharedReport> reports;
}

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.displayName,
    required this.isOwner,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final bool isOwner;
  final String? avatarUrl;
}

class FamilyInvite {
  const FamilyInvite({required this.email, required this.expiresAt});

  final String email;
  final DateTime expiresAt;
}

class FamilyInviteCode {
  const FamilyInviteCode({required this.invitationCode});

  final String invitationCode;
}

class SharedReport {
  const SharedReport({
    required this.category,
    required this.description,
    required this.createdAt,
  });

  final String category;
  final String description;
  final DateTime createdAt;
}

class SecurityAlert {
  const SecurityAlert({
    required this.id,
    required this.title,
    required this.detail,
    required this.severity,
    required this.createdAt,
    required this.isRead,
    this.familyId,
  });

  final String id;
  final String title;
  final String detail;
  final String severity;
  final DateTime createdAt;
  final bool isRead;
  final String? familyId;
}

class ScanHistoryEntry {
  const ScanHistoryEntry({
    required this.id,
    required this.scanType,
    required this.riskLevel,
    required this.indicators,
    required this.createdAt,
    this.classification = ScanClassification.unknown,
    this.confidence = 0,
    this.analysisSummary,
    this.recommendedActions = const [],
    this.analysisModulesStatus = const {},
    this.confidenceReasons = const [],
    this.analysisModules = const [],
    this.ruleAnalysis = const {},
    this.aiAnalysis = const {},
    this.evidence = const [],
    this.engineVersion = '',
    this.analyzedAt,
  });

  final String id;
  final String scanType;
  final ScanRiskLevel riskLevel;
  final ScanClassification classification;
  final int confidence;
  final List<String> indicators;
  final DateTime createdAt;
  final String? analysisSummary;
  final List<String> recommendedActions;
  final Map<String, String> analysisModulesStatus;
  final List<String> confidenceReasons;
  final List<Map<String, dynamic>> analysisModules;
  final Map<String, dynamic> ruleAnalysis;
  final Map<String, dynamic> aiAnalysis;
  final List<String> evidence;
  final String engineVersion;
  final DateTime? analyzedAt;

  ScanResult toScanResult() => ScanResult(
    level: riskLevel,
    classification: classification,
    confidence: confidence,
    indicators: indicators,
    summary:
        analysisSummary ??
        (indicators.isEmpty
            ? 'No known indicators were recorded; this is not a safety verdict.'
            : 'Warning signs found:'),
    guidance: recommendedActions.join('\n'),
    recommendedActions: recommendedActions,
    analysisModulesStatus: analysisModulesStatus,
    ruleAnalysis: ruleAnalysis,
    aiAnalysis: aiAnalysis,
    evidence: evidence,
    engineVersion: engineVersion,
    analyzedAt: analyzedAt ?? createdAt,
    recordId: id,
    confidenceReasons: confidenceReasons,
    analysisModules: analysisModules,
  );
}

class AssistantChatMessage {
  const AssistantChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class TrustedExampleStatus {
  const TrustedExampleStatus({
    required this.id,
    required this.contentType,
    required this.submittedLabel,
    required this.status,
    required this.createdAt,
    this.statusNote,
  });

  final String id;
  final String contentType;
  final String submittedLabel;
  final String status;
  final DateTime createdAt;
  final String? statusNote;
}

class TrustedExampleReview {
  const TrustedExampleReview({
    required this.reviewerId,
    required this.decision,
    required this.verificationMethod,
    required this.evidenceReference,
    required this.createdAt,
    this.notes,
  });

  final String reviewerId;
  final String decision;
  final String verificationMethod;
  final String evidenceReference;
  final DateTime createdAt;
  final String? notes;
}

class TrustedReviewSubmission {
  const TrustedReviewSubmission({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.content,
    required this.contentHash,
    required this.submittedLabel,
    required this.status,
    required this.createdAt,
    required this.screeningCategories,
    required this.reviews,
    required this.reviewedByCurrentUser,
    this.statusNote,
    this.screeningRiskLevel,
  });

  final String id;
  final String reporterId;
  final String contentType;
  final String content;
  final String contentHash;
  final String submittedLabel;
  final String status;
  final DateTime createdAt;
  final List<String> screeningCategories;
  final List<TrustedExampleReview> reviews;
  final bool reviewedByCurrentUser;
  final String? statusNote;
  final String? screeningRiskLevel;
}

class TrustedDatasetVersion {
  const TrustedDatasetVersion({
    required this.id,
    required this.versionLabel,
    required this.exampleCount,
    required this.evaluationStatus,
    required this.releaseStatus,
    required this.createdAt,
    required this.evaluationMetrics,
  });

  final String id;
  final String versionLabel;
  final int exampleCount;
  final String evaluationStatus;
  final String releaseStatus;
  final DateTime createdAt;
  final Map<String, dynamic> evaluationMetrics;
}

class TrustedExampleSubmissionResult {
  const TrustedExampleSubmissionResult({
    required this.status,
    required this.submissionId,
    required this.message,
  });

  final String status;
  final String submissionId;
  final String message;
}

class TrustedDatasetEvaluationResult {
  const TrustedDatasetEvaluationResult({
    required this.status,
    required this.evaluation,
  });

  final String status;
  final Map<String, dynamic> evaluation;
}

abstract interface class DashboardRepository {
  Future<DashboardSummary> loadSummary();

  Future<List<ScanHistoryEntry>> loadScanHistory({
    required int offset,
    required int limit,
  });

  Future<PrivacySettings> loadPrivacySettings();

  Future<void> updatePrivacySettings(PrivacySettings settings);

  Future<void> requestPasswordReset();

  Future<void> updatePassword(String password);

  Future<List<AccountSecurityFactor>> loadAccountSecurityFactors();

  Future<String> enrollPhoneFactor(String phoneNumber);

  Future<PhoneFactorChallenge> sendPhoneFactorChallenge(String factorId);

  Future<void> verifyPhoneFactorChallenge({
    required String factorId,
    required String challengeId,
    required String code,
  });

  Future<void> removePhoneFactor(String factorId);

  Future<void> updateAccountProfile({
    required String firstName,
    required String lastName,
    required String email,
  });

  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  });

  Future<String?> loadProfilePhotoUrl(String? avatarPath);

  Future<ScanResult> analyzeAndSave(
    String type,
    String input, {
    bool useAi = false,
    bool useUrlReputation = false,
    String? notificationIdempotencyKey,
  });

  Future<String> chatSafetyAssistant(List<AssistantChatMessage> messages);

  Future<TrustedExampleSubmissionResult> submitTrustedExample({
    required String contentType,
    required String content,
    required String submittedLabel,
    String? scanRecordId,
  });

  Future<List<TrustedExampleStatus>> loadMyTrustedExamples();

  Future<List<TrustedReviewSubmission>> loadTrustedReviewQueue({
    int limit = 30,
  });

  Future<void> reviewTrustedExample({
    required String submissionId,
    required String decision,
    required String verificationMethod,
    required String evidenceReference,
    String? notes,
  });

  Future<void> resolveTrustedDispute({
    required String submissionId,
    required String decision,
    required String evidenceReference,
  });

  Future<List<TrustedDatasetVersion>> loadTrustedDatasetVersions();

  Future<TrustedDatasetEvaluationResult> evaluateTrustedDatasetVersion(
    String datasetVersionId,
  );

  Future<void> releaseTrustedDatasetVersion(String datasetVersionId);

  Stream<List<SecurityAlert>> watchAlerts();

  Future<void> markAlertRead(String alertId);

  Future<FamilyGroup?> loadFamily();

  Future<void> createFamily(String name);

  Future<FamilyInviteCode> createFamilyInvite(String email);

  Future<void> revokeFamilyInvite(String email);

  Future<void> acceptFamilyInvite(String token);

  Future<void> removeFamilyMember(String userId);

  Future<void> leaveFamily();

  Future<void> deleteFamily();

  Future<void> setFamilySharing(bool enabled);

  Future<void> submitScamReport({
    required String category,
    required String description,
    required bool shareWithFamily,
    String? indicator,
  });

  Future<void> seedFamilyThreatReports();

  Future<void> deleteScanHistory();
}

class SupabaseDashboardRepository implements DashboardRepository {
  SupabaseDashboardRepository(this._client);

  static const _scanHistoryRetention = Duration(days: 120);
  static const _profileAvatarBucket = 'profile-avatars';
  static const _maxProfilePhotoBytes = 5 * 1024 * 1024;
  static const _profilePhotoUrlLifetimeSeconds = 7 * 24 * 60 * 60;
  static final _profileAvatarPathPattern = RegExp(r'^[0-9a-fA-F-]{36}/avatar$');

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before using dashboard services.');
    }
    return userId;
  }

  @override
  Future<DashboardSummary> loadSummary() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));
    final scans = await _client
        .from('scan_records')
        .select('risk_level')
        .eq('user_id', _userId)
        .gte('created_at', startOfDay.toUtc().toIso8601String())
        .lt('created_at', startOfNextDay.toUtc().toIso8601String());
    return DashboardSummary.fromRiskLevels(
      scans.map((scan) => scan['risk_level']),
    );
  }

  @override
  Future<List<ScanHistoryEntry>> loadScanHistory({
    required int offset,
    required int limit,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Scan history pagination is invalid.');
    }

    if (offset == 0) {
      final expiresBefore = DateTime.now()
          .toUtc()
          .subtract(_scanHistoryRetention)
          .toIso8601String();
      await _client
          .from('scan_records')
          .delete()
          .eq('user_id', _userId)
          .lt('created_at', expiresBefore);
    }

    final rows = await _client
        .from('scan_records')
        .select(
          'id, scan_type, risk_level, indicators, created_at, '
          'threat_scan_results(analysis_classification, analysis_risk_level, '
          'analysis_confidence, analysis_summary, rule_analysis, ai_analysis, '
          'evidence, recommended_actions, analysis_modules_status, '
          'confidence_reasons, analyzed_at, engine_version, '
          'analysis_module_results(module, indicator_type, indicator_hash, '
          'status, evidence_kind, confidence, evidence, source, error_reason, '
          'category, details, checked_at))',
        )
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows
        .map((row) {
          final scanType = row['scan_type'];
          if (scanType is! String ||
              !const {'message', 'url', 'screenshot'}.contains(scanType)) {
            throw const FormatException(
              'Scan history contains an unsupported scan type.',
            );
          }

          final threatRow = _singleThreatRow(row['threat_scan_results']);
          final unifiedRisk = threatRow?['analysis_risk_level'];
          final riskLevel = switch (unifiedRisk ?? row['risk_level']) {
            'low' => ScanRiskLevel.low,
            'LOW' => ScanRiskLevel.low,
            'review' => ScanRiskLevel.medium,
            'MEDIUM' => ScanRiskLevel.medium,
            'high' => ScanRiskLevel.high,
            'HIGH' => ScanRiskLevel.high,
            'CRITICAL' => ScanRiskLevel.critical,
            'UNKNOWN' => ScanRiskLevel.unknown,
            'UNDETERMINED' => ScanRiskLevel.unknown,
            _ => throw const FormatException(
              'Scan history contains an unsupported risk level.',
            ),
          };

          final rawIndicators = row['indicators'];
          if (rawIndicators is! List ||
              rawIndicators.any((indicator) => indicator is! String)) {
            throw const FormatException(
              'Scan history contains invalid warning indicators.',
            );
          }
          final classification =
              switch (threatRow?['analysis_classification']) {
                'SAFE' => ScanClassification.safe,
                'SUSPICIOUS' => ScanClassification.suspicious,
                'SCAM' => ScanClassification.scam,
                'MALICIOUS' => ScanClassification.scam,
                _ => ScanClassification.unknown,
              };
          final confidenceValue =
              threatRow?['analysis_confidence'] ??
              (threatRow?['confidence'] as num?)?.round() ??
              0;
          final rawActions = threatRow?['recommended_actions'];
          final actions = rawActions is List
              ? rawActions.whereType<String>().take(5).toList(growable: false)
              : const <String>[];
          final ruleAnalysis = _historyJsonObject(
            threatRow?['rule_analysis'],
            'rule findings',
          );
          final aiAnalysis = _historyJsonObject(
            threatRow?['ai_analysis'],
            'AI findings',
          );
          final evidence = _historyStringList(
            threatRow?['evidence'],
            'supporting evidence',
          );
          final rawEngineVersion = threatRow?['engine_version'];
          if (rawEngineVersion != null && rawEngineVersion is! String) {
            throw const FormatException(
              'Scan history contains invalid analysis version metadata.',
            );
          }
          final rawAnalyzedAt = threatRow?['analyzed_at'];
          DateTime? analyzedAt;
          if (rawAnalyzedAt != null) {
            if (rawAnalyzedAt is! String ||
                DateTime.tryParse(rawAnalyzedAt) == null) {
              throw const FormatException(
                'Scan history contains an invalid analysis timestamp.',
              );
            }
            analyzedAt = DateTime.parse(rawAnalyzedAt);
          }
          final rawModulesStatus = threatRow?['analysis_modules_status'];
          final rawConfidenceReasons = threatRow?['confidence_reasons'];
          if (rawConfidenceReasons != null &&
              (rawConfidenceReasons is! List ||
                  rawConfidenceReasons.any((item) => item is! String))) {
            throw const FormatException(
              'Scan history contains invalid confidence reasons.',
            );
          }
          final rawModuleResults = threatRow?['analysis_module_results'];
          final moduleResults = _parseAnalysisModuleResults(rawModuleResults);
          final modulesStatus = rawModulesStatus is Map
              ? rawModulesStatus.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                )
              : const <String, String>{};

          return ScanHistoryEntry(
            id: row['id'] as String,
            scanType: scanType,
            riskLevel: riskLevel,
            classification: classification,
            confidence: confidenceValue is int ? confidenceValue : 0,
            indicators: List.unmodifiable(rawIndicators.cast<String>()),
            createdAt: DateTime.parse(row['created_at'] as String),
            analysisSummary: threatRow?['analysis_summary'] as String?,
            recommendedActions: actions,
            analysisModulesStatus: modulesStatus,
            confidenceReasons: rawConfidenceReasons is List
                ? List.unmodifiable(rawConfidenceReasons.cast<String>())
                : const [],
            analysisModules: moduleResults,
            ruleAnalysis: ruleAnalysis,
            aiAnalysis: aiAnalysis,
            evidence: evidence,
            engineVersion: rawEngineVersion is String ? rawEngineVersion : '',
            analyzedAt: analyzedAt,
          );
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _historyJsonObject(Object? value, String description) {
    if (value == null) return const {};
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('Scan history contains invalid $description.');
    }
    return Map.unmodifiable(Map<String, dynamic>.from(value));
  }

  List<String> _historyStringList(Object? value, String description) {
    if (value == null) return const [];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('Scan history contains invalid $description.');
    }
    return List.unmodifiable(value.cast<String>());
  }

  @override
  Future<PrivacySettings> loadPrivacySettings() async {
    final row = await _client
        .from('user_settings')
        .select(
          'share_protection_status, share_scan_results, '
          'share_security_alerts, family_activity_notifications, '
          'push_notifications_enabled',
        )
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) {
      throw StateError(
        'Privacy settings are not initialized for this account. '
        'Apply the user privacy settings migration.',
      );
    }

    return PrivacySettings(
      shareProtectionStatus: row['share_protection_status'] as bool,
      shareScanResults: row['share_scan_results'] as bool,
      shareSecurityAlerts: row['share_security_alerts'] as bool,
      familyActivityNotifications: row['family_activity_notifications'] as bool,
      pushNotificationsEnabled: row['push_notifications_enabled'] as bool,
    );
  }

  @override
  Future<void> updatePrivacySettings(PrivacySettings settings) async {
    final updatedRows = await _client
        .from('user_settings')
        .update({
          'share_protection_status': settings.shareProtectionStatus,
          'share_scan_results': settings.shareScanResults,
          'share_security_alerts': settings.shareSecurityAlerts,
          'family_activity_notifications': settings.familyActivityNotifications,
          'push_notifications_enabled': settings.pushNotificationsEnabled,
        })
        .eq('user_id', _userId)
        .select('user_id');
    if (updatedRows.isEmpty) {
      throw StateError(
        'Privacy settings could not be updated for this account. '
        'Apply the user privacy settings migration.',
      );
    }
  }

  @override
  Future<void> requestPasswordReset() async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.trim().isEmpty) {
      throw StateError(
        'This account does not have a resettable email address.',
      );
    }
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: authRedirectUrl,
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    if (password.length < 12) {
      throw const FormatException(
        'Use at least 12 characters for your password.',
      );
    }
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<List<AccountSecurityFactor>> loadAccountSecurityFactors() async {
    final response = await _client.auth.mfa.listFactors();
    return response.all
        .map(
          (factor) => AccountSecurityFactor(
            id: factor.id,
            type: factor.factorType.name,
            status: factor.status.name,
            friendlyName: factor.friendlyName,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String> enrollPhoneFactor(String phoneNumber) async {
    final normalizedPhoneNumber = phoneNumber.trim();
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalizedPhoneNumber)) {
      throw const FormatException(
        'Enter a valid phone number in international format, such as +14155552671.',
      );
    }

    final digits = normalizedPhoneNumber.substring(1);
    final response = await _client.auth.mfa.enroll(
      factorType: FactorType.phone,
      phone: normalizedPhoneNumber,
      friendlyName: 'Mobile ending ${digits.substring(digits.length - 4)}',
    );
    return response.id;
  }

  @override
  Future<PhoneFactorChallenge> sendPhoneFactorChallenge(String factorId) async {
    final response = await _client.auth.mfa.challenge(
      factorId: factorId,
      channel: OtpChannel.sms,
    );
    return PhoneFactorChallenge(id: response.id, expiresAt: response.expiresAt);
  }

  @override
  Future<void> verifyPhoneFactorChallenge({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException('Enter the six-digit SMS code.');
    }
    await _client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
  }

  @override
  Future<void> removePhoneFactor(String factorId) async {
    await _client.auth.mfa.unenroll(factorId);
  }

  @override
  Future<void> updateAccountProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final currentEmail = _client.auth.currentUser?.email;
    final metadata = _client.auth.currentUser?.userMetadata ?? const {};
    await _client.auth.updateUser(
      UserAttributes(
        email: email.trim().toLowerCase() == currentEmail?.toLowerCase()
            ? null
            : email.trim(),
        data: {
          ...metadata,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
        },
      ),
    );
  }

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty || bytes.length > _maxProfilePhotoBytes) {
      throw const FormatException('Choose a photo smaller than 5 MB.');
    }
    if (!const {
      'image/jpeg',
      'image/png',
      'image/webp',
    }.contains(contentType)) {
      throw const FormatException('Choose a JPEG, PNG, or WebP photo.');
    }

    final path = '$_userId/avatar';
    await _client.storage
        .from(_profileAvatarBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '0',
            contentType: contentType,
            upsert: true,
          ),
        );
    final url = await _client.storage
        .from(_profileAvatarBucket)
        .createSignedUrl(path, _profilePhotoUrlLifetimeSeconds);
    final metadata = _client.auth.currentUser?.userMetadata ?? const {};
    await _client.auth.updateUser(
      UserAttributes(data: {...metadata, 'avatar_path': path}),
    );
    return url;
  }

  @override
  Future<String?> loadProfilePhotoUrl(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    if (!_profileAvatarPathPattern.hasMatch(avatarPath)) {
      throw const FormatException('The saved profile photo path is invalid.');
    }
    return _client.storage
        .from(_profileAvatarBucket)
        .createSignedUrl(avatarPath, _profilePhotoUrlLifetimeSeconds);
  }

  @override
  Future<ScanResult> analyzeAndSave(
    String type,
    String input, {
    bool useAi = false,
    bool useUrlReputation = false,
    String? notificationIdempotencyKey,
  }) async {
    if (type != 'message' && type != 'url' && type != 'screenshot') {
      throw ArgumentError(
        'Server analysis supports messages, URLs, and screenshots only.',
      );
    }
    if (useUrlReputation && type != 'url') {
      throw ArgumentError(
        'External URL reputation checks are available for URL scans only.',
      );
    }
    if (input.trim().isEmpty || input.length > (type == 'url' ? 2048 : 5000)) {
      throw const FormatException('The content is empty or too long to scan.');
    }

    final response = await _client.functions.invoke(
      'scam-intelligence',
      body: {
        'type': type,
        'input': input,
        'use_ai': useAi,
        'use_url_reputation': useUrlReputation,
        'notification_idempotency_key': notificationIdempotencyKey,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'The analysis service returned an invalid response.',
      );
    }

    final rawClassification = data['classification'];
    final classification = switch (rawClassification is String
        ? rawClassification.toUpperCase()
        : null) {
      'SAFE' => ScanClassification.safe,
      'SUSPICIOUS' => ScanClassification.suspicious,
      'SCAM' => ScanClassification.scam,
      'MALICIOUS' => ScanClassification.scam,
      'UNKNOWN' => ScanClassification.unknown,
      _ => throw const FormatException(
        'The analysis service returned an unsupported classification.',
      ),
    };
    final rawRiskLevel = data['risk_level'];
    final level = switch (rawRiskLevel is String
        ? rawRiskLevel.toUpperCase()
        : null) {
      'LOW' => ScanRiskLevel.low,
      'MEDIUM' => ScanRiskLevel.medium,
      'HIGH' => ScanRiskLevel.high,
      'CRITICAL' => ScanRiskLevel.critical,
      'UNKNOWN' => ScanRiskLevel.unknown,
      'UNDETERMINED' => ScanRiskLevel.unknown,
      _ => throw const FormatException(
        'The analysis service returned an unsupported risk level.',
      ),
    };
    final confidence = data['confidence'];
    final summary = data['analysis_summary'];
    final recordId = data['scan_id'];
    final analyzedAt = data['analyzed_at'];
    final engineVersion = data['engine_version'];
    if (confidence is! int ||
        confidence < 0 ||
        confidence > 100 ||
        summary is! String ||
        summary.trim().isEmpty ||
        summary.length > 500 ||
        recordId is! String ||
        !_isUuid(recordId) ||
        analyzedAt is! String ||
        DateTime.tryParse(analyzedAt) == null ||
        engineVersion is! String ||
        engineVersion.isEmpty) {
      throw const FormatException(
        'The analysis service returned incomplete assessment metadata.',
      );
    }
    final rawIndicators = data['indicators'];
    if (rawIndicators is! List ||
        rawIndicators.length > 15 ||
        rawIndicators.any(
          (indicator) =>
              indicator is! String ||
              indicator.trim().isEmpty ||
              indicator.length > 160,
        )) {
      throw const FormatException(
        'The analysis service returned invalid indicators.',
      );
    }

    final rawRules = data['rule_analysis'];
    final rawAi = data['ai_analysis'];
    final rawEvidence = data['evidence'];
    final rawActions = data['recommended_actions'];
    final rawModulesStatus = data['analysis_modules_status'];
    final rawModuleResults = data['analysis_modules'] ?? const [];
    final rawConfidenceReasons = data['confidence_reasons'] ?? const [];
    if (rawRules is! Map<String, dynamic> ||
        rawAi is! Map<String, dynamic> ||
        rawEvidence is! List ||
        rawEvidence.length > 30 ||
        rawEvidence.any((value) => value is! String || value.length > 300) ||
        rawActions is! List ||
        rawActions.isEmpty ||
        rawActions.length > 5 ||
        rawActions.any((value) => value is! String || value.length > 240) ||
        rawModulesStatus is! Map<String, dynamic> ||
        rawModulesStatus.values.any((value) => value is! String) ||
        rawConfidenceReasons is! List ||
        rawConfidenceReasons.length > 8 ||
        rawConfidenceReasons.any((value) => value is! String)) {
      throw const FormatException(
        'The analysis service returned incomplete supporting findings.',
      );
    }
    final analysisModules = _parseAnalysisModuleResults(rawModuleResults);

    final score = rawRules['score'];
    final categories = rawRules['categories'];
    final rulesVersion = rawRules['version'];
    if (score is! int ||
        score < 0 ||
        categories is! List ||
        categories.any((value) => value is! String) ||
        rulesVersion is! String ||
        rulesVersion.isEmpty) {
      throw const FormatException(
        'The analysis service returned invalid rule findings.',
      );
    }
    if (!const {
      'available',
      'not_configured',
      'not_requested',
      'disabled',
      'unavailable',
      'timeout',
      'failed',
      'rate_limited',
    }.contains(rawAi['status'])) {
      throw const FormatException(
        'The analysis service returned an invalid AI status.',
      );
    }

    return ScanResult(
      level: level,
      classification: classification,
      confidence: confidence,
      indicators: List.unmodifiable(rawIndicators.cast<String>()),
      summary: summary,
      guidance: rawActions.cast<String>().join('\n'),
      recommendedActions: List.unmodifiable(rawActions.cast<String>()),
      analysisModulesStatus: Map.unmodifiable(
        rawModulesStatus.map((key, value) => MapEntry(key, value as String)),
      ),
      ruleAnalysis: Map.unmodifiable(rawRules),
      aiAnalysis: Map.unmodifiable(rawAi),
      evidence: List.unmodifiable(rawEvidence.cast<String>()),
      engineVersion: engineVersion,
      analyzedAt: DateTime.parse(analyzedAt),
      recordId: recordId,
      confidenceReasons: List.unmodifiable(rawConfidenceReasons.cast<String>()),
      analysisModules: analysisModules,
    );
  }

  @override
  Future<String> chatSafetyAssistant(
    List<AssistantChatMessage> messages,
  ) async {
    if (messages.isEmpty ||
        messages.length > 7 ||
        messages.last.role != 'user' ||
        messages.any(
          (message) =>
              message.content.trim().isEmpty || message.content.length > 5000,
        )) {
      throw const FormatException('The assistant conversation is invalid.');
    }

    final response = await _client.functions.invoke(
      'scam-intelligence',
      body: {
        'action': 'assistant_chat',
        'messages': messages.map((message) => message.toJson()).toList(),
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'The AI assistant returned an invalid response.',
      );
    }
    final reply = data['reply'];
    if (reply is! String || reply.trim().isEmpty || reply.length > 5000) {
      throw const FormatException(
        'The AI assistant returned an invalid response.',
      );
    }
    return reply.trim();
  }

  @override
  Future<TrustedExampleSubmissionResult> submitTrustedExample({
    required String contentType,
    required String content,
    required String submittedLabel,
    String? scanRecordId,
  }) async {
    if (!const {'message', 'url', 'screenshot'}.contains(contentType) ||
        !const {'scam', 'legitimate', 'unsure'}.contains(submittedLabel) ||
        content.trim().isEmpty ||
        content.length > 5000) {
      throw const FormatException('The submitted example is invalid.');
    }
    final data = await _invokeTrustedAction({
      'action': 'submit_example',
      'content_type': contentType,
      'content': content,
      'submitted_label': submittedLabel,
      ...?(scanRecordId == null ? null : {'scan_record_id': scanRecordId}),
    });
    final status = data['status'];
    final submissionId = data['submission_id'];
    final message = data['message'];
    if (status is! String ||
        submissionId is! String ||
        message is! String ||
        message.length > 300) {
      throw const FormatException(
        'The example submission service returned an invalid response.',
      );
    }
    return TrustedExampleSubmissionResult(
      status: status,
      submissionId: submissionId,
      message: message,
    );
  }

  @override
  Future<List<TrustedExampleStatus>> loadMyTrustedExamples() async {
    final data = await _invokeTrustedAction({'action': 'my_examples'});
    final rawSubmissions = data['submissions'];
    if (rawSubmissions is! List || rawSubmissions.length > 50) {
      throw const FormatException(
        'The example status service returned invalid data.',
      );
    }
    return List.unmodifiable(
      rawSubmissions.map((raw) {
        final row = _trustedJsonObject(raw, 'example status');
        final id = row['id'];
        final type = row['content_type'];
        final label = row['submitted_label'];
        final status = row['status'];
        final createdAt = row['created_at'];
        final statusNote = row['status_note'];
        if (id is! String ||
            type is! String ||
            !const {'message', 'url', 'screenshot'}.contains(type) ||
            label is! String ||
            !const {'scam', 'legitimate', 'unsure'}.contains(label) ||
            status is! String ||
            createdAt is! String ||
            DateTime.tryParse(createdAt) == null ||
            (statusNote != null && statusNote is! String)) {
          throw const FormatException(
            'The example status service returned invalid data.',
          );
        }
        return TrustedExampleStatus(
          id: id,
          contentType: type,
          submittedLabel: label,
          status: status,
          createdAt: DateTime.parse(createdAt),
          statusNote: statusNote as String?,
        );
      }),
    );
  }

  @override
  Future<List<TrustedReviewSubmission>> loadTrustedReviewQueue({
    int limit = 30,
  }) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Must be from 1 to 50.');
    }
    final data = await _invokeTrustedAction({
      'action': 'review_queue',
      'limit': limit,
    });
    final rawSubmissions = data['submissions'];
    if (rawSubmissions is! List || rawSubmissions.length > limit) {
      throw const FormatException('The review queue response is invalid.');
    }
    return List.unmodifiable(
      rawSubmissions.map((raw) {
        final row = _trustedJsonObject(raw, 'review submission');
        final id = row['id'];
        final reporterId = row['reporter_id'];
        final type = row['content_type'];
        final content = row['redacted_content'];
        final hash = row['content_hash'];
        final label = row['submitted_label'];
        final status = row['status'];
        final createdAt = row['created_at'];
        final screening = _trustedJsonObject(
          row['screening_result'],
          'screening result',
        );
        final rawCategories = screening['categories'];
        final rawReviews = row['reviews'];
        final reviewedByCurrentUser = row['reviewed_by_current_user'];
        final statusNote = row['status_note'];
        final riskLevel = screening['risk_level'];
        if (id is! String ||
            reporterId is! String ||
            type is! String ||
            !const {'message', 'url', 'screenshot'}.contains(type) ||
            content is! String ||
            content.length > 5000 ||
            hash is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
            label is! String ||
            !const {'scam', 'legitimate', 'unsure'}.contains(label) ||
            status is! String ||
            createdAt is! String ||
            DateTime.tryParse(createdAt) == null ||
            rawCategories is! List ||
            rawCategories.length > 12 ||
            rawCategories.any((value) => value is! String) ||
            rawReviews is! List ||
            rawReviews.length > 20 ||
            reviewedByCurrentUser is! bool ||
            (statusNote != null && statusNote is! String) ||
            (riskLevel != null && riskLevel is! String)) {
          throw const FormatException('The review queue response is invalid.');
        }
        final reviews = rawReviews
            .map((rawReview) {
              final review = _trustedJsonObject(rawReview, 'moderator review');
              final reviewerId = review['reviewer_id'];
              final decision = review['decision'];
              final method = review['verification_method'];
              final evidenceReference = review['evidence_reference'];
              final reviewedAt = review['created_at'];
              final notes = review['notes'];
              if (reviewerId is! String ||
                  decision is! String ||
                  method is! String ||
                  evidenceReference is! String ||
                  evidenceReference.length > 2000 ||
                  reviewedAt is! String ||
                  DateTime.tryParse(reviewedAt) == null ||
                  (notes != null && notes is! String)) {
                throw const FormatException(
                  'The moderator review response is invalid.',
                );
              }
              return TrustedExampleReview(
                reviewerId: reviewerId,
                decision: decision,
                verificationMethod: method,
                evidenceReference: evidenceReference,
                createdAt: DateTime.parse(reviewedAt),
                notes: notes as String?,
              );
            })
            .toList(growable: false);
        return TrustedReviewSubmission(
          id: id,
          reporterId: reporterId,
          contentType: type,
          content: content,
          contentHash: hash,
          submittedLabel: label,
          status: status,
          createdAt: DateTime.parse(createdAt),
          screeningCategories: List.unmodifiable(rawCategories.cast<String>()),
          reviews: List.unmodifiable(reviews),
          reviewedByCurrentUser: reviewedByCurrentUser,
          statusNote: statusNote as String?,
          screeningRiskLevel: riskLevel as String?,
        );
      }),
    );
  }

  @override
  Future<void> reviewTrustedExample({
    required String submissionId,
    required String decision,
    required String verificationMethod,
    required String evidenceReference,
    String? notes,
  }) async {
    if (!const {
          'verified_scam',
          'verified_legitimate',
          'rejected',
          'disputed',
        }.contains(decision) ||
        !const {
          'official_source',
          'direct_contact',
          'law_enforcement',
          'independent_fact_check',
          'other',
        }.contains(verificationMethod) ||
        evidenceReference.trim().length < 12 ||
        evidenceReference.length > 2000 ||
        (notes?.length ?? 0) > 2000) {
      throw const FormatException('The moderator review is invalid.');
    }
    await _invokeTrustedAction({
      'action': 'review_example',
      'submission_id': submissionId,
      'decision': decision,
      'verification_method': verificationMethod,
      'evidence_reference': evidenceReference.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  @override
  Future<void> resolveTrustedDispute({
    required String submissionId,
    required String decision,
    required String evidenceReference,
  }) async {
    if (!const {'verified_scam', 'verified_legitimate'}.contains(decision) ||
        evidenceReference.trim().length < 12 ||
        evidenceReference.length > 2000) {
      throw const FormatException(
        'The administrator dispute resolution is invalid.',
      );
    }
    await _invokeTrustedAction({
      'action': 'resolve_dispute',
      'submission_id': submissionId,
      'decision': decision,
      'evidence_reference': evidenceReference.trim(),
    });
  }

  @override
  Future<List<TrustedDatasetVersion>> loadTrustedDatasetVersions() async {
    final rows = await _client
        .from('dataset_versions')
        .select(
          'id, version_label, example_count, evaluation_status, release_status, created_at, evaluation_metrics',
        )
        .order('created_at', ascending: false)
        .limit(50);
    return List.unmodifiable(
      rows.map((raw) {
        final row = _trustedJsonObject(raw, 'dataset version');
        final id = row['id'];
        final label = row['version_label'];
        final count = row['example_count'];
        final evaluationStatus = row['evaluation_status'];
        final releaseStatus = row['release_status'];
        final createdAt = row['created_at'];
        if (id is! String ||
            label is! String ||
            count is! int ||
            count < 1 ||
            evaluationStatus is! String ||
            releaseStatus is! String ||
            createdAt is! String ||
            DateTime.tryParse(createdAt) == null) {
          throw const FormatException('The dataset version is invalid.');
        }
        return TrustedDatasetVersion(
          id: id,
          versionLabel: label,
          exampleCount: count,
          evaluationStatus: evaluationStatus,
          releaseStatus: releaseStatus,
          createdAt: DateTime.parse(createdAt),
          evaluationMetrics: row['evaluation_metrics'] == null
              ? const {}
              : _trustedJsonObject(
                  row['evaluation_metrics'],
                  'dataset evaluation metrics',
                ),
        );
      }),
    );
  }

  @override
  Future<TrustedDatasetEvaluationResult> evaluateTrustedDatasetVersion(
    String datasetVersionId,
  ) async {
    final data = await _invokeTrustedAction({
      'action': 'evaluate_dataset',
      'dataset_version_id': datasetVersionId,
    });
    final status = data['evaluation_status'];
    final evaluation = _trustedJsonObject(
      data['evaluation'],
      'dataset evaluation',
    );
    if (status is! String) {
      throw const FormatException('The evaluation response is invalid.');
    }
    return TrustedDatasetEvaluationResult(
      status: status,
      evaluation: Map.unmodifiable(evaluation),
    );
  }

  @override
  Future<void> releaseTrustedDatasetVersion(String datasetVersionId) async {
    await _invokeTrustedAction({
      'action': 'release_dataset',
      'dataset_version_id': datasetVersionId,
    });
  }

  Future<Map<String, dynamic>> _invokeTrustedAction(
    Map<String, Object?> body,
  ) async {
    final response = await _client.functions.invoke(
      'scam-intelligence',
      body: body,
    );
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException(
        'The scam-intelligence service returned an invalid response.',
      );
    }
    return response.data as Map<String, dynamic>;
  }

  Map<String, dynamic> _trustedJsonObject(Object? value, String description) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('The $description response is invalid.');
    }
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _parseAnalysisModuleResults(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > 50) {
      throw const FormatException(
        'The analysis service returned invalid analysis modules.',
      );
    }
    final results = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map<String, dynamic> ||
          item['module'] is! String ||
          !const {
            'url_structure',
            'domain_dns',
            'ssl_tls',
            'redirect_analysis',
            'suspicious_patterns',
            'local_indicator_database',
            'community_reports',
            'external_threat_intelligence',
            'scam_pattern_recognition',
            'anomaly_detection',
            'adaptive_pattern_analysis',
          }.contains(item['module']) ||
          (item['indicator_type'] != null &&
              !const {
                'url',
                'domain',
                'ip',
              }.contains(item['indicator_type'])) ||
          item['status'] is! String ||
          !const {
            'completed',
            'unavailable',
            'failed',
            'not_applicable',
          }.contains(item['status']) ||
          item['evidence_kind'] is! String ||
          !const {
            'confirmed_detection',
            'suspicious_signal',
            'no_match',
            'not_checked',
            'analysis_unavailable',
            'analysis_failed',
          }.contains(item['evidence_kind']) ||
          item['confidence'] is! num ||
          (item['confidence'] as num) < 0 ||
          (item['confidence'] as num) > 1 ||
          item['source'] is! String ||
          item['checked_at'] is! String ||
          DateTime.tryParse(item['checked_at'] as String) == null ||
          item['evidence'] is! List ||
          (item['evidence'] as List).length > 8 ||
          (item['evidence'] as List).any((entry) => entry is! String) ||
          (item['details'] != null &&
              item['details'] is! Map<String, dynamic>)) {
        throw const FormatException(
          'The analysis service returned an invalid analysis module.',
        );
      }
      results.add(Map.unmodifiable(item));
    }
    return List.unmodifiable(results);
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);

  Map<String, dynamic>? _singleThreatRow(Object? value) {
    if (value == null) return null;
    if (value is List) {
      if (value.isEmpty) return null;
      if (value.length != 1 || value.single is! Map<String, dynamic>) {
        throw const FormatException(
          'Scan history contains invalid threat metadata.',
        );
      }
      return value.single as Map<String, dynamic>;
    }
    if (value is Map<String, dynamic>) return value;
    throw const FormatException(
      'Scan history contains invalid threat metadata.',
    );
  }

  @override
  Stream<List<SecurityAlert>> watchAlerts() {
    final userId = _userId;
    return _client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50)
        .asyncMap((rows) async {
          if (rows.isEmpty) return const <SecurityAlert>[];
          final ids = rows.map((row) => row['id'] as String).toList();
          final readRows = await _client
              .from('alert_reads')
              .select('alert_id')
              .eq('user_id', userId)
              .inFilter('alert_id', ids);
          final readIds = readRows
              .map((row) => row['alert_id'] as String)
              .toSet();
          return rows
              .map(
                (row) => SecurityAlert(
                  id: row['id'] as String,
                  title: row['title'] as String,
                  detail: row['detail'] as String,
                  severity: row['severity'] as String,
                  createdAt: DateTime.parse(row['created_at'] as String),
                  isRead: readIds.contains(row['id']),
                  familyId: row['family_id'] as String?,
                ),
              )
              .toList();
        });
  }

  @override
  Future<void> markAlertRead(String alertId) async {
    await _client.from('alert_reads').upsert({
      'alert_id': alertId,
      'user_id': _userId,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<FamilyGroup?> loadFamily() async {
    final membership = await _client
        .from('family_members')
        .select('family_id, role')
        .eq('user_id', _userId)
        .maybeSingle();
    if (membership == null) return null;

    final familyId = membership['family_id'] as String;
    final family = await _client
        .from('families')
        .select('id, name, owner_id, share_reports')
        .eq('id', familyId)
        .single();
    final memberRows = await _client
        .from('family_members')
        .select('user_id, role')
        .eq('family_id', familyId);
    final memberIds = memberRows
        .map((row) => row['user_id'] as String)
        .toList(growable: false);
    final profileRows = memberIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('profiles')
              .select('user_id, first_name, last_name, avatar_path')
              .inFilter('user_id', memberIds);
    final profiles = <String, Map<String, dynamic>>{
      for (final profile in profileRows) profile['user_id'] as String: profile,
    };
    final members = await Future.wait(
      memberRows.map((row) async {
        final userId = row['user_id'] as String;
        final profile = profiles[userId];
        final firstName = profile?['first_name'] as String? ?? '';
        final lastName = profile?['last_name'] as String? ?? '';
        final displayName = [
          firstName,
          lastName,
        ].where((part) => part.isNotEmpty).join(' ');
        final avatarPath = profile?['avatar_path'] as String?;
        return FamilyMember(
          userId: userId,
          displayName: displayName.isNotEmpty ? displayName : 'Family member',
          isOwner: row['role'] == 'owner',
          avatarUrl: await loadProfilePhotoUrl(avatarPath),
        );
      }),
    );
    final isOwner = membership['role'] == 'owner';
    final inviteRows = isOwner
        ? await _client
              .from('family_invites')
              .select('invited_email, expires_at')
              .eq('family_id', familyId)
              .isFilter('accepted_at', null)
              .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        : <Map<String, dynamic>>[];
    final reportRows = await _client
        .from('scam_reports')
        .select('category, description, created_at')
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(20);

    return FamilyGroup(
      id: family['id'] as String,
      name: family['name'] as String,
      ownerId: family['owner_id'] as String,
      isOwner: isOwner,
      shareReports: family['share_reports'] as bool,
      members: members,
      pendingInvites: inviteRows
          .map(
            (row) => FamilyInvite(
              email: row['invited_email'] as String,
              expiresAt: DateTime.parse(row['expires_at'] as String),
            ),
          )
          .toList(growable: false),
      reports: reportRows
          .map(
            (row) => SharedReport(
              category: row['category'] as String,
              description: row['description'] as String,
              createdAt: DateTime.parse(row['created_at'] as String),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> createFamily(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      throw const FormatException(
        'Family group name must be between 1 and 80 characters.',
      );
    }
    await _client.from('families').insert({
      'name': trimmedName,
      'owner_id': _userId,
    });
  }

  @override
  Future<FamilyInviteCode> createFamilyInvite(String email) async {
    final family = await loadFamily();
    if (family == null || !family.isOwner) {
      throw StateError('Only a family owner can invite a member.');
    }
    final response = await _client.functions.invoke(
      'family-invitations',
      body: {'action': 'invite', 'familyId': family.id, 'email': email.trim()},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'The invitation service returned an invalid response.',
      );
    }

    final invitationCode = data['invitationCode'];
    if (invitationCode is! String ||
        !RegExp(
          r'^[0-9a-f]{64}$',
          caseSensitive: false,
        ).hasMatch(invitationCode)) {
      throw const FormatException(
        'The invitation service did not return a valid invitation code.',
      );
    }

    return FamilyInviteCode(invitationCode: invitationCode);
  }

  @override
  Future<void> revokeFamilyInvite(String email) async {
    final family = await loadFamily();
    if (family == null || !family.isOwner) {
      throw StateError('Only a family owner can cancel an invitation.');
    }
    await _client.functions.invoke(
      'family-invitations',
      body: {'action': 'revoke', 'familyId': family.id, 'email': email.trim()},
    );
  }

  @override
  Future<void> acceptFamilyInvite(String token) async {
    await _client.functions.invoke(
      'family-invitations',
      body: {'action': 'accept', 'token': token.trim()},
    );
  }

  @override
  Future<void> removeFamilyMember(String userId) async {
    final family = await loadFamily();
    if (family == null || !family.isOwner) {
      throw StateError('Only the family owner can remove a member.');
    }
    if (userId == family.ownerId || userId == _userId) {
      throw StateError(
        'The family owner must delete the group or leave it separately.',
      );
    }
    final deletedRows = await _client
        .from('family_members')
        .delete()
        .eq('family_id', family.id)
        .eq('user_id', userId)
        .select('user_id');
    if (deletedRows.isEmpty) {
      throw StateError('That family member could not be found in this group.');
    }
  }

  @override
  Future<void> leaveFamily() async {
    final family = await loadFamily();
    if (family == null || family.isOwner) {
      throw StateError('The family owner must delete the group to leave it.');
    }
    await _client
        .from('family_members')
        .delete()
        .eq('family_id', family.id)
        .eq('user_id', _userId);
  }

  @override
  Future<void> deleteFamily() async {
    final family = await loadFamily();
    if (family == null || !family.isOwner) {
      throw StateError('Only the family owner can delete the group.');
    }
    await _client.from('families').delete().eq('id', family.id);
  }

  @override
  Future<void> setFamilySharing(bool enabled) async {
    final family = await loadFamily();
    if (family == null || !family.isOwner) {
      throw StateError('Only the family owner can change sharing settings.');
    }
    await _client
        .from('families')
        .update({'share_reports': enabled})
        .eq('id', family.id);
  }

  @override
  Future<void> submitScamReport({
    required String category,
    required String description,
    required bool shareWithFamily,
    String? indicator,
  }) async {
    String? familyId;
    if (shareWithFamily) {
      final family = await loadFamily();
      if (family == null) {
        throw StateError('Create or join a family before sharing a report.');
      }
      if (!family.shareReports) {
        throw StateError('Family report sharing is currently turned off.');
      }
      familyId = family.id;
    }
    await _client.from('scam_reports').insert({
      'user_id': _userId,
      'family_id': familyId,
      'category': category,
      'description': description.trim(),
    });
    final normalizedIndicator = indicator?.trim();
    if (normalizedIndicator != null && normalizedIndicator.isNotEmpty) {
      try {
        final response = await _client.functions.invoke(
          'scam-intelligence',
          body: {
            'action': 'report_indicator',
            'indicator': normalizedIndicator,
            'category': category,
          },
        );
        if (response.data is! Map<String, dynamic> ||
            response.data['status'] != 'pending_review') {
          throw const FormatException(
            'The indicator report service returned an invalid response.',
          );
        }
      } on FunctionException catch (error) {
        throw StateError(
          'The scam report was saved, but its indicator was not submitted: '
          '${error.details ?? error.reasonPhrase ?? error.status}',
        );
      }
    }
  }

  @override
  Future<void> seedFamilyThreatReports() async {
    final family = await loadFamily();
    if (family == null || !family.isOwner) {
      throw StateError('Only a family owner can add sample reports.');
    }
    if (!family.shareReports) {
      throw StateError('Family report sharing is currently turned off.');
    }

    const reports = [
      (
        category: 'Phishing',
        description: 'A message asked a family member to verify an account through an unfamiliar sign-in page.',
      ),
      (
        category: 'Fake prize',
        description: 'A prize notification requested a processing fee and personal details before releasing the reward.',
      ),
      (
        category: 'Impersonation',
        description: 'Someone claimed to be a relative and urgently requested a money transfer.',
      ),
      (
        category: 'Bank scam',
        description: 'A caller requested a one-time code and full card details to “secure” a bank account.',
      ),
      (
        category: 'Delivery scam',
        description: 'A parcel notice linked to an unverified payment page to reschedule delivery.',
      ),
      (
        category: 'Job scam',
        description: 'A work-from-home offer required an upfront payment for training materials.',
      ),
      (
        category: 'Investment scam',
        description: 'A social media contact promised guaranteed returns and pressured immediate payment.',
      ),
      (
        category: 'Romance scam',
        description: 'An online contact asked for emergency financial help while avoiding a video call.',
      ),
      (
        category: 'Tech support scam',
        description: 'A pop-up claimed the device was infected and directed the user to call an unknown number.',
      ),
      (
        category: 'Account takeover',
        description: 'A message requested a password reset code that the family member did not initiate.',
      ),
    ];

    for (final report in reports) {
      await submitScamReport(
        category: report.category,
        description: report.description,
        shareWithFamily: true,
      );
    }
  }

  @override
  Future<void> deleteScanHistory() async {
    await _client.from('scan_records').delete().eq('user_id', _userId);
  }
}
