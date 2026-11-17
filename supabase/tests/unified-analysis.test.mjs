import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  buildStaticModules,
  createModuleResult,
  extractIndicators,
  hashIndicator,
  normalizeReportIndicators,
} from "../functions/_shared/analysis-modules.ts";
import {
  analyzeDomainAndTls,
  createDnsOverHttpsResolver,
  isPublicIp,
} from "../functions/_shared/network-analysis.ts";
import {
  assessUnifiedRisk,
  hasVerifiedThreatEvidence,
  validateUnifiedAssessment,
} from "../functions/_shared/risk-assessment.ts";
import {
  analyzeWithProviders,
  chatWithProviders,
  getConfiguredProviders,
  getAiProviderRegistry,
  parseProviderOrder,
} from "../functions/_shared/ai-provider-analysis.ts";
import { createRequestFingerprint } from "../functions/_shared/request-fingerprint.ts";
import { classifyScamContent } from "../functions/scam-intelligence/scam-patterns.ts";

const here = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(here, "../..");
const cleanRuleResult = {
  score: 0,
  categories: [],
  indicators: [],
  rulesVersion: "test-rules",
};
const noAi = {
  status: "disabled",
  provider: null,
  providers_tried: [],
  provider_attempts: [],
};
const fixedTime = "2026-11-13T00:00:00.000Z";
const publicDns = {
  async resolve(_hostname, type) {
    return type === "A" ? ["8.8.8.8"] : [];
  },
  async verifyTls() {},
};

function withoutAttemptDurations(attempts) {
  return attempts.map(({ duration_ms, ...attempt }) => attempt);
}

async function analyzeUrl(
  value,
  {
    localThreats = [],
    communityThreats = [],
    localDatabaseAvailable = true,
    communityDatabaseAvailable = true,
    dnsTlsTools = publicDns,
    ai = noAi,
  } = {},
) {
  const indicators = extractIndicators("url", value);
  const rules = classifyScamContent("url", value);
  const staticModules = await buildStaticModules({
    type: "url",
    content: value,
    indicators,
    rules,
    localThreats,
    communityThreats,
    localDatabaseAvailable,
    communityDatabaseAvailable,
  });
  const networkModules = await Promise.all(
    indicators.filter((item) => item.type === "url").map((indicator) =>
      analyzeDomainAndTls(indicator, dnsTlsTools)
    ),
  );
  return assessUnifiedRisk(
    {
      score: rules.score,
      categories: rules.categories,
      indicators: rules.indicators,
      rulesVersion: rules.rulesVersion,
    },
    [...staticModules, ...networkModules.flat()],
    ai,
    fixedTime,
  );
}

test("URLs and their host indicators are normalized independently", async () => {
  const indicators = extractIndicators("url", "HTTPS://Example.com/path#fragment");
  assert.deepEqual(
    indicators.map((item) => item.type),
    ["url", "domain"],
  );
  assert.equal(indicators[0].value, "https://example.com/path#fragment");
  assert.equal(
    await hashIndicator(indicators[0]),
    await hashIndicator({ type: "url", value: indicators[0].value }),
  );
});

test("five extracted links stay within the persisted module-result limit", async () => {
  const content = [
    "https://one.example/",
    "https://two.example/",
    "https://three.example/",
    "https://four.example/",
    "https://five.example/",
  ].join(" ");
  const indicators = extractIndicators("message", content);
  const staticModules = await buildStaticModules({
    type: "message",
    content,
    indicators,
    rules: cleanRuleResult,
    localThreats: [],
    communityThreats: [],
    localDatabaseAvailable: true,
    communityDatabaseAvailable: true,
  });
  const networkModules = await Promise.all(
    indicators.filter((item) => item.type === "url").map((indicator) =>
      analyzeDomainAndTls(indicator, publicDns)
    ),
  );
  assert.ok(staticModules.length + networkModules.flat().length <= 50);
});

test("anomaly cues raise only a suspicious signal, never a malicious verdict", async () => {
  const content = "Check your account\u200B at https://example.com";
  const indicators = extractIndicators("message", content);
  const rules = classifyScamContent("message", content);
  const modules = await buildStaticModules({
    type: "message",
    content,
    indicators,
    rules,
    localThreats: [],
    communityThreats: [],
    localDatabaseAvailable: true,
    communityDatabaseAvailable: true,
  });
  const anomaly = modules.find((item) => item.module === "anomaly_detection");
  assert.equal(anomaly?.evidence_kind, "suspicious_signal");
  assert.equal(anomaly?.details?.anomaly_score >= 40, true);

  const result = assessUnifiedRisk({
    score: 0,
    categories: [],
    indicators: [],
    rulesVersion: "test-rules",
  }, [anomaly], noAi, fixedTime);
  assert.equal(result.classification, "SUSPICIOUS");
  assert.notEqual(result.classification, "MALICIOUS");
});

test("adaptive pattern signals require moderator-verified examples", async () => {
  const content = "urgent account payment";
  const rules = {
    ...cleanRuleResult,
    categories: ["urgency", "payment-request"],
  };
  const base = {
    type: "message",
    content,
    indicators: [],
    rules,
    localThreats: [],
    communityThreats: [],
    localDatabaseAvailable: true,
    communityDatabaseAvailable: true,
  };
  const singleExample = await buildStaticModules({
    ...base,
    trustedExamplesStatus: "active",
    trustedExamples: [{
      label: "verified_scam",
      categories: ["urgency", "payment-request"],
    }],
  });
  assert.equal(
    singleExample.find((item) =>
      item.module === "adaptive_pattern_analysis"
    )?.evidence_kind,
    "no_match",
  );

  const repeatedExamples = await buildStaticModules({
    ...base,
    trustedExamplesStatus: "active",
    trustedExamples: Array.from({ length: 2 }, () => ({
      label: "verified_scam",
      categories: ["urgency", "payment-request"],
    })),
  });
  assert.equal(
    repeatedExamples.find((item) =>
      item.module === "adaptive_pattern_analysis"
    )?.evidence_kind,
    "suspicious_signal",
  );
});

test("community reports accept validated indicators and store only typed hashes", async () => {
  const normalized = normalizeReportIndicators(
    "https://Example.com/path?token=private#section",
  );
  assert.deepEqual(normalized.map((item) => item.type), ["url", "domain"]);
  const hashes = await Promise.all(normalized.map(hashIndicator));
  assert.ok(hashes.every((hash) => /^[0-9a-f]{64}$/.test(hash)));
  assert.equal(hashes.some((hash) => hash.includes("private")), false);
  assert.equal(normalizeReportIndicators("javascript:alert(1)"), null);
  assert.equal(
    normalizeReportIndicators("https://user:password@example.com"),
    null,
  );
});

test("fully completed local checks with no findings produce SAFE with caveat", async () => {
  const result = await analyzeUrl("https://example.com/");
  assert.equal(result.classification, "SAFE");
  assert.equal(result.risk_level, "LOW");
  assert.ok(result.confidence > 0);
  assert.match(result.analysis_summary, /not a guarantee/i);
});

