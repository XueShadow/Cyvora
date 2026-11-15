import type { ScamAnalysisResult } from "../scam-intelligence/scam-patterns.ts";

export type IndicatorType = "url" | "domain" | "ip";
export type AnalysisModuleName =
  | "url_structure"
  | "domain_dns"
  | "ssl_tls"
  | "redirect_analysis"
  | "suspicious_patterns"
  | "local_indicator_database"
  | "community_reports"
  | "external_threat_intelligence"
  | "scam_pattern_recognition"
  | "anomaly_detection"
  | "adaptive_pattern_analysis";
export type ModuleStatus =
  | "completed"
  | "unavailable"
  | "failed"
  | "not_applicable";
export type EvidenceKind =
  | "confirmed_detection"
  | "suspicious_signal"
  | "no_match"
  | "not_checked"
  | "analysis_unavailable"
  | "analysis_failed";

export type NormalizedIndicator = {
  type: IndicatorType;
  value: string;
};

export type AnalysisModuleResult = {
  module: AnalysisModuleName;
  indicator_type: IndicatorType | null;
  indicator_hash: string | null;
  status: ModuleStatus;
  evidence_kind: EvidenceKind;
  confidence: number;
  evidence: string[];
  source: string;
  error_reason?: string;
  category?: string;
  details?: Record<string, unknown>;
  checked_at: string;
};

export type ThreatMatch = {
  indicator_type: IndicatorType;
  indicator_hash: string;
  category: string;
  source_note?: string | null;
  reporter_id?: string;
};

export type TrustedPatternExample = {
  label: "verified_scam" | "verified_legitimate";
  categories: string[];
};

type NetworkModule = Pick<
  AnalysisModuleResult,
  "module" | "indicator_type" | "indicator_hash" | "status" |
    "evidence_kind" | "confidence" | "evidence" | "source" |
    "error_reason" | "category" | "details" | "checked_at"
>;

const source = "Cyvora local analysis";

export function extractIndicators(
  type: "message" | "url" | "screenshot",
  input: string,
): NormalizedIndicator[] {
  const raw = type === "url"
    ? [input.trim()]
    : input.match(/(?:https?:\/\/|www\.)[^\s<>"']+/gi) ?? [];
  const indicators = new Map<string, NormalizedIndicator>();
  for (const candidate of raw.slice(0, 5)) {
    const trimmed = candidate.replace(/[),.!?;:]+$/, "");
    const normalized = trimmed.includes("://") ? trimmed : `https://${trimmed}`;
    let url: URL;
    try {
      url = new URL(normalized);
    } catch {
      continue;
    }
    if (
      (url.protocol !== "https:" && url.protocol !== "http:") ||
      !url.hostname ||
      url.username ||
      url.password
    ) continue;

    const hostname = url.hostname.toLowerCase().replace(/\.$/, "");
    indicators.set(`url:${url.href}`, { type: "url", value: url.href });
    if (isIpAddress(hostname)) {
      const value = hostname.replace(/^\[|\]$/g, "");
      indicators.set(`ip:${value}`, { type: "ip", value });
    } else {
      indicators.set(`domain:${hostname}`, { type: "domain", value: hostname });
    }
  }
  return [...indicators.values()];
}

export function normalizeReportIndicators(
  value: string,
): NormalizedIndicator[] | null {
  const input = value.trim();
  if (!input || input.length > 2048) return null;
  let url: URL;
  try {
    url = new URL(input.includes("://") ? input : `https://${input}`);
  } catch {
    return null;
  }
  if (
    (url.protocol !== "http:" && url.protocol !== "https:") ||
    !url.hostname ||
    url.username ||
    url.password
  ) return null;

  const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, "")
    .replace(/\.$/, "");
  const hostType = isIpAddress(hostname) ? "ip" : "domain";
  return [
    { type: "url", value: url.href },
    { type: hostType, value: hostname },
  ];
}

