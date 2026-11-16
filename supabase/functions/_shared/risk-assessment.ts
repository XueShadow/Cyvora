import type {
  AnalysisModuleName,
  AnalysisModuleResult,
} from "./analysis-modules.ts";
import type {
  AiAnalysisResult,
  AiProviderAttempt,
} from "./ai-provider-analysis.ts";

type RuleResult = {
  score: number;
  categories: string[];
  indicators: string[];
  rulesVersion: string;
};

type RuleAnalysisResult = Omit<RuleResult, "rulesVersion"> & {
  version: string;
};

type AiResult =
  | AiAnalysisResult
  | {
    status: "disabled";
    provider: null;
    providers_tried: [];
    provider_attempts: [];
  }
  | {
    status: "skipped_verified_threat";
    provider: null;
    providers_tried: [];
    provider_attempts: [];
  };

export type UnifiedAssessment = {
  classification: "SAFE" | "SUSPICIOUS" | "MALICIOUS" | "UNKNOWN";
  risk_level: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL" | "UNDETERMINED";
  confidence: number;
  confidence_reasons: string[];
  analysis_summary: string;
  indicators: string[];
  rule_analysis: RuleAnalysisResult;
  analysis_modules: AnalysisModuleResult[];
  ai_analysis: {
    status: AiAnalysisResult["status"] | "disabled" |
      "skipped_verified_threat";
    provider: AiAnalysisResult["provider"];
    providers_tried: AiAnalysisResult["providers_tried"];
    provider_attempts: AiProviderAttempt[];
    signals: string[];
    summary: string | null;
    recommended_actions: string[];
  };
  evidence: string[];
  analysis_modules_status: Record<string, string>;
  recommended_actions: string[];
  analyzed_at: string;
  engine_version: string;
};

const moduleReliability: Record<AnalysisModuleName, number> = {
  url_structure: 0.72,
  domain_dns: 0.66,
  ssl_tls: 0.7,
  redirect_analysis: 0.65,
  suspicious_patterns: 0.6,
  local_indicator_database: 0.98,
  community_reports: 0.76,
  external_threat_intelligence: 0.68,
  scam_pattern_recognition: 0.72,
  anomaly_detection: 0.42,
  adaptive_pattern_analysis: 0.45,
};