test("suspicious explanations name the flagged cues and include prevention steps", () => {
  const cues = [
    "Urgent or coercive language",
    "Unexpected prize, reward, or refund",
    "Suspicious or unusual URL characteristics",
  ];
  const result = assessUnifiedRisk({
    score: 4,
    categories: ["urgency", "unexpected-prize"],
    indicators: cues,
    rulesVersion: "test-rules",
  }, [], noAi, fixedTime);
  assert.equal(result.classification, "SUSPICIOUS");
  for (const cue of cues) {
    assert.ok(result.analysis_summary.includes(cue));
  }
  assert.match(result.analysis_summary, /not proof/i);
  assert.match(result.recommended_actions.join(" "), /official app or website/i);
  assert.match(result.recommended_actions.join(" "), /one-time codes/i);
  assert.equal(validateUnifiedAssessment(result), true);
});

test("assessment evidence matches the Flutter response limits", async () => {
  const result = await analyzeUrl("https://example.com/");
  assert.deepEqual(result.rule_analysis, {
    score: 0,
    categories: [],
    indicators: [],
    version: "bantai-rules-1",
  });
  assert.equal("rulesVersion" in result.rule_analysis, false);
  const maximumEvidence = {
    ...result,
    evidence: Array.from({ length: 30 }, (_, index) => `finding ${index}`),
  };
  assert.equal(validateUnifiedAssessment(maximumEvidence), true);
  assert.equal(
    validateUnifiedAssessment({
      ...maximumEvidence,
      evidence: [...maximumEvidence.evidence, "one more finding"],
    }),
    false,
  );
  assert.equal(
    validateUnifiedAssessment({
      ...result,
      evidence: ["x".repeat(301)],
    }),
    false,
  );
  assert.ok(result.evidence.every((item) => item.length <= 300));
});

test("HTTP URLs are suspicious rather than treated as missing TLS data", async () => {
  const result = await analyzeUrl("http://example.com/");
  assert.equal(result.classification, "SUSPICIOUS");
  assert.ok(result.analysis_modules.some((item) =>
    item.module === "ssl_tls" &&
    item.status === "completed" &&
    item.category === "unencrypted_http"
  ));

  let tlsAttempts = 0;
  const unresolvedResult = await analyzeUrl(
    "http://fake-prize-claim.example.com/",
    {
      dnsTlsTools: {
        async resolve() {
          return [];
        },
        async verifyTls() {
          tlsAttempts++;
        },
      },
    },
  );
  assert.equal(unresolvedResult.classification, "SUSPICIOUS");
  assert.ok(unresolvedResult.analysis_modules.some((item) =>
    item.module === "domain_dns" &&
    item.category === "no_dns_records"
  ));
  assert.ok(unresolvedResult.analysis_modules.some((item) =>
    item.module === "ssl_tls" &&
    item.status === "completed" &&
    item.category === "unencrypted_http"
  ));
  assert.equal(tlsAttempts, 0);
});

test("an exact curated local indicator match produces MALICIOUS", async () => {
  const indicator = { type: "url", value: "https://bad.example/login" };
  const hash = await hashIndicator(indicator);
  const result = await analyzeUrl(indicator.value, {
    localThreats: [{
      indicator_type: "url",
      indicator_hash: hash,
      category: "Phishing",
    }],
  });
  assert.equal(result.classification, "MALICIOUS");
  assert.equal(result.analysis_modules.some((item) =>
    item.module === "local_indicator_database" &&
    item.evidence_kind === "confirmed_detection"
  ), true);
});

test("verified threat evidence can skip optional AI without weakening the verdict", async () => {
  const indicator = { type: "url", value: "https://bad.example/login" };
  const hash = await hashIndicator(indicator);
  const result = await analyzeUrl(indicator.value, {
    localThreats: [{
      indicator_type: "url",
      indicator_hash: hash,
      category: "Phishing",
    }],
  });
  assert.equal(hasVerifiedThreatEvidence(result.analysis_modules), true);

  const assessment = assessUnifiedRisk(
    cleanRuleResult,
    result.analysis_modules,
    {
      status: "skipped_verified_threat",
      provider: null,
      providers_tried: [],
      provider_attempts: [],
    },
    fixedTime,
  );
  assert.equal(assessment.classification, "MALICIOUS");
  assert.equal(assessment.ai_analysis.status, "skipped_verified_threat");
  assert.deepEqual(assessment.ai_analysis.provider_attempts, []);
  assert.equal(validateUnifiedAssessment(assessment), true);

  const suspicious = await analyzeUrl("urgent verify your account and pay now");
  assert.equal(hasVerifiedThreatEvidence(suspicious.analysis_modules), false);
});

test("one reviewed community report is suspicious, not confirmed malicious", async () => {
  const indicator = { type: "url", value: "https://reported.example/" };
  const hash = await hashIndicator(indicator);
  const result = await analyzeUrl(indicator.value, {
    communityThreats: [{
      indicator_type: "url",
      indicator_hash: hash,
      category: "Phishing",
      reporter_id: "reporter-one",
    }],
  });
  assert.equal(result.classification, "SUSPICIOUS");
  assert.equal(result.analysis_modules.some((item) =>
    item.module === "community_reports" &&
    item.evidence_kind === "confirmed_detection"
  ), false);
});

test("three distinct reviewed community reporters can confirm a match", async () => {
  const indicator = { type: "url", value: "https://reported.example/" };
  const hash = await hashIndicator(indicator);
  const reports = ["one", "two", "three"].map((id) => ({
    indicator_type: "url",
    indicator_hash: hash,
    category: "Phishing",
    reporter_id: id,
  }));
  const result = await analyzeUrl(indicator.value, {
    communityThreats: reports,
  });
  assert.equal(result.classification, "MALICIOUS");
});

test("external reputation matches flag suspicious without overriding the malicious threshold", async () => {
  const url = { type: "url", value: "https://reported.example/" };
  const base = await analyzeUrl(url.value);
  const externalMatch = createModuleResult(
    "external_threat_intelligence",
    "completed",
    "confirmed_detection",
    ["External provider match."],
    { indicator: url, confidence: 0.8 },
  );
  const rules = {
    score: base.rule_analysis.score,
    categories: base.rule_analysis.categories,
    indicators: base.rule_analysis.indicators,
    rulesVersion: base.rule_analysis.version,
  };
  const externalOnly = assessUnifiedRisk(
    rules,
    [...base.analysis_modules, externalMatch],
    noAi,
    fixedTime,
  );
  assert.equal(externalOnly.classification, "SUSPICIOUS");
  assert.equal(externalOnly.risk_level, "MEDIUM");

  const localMatch = createModuleResult(
    "local_indicator_database",
    "completed",
    "confirmed_detection",
    ["Reviewed local indicator matched exactly."],
    { indicator: url, confidence: 1 },
  );
  const reviewedLocal = assessUnifiedRisk(
    rules,
    [...base.analysis_modules, externalMatch, localMatch],
    noAi,
    fixedTime,
  );
  assert.equal(reviewedLocal.classification, "MALICIOUS");
});