export async function hashIndicator(
  indicator: NormalizedIndicator,
): Promise<string> {
  const bytes = new TextEncoder().encode(
    `${indicator.type}:${indicator.value}`,
  );
  const hash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", bytes),
  );
  return Array.from(hash, (byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function createModuleResult(
  module: AnalysisModuleName,
  status: ModuleStatus,
  evidenceKind: EvidenceKind,
  evidence: string[],
  options: {
    indicator?: NormalizedIndicator;
    indicatorHash?: string;
    confidence?: number;
    source?: string;
    errorReason?: string;
    category?: string;
    details?: Record<string, unknown>;
  } = {},
): AnalysisModuleResult {
  return {
    module,
    indicator_type: options.indicator?.type ?? null,
    indicator_hash: options.indicatorHash ?? null,
    status,
    evidence_kind: evidenceKind,
    confidence: options.confidence ?? 0,
    evidence: evidence.slice(0, 8),
    source: options.source ?? source,
    ...(options.errorReason ? { error_reason: options.errorReason } : {}),
    ...(options.category ? { category: options.category } : {}),
    ...(options.details ? { details: options.details } : {}),
    checked_at: new Date().toISOString(),
  };
}

export async function buildStaticModules(input: {
  type: "message" | "url" | "screenshot";
  content: string;
  indicators: NormalizedIndicator[];
  rules: ScamAnalysisResult;
  localThreats: ThreatMatch[];
  communityThreats: ThreatMatch[];
  localDatabaseAvailable: boolean;
  communityDatabaseAvailable: boolean;
  trustedExamples?: TrustedPatternExample[];
  trustedExamplesStatus?: "active" | "not_released" | "unavailable";
}): Promise<AnalysisModuleResult[]> {
  const results: AnalysisModuleResult[] = [];
  const urls = input.indicators.filter((item) => item.type === "url");
  const urlFeatures = input.rules.categories.filter((category) =>
    [
      "encoded-domain",
      "shortener",
      "ip-host",
      "embedded-credentials",
      "unusual-port",
      "deep-subdomain",
      "redirect-parameter",
    ].includes(category) ||
    category.startsWith("brand-") ||
    category.startsWith("lookalike-")
  );
  const urlIndicators: string[] = input.rules.indicators.filter((indicator) =>
    indicator === "Suspicious or unusual URL characteristics" ||
    indicator === "Unusual URL structure" ||
    indicator === "Shortened, hidden, or redirecting link" ||
    indicator === "Impersonation or brand spoofing"
  );
  const patternIndicators = input.rules.indicators.filter((indicator) =>
    !urlIndicators.includes(indicator)
  );
  const urlHashes = await Promise.all(urls.map(hashIndicator));

  for (let index = 0; index < urls.length; index++) {
    const indicator = urls[index];
    const hash = urlHashes[index];
    const url = new URL(indicator.value);
    const features = urlFeatures.length > 0
      ? urlFeatures.map((item) => `URL pattern: ${item}`)
      : ["URL syntax and hostname structure were checked locally."];
    results.push(createModuleResult(
      "url_structure",
      "completed",
      urlFeatures.length > 0 ? "suspicious_signal" : "no_match",
      features,
      {
        indicator,
        indicatorHash: hash,
        confidence: urlFeatures.length > 0 ? 0.62 : 0.35,
        category: urlFeatures[0],
        details: {
          scheme: url.protocol.slice(0, -1),
          hostname_length: url.hostname.length,
          subdomain_depth: Math.max(0, url.hostname.split(".").length - 2),
          query_parameter_count: [...url.searchParams.keys()].length,
        },
      },
    ));
    const redirectParameters = [...url.searchParams.entries()]
      .filter(([key, value]) =>
        /^(continue|dest|destination|next|redirect|redirect_uri|return|returnto|target|to|url)$/i
          .test(key) && /^(https?:\/\/|\/\/)/i.test(value)
      )
      .map(([key]) => key);
    results.push(createModuleResult(
      "redirect_analysis",
      "completed",
      redirectParameters.length > 0 ? "suspicious_signal" : "no_match",
      redirectParameters.length > 0
        ? [`Redirect-like URL parameter(s): ${redirectParameters.join(", ")}`]
        : ["Redirect parameters were inspected locally; no destination was fetched."],
      {
        indicator,
        indicatorHash: hash,
        confidence: redirectParameters.length > 0 ? 0.58 : 0.3,
        category: "static_redirect_structure",
      },
    ));
  }

  results.push(createModuleResult(
    "suspicious_patterns",
    "completed",
    patternIndicators.length > 0 ? "suspicious_signal" : "no_match",
    patternIndicators.length > 0
      ? patternIndicators.map((item) => `Pattern: ${item}`)
      : ["No configured scam-language pattern matched."],
    {
      confidence: patternIndicators.length > 0 ? 0.58 : 0.25,
      category: input.rules.categories[0],
    },
  ));
  results.push(createModuleResult(
    "scam_pattern_recognition",
    "completed",
    input.rules.indicators.length > 0 ? "suspicious_signal" : "no_match",
    input.rules.indicators.length > 0
      ? input.rules.indicators.map((item) => `Rule: ${item}`)
      : ["Versioned Cyvora scam-pattern rules completed without a match."],
    {
      confidence: input.rules.indicators.length > 0 ? 0.68 : 0.3,
      category: input.rules.categories[0],
      details: {
        score: input.rules.score,
        categories: input.rules.categories,
        rules_version: input.rules.rulesVersion,
      },
    },
  ));

  const anomaly = analyzeContentAnomalies(input.type, input.content);
  results.push(createModuleResult(
    "anomaly_detection",
    "completed",
    anomaly.score >= 40 ? "suspicious_signal" : "no_match",
    anomaly.findings.length > 0
      ? anomaly.findings
      : ["No configured anomalous-content signals were found."],
    {
      confidence: anomaly.score >= 40 ? 0.62 : 0.25,
      category: anomaly.categories[0],
      source: "Cyvora anomaly heuristics",
      details: {
        anomaly_score: anomaly.score,
        categories: anomaly.categories,
      },
    },
  ));

  const trustedExamplesStatus = input.trustedExamplesStatus ?? "not_released";
  if (trustedExamplesStatus === "unavailable") {
    results.push(createModuleResult(
      "adaptive_pattern_analysis",
      "unavailable",
      "analysis_unavailable",
      [],
      {
        source: "Cyvora moderator-verified pattern examples",
        errorReason: "The active trusted dataset could not be loaded.",
      },
    ));
  } else if (trustedExamplesStatus === "not_released") {
    results.push(createModuleResult(
      "adaptive_pattern_analysis",
      "not_applicable",
      "not_checked",
      [
        "No moderator-verified dataset has passed evaluation and been released; staged examples do not affect scan results.",
      ],
      { source: "Cyvora moderator-verified pattern examples" },
    ));
  } else {
    const adaptive = analyzeTrustedPatternExamples(
      input.rules.categories,
      input.trustedExamples ?? [],
    );
    results.push(createModuleResult(
      "adaptive_pattern_analysis",
      "completed",
      adaptive.scamExamples >= 2 ? "suspicious_signal" : "no_match",
      adaptive.scamExamples >= 2
        ? [
          "At least two moderator-verified scam examples share multiple rule features with this content.",
          "This is a review signal only; it is not proof that the content is malicious.",
        ]
        : adaptive.legitimateExamples > 0
        ? [
          "Some features overlap with moderator-verified legitimate examples; that does not establish safety.",
        ]
        : ["No sufficiently similar moderator-verified examples were available."],
      {
        confidence: adaptive.scamExamples >= 2 ? 0.52 : 0.2,
        source: "Cyvora moderator-verified pattern examples",
        details: {
          similar_verified_scam_examples: adaptive.scamExamples,
          similar_verified_legitimate_examples: adaptive.legitimateExamples,
        },
      },
    ));
  }

  for (const [module, matches] of [
    ["local_indicator_database", input.localThreats],
    ["community_reports", input.communityThreats],
  ] as const) {
    const databaseAvailable = module === "local_indicator_database"
      ? input.localDatabaseAvailable
      : input.communityDatabaseAvailable;
    if (!databaseAvailable) {
      results.push(createModuleResult(
        module,
        "unavailable",
        "analysis_unavailable",
        [],
        { errorReason: "Reviewed threat-indicator data could not be loaded." },
      ));
      continue;
    }
    const byHash = new Map<string, ThreatMatch[]>();
    for (const match of matches) {
      const current = byHash.get(match.indicator_hash) ?? [];
      current.push(match);
      byHash.set(match.indicator_hash, current);
    }
    if (input.indicators.length === 0) {
      results.push(createModuleResult(
        module,
        "completed",
        "no_match",
        ["No URL indicators were present to compare."],
      ));
      continue;
    }
    for (const indicator of input.indicators) {
      const hash = await hashIndicator(indicator);
      const found = byHash.get(hash) ?? [];
      const distinctReporters = new Set(
        found.map((item) => item.reporter_id).filter(Boolean),
      );
      const malicious = module === "local_indicator_database" && found.length > 0;
      const multipleReports = module === "community_reports" &&
        distinctReporters.size >= 3;
      results.push(createModuleResult(
        module,
        "completed",
        malicious || multipleReports
          ? "confirmed_detection"
          : found.length > 0
          ? "suspicious_signal"
          : "no_match",
        found.length > 0
          ? [
            `${found.length} reviewed ${module === "community_reports" ? "community report(s)" : "local indicator record(s)"} matched this exact indicator.`,
            ...[...new Set(found.map((item) => item.category))].slice(0, 3)
              .map((category) => `Category: ${category}`),
          ]
          : ["No reviewed exact-indicator entry matched."],
        {
          indicator,
          indicatorHash: hash,
          confidence: malicious ? 0.95 : multipleReports ? 0.85 : found.length > 0 ? 0.55 : 0.3,
          category: found[0]?.category,
          source: module === "community_reports"
            ? "Reviewed Cyvora community reports"
            : "Cyvora local indicator database",
          details: {
            matching_reports: found.length,
            distinct_reporters: distinctReporters.size,
            review_status: "reviewed",
          },
        },
      ));
    }
  }
  return results;
}

function analyzeContentAnomalies(
  type: "message" | "url" | "screenshot",
  content: string,
): { score: number; categories: string[]; findings: string[] } {
  const categories: string[] = [];
  const findings: string[] = [];
  let score = 0;
  const invisibleCharacters = content.match(
    /[\u00ad\u200b-\u200f\u202a-\u202e\u2060-\u206f\ufeff]/g,
  )?.length ?? 0;
  if (invisibleCharacters > 0) {
    categories.push("hidden-control-characters");
    findings.push(
      "Hidden formatting or bidirectional control characters were found.",
    );
    score += Math.min(60, 35 + invisibleCharacters * 5);
  }

  const hasLatin = /\p{Script=Latin}/u.test(content);
  const hasCyrillic = /\p{Script=Cyrillic}/u.test(content);
  const hasGreek = /\p{Script=Greek}/u.test(content);
  if (hasLatin && (hasCyrillic || hasGreek)) {
    categories.push("mixed-script-text");
    findings.push(
      "Text mixes Latin characters with Cyrillic or Greek characters, which can disguise lookalike words.",
    );
    score += 35;
  }

  const linkCount = extractIndicators(type, content).filter((item) =>
    item.type === "url"
  ).length;
  if (linkCount >= 4) {
    categories.push("many-links");
    findings.push(
      `The content contains ${linkCount} distinct links; check each destination independently.`,
    );
    score += 20;
  }

  return {
    score: Math.min(100, score),
    categories,
    findings: findings.slice(0, 5),
  };
}

function analyzeTrustedPatternExamples(
  categories: string[],
  examples: TrustedPatternExample[],
): { scamExamples: number; legitimateExamples: number } {
  const current = new Set(categories);
  if (current.size < 2) return { scamExamples: 0, legitimateExamples: 0 };

  let scamExamples = 0;
  let legitimateExamples = 0;
  for (const example of examples) {
    if (
      example.label !== "verified_scam" &&
      example.label !== "verified_legitimate"
    ) continue;
    const exampleCategories = new Set(
      example.categories.filter((category) => typeof category === "string"),
    );
    if (exampleCategories.size < 2) continue;
    const overlap = [...current].filter((category) =>
      exampleCategories.has(category)
    ).length;
    const similarity = overlap /
      (current.size + exampleCategories.size - overlap);
    if (overlap < 2 || similarity < 0.6) continue;
    if (example.label === "verified_scam") scamExamples++;
    else legitimateExamples++;
  }
  return { scamExamples, legitimateExamples };
}

function isIpAddress(host: string): boolean {
  return /^\d{1,3}(?:\.\d{1,3}){3}$/.test(host) ||
    host.includes(":") || host.startsWith("[") && host.endsWith("]");
}
