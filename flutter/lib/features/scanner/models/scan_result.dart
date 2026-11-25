class ScanResult {
  const ScanResult({
    required this.level,
    required this.indicators,
    required this.summary,
    required this.guidance,
    this.classification = ScanClassification.unknown,
    this.confidence = 0,
    this.recommendedActions = const [],
    this.analysisModulesStatus = const {},
    this.ruleAnalysis = const {},
    this.aiAnalysis = const {},
    this.evidence = const [],
    this.engineVersion = '',
    this.analyzedAt,
    this.recordId,
    this.confidenceReasons = const [],
    this.analysisModules = const [],
  });

  final ScanRiskLevel level;
  final ScanClassification classification;
  final int confidence;
  final List<String> indicators;
  final String summary;
  final String guidance;
  final List<String> recommendedActions;
  final Map<String, String> analysisModulesStatus;
  final Map<String, dynamic> ruleAnalysis;
  final Map<String, dynamic> aiAnalysis;
  final List<String> evidence;
  final String engineVersion;
  final DateTime? analyzedAt;
  final String? recordId;
  final List<String> confidenceReasons;
  final List<Map<String, dynamic>> analysisModules;

  ScanResult withRecordId(String value) => ScanResult(
    level: level,
    classification: classification,
    confidence: confidence,
    indicators: indicators,
    summary: summary,
    guidance: guidance,
    recommendedActions: recommendedActions,
    analysisModulesStatus: analysisModulesStatus,
    ruleAnalysis: ruleAnalysis,
    aiAnalysis: aiAnalysis,
    evidence: evidence,
    engineVersion: engineVersion,
    analyzedAt: analyzedAt,
    recordId: value,
    confidenceReasons: confidenceReasons,
    analysisModules: analysisModules,
  );
}

enum ScanClassification { safe, suspicious, scam, unknown }

enum ScanRiskLevel { low, medium, high, critical, unknown }