test("database and DNS outages remain UNKNOWN, not clean", async () => {
  const result = await analyzeUrl("https://example.com/", {
    localDatabaseAvailable: false,
    communityDatabaseAvailable: false,
    dnsTlsTools: {
      async resolve() {
        throw new Error("DNS unavailable");
      },
      async verifyTls() {
        assert.fail("TLS must not run when DNS is unavailable");
      },
    },
  });
  assert.equal(result.classification, "UNKNOWN");
  assert.equal(result.risk_level, "UNDETERMINED");
  assert.ok(result.analysis_modules.some((item) =>
    item.status === "unavailable"
  ));
});

test("DNS-over-HTTPS resolves only valid records of the requested type", async () => {
  const calls = [];
  const resolve = createDnsOverHttpsResolver(async (input, init) => {
    calls.push({ input: String(input), init });
    return Response.json({
      Status: 0,
      Answer: [
        { type: 1, data: "8.8.8.8" },
        { type: 1, data: "127.0.0.1" },
        { type: 28, data: "2001:4860:4860::8888" },
        { type: 1, data: "not-an-ip" },
      ],
    });
  });
  assert.deepEqual(await resolve("example.com", "A"), [
    "8.8.8.8",
    "127.0.0.1",
  ]);
  assert.deepEqual(await resolve("example.com", "AAAA"), [
    "2001:4860:4860::8888",
  ]);
  assert.equal(calls.length, 2);
  assert.equal(
    new URL(calls[0].input).searchParams.get("name"),
    "example.com",
  );
  assert.equal(new URL(calls[0].input).searchParams.get("type"), "A");
  assert.equal(calls[0].init.headers.Accept, "application/dns-json");
  assert.equal(calls[0].init.redirect, "error");
});

test("DNS-over-HTTPS treats NXDOMAIN as no records and rejects invalid responses", async () => {
  const resolveMissing = createDnsOverHttpsResolver(async () =>
    Response.json({ Status: 3 })
  );
  assert.deepEqual(await resolveMissing("missing.example", "A"), []);

  const resolveInvalid = createDnsOverHttpsResolver(async () =>
    Response.json({ Status: 0, Answer: "invalid" })
  );
  await assert.rejects(resolveInvalid("example.com", "A"), TypeError);
});

test("runtime TLS capability restrictions remain unavailable, not scan failures", async () => {
  const result = await analyzeDomainAndTls(
    { type: "url", value: "https://example.com/" },
    {
      async resolve(_hostname, type) {
        return type === "A" ? ["8.8.8.8"] : [];
      },
      async verifyTls() {
        const error = new Error("Permission denied");
        error.name = "NotCapable";
        throw error;
      },
    },
  );
  assert.equal(result[1].status, "unavailable");
  assert.match(result[1].error_reason, /unavailable in this runtime/i);
});

test("private, reserved, mapped, and transition IPs are not probeable", async () => {
  for (const address of [
    "127.0.0.1",
    "10.0.0.1",
    "169.254.1.1",
    "192.168.1.1",
    "::ffff:127.0.0.1",
    "2001:20::1",
    "2002:7f00:1::",
  ]) {
    assert.equal(isPublicIp(address), false, address);
  }
  assert.equal(isPublicIp("8.8.8.8"), true);
  assert.equal(isPublicIp("2001:4860:4860::8888"), true);

  let tlsCalls = 0;
  const results = await analyzeDomainAndTls(
    { type: "url", value: "https://public.example/" },
    {
      async resolve(_hostname, type) {
        return type === "A" ? ["127.0.0.1"] : [];
      },
      async verifyTls() {
        tlsCalls++;
      },
    },
  );
  assert.equal(tlsCalls, 0);
  assert.equal(results[0].evidence_kind, "suspicious_signal");
  assert.equal(results[1].status, "unavailable");
});

test("AI-provider outage is reported separately and cannot change the verdict", async () => {
  const ai = await analyzeWithProviders({
    contentType: "url",
    content: "https://example.com/",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "test-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async () => {
    throw new TypeError("connection refused");
  });
  assert.equal(ai.status, "unavailable");
  assert.deepEqual(ai.providers_tried, ["gemini"]);
  assert.deepEqual(withoutAttemptDurations(ai.provider_attempts), [{
    provider: "gemini",
    status: "network_error",
  }]);

  const result = await analyzeUrl("https://example.com/", { ai });
  assert.equal(result.classification, "SAFE");
  assert.equal(result.ai_analysis.status, "unavailable");
  assert.equal(result.evidence.some((item) => item.startsWith("AI-provider")), false);
});

test("AI provider budgets deny calls before contacting external providers", async () => {
  let fetchCalls = 0;
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic text.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "gemini-model",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "groq-model",
      })[name];
    },
  }, async () => {
    fetchCalls++;
    throw new Error("Budget denial must prevent provider calls.");
  }, {
    async authorize() {
      return { allowed: false, reason: "global_budget_exhausted" };
    },
    async complete() {
      assert.fail("Denied provider attempts must not be recorded as requests.");
    },
  });

  assert.equal(result.status, "rate_limited");
  assert.deepEqual(result.providers_tried, []);
  assert.equal(fetchCalls, 0);
  assert.equal(result.provider_attempts[0].status, "global_budget_exhausted");
});

test("AI calls fail closed when daily request budgets are not configured", async () => {
  let fetchCalls = 0;
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic text.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "gemini-model",
      })[name];
    },
  }, async () => {
    fetchCalls++;
    throw new Error("Unconfigured budgets must prevent provider calls.");
  }, {
    async authorize() {
      return { allowed: false, reason: "budget_unconfigured" };
    },
    async complete() {
      assert.fail("Unconfigured provider attempts must not be completed.");
    },
  });

  assert.equal(result.status, "not_configured");
  assert.equal(fetchCalls, 0);
  assert.equal(result.provider_attempts[0].status, "budget_unconfigured");
});

test("assistant chat is also gated by provider request budgets", async () => {
  let fetchCalls = 0;
  const result = await chatWithProviders([{
    role: "user",
    content: "How do I verify this message?",
  }], {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "gemini-model",
      })[name];
    },
  }, async () => {
    fetchCalls++;
    throw new Error("Budget denial must prevent provider calls.");
  }, {
    async authorize() {
      return { allowed: false, reason: "user_budget_exhausted" };
    },
    async complete() {
      assert.fail("Denied provider attempts must not be recorded as requests.");
    },
  });

  assert.equal(result.status, "rate_limited");
  assert.equal(fetchCalls, 0);
  assert.equal(result.provider_attempts[0].status, "user_budget_exhausted");
});

test("assistant chat stops before fallback for cooldown, duplicates, and concurrency limits", async () => {
  for (const reason of [
    "user_cooldown",
    "duplicate_request",
    "concurrency_limited",
  ]) {
    let fetchCalls = 0;
    const result = await chatWithProviders([{
      role: "user",
      content: "How do I verify this message?",
    }], {
      get(name) {
        return ({
          AI_PROVIDER_ORDER: "gemini,groq",
          GEMINI_API_KEY: "gemini-key",
          GEMINI_MODEL: "gemini-model",
          GROQ_API_KEY: "groq-key",
          GROQ_MODEL: "groq-model",
        })[name];
      },
    }, async () => {
      fetchCalls++;
      throw new Error("A denied request must not reach a provider.");
    }, {
      async authorize(provider) {
        assert.equal(provider, "gemini");
        return { allowed: false, reason };
      },
      async complete() {
        assert.fail("Denied provider attempts must not be completed.");
      },
    });

    assert.equal(result.status, "rate_limited");
    assert.equal(fetchCalls, 0);
    assert.deepEqual(result.providers_tried, []);
    assert.deepEqual(result.provider_attempts.map((item) => item.status), [
      reason,
    ]);
  }
});