export function assessUnifiedRisk(
  rules: RuleResult,
  modules: AnalysisModuleResult[],
  ai: AiResult,
  analyzedAt = new Date().toISOString(),
): UnifiedAssessment {
  const requiredModules = modules.filter((item) =>
    item.module !== "external_threat_intelligence"
  );
  const applicableModules = requiredModules.filter((item) =>
    item.status !== "not_applicable"
  );
  const completeModules = modules.filter((item) =>
    item.status === "completed"
  );
  const completedRequiredModules = applicableModules.filter((item) =>
    item.status === "completed"
  );
  const localThreat = hasVerifiedLocalThreat(completeModules);
  const verifiedThreat = hasVerifiedThreatEvidence(completeModules);
  const externalThreat = completeModules.some((item) =>
    item.module === "external_threat_intelligence" &&
    item.evidence_kind === "confirmed_detection"
  );
  const suspiciousEvidence = completeModules.some((item) =>
    item.evidence_kind === "suspicious_signal" ||
    item.module === "community_reports" &&
      item.evidence_kind === "confirmed_detection" ||
    item.module === "external_threat_intelligence" &&
      item.evidence_kind === "confirmed_detection"
  );
  const rulesSuspicious = rules.score >= 3 || rules.categories.length >= 2;
  const completeAnalysis = applicableModules.length > 0 &&
    applicableModules.every((item) => item.status === "completed");
  const noKnownFindings = applicableModules.every((item) =>
    item.evidence_kind === "no_match"
  ) && rules.score === 0;

  let classification: UnifiedAssessment["classification"] = "UNKNOWN";
  let riskLevel: UnifiedAssessment["risk_level"] = "UNDETERMINED";
  if (verifiedThreat) {
    classification = "MALICIOUS";
    riskLevel = localThreat ? "CRITICAL" : "HIGH";
  } else if (rulesSuspicious || suspiciousEvidence) {
    classification = "SUSPICIOUS";
    riskLevel = rules.score >= 6 ? "HIGH" : "MEDIUM";
  } else if (completeAnalysis && noKnownFindings) {
    classification = "SAFE";
    riskLevel = "LOW";
  }

  const confidence = calculateConfidence(
    rules,
    applicableModules,
    completedRequiredModules.length,
    classification,
    externalThreat
      ? moduleReliability.external_threat_intelligence *
        (completeModules.find((item) =>
          item.module === "external_threat_intelligence" &&
          item.evidence_kind === "confirmed_detection"
        )?.confidence ?? 0)
      : 0,
  );
  if (classification === "UNKNOWN") {
    confidence.reasons.push(
      "One or more required checks are unavailable, incomplete, or have insufficient evidence.",
    );
  }
  if (ai.status !== "available") {
    confidence.reasons.push(
      `Optional AI-provider analysis was ${ai.status}; it did not contribute evidence or a safety verdict.`,
    );
  }

  const indicators = [...new Set(rules.indicators)].slice(0, 15);
  const evidence = [...new Set([
    ...completeModules.flatMap((item) =>
      item.evidence.map((entry) => `${item.module}: ${entry}`.slice(0, 300))
    ),
    ...(ai.status === "available"
      ? [`AI-provider analysis: ${ai.analysis.summary}`.slice(0, 300)]
      : []),
  ])].slice(0, 30);
  const moduleStatuses: Record<string, string> = {};
  for (const item of modules) {
    const prior = moduleStatuses[item.module];
    moduleStatuses[item.module] = prior && prior !== item.status
      ? "partial"
      : item.status;
  }
  const recommendedActions = classification === "MALICIOUS"
    ? [
      "Do not click, reply, download files, share codes, or send money.",
      "Verify with the claimed organization using its official app, website, or a number you already trust.",
      "If you shared credentials or payment details, secure the account through its official service and contact your bank or provider.",
    ]
    : classification === "SUSPICIOUS"
    ? [
      "Do not click or reply while the request is unverified; never share passwords, one-time codes, PINs, or payment details.",
      "Check the offer using the organization’s official app or website, or a phone number you already trust—not the message link.",
      "Confirm any prize, refund, or payment request directly before sending money or personal information.",
    ]
    : classification === "SAFE"
    ? [
      "No warning signs were found in completed checks; still inspect the sender and domain before acting.",
      "Open important services through their official app or a saved bookmark, and never share passwords or one-time codes.",
    ]
    : [
      "Checks were incomplete; avoid clicking, replying, or sharing codes or money until you verify the request.",
      "Use the organization’s official app, website, or a phone number you already trust—not contact details in the message.",
      "If you already shared account or payment information, contact the service or bank through an official channel.",
    ];

  return {
    classification,
    risk_level: riskLevel,
    confidence: confidence.value,
    confidence_reasons: confidence.reasons.slice(0, 8),
    analysis_summary: buildAnalysisSummary(
      classification,
      rules,
      modules,
      externalThreat,
    ),
    indicators,
    rule_analysis: {
      score: rules.score,
      categories: rules.categories,
      indicators: rules.indicators,
      version: rules.rulesVersion,
    },
    analysis_modules: modules,
    ai_analysis: {
      status: ai.status,
      provider: ai.status === "disabled" ||
          ai.status === "skipped_verified_threat"
        ? null
        : ai.provider,
      providers_tried: ai.status === "disabled" ||
          ai.status === "skipped_verified_threat"
        ? []
        : ai.providers_tried,
      provider_attempts: ai.status === "disabled" ||
          ai.status === "skipped_verified_threat"
        ? []
        : ai.provider_attempts,
      signals: ai.status === "available" ? ai.analysis.signals : [],
      summary: ai.status === "available" ? ai.analysis.summary : null,
      recommended_actions: ai.status === "available"
        ? ai.analysis.recommended_actions
        : [],
    },
    evidence,
    analysis_modules_status: moduleStatuses,
    recommended_actions: recommendedActions,
    analyzed_at: analyzedAt,
    engine_version: "bantai-independent-analysis-1",
  };
}

