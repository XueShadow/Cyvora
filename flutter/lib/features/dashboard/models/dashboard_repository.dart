import 'dart:typed_data';

import '../../scanner/models/scan_result.dart';
import 'dashboard_models.dart';

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

  Future<void> deleteAccount();
}