test("AI provider circuit denial does not consume fallback quota", async () => {
  const attempted = [];
  const completed = [];
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic text.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "gemini-model",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "groq-model",
      })[name];
    },
  }, async (url) => {
    attempted.push(url);
    return new Response(JSON.stringify({
      choices: [{
        message: {
          content: JSON.stringify({
            signals: [],
            summary: "The supplied evidence does not establish a threat.",
            recommended_actions: [],
          }),
        },
      }],
    }), { status: 200 });
  }, {
    async authorize(provider) {
      return provider === "gemini"
        ? { allowed: false, reason: "circuit_open" }
        : { allowed: true, reservationId: "reservation-groq" };
    },
    async complete(attempt) {
      completed.push(attempt);
    },
  });

  assert.equal(result.status, "unavailable");
  assert.equal(result.provider, null);
  assert.equal(attempted.length, 0);
  assert.deepEqual(completed, []);
  assert.deepEqual(result.providers_tried, []);
  assert.equal(result.provider_attempts[0].status, "circuit_open");
});

test("fallback requests complete the reservation issued for that provider", async () => {
  const authorizations = [];
  const completions = [];
  let fetchCalls = 0;
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic text.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "gemini-model",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "groq-model",
      })[name];
    },
  }, async () => {
    fetchCalls++;
    if (fetchCalls === 1) return new Response("unavailable", { status: 503 });
    return new Response(JSON.stringify({
      choices: [{
        message: {
          content: JSON.stringify({
            signals: [],
            summary: "The available evidence does not establish a threat.",
            recommended_actions: ["Verify requests through an official channel."],
          }),
        },
      }],
    }), { status: 200 });
  }, {
    async authorize(provider) {
      authorizations.push(provider);
      return {
        allowed: true,
        reservationId: provider === "gemini"
          ? "reservation-gemini"
          : "reservation-groq",
      };
    },
    async complete(attempt, reservationId) {
      completions.push({ provider: attempt.provider, reservationId });
    },
  });

  assert.equal(result.status, "available");
  assert.deepEqual(authorizations, ["gemini", "groq"]);
  assert.deepEqual(completions, [
    { provider: "gemini", reservationId: "reservation-gemini" },
    { provider: "groq", reservationId: "reservation-groq" },
  ]);
});

test("provider timeouts record the reserved attempt before returning", async () => {
  const completions = [];
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic text.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "gemini-model",
      })[name];
    },
  }, async () => {
    throw new DOMException("Provider timed out.", "AbortError");
  }, {
    async authorize() {
      return { allowed: true, reservationId: "reservation-timeout" };
    },
    async complete(attempt, reservationId) {
      completions.push({ provider: attempt.provider, status: attempt.status, reservationId });
    },
  });

  assert.equal(result.status, "timeout");
  assert.deepEqual(completions, [{
    provider: "gemini",
    status: "timeout",
    reservationId: "reservation-timeout",
  }]);
});

test("daily quota denial does not consume fallback provider quota", async () => {
  for (const reason of [
    "provider_budget_exhausted",
    "user_budget_exhausted",
    "global_budget_exhausted",
  ]) {
    const authorized = [];
    let fetchCalls = 0;
    const result = await analyzeWithProviders({
      contentType: "message",
      content: "Synthetic text.",
      ruleFindings: [],
      threatFindings: [],
    }, {
      get(name) {
        return ({
          AI_PROVIDER_ORDER: "gemini,groq",
          GEMINI_API_KEY: "gemini-key",
          GEMINI_MODEL: "gemini-model",
          GROQ_API_KEY: "groq-key",
          GROQ_MODEL: "groq-model",
        })[name];
      },
    }, async () => {
      fetchCalls++;
      throw new Error("Quota denial must prevent provider calls.");
    }, {
      async authorize(provider) {
        authorized.push(provider);
        return { allowed: false, reason };
      },
      async complete() {
        assert.fail("Denied provider attempts must not be completed.");
      },
    });

    assert.equal(result.status, "rate_limited");
    assert.deepEqual(authorized, ["gemini"]);
    assert.equal(fetchCalls, 0);
    assert.deepEqual(result.provider_attempts.map((item) => item.status), [
      reason,
    ]);
  }
});

test("provider rate limits stop fallback instead of spending another quota", async () => {
  let fetchCalls = 0;
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic text.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "gemini-model",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "groq-model",
      })[name];
    },
  }, async () => {
    fetchCalls++;
    return new Response("rate limited", { status: 429 });
  });

  assert.equal(result.status, "rate_limited");
  assert.equal(fetchCalls, 1);
  assert.deepEqual(result.providers_tried, ["gemini"]);
  assert.deepEqual(result.provider_attempts.map((attempt) => attempt.provider), [
    "gemini",
  ]);
});

test("request fingerprints are stable, user-scoped, and do not reveal content", async () => {
  const content = "A synthetic message containing an OTP.";
  const fingerprint = await createRequestFingerprint(
    "test-only-hmac-key",
    "user-1",
    "scan:message",
    content,
  );
  assert.match(fingerprint, /^[0-9a-f]{64}$/);
  assert.equal(
    await createRequestFingerprint(
      "test-only-hmac-key",
      "user-1",
      "scan:message",
      content,
    ),
    fingerprint,
  );
  assert.notEqual(
    await createRequestFingerprint(
      "test-only-hmac-key",
      "user-2",
      "scan:message",
      content,
    ),
    fingerprint,
  );
  assert.notEqual(
    await createRequestFingerprint(
      "test-only-hmac-key",
      "user-1",
      "assistant_chat",
      content,
    ),
    fingerprint,
  );
  assert.equal(fingerprint.includes(content), false);
});

test("AI outcome accounting failure stops provider fallback", async () => {
  let fetchCalls = 0;
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic text.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "gemini-model",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "groq-model",
      })[name];
    },
  }, async () => {
    fetchCalls++;
    return new Response("unavailable", { status: 503 });
  }, {
    async authorize() {
      return { allowed: true, reservationId: "reservation-gemini" };
    },
    async complete() {
      throw new Error("Accounting failure");
    },
  });

  assert.equal(result.status, "unavailable");
  assert.equal(fetchCalls, 1);
  assert.deepEqual(result.providers_tried, ["gemini"]);
});

test("provider order is validated, deduplicated, and capped at primary plus fallback", () => {
  assert.deepEqual(
    parseProviderOrder("gemini, groq, INVALID, gemini,openrouter"),
    ["gemini", "groq"],
  );
  assert.deepEqual(parseProviderOrder(""), []);
});