export function hasVerifiedThreatEvidence(
  modules: AnalysisModuleResult[],
): boolean {
  const completeModules = modules.filter((item) =>
    item.status === "completed"
  );
  const localThreat = hasVerifiedLocalThreat(completeModules);
  const confirmedCommunityReports = completeModules
    .filter((item) =>
      item.module === "community_reports" &&
      item.evidence_kind === "confirmed_detection"
    )
    .reduce(
      (count, item) =>
        count + Number(item.details?.distinct_reporters ?? 0),
      0,
    );
  return localThreat || confirmedCommunityReports >= 3;
}

function hasVerifiedLocalThreat(modules: AnalysisModuleResult[]): boolean {
  return modules.some((item) =>
    item.module === "local_indicator_database" &&
    item.evidence_kind === "confirmed_detection"
  );
}

function buildAnalysisSummary(
  classification: UnifiedAssessment["classification"],
  rules: RuleResult,
  modules: AnalysisModuleResult[],
  externalThreat: boolean,
): string {
  if (classification === "MALICIOUS") {
    const match = modules.find((item) =>
      item.status === "completed" &&
      item.evidence_kind === "confirmed_detection"
    );
    const source = match?.source ?? "a reviewed threat indicator";
    const category = match?.category ? ` (${match.category})` : "";
    return `A confirmed match was found in ${source}${category}. Do not interact with the content; if it claims to be from an organization, verify through that organization’s official app, website, or a number you already trust.`;
  }
  if (classification === "SUSPICIOUS") {
    const cues = [...new Set(rules.indicators)].slice(0, 3);
    if (cues.length > 0) {
      const cueText = cues.length === 1
        ? cues[0]
        : `${cues.slice(0, -1).join(", ")}${cues.length === 2 ? "" : ","} and ${cues[cues.length - 1]}`;
      const reputationNote = externalThreat
        ? " An external reputation provider also reported a match."
        : "";
      return `Flagged for ${cueText}.${reputationNote} These are warning signs, not proof of who sent the content or what an unvisited page contains; verify independently before acting.`;
    }
    return externalThreat
      ? "An external reputation provider reported a match. Review the threat-intelligence evidence below and verify independently; the report does not establish who sent the content."
      : "One or more structural or reviewed-report checks raised a warning. Review the evidence below and verify independently; a warning is not proof of malicious intent.";
  }
  if (classification === "SAFE") {
    return "All applicable checks completed without a known warning sign. This is not a guarantee of safety; new or unreported threats may not be detected.";
  }
  return "A reliable verdict is not available because evidence is incomplete or insufficient. Treat the content as unverified and use the check details below to see what could not be confirmed.";
}

function calculateConfidence(
  rules: RuleResult,
  applicable: AnalysisModuleResult[],
  completedCount: number,
  classification: UnifiedAssessment["classification"],
  externalThreatWeight = 0,
): { value: number; reasons: string[] } {
  const coverage = applicable.length === 0
    ? 0
    : completedCount / applicable.length;
  const positiveWeight = applicable.reduce((total, item) => {
    const positive = item.evidence_kind === "confirmed_detection" ||
      item.evidence_kind === "suspicious_signal";
    const relevance = item.indicator_hash && item.indicator_type ? 1 : 0.75;
    return total + (positive
      ? moduleReliability[item.module] * item.confidence * relevance
      : 0);
  }, 0) + Math.min(1, rules.score / 8) * 0.7 + externalThreatWeight;
  const negativeWeight = applicable.reduce((total, item) => {
    const relevance = item.indicator_hash && item.indicator_type ? 1 : 0.75;
    return total + (item.status === "completed" &&
        item.evidence_kind === "no_match"
      ? moduleReliability[item.module] * Math.max(item.confidence, 0.2) *
        relevance
      : 0);
  }, 0);
  const totalWeight = positiveWeight + negativeWeight;
  const agreement = totalWeight === 0
    ? 0
    : Math.max(positiveWeight, negativeWeight) / totalWeight;
  const quality = totalWeight === 0 ? 0 : 1 - Math.exp(-totalWeight);
  const certainty = quality * agreement * coverage;
  const value = classification === "UNKNOWN"
    ? Math.round(certainty * 100)
    : Math.round(Math.min(0.95, certainty) * 100);
  return {
    value,
    reasons: [
      `Analysis coverage: ${completedCount} of ${applicable.length} applicable module checks completed.`,
      `Evidence strength is weighted by module reliability, indicator relevance, and the classifier's rule score.`,
      `Weighted evidence agreement: ${Math.round(agreement * 100)}%.`,
    ],
  };
}

