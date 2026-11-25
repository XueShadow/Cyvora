import '../../scanner/models/scan_result.dart';

class ScanAnalysisException implements Exception {
  const ScanAnalysisException({required this.status, required this.message});

  final int status;
  final String message;

  @override
  String toString() => message;
}

class AssistantRequestException implements Exception {
  const AssistantRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssistantConversationEntry {
  const AssistantConversationEntry({
    required this.text,
    required this.isUser,
    required this.isError,
  });

  factory AssistantConversationEntry.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['text'] is! String ||
        value['isUser'] is! bool ||
        value['isError'] is! bool) {
      throw const FormatException('Saved chat data is invalid.');
    }
    return AssistantConversationEntry(
      text: value['text'] as String,
      isUser: value['isUser'] as bool,
      isError: value['isError'] as bool,
    );
  }

  final String text;
  final bool isUser;
  final bool isError;

  Map<String, Object> toJson() => {
    'text': text,
    'isUser': isUser,
    'isError': isError,
  };
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
    this.scanHistoryRetentionDays = 90,
  });

  final bool shareProtectionStatus;
  final bool shareScanResults;
  final bool shareSecurityAlerts;
  final bool familyActivityNotifications;
  final bool pushNotificationsEnabled;
  final int scanHistoryRetentionDays;

  PrivacySettings copyWith({
    bool? shareProtectionStatus,
    bool? shareScanResults,
    bool? shareSecurityAlerts,
    bool? familyActivityNotifications,
    bool? pushNotificationsEnabled,
    int? scanHistoryRetentionDays,
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
      scanHistoryRetentionDays:
          scanHistoryRetentionDays ?? this.scanHistoryRetentionDays,
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