test("the provider client sends its API key and falls back in configured order", async () => {
  const apiKey = "a".repeat(32);
  const requests = [];
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Please review this message.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq",
        GEMINI_API_KEY: apiKey,
        GEMINI_MODEL: "test-gemini-model",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "test-groq-model",
      })[name];
    },
  }, async (url, options) => {
    requests.push({ url, options });
    if (url.includes("generativelanguage")) {
      return new Response("provider unavailable", { status: 503 });
    }
    return new Response(JSON.stringify({
      choices: [{
        message: {
          content: JSON.stringify({
            signals: [],
            summary: "No specific scam signals were identified.",
            recommended_actions: [],
          }),
        },
      }],
    }), { status: 200 });
  });
  assert.equal(result.status, "available");
  assert.equal(result.provider, "groq");
  assert.deepEqual(result.providers_tried, ["gemini", "groq"]);
  assert.deepEqual(withoutAttemptDurations(result.provider_attempts), [
    {
      provider: "gemini",
      status: "provider_error",
      http_status: 503,
    },
    {
      provider: "groq",
      status: "available",
      http_status: 200,
    },
  ]);
  assert.ok(result.provider_attempts.every((attempt) =>
    Number.isSafeInteger(attempt.duration_ms) && attempt.duration_ms >= 0
  ));
  assert.equal(requests.length, 2);
  assert.equal(
    "response_format" in JSON.parse(requests[0].options.body),
    false,
  );
  assert.equal(
    requests[0].options.headers.Authorization,
    `Bearer ${apiKey}`,
  );
  assert.equal(requests[1].options.headers.Authorization, "Bearer groq-key");
});

test("AI URL analysis redacts token-like path segments before sending content", async () => {
  const token = "A".repeat(32);
  let requestBody;
  const result = await analyzeWithProviders({
    contentType: "url",
    content: `https://example.com/reset/${token}?session=private#fragment`,
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "test-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async (_url, options) => {
    requestBody = JSON.parse(options.body);
    return Response.json({
      choices: [{
        message: {
          content: JSON.stringify({
            signals: [],
            summary: "The URL could not be independently verified.",
            recommended_actions: [],
          }),
        },
      }],
    });
  });

  assert.equal(result.status, "available");
  const sentUrl = JSON.parse(requestBody.messages[1].content).untrusted_content;
  assert.match(sentUrl, /example\.com\/reset\/\[redacted\]/i);
  assert.doesNotMatch(sentUrl, new RegExp(token));
  assert.doesNotMatch(sentUrl, /session=private|fragment/);
});

test("the safety assistant answers the latest question with redacted context", async () => {
  const messages = [
    { role: "user", content: "I received a message asking for a login code." },
    { role: "assistant", content: "Never share one-time codes." },
    {
      role: "user",
      content: "I already sent 123456. What should I do? Contact me at help@example.com.",
    },
  ];
  let requestBody;
  const result = await chatWithProviders(messages, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "test-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async (_url, options) => {
    requestBody = JSON.parse(options.body);
    return new Response(JSON.stringify({
      choices: [{
        message: {
          content:
            "Contact the service through its official app and secure your account.",
        },
      }],
    }), { status: 200 });
  });

  assert.equal(result.status, "available");
  assert.match(result.reply, /^Contact the service/);
  assert.deepEqual(requestBody.messages.map(({ role }) => role), [
    "system",
    "user",
    "assistant",
    "user",
  ]);
  assert.match(requestBody.messages[0].content, /Answer the user's latest question directly/);
  assert.match(requestBody.messages[0].content, /do not classify the user's message/);
  assert.match(requestBody.messages[3].content, /\[redacted code\]/);
  assert.match(requestBody.messages[3].content, /\[redacted email\]/);
});

test("AI fallback can be disabled to enforce primary-provider-only execution", async () => {
  const requestedProviders = [];
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Please review this message.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq",
        AI_FALLBACK_ENABLED: "false",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "test-gemini-model",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "test-groq-model",
      })[name];
    },
  }, async (url) => {
    requestedProviders.push(String(url));
    return new Response("unavailable", { status: 503 });
  });
  assert.equal(result.status, "unavailable");
  assert.deepEqual(result.providers_tried, ["gemini"]);
  assert.deepEqual(withoutAttemptDurations(result.provider_attempts), [{
    provider: "gemini",
    status: "provider_error",
    http_status: 503,
  }]);
  assert.deepEqual(requestedProviders, [
    "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
  ]);
});

test("AI provider auth failures expose a safe code without provider response text", async () => {
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "This is synthetic text for a provider connection check.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "test-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async () => new Response("sensitive provider error body", {
    status: 401,
  }));
  assert.equal(result.status, "failed");
  assert.deepEqual(withoutAttemptDurations(result.provider_attempts), [{
    provider: "gemini",
    status: "authentication_error",
    http_status: 401,
  }]);
  assert.equal(
    JSON.stringify(result).includes("sensitive provider error body"),
    false,
  );
});

test("AI provider failures distinguish billing, missing models, and retired models", async () => {
  for (const [httpStatus, status] of [
    [402, "billing_required"],
    [404, "model_not_found"],
    [410, "model_retired"],
  ]) {
    const result = await analyzeWithProviders({
      contentType: "message",
      content: "Synthetic benign message.",
      ruleFindings: [],
      threatFindings: [],
    }, {
      get(name) {
        return ({
          AI_PROVIDER_ORDER: "gemini",
          GEMINI_API_KEY: "test-key",
          GEMINI_MODEL: "test-model",
        })[name];
      },
    }, async () => new Response("provider error details", {
      status: httpStatus,
    }));
    assert.equal(result.status, "failed");
    assert.deepEqual(withoutAttemptDurations(result.provider_attempts), [{
      provider: "gemini",
      status,
      http_status: httpStatus,
    }]);
    assert.equal(
      JSON.stringify(result).includes("provider error details"),
      false,
    );
    const assessment = assessUnifiedRisk(
      cleanRuleResult,
      [],
      result,
      fixedTime,
    );
    assert.equal(validateUnifiedAssessment(assessment), true);
  }
});

test("AI provider accepts a validated JSON response wrapped in a code fence", async () => {
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic benign message.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "test-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async () => Response.json({
    choices: [{
      message: {
        content: '```json\n{"signals":[],"summary":"No specific signals.","recommended_actions":[]}\n```',
      },
    }],
  }));
  assert.equal(result.status, "available");
  assert.equal(result.provider_attempts[0].status, "available");
});

test("AI provider extracts validated JSON from a text response block", async () => {
  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic benign message.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "openrouter",
        OPENROUTER_API_KEY: "test-key",
        OPENROUTER_MODEL: "test-model",
      })[name];
    },
  }, async () => Response.json({
    choices: [{
      message: {
        content: [{
          type: "text",
          text: 'Here is the result:\n{"signals":[],"summary":"No specific signals.","recommended_actions":[]}',
        }],
      },
    }],
  }));
  assert.equal(result.status, "available");
  assert.equal(result.provider, "openrouter");
  assert.equal(result.analysis.summary, "No specific signals.");
});

