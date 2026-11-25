import 'dart:typed_data';
import 'dart:convert';

import '../../../core/storage/preferences_store.dart';
import '../../scanner/models/scan_result.dart';
import '../../profile/models/profile_photo.dart';
import '../models/dashboard_models.dart';
import '../models/dashboard_repository.dart';

class DashboardPresenter {
  const DashboardPresenter(
    this._repository, {
    this._preferencesStore = const SharedPreferencesStore(),
    this._profilePhotoPickerRepository,
  });

  final DashboardRepository _repository;
  final PreferencesStore _preferencesStore;
  final ProfilePhotoPickerRepository? _profilePhotoPickerRepository;

  Future<List<AssistantConversationEntry>> loadAssistantConversation(
    String storageKey,
  ) async {
    final stored = await _preferencesStore.readString(
      _assistantPreferenceKey(storageKey),
    );
    if (stored == null) return const [];
    final decoded = jsonDecode(stored);
    if (decoded is! List) {
      throw const FormatException('Saved chat data is invalid.');
    }
    return List.unmodifiable(decoded.map(AssistantConversationEntry.fromJson));
  }

  Future<void> saveAssistantConversation(
    String storageKey,
    List<AssistantConversationEntry> entries,
  ) async {
    final saved = await _preferencesStore.writeString(
      _assistantPreferenceKey(storageKey),
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
    if (!saved) throw StateError('Saved chat storage did not save.');
  }

  Future<int> recordCompletedScan(String email) async {
    final key = 'cyvora.feedback.scan-count.${Uri.encodeComponent(email)}';
    final count = (await _preferencesStore.readInt(key) ?? 0) + 1;
    await _preferencesStore.writeInt(key, count);
    return count;
  }

  String _assistantPreferenceKey(String storageKey) =>
      'cyvora.safety_assistant.${Uri.encodeComponent(storageKey)}';

  Future<DashboardSummary> loadSummary() => _repository.loadSummary();

  Future<List<ScanHistoryEntry>> loadScanHistory({
    required int offset,
    required int limit,
  }) => _repository.loadScanHistory(offset: offset, limit: limit);

  Future<PrivacySettings> loadPrivacySettings() =>
      _repository.loadPrivacySettings();

  Future<void> updatePrivacySettings(PrivacySettings settings) =>
      _repository.updatePrivacySettings(settings);

  Future<void> requestPasswordReset() => _repository.requestPasswordReset();

  Future<void> updatePassword(String password) =>
      _repository.updatePassword(password);

  Future<List<AccountSecurityFactor>> loadAccountSecurityFactors() =>
      _repository.loadAccountSecurityFactors();

  Future<String> enrollPhoneFactor(String phoneNumber) =>
      _repository.enrollPhoneFactor(phoneNumber);

  Future<PhoneFactorChallenge> sendPhoneFactorChallenge(String factorId) =>
      _repository.sendPhoneFactorChallenge(factorId);

  Future<void> verifyPhoneFactorChallenge({
    required String factorId,
    required String challengeId,
    required String code,
  }) => _repository.verifyPhoneFactorChallenge(
    factorId: factorId,
    challengeId: challengeId,
    code: code,
  );

  Future<void> removePhoneFactor(String factorId) =>
      _repository.removePhoneFactor(factorId);

  Future<void> updateAccountProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) => _repository.updateAccountProfile(
    firstName: firstName,
    lastName: lastName,
    email: email,
  );

  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) => _repository.uploadProfilePhoto(bytes: bytes, contentType: contentType);

  Future<String?> loadProfilePhotoUrl(String? avatarPath) =>
      _repository.loadProfilePhotoUrl(avatarPath);

  Future<ProfilePhoto?> pickProfilePhoto() {
    final repository = _profilePhotoPickerRepository;
    if (repository == null) {
      throw StateError('Profile photo selection is not configured.');
    }
    return repository.pickProfilePhoto();
  }

  Future<ScanResult> analyzeAndSave(
    String type,
    String input, {
    bool useAi = false,
    bool useUrlReputation = false,
    String? notificationIdempotencyKey,
  }) => _repository.analyzeAndSave(
    type,
    input,
    useAi: useAi,
    useUrlReputation: useUrlReputation,
    notificationIdempotencyKey: notificationIdempotencyKey,
  );

  Future<String> chatSafetyAssistant(List<AssistantChatMessage> messages) =>
      _repository.chatSafetyAssistant(messages);

  Future<TrustedExampleSubmissionResult> submitTrustedExample({
    required String contentType,
    required String content,
    required String submittedLabel,
    String? scanRecordId,
  }) => _repository.submitTrustedExample(
    contentType: contentType,
    content: content,
    submittedLabel: submittedLabel,
    scanRecordId: scanRecordId,
  );

  Future<List<TrustedExampleStatus>> loadMyTrustedExamples() =>
      _repository.loadMyTrustedExamples();

  Future<List<TrustedReviewSubmission>> loadTrustedReviewQueue({
    int limit = 30,
  }) => _repository.loadTrustedReviewQueue(limit: limit);

  Future<void> reviewTrustedExample({
    required String submissionId,
    required String decision,
    required String verificationMethod,
    required String evidenceReference,
    String? notes,
  }) => _repository.reviewTrustedExample(
    submissionId: submissionId,
    decision: decision,
    verificationMethod: verificationMethod,
    evidenceReference: evidenceReference,
    notes: notes,
  );

  Future<void> resolveTrustedDispute({
    required String submissionId,
    required String decision,
    required String evidenceReference,
  }) => _repository.resolveTrustedDispute(
    submissionId: submissionId,
    decision: decision,
    evidenceReference: evidenceReference,
  );

  Future<List<TrustedDatasetVersion>> loadTrustedDatasetVersions() =>
      _repository.loadTrustedDatasetVersions();

  Future<TrustedDatasetEvaluationResult> evaluateTrustedDatasetVersion(
    String datasetVersionId,
  ) => _repository.evaluateTrustedDatasetVersion(datasetVersionId);

  Future<void> releaseTrustedDatasetVersion(String datasetVersionId) =>
      _repository.releaseTrustedDatasetVersion(datasetVersionId);

  Stream<List<SecurityAlert>> watchAlerts() => _repository.watchAlerts();

  Future<void> markAlertRead(String alertId) =>
      _repository.markAlertRead(alertId);

  Future<FamilyGroup?> loadFamily() => _repository.loadFamily();

  Future<void> createFamily(String name) => _repository.createFamily(name);

  Future<FamilyInviteCode> createFamilyInvite(String email) =>
      _repository.createFamilyInvite(email);

  Future<void> revokeFamilyInvite(String email) =>
      _repository.revokeFamilyInvite(email);

  Future<void> acceptFamilyInvite(String token) =>
      _repository.acceptFamilyInvite(token);

  Future<void> removeFamilyMember(String userId) =>
      _repository.removeFamilyMember(userId);

  Future<void> leaveFamily() => _repository.leaveFamily();

  Future<void> deleteFamily() => _repository.deleteFamily();

  Future<void> setFamilySharing(bool enabled) =>
      _repository.setFamilySharing(enabled);

  Future<void> submitScamReport({
    required String category,
    required String description,
    required bool shareWithFamily,
    String? indicator,
  }) => _repository.submitScamReport(
    category: category,
    description: description,
    shareWithFamily: shareWithFamily,
    indicator: indicator,
  );

  Future<void> deleteScanHistory() => _repository.deleteScanHistory();

  Future<void> deleteAccount() => _repository.deleteAccount();
}