export function validateUnifiedAssessment(
  value: unknown,
): value is UnifiedAssessment {
  if (!isRecord(value)) return false;
  return (
    ["SAFE", "SUSPICIOUS", "MALICIOUS", "UNKNOWN"].includes(
      String(value.classification),
    ) &&
    ["LOW", "MEDIUM", "HIGH", "CRITICAL", "UNDETERMINED"].includes(
      String(value.risk_level),
    ) &&
    Number.isInteger(value.confidence) &&
    (value.confidence as number) >= 0 &&
    (value.confidence as number) <= 100 &&
    Array.isArray(value.confidence_reasons) &&
    value.confidence_reasons.length <= 8 &&
    value.confidence_reasons.every((item) => typeof item === "string") &&
    typeof value.analysis_summary === "string" &&
    value.analysis_summary.length > 0 &&
    value.analysis_summary.length <= 500 &&
    Array.isArray(value.indicators) &&
    value.indicators.length <= 15 &&
    value.indicators.every((item) => typeof item === "string" && item.length <= 160) &&
    isRecord(value.rule_analysis) &&
    Array.isArray(value.analysis_modules) &&
    value.analysis_modules.length <= 50 &&
    isRecord(value.ai_analysis) &&
    [
      "available",
      "disabled",
      "not_configured",
      "unavailable",
      "timeout",
      "failed",
      "rate_limited",
      "skipped_verified_threat",
    ].includes(String(value.ai_analysis.status)) &&
    Array.isArray(value.ai_analysis.provider_attempts) &&
    value.ai_analysis.provider_attempts.length <= 10 &&
    value.ai_analysis.provider_attempts.every((attempt) =>
      isRecord(attempt) &&
      typeof attempt.provider === "string" &&
      typeof attempt.status === "string" &&
      [
        "available",
        "budget_unconfigured",
        "budget_check_failed",
        "provider_budget_exhausted",
        "user_budget_exhausted",
        "global_budget_exhausted",
        "user_cooldown",
        "duplicate_request",
        "concurrency_limited",
        "circuit_open",
        "authentication_error",
        "rate_limited",
        "billing_required",
        "model_not_found",
        "model_retired",
        "request_rejected",
        "provider_error",
        "invalid_response",
        "timeout",
        "network_error",
      ].some((status) => status === attempt.status) &&
      (attempt.http_status === undefined ||
        typeof attempt.http_status === "number" &&
        Number.isInteger(attempt.http_status) &&
          attempt.http_status >= 100 &&
          attempt.http_status <= 599)
    ) &&
    Array.isArray(value.ai_analysis.signals) &&
    value.ai_analysis.signals.length <= 10 &&
    value.ai_analysis.signals.every((item) =>
      typeof item === "string" && item.length <= 160
    ) &&
    (value.ai_analysis.summary === null ||
      typeof value.ai_analysis.summary === "string" &&
        value.ai_analysis.summary.length <= 900) &&
    Array.isArray(value.ai_analysis.recommended_actions) &&
    value.ai_analysis.recommended_actions.length <= 5 &&
    value.ai_analysis.recommended_actions.every((item) =>
      typeof item === "string" && item.length <= 200
    ) &&
    Array.isArray(value.evidence) &&
    value.evidence.length <= 30 &&
    value.evidence.every((item) =>
      typeof item === "string" && item.length <= 300
    ) &&
    isRecord(value.analysis_modules_status) &&
    Array.isArray(value.recommended_actions) &&
    value.recommended_actions.length > 0 &&
    value.recommended_actions.length <= 5 &&
    value.recommended_actions.every((item) => typeof item === "string" && item.length <= 240) &&
    typeof value.analyzed_at === "string" &&
    !Number.isNaN(Date.parse(value.analyzed_at)) &&
    typeof value.engine_version === "string"
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