test("providers without keys are skipped and provider order can be configured", () => {
  assert.deepEqual(
    parseProviderOrder("gemini, groq, INVALID, gemini,openrouter"),
    ["gemini", "groq"],
  );
  const providers = getConfiguredProviders({
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq,cloudflare",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "test-gemini-model",
        CLOUDFLARE_API_TOKEN: "cloudflare-key",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "test-groq-model",
      })[name];
    },
  });
  assert.deepEqual(providers.map((provider) => provider.id), ["gemini", "groq"]);
  assert.equal(
    providers[0].endpoint,
    "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
  );
  assert.equal(
    providers[1].endpoint,
    "https://api.groq.com/openai/v1/chat/completions",
  );
});

test("provider keys alone do not activate AI or incur provider calls", async () => {
  let fetchCalls = 0;
  const environment = {
    get(name) {
      return ({
        GEMINI_API_KEY: "configured-key",
        GEMINI_MODEL: "configured-model",
      })[name];
    },
  };
  assert.deepEqual(getConfiguredProviders(environment), []);

  const result = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic text.",
    ruleFindings: [],
    threatFindings: [],
  }, environment, async () => {
    fetchCalls++;
    throw new Error("Unselected providers must not be called.");
  });
  assert.equal(result.status, "not_configured");
  assert.equal(fetchCalls, 0);
});

test("provider selection requires an explicit model and uses at most two entries", () => {
  const incomplete = getConfiguredProviders({
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini,groq",
        GEMINI_API_KEY: "gemini-key",
        GROQ_API_KEY: "groq-key",
        GROQ_MODEL: "groq-model",
      })[name];
    },
  });
  assert.deepEqual(incomplete.map((provider) => provider.id), ["groq"]);
  assert.deepEqual(
    parseProviderOrder("gemini,groq,openrouter,mistral"),
    ["gemini", "groq"],
  );
});

test("the provider registry reports configuration without exposing credentials", () => {
  const registry = getAiProviderRegistry({
    get(name) {
      return ({
        GEMINI_API_KEY: "private-test-key",
        GEMINI_MODEL: "gemini-test-model",
        HF_TOKEN: "hf-private-test-token",
        HUGGINGFACE_MODEL: "hf-test-model",
        AI_PROVIDER_HUGGINGFACE_ENABLED: "false",
      })[name];
    },
  });
  assert.deepEqual(registry.find((item) => item.id === "gemini"), {
    id: "gemini",
    status: "configured",
    model: "gemini-test-model",
    capabilities: ["text_analysis"],
  });
  assert.deepEqual(registry.find((item) => item.id === "huggingface"), {
    id: "huggingface",
    status: "disabled",
    model: "hf-test-model",
    capabilities: ["text_analysis"],
  });
  assert.equal(JSON.stringify(registry).includes("private-test-key"), false);
  assert.equal(JSON.stringify(registry).includes("hf-private-test-token"), false);
});

test("the server environment template lists supported providers with blank secrets", async () => {
  const template = await readFile(
    resolve(projectRoot, "supabase/.env.example"),
    "utf8",
  );
  for (const name of [
    "GEMINI_API_KEY",
    "GROQ_API_KEY",
    "OPENROUTER_API_KEY",
    "MISTRAL_API_KEY",
    "CLOUDFLARE_API_TOKEN",
    "SAMBANOVA_API_KEY",
    "COHERE_API_KEY",
    "NVIDIA_API_KEY",
    "HF_TOKEN",
    "ZAI_API_KEY",
    "URLHAUS_AUTH_KEY",
    "PULSEDIVE_API_KEY",
    "AI_FALLBACK_ENABLED",
    "AI_PROVIDER_ORDER",
    "AI_GLOBAL_DAILY_REQUEST_LIMIT",
    "AI_USER_DAILY_REQUEST_LIMIT",
    "AI_USER_COOLDOWN_SECONDS",
    "AI_DUPLICATE_WINDOW_SECONDS",
    "AI_MAX_CONCURRENT_PROVIDER_REQUESTS",
    "AI_GEMINI_DAILY_REQUEST_LIMIT",
    "AI_GROQ_DAILY_REQUEST_LIMIT",
    "AI_OPENROUTER_DAILY_REQUEST_LIMIT",
    "AI_MISTRAL_DAILY_REQUEST_LIMIT",
    "AI_CLOUDFLARE_DAILY_REQUEST_LIMIT",
    "AI_SAMBANOVA_DAILY_REQUEST_LIMIT",
    "AI_COHERE_DAILY_REQUEST_LIMIT",
    "AI_NVIDIA_DAILY_REQUEST_LIMIT",
    "AI_ZAI_DAILY_REQUEST_LIMIT",
    "AI_HUGGINGFACE_DAILY_REQUEST_LIMIT",
  ]) {
    assert.match(template, new RegExp(`^${name}=$`, "m"));
  }
  assert.match(template, /^MISTRAL_MODEL=$/m);
  assert.match(template, /^ZAI_MODEL=$/m);
  assert.doesNotMatch(template, /^OLLAMA_/m);
  assert.doesNotMatch(template, /(?:API_KEY|TOKEN|AUTH_KEY)=[^\r\n]+/);
});

test("Hugging Face can be configured and independently disabled", () => {
  const enabled = getConfiguredProviders({
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "huggingface",
        HF_TOKEN: "hf-private-test-token",
        HUGGINGFACE_MODEL: "test-model",
      })[name];
    },
  });
  assert.equal(enabled.at(-1)?.id, "huggingface");
  assert.equal(
    enabled.at(-1)?.endpoint,
    "https://router.huggingface.co/v1/chat/completions",
  );
  const disabled = getConfiguredProviders({
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "huggingface",
        HF_TOKEN: "hf-private-test-token",
        HUGGINGFACE_MODEL: "test-model",
        AI_PROVIDER_HUGGINGFACE_ENABLED: "false",
      })[name];
    },
  });
  assert.equal(disabled.some((provider) => provider.id === "huggingface"), false);
});

test("AI-provider output is validated and never changes the scan classification", async () => {
  const ai = await analyzeWithProviders({
    contentType: "url",
    content: "https://example.com/",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async () => new Response(JSON.stringify({
    choices: [{
      message: {
        content: JSON.stringify({
          signals: [],
          summary: "The content appears safe.",
          recommended_actions: [],
        }),
      },
    }],
  }), { status: 200 }));
  const result = await analyzeUrl("https://example.com/", { ai });
  assert.equal(result.classification, "SAFE");
  assert.equal(result.ai_analysis.provider, "gemini");
  assert.equal(result.ai_analysis.recommended_actions.length, 0);
});

test("AI-provider output filters unknown signals without discarding its summary", async () => {
  const ai = await analyzeWithProviders({
    contentType: "message",
    content: "Please review this message.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async () => new Response(JSON.stringify({
    choices: [{
      message: {
        content: JSON.stringify({
          signals: ["Invented finding"],
          summary: "Potential issue.",
          recommended_actions: [],
        }),
      },
    }],
  }), { status: 200 }));
  assert.equal(ai.status, "available");
  assert.deepEqual(ai.providers_tried, ["gemini"]);
  assert.deepEqual(ai.analysis.signals, []);
  assert.equal(ai.analysis.summary, "Potential issue.");
});

test("AI-provider accepts structured content and normalizes optional fields", async () => {
  const ai = await analyzeWithProviders({
    contentType: "message",
    content: "Please review this message.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async () => Response.json({
    choices: [{
      message: {
        content: null,
        parsed: {
          result: {
            explanation: " A concise assessment. ",
            signals: [
              "Urgent or coercive language",
              "Not an approved signal",
            ],
            actions: [" Verify through the official channel. ", 42],
          },
        },
      },
    }],
  }));
  assert.equal(ai.status, "available");
  assert.equal(ai.analysis.summary, "A concise assessment.");
  assert.deepEqual(ai.analysis.signals, ["Urgent or coercive language"]);
  assert.deepEqual(ai.analysis.recommended_actions, [
    "Verify through the official channel.",
  ]);
});

test("AI-provider preserves informative summaries longer than 500 characters", async () => {
  const summary =
    "The message offers an unexpected prize and links to a domain that has not been verified. " +
    "Those cues can pressure a recipient to click or share information, but they do not prove who sent the message. " +
    "x".repeat(600);
  const ai = await analyzeWithProviders({
    contentType: "message",
    content: "Synthetic message with prize and URL.",
    ruleFindings: [
      "Unexpected prize, reward, or refund",
      "Suspicious or unusual URL characteristics",
    ],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async () => Response.json({
    choices: [{
      message: {
        content: JSON.stringify({
          signals: ["Unexpected prize, reward, or refund"],
          summary,
          recommended_actions: [
            "Verify the offer using the organization's official website.",
          ],
        }),
      },
    }],
  }));
  assert.equal(ai.status, "available");
  assert.equal(ai.analysis.summary, summary);
});

test("AI-provider still rejects an invalid response without a summary", async () => {
  const ai = await analyzeWithProviders({
    contentType: "message",
    content: "Please review this message.",
    ruleFindings: [],
    threatFindings: [],
  }, {
    get(name) {
      return ({
        AI_PROVIDER_ORDER: "gemini",
        GEMINI_API_KEY: "gemini-key",
        GEMINI_MODEL: "test-model",
      })[name];
    },
  }, async () => Response.json({
    choices: [{
      message: {
        content: JSON.stringify({
          signals: ["Urgent or coercive language"],
          recommended_actions: [],
        }),
      },
    }],
  }));
  assert.equal(ai.status, "failed");
  assert.deepEqual(withoutAttemptDurations([ai.provider_attempts[0]])[0], {
    provider: "gemini",
    status: "invalid_response",
    http_status: 200,
  });
});

test("no configured provider keys means AI is not configured and makes no requests", async () => {
  let fetchCalls = 0;
  const ai = await analyzeWithProviders({
    contentType: "message",
    content: "Please review this message.",
    ruleFindings: [],
    threatFindings: [],
  }, { get: () => undefined }, async () => {
    fetchCalls++;
    throw new Error("Unconfigured providers must not be called.");
  });
  assert.deepEqual(ai, {
    status: "not_configured",
    provider: null,
    providers_tried: [],
    provider_attempts: [],
  });
  assert.equal(fetchCalls, 0);
});

test("provider integrations keep credentials in server-side adapters", async () => {
  const functionsRoot = resolve(projectRoot, "supabase/functions");
  const files = [];
  async function collect(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) await collect(path);
      else if (entry.name.endsWith(".ts")) files.push(path);
    }
  }
  await collect(functionsRoot);
  const source = (await Promise.all(files.map((file) => readFile(file, "utf8"))))
    .join("\n");
  assert.doesNotMatch(source, /ollama/i);
  const config = await readFile(
    resolve(projectRoot, "supabase/config.toml"),
    "utf8",
  );
  const orchestration = await readFile(
    resolve(projectRoot, "supabase/functions/scam-intelligence/index.ts"),
    "utf8",
  );
  const networkAnalysis = await readFile(
    resolve(projectRoot, "supabase/functions/_shared/network-analysis.ts"),
    "utf8",
  );
  assert.doesNotMatch(source, /Deno\.env\.get\(["'][A-Z0-9_]*(?:API_KEY|AUTH_KEY)["']\)/);
  assert.doesNotMatch(orchestration, /\bfetch\s*\(/);
  assert.doesNotMatch(networkAnalysis, /\bfetch\s*\(/);
  assert.deepEqual(
    [...config.matchAll(/^\[functions\.([^\]]+)\]/gm)].map((match) => match[1]).sort(),
    ["family-invitations", "scam-intelligence"],
  );
});

test("an independent-analysis migration stores only indicator hashes", async () => {
  const migration = await readFile(
    resolve(projectRoot, "supabase/migrations/202611130003_independent_analysis.sql"),
    "utf8",
  );
  assert.match(migration, /create table if not exists public\.community_threat_reports/);
  assert.match(migration, /indicator_hash text not null/);
  assert.match(migration, /review_status in \('pending', 'confirmed', 'rejected'\)/);
  assert.match(migration, /create table if not exists public\.analysis_module_results/);
  assert.match(migration, /enable row level security/);
  assert.match(migration, /drop table if exists public\.threat_lookup_cache/);
});

test("the URL reputation migration permits persisted external provider evidence", async () => {
  const migration = await readFile(
    resolve(projectRoot, "supabase/migrations/202611130004_url_reputation.sql"),
    "utf8",
  );
  assert.match(migration, /external_threat_intelligence/);
  assert.match(migration, /analysis_module_results_module_check/);
});

test("AI provider guardrails reserve bounded budgets and keep controls service-only", async () => {
  const migration = await readFile(
    resolve(projectRoot, "supabase/migrations/202611170002_ai_provider_guardrails.sql"),
    "utf8",
  );
  assert.match(migration, /pg_advisory_xact_lock/);
  assert.match(migration, /target_global_limit is null/i);
  assert.match(migration, /target_user_limit is null/i);
  assert.match(migration, /target_provider_limit is null/i);
  assert.match(migration, /circuit_open_until[\s\S]*interval '15 minutes'/i);
  assert.match(migration, /probe_lease_until[\s\S]*interval '90 seconds'/i);
  assert.match(migration, /enable row level security/i);
  assert.match(migration, /revoke all on function public\.reserve_ai_provider_attempt/i);
  assert.match(migration, /revoke all on function public\.record_ai_provider_attempt/i);
  assert.match(migration, /grant execute on function public\.reserve_ai_provider_attempt[\s\S]*to service_role;/i);
  assert.match(migration, /grant execute on function public\.record_ai_provider_attempt[\s\S]*to service_role;/i);
  assert.match(migration, /grant select on public\.ai_provider_health to service_role;/i);
  assert.match(migration, /security_invoker = true/i);
});

test("AI request controls deduplicate, cool down users, and cap concurrency", async () => {
  const migration = await readFile(
    resolve(projectRoot, "supabase/migrations/202611170003_ai_request_dedup_cooldowns.sql"),
    "utf8",
  );
  const forwardMigration = await readFile(
    resolve(projectRoot, "supabase/migrations/202611170004_ai_request_dedup_quota_reservation.sql"),
    "utf8",
  );
  const edgeFunction = await readFile(
    resolve(projectRoot, "supabase/functions/scam-intelligence/index.ts"),
    "utf8",
  );
  assert.match(edgeFunction, /admin\.rpc\(\s*"reserve_ai_provider_attempt_v2"/);
  assert.match(edgeFunction, /admin\.rpc\(\s*"record_ai_provider_attempt_v2"/);
  assert.match(edgeFunction, /target_reservation_id:\s*reservationId/);
  assert.match(edgeFunction, /createAiProviderAttemptController\(admin, user\.id, requestFingerprint\)/);
  assert.doesNotMatch(edgeFunction, /admin\.rpc\(\s*"reserve_ai_provider_attempt"/);
  assert.doesNotMatch(edgeFunction, /admin\.rpc\(\s*"record_ai_provider_attempt"/);
  assert.match(migration, /create table if not exists public\.ai_request_deduplication/);
  assert.match(migration, /request_fingerprint text not null/);
  assert.match(migration, /target_user_cooldown_seconds/);
  assert.match(migration, /previous_request_at >[\s\S]*target_user_cooldown_seconds/);
  assert.match(migration, /target_max_concurrent_requests/);
  assert.match(migration, /concurrency_limited/);
  assert.match(migration, /target_initial_attempt/);
  assert.match(migration, /delete from public\.ai_provider_attempt_leases[\s\S]*where expires_at <= request_time/);
  assert.match(migration, /reservation_id uuid primary key/);
  assert.match(migration, /user_id uuid not null references auth\.users\(id\) on delete cascade,[\s\S]*provider text not null/);
  assert.match(migration, /insert into public\.ai_request_deduplication as existing/);
  assert.match(migration, /reserve_result := public\.reserve_ai_provider_attempt/);
  assert.match(forwardMigration, /previous_fingerprint_at >[\s\S]*target_duplicate_window_seconds/);
  assert.match(forwardMigration, /select requested_at[\s\S]*for update/);
  assert.match(forwardMigration, /reserve_result := public\.reserve_ai_provider_attempt/);
  const dedupCheckIndex = forwardMigration.indexOf("select requested_at");
  const quotaReservationIndex = forwardMigration.indexOf(
    "reserve_result := public.reserve_ai_provider_attempt",
  );
  const dedupInsertIndex = forwardMigration.indexOf(
    "insert into public.ai_request_deduplication (",
  );
  assert.ok(dedupCheckIndex < quotaReservationIndex);
  assert.ok(quotaReservationIndex < dedupInsertIndex);
  assert.match(migration, /create table if not exists public\.ai_provider_attempt_leases/);
  assert.match(migration, /expires_at > pg_catalog\.clock_timestamp\(\)[\s\S]*for update/);
  assert.match(migration, /if lease_provider <> target_provider then/);
  assert.match(migration, /delete from public\.ai_provider_attempt_leases[\s\S]*where reservation_id = target_reservation_id/);
  assert.match(migration, /revoke all on function public\.reserve_ai_provider_attempt_v2/i);
  assert.match(migration, /revoke all on function public\.record_ai_provider_attempt_v2/i);
  assert.match(migration, /grant execute on function public\.reserve_ai_provider_attempt_v2[\s\S]*to service_role;/i);
  assert.match(migration, /grant execute on function public\.record_ai_provider_attempt_v2[\s\S]*to service_role;/i);
  assert.match(forwardMigration, /revoke all on function public\.reserve_ai_provider_attempt_v2/i);
  assert.match(forwardMigration, /grant execute on function public\.reserve_ai_provider_attempt_v2[\s\S]*to service_role;/i);
});

test("AI provider circuit breaker has half-open success and failure recovery paths", async () => {
  const migration = await readFile(
    resolve(projectRoot, "supabase/migrations/202611170002_ai_provider_guardrails.sql"),
    "utf8",
  );
  assert.match(
    migration,
    /when circuit_open_until is not null\s+and circuit_open_until <= request_time\s+then request_time \+ interval '90 seconds'/i,
  );
  assert.match(
    migration,
    /when current_circuit_until > recorded_at\s+then current_failures[\s\S]*else 0/i,
  );
  assert.match(
    migration,
    /when was_half_open_probe\s+then 3[\s\S]*recorded_at \+ interval '15 minutes'/i,
  );
  assert.match(migration, /revoke all on function public\.reserve_ai_provider_attempt[\s\S]*from public, anon, authenticated/i);
  assert.match(migration, /revoke all on function public\.record_ai_provider_attempt[\s\S]*from public, anon, authenticated/i);
});
test("risk validation accepts provider budget and circuit statuses", () => {
  const statuses = [
    "budget_unconfigured",
    "budget_check_failed",
    "global_budget_exhausted",
    "user_budget_exhausted",
    "provider_budget_exhausted",
    "user_cooldown",
    "duplicate_request",
    "concurrency_limited",
    "circuit_open",
  ];
  const assessment = assessUnifiedRisk(
    cleanRuleResult,
    [],
    {
      status: "unavailable",
      provider: null,
      providers_tried: [],
      provider_attempts: statuses.map((status) => ({
        provider: "gemini",
        status,
        duration_ms: 0,
      })),
    },
    fixedTime,
  );
  assert.equal(validateUnifiedAssessment(assessment), true);
});

test("trusted intelligence requires moderator review and admin-only release", async () => {
  const migration = await readFile(
    resolve(projectRoot, "supabase/migrations/202611150003_trusted_scam_intelligence.sql"),
    "utf8",
  );
  assert.match(migration, /'anomaly_detection', 'adaptive_pattern_analysis'/);
  assert.match(migration, /reviewer_count < 2/);
  assert.match(migration, /auth\.jwt\(\) -> 'app_metadata' ->> 'role'/);
  assert.match(migration, /evaluation_status <> 'passed'/);
  assert.match(migration, /release_status = 'active'/);
  assert.match(migration, /target_admin_override/);
  assert.match(
    migration,
    /grant select \(\s*id, scan_record_id, content_type, submitted_label, status, status_note,/,
  );
  assert.doesNotMatch(
    migration.match(/grant select \([\s\S]*?\) on public\.example_submissions/)[0],
    /redacted_content|content_hash|reporter_id/,
  );
});

test("trusted dataset snapshots are ordered and activation is serialized", async () => {
  const migration = await readFile(
    resolve(projectRoot, "supabase/migrations/202611150004_trusted_dataset_ordering.sql"),
    "utf8",
  );
  const edgeFunction = await readFile(
    resolve(projectRoot, "supabase/functions/scam-intelligence/index.ts"),
    "utf8",
  );

  assert.match(migration, /version_sequence bigint[\s\S]*generated by default as identity/);
  assert.match(migration, /dataset_versions_single_active[\s\S]*where release_status = 'active'/);
  assert.match(migration, /pg_advisory_xact_lock\(834761002\)/);
  assert.match(
    edgeFunction,
    /\.lte\("version_sequence", version\.version_sequence\)/,
  );
  assert.match(
    edgeFunction,
    /\.lte\("version_sequence", activeVersion\.version_sequence\)/,
  );
});
