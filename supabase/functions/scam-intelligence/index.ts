import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";
import {
  buildStaticModules,
  extractIndicators,
  hashIndicator,
  normalizeReportIndicators,
  type AnalysisModuleResult,
  type NormalizedIndicator,
  type ThreatMatch,
} from "../_shared/analysis-modules.ts";
import {
  analyzeWithProviders,
  chatWithProviders,
  type AiAnalysisResult,
  type SafetyAssistantMessage,
} from "../_shared/ai-provider-analysis.ts";
import { analyzeDomainAndTls } from "../_shared/network-analysis.ts";
import {
  analyzeUrlReputation,
  isPublicReputationTarget,
  type UrlReputationResult,
} from "../_shared/url-reputation.ts";
import {
  assessUnifiedRisk,
  validateUnifiedAssessment,
} from "../_shared/risk-assessment.ts";
import { requiresMfaChallenge } from "../_shared/mfa-auth.ts";
import { readLimitedBody } from "../_shared/request-body.ts";
import {
  assignDatasetSplit,
  evaluateTrustedDataset,
  type EvaluationExample,
} from "../_shared/dataset-evaluation.ts";
import {
  hashTrustedContent,
  parseTrustedExampleFeatures,
  redactTrustedContent,
  screenTrustedContent,
  type SubmittedContentType,
  type SubmittedLabel,
} from "../_shared/trusted-intelligence.ts";
import type { Database, Json } from "../_shared/database.types.ts";
import { classifyScamContent } from "./scam-patterns.ts";

type AdminClient = SupabaseClient<Database>;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Cache-Control": "no-store",
      "Content-Type": "application/json",
    },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function toJson(value: unknown): Json {
  if (
    value === null || typeof value === "string" || typeof value === "boolean"
  ) return value;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (Array.isArray(value)) return value.map(toJson);
  if (isRecord(value)) {
    const result: { [key: string]: Json | undefined } = {};
    for (const [key, item] of Object.entries(value)) {
      if (item !== undefined) result[key] = toJson(item);
    }
    return result;
  }
  return null;
}

function parseAssistantMessages(value: unknown): SafetyAssistantMessage[] | null {
  if (!Array.isArray(value) || value.length === 0 || value.length > 7) {
    return null;
  }
  const messages: SafetyAssistantMessage[] = [];
  let totalLength = 0;
  for (let index = 0; index < value.length; index++) {
    const item = value[index];
    const expectedRole = index % 2 === 0 ? "user" : "assistant";
    if (
      !isRecord(item) ||
      item.role !== expectedRole ||
      typeof item.content !== "string"
    ) return null;
    const content = item.content.trim();
    if (!content || content.length > 5000) return null;
    totalLength += content.length;
    if (totalLength > 12000) return null;
    messages.push({
      role: expectedRole,
      content,
    });
  }
  if (messages[messages.length - 1].role !== "user") return null;
  return messages;
}

function parseUrl(input: string): URL | null {
  try {
    const url = new URL(input.includes("://") ? input : `https://${input}`);
    if (
      (url.protocol !== "http:" && url.protocol !== "https:") ||
      !url.hostname ||
      url.username ||
      url.password
    ) return null;
    return url;
  } catch {
    return null;
  }
}

async function loadReviewedMatches(
  admin: AdminClient,
  table: "local_threat_indicators" | "community_threat_reports",
  indicators: NormalizedIndicator[],
): Promise<{ matches: Record<string, unknown>[]; error: unknown }> {
  if (indicators.length === 0) return { matches: [], error: null };
  const hashes = [...new Set(await Promise.all(indicators.map(hashIndicator)))];
  if (table === "local_threat_indicators") {
    const { data, error } = await admin.from(table).select(
      "indicator_type, indicator_hash, category, source_note",
    ).eq("active", true).not("reviewed_by", "is", null)
      .in("indicator_hash", hashes);
    return {
      matches: (data ?? []).map((row) => ({
        indicator_type: row.indicator_type,
        indicator_hash: row.indicator_hash,
        category: row.category,
        source_note: row.source_note,
      })),
      error,
    };
  }
  const { data, error } = await admin.from(table).select(
    "indicator_type, indicator_hash, category, reporter_id",
  ).eq("review_status", "confirmed")
    .not("reviewed_by", "is", null).in("indicator_hash", hashes);
  return {
    matches: (data ?? []).map((row) => ({
      indicator_type: row.indicator_type,
      indicator_hash: row.indicator_hash,
      category: row.category,
      reporter_id: row.reporter_id,
    })),
    error,
  };
}

async function submitCommunityReport(
  admin: AdminClient,
  userId: string,
  indicatorInput: string,
  category: string,
): Promise<number> {
  const indicators = normalizeReportIndicators(indicatorInput);
  if (!indicators || !["Phishing", "Impersonation", "Payment scam", "Fake offer", "Other"].includes(category)) {
    throw new TypeError("Enter a valid URL or domain and report category.");
  }
  const rows = await Promise.all(indicators.map(async (indicator) => ({
    reporter_id: userId,
    indicator_type: indicator.type,
    indicator_hash: await hashIndicator(indicator),
    category,
  })));
  const { error } = await admin.from("community_threat_reports").upsert(rows, {
    onConflict: "reporter_id,indicator_type,indicator_hash",
    ignoreDuplicates: true,
  });
  if (error) {
    console.error("Scam intelligence: community indicator report could not be saved.");
    throw new Error("The indicator report could not be saved.");
  }
  return rows.length;
}

function isModuleResults(value: unknown): value is AnalysisModuleResult[] {
  const modules = new Set([
    "url_structure",
    "domain_dns",
    "ssl_tls",
    "redirect_analysis",
    "suspicious_patterns",
    "local_indicator_database",
    "community_reports",
    "external_threat_intelligence",
    "scam_pattern_recognition",
    "anomaly_detection",
    "adaptive_pattern_analysis",
  ]);
  const statuses = new Set([
    "completed",
    "unavailable",
    "failed",
    "not_applicable",
  ]);
  const evidenceKinds = new Set([
    "confirmed_detection",
    "suspicious_signal",
    "no_match",
    "not_checked",
    "analysis_unavailable",
    "analysis_failed",
  ]);
  return Array.isArray(value) && value.length <= 50 &&
    value.every((item) =>
      isRecord(item) &&
      modules.has(String(item.module)) &&
      statuses.has(String(item.status)) &&
      evidenceKinds.has(String(item.evidence_kind)) &&
      typeof item.confidence === "number" &&
      item.confidence >= 0 && item.confidence <= 1 &&
      Array.isArray(item.evidence) &&
      item.evidence.length <= 8 &&
      item.evidence.every((line) => typeof line === "string") &&
      typeof item.source === "string" &&
      typeof item.checked_at === "string" &&
      !Number.isNaN(Date.parse(item.checked_at))
    );
}

function parseThreatMatches(
  rows: Record<string, unknown>[],
  community: boolean,
): ThreatMatch[] {
  return rows.flatMap((row) => {
    if (
      (row.indicator_type !== "url" && row.indicator_type !== "domain" &&
        row.indicator_type !== "ip") ||
      typeof row.indicator_hash !== "string" ||
      !/^[0-9a-f]{64}$/.test(row.indicator_hash) ||
      typeof row.category !== "string"
    ) return [];
    if (community && typeof row.reporter_id !== "string") return [];
    return [{
      indicator_type: row.indicator_type,
      indicator_hash: row.indicator_hash,
      category: row.category,
      ...(typeof row.source_note === "string"
        ? { source_note: row.source_note }
        : {}),
      ...(typeof row.reporter_id === "string"
        ? { reporter_id: row.reporter_id }
        : {}),
    }];
  });
}

async function recordThreatScan(
  admin: AdminClient,
  userId: string,
  type: "message" | "url" | "screenshot",
  result: ReturnType<typeof classifyScamContent>,
  unified: ReturnType<typeof assessUnifiedRisk>,
): Promise<string> {
  const targetRiskLevel = unified.risk_level === "HIGH" ||
      unified.risk_level === "CRITICAL"
    ? "high"
    : unified.risk_level === "MEDIUM" || unified.risk_level === "UNDETERMINED"
    ? "review"
    : "low";
  const { data, error } = await admin.rpc("record_threat_scan", {
    target_user_id: userId,
    target_scan_type: type,
    target_risk_level: targetRiskLevel,
    target_indicators: result.indicators,
    target_assessment: toJson({
      unified_result: unified,
      legacy_explanation: result.summary,
    }),
    target_analysis_modules: toJson(unified.analysis_modules),
  });
  if (error || typeof data !== "string") {
    console.error("Scam intelligence: analysis metadata could not be saved.", error);
    throw new Error("Analysis results could not be saved.");
  }
  return data;
}

function hasTrustedReviewRole(user: {
  app_metadata?: Record<string, unknown>;
}): boolean {
  return user.app_metadata?.role === "moderator" ||
    user.app_metadata?.role === "admin";
}

function hasTrustedAdminRole(user: {
  app_metadata?: Record<string, unknown>;
}): boolean {
  return user.app_metadata?.role === "admin";
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function isVerificationMethod(
  value: unknown,
): value is
  | "official_source"
  | "direct_contact"
  | "law_enforcement"
  | "independent_fact_check"
  | "other" {
  return value === "official_source" || value === "direct_contact" ||
    value === "law_enforcement" || value === "independent_fact_check" ||
    value === "other";
}

async function recordIntelligenceAudit(
  admin: AdminClient,
  input: {
    actorId: string;
    action: string;
    submissionId?: string;
    datasetVersionId?: string;
    metadata?: Record<string, unknown>;
  },
): Promise<void> {
  const { error } = await admin.from("intelligence_audit_logs").insert({
    actor_id: input.actorId,
    action: input.action,
    submission_id: input.submissionId ?? null,
    dataset_version_id: input.datasetVersionId ?? null,
    metadata: toJson(input.metadata ?? {}) ?? {},
  });
  if (error) {
    console.error("Scam intelligence: trusted-review audit could not be saved.");
    throw new Error("The intelligence audit event could not be saved.");
  }
}

async function submitTrustedExample(
  admin: AdminClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const type = body.content_type;
  const content = body.content;
  const label = body.submitted_label;
  if (
    (type !== "message" && type !== "url" && type !== "screenshot") ||
    typeof content !== "string" ||
    content.trim().length === 0 ||
    content.length > 5000 ||
    (label !== "scam" && label !== "legitimate" && label !== "unsure") ||
    (body.scan_record_id !== undefined &&
      body.scan_record_id !== null &&
      !isUuid(body.scan_record_id))
  ) {
    return jsonResponse(400, {
      error: "Provide a supported content type, example, label, and scan ID.",
    });
  }
  if (type === "url" && !parseUrl(content.trim())) {
    return jsonResponse(400, {
      error: "URL examples must be valid HTTP or HTTPS addresses.",
    });
  }

  const { data: allowed, error: quotaError } = await admin.rpc(
    "consume_scam_intelligence_quota",
    { target_user_id: userId },
  );
  if (quotaError) {
    console.error("Scam intelligence: example submission limit check failed.");
    return jsonResponse(500, {
      error: "Could not verify the example submission limit.",
    });
  }
  if (allowed !== true) {
    return jsonResponse(429, {
      error: "This account has reached its daily Cyvora submission limit.",
    });
  }

  const scanRecordId = isUuid(body.scan_record_id)
    ? body.scan_record_id
    : null;
  if (scanRecordId) {
    const { data: scan, error } = await admin.from("scan_records")
      .select("id")
      .eq("id", scanRecordId)
      .eq("user_id", userId)
      .maybeSingle();
    if (error) {
      console.error("Scam intelligence: scan ownership could not be verified.");
      return jsonResponse(500, {
        error: "Could not verify the related scan.",
      });
    }
    if (!scan) {
      return jsonResponse(403, {
        error: "The related scan does not belong to this account.",
      });
    }
  }

  const redactedContent = redactTrustedContent(content);
  if (redactedContent.length < 4) {
    return jsonResponse(400, {
      error: "The example is too short after sensitive details are removed.",
    });
  }
  const contentHash = await hashTrustedContent(redactedContent);
  const { data: existing, error: duplicateError } = await admin
    .from("example_submissions")
    .select("id, status")
    .eq("reporter_id", userId)
    .eq("content_hash", contentHash)
    .in("status", [
      "pending",
      "under_review",
      "verified_scam",
      "verified_legitimate",
    ])
    .limit(1)
    .maybeSingle();
  if (duplicateError) {
    console.error("Scam intelligence: duplicate submission check failed.");
    return jsonResponse(500, {
      error: "Could not check for a duplicate example.",
    });
  }
  if (existing) {
    await recordIntelligenceAudit(admin, {
      actorId: userId,
      action: "duplicate_example_submission",
      submissionId: existing.id,
      metadata: { content_type: type },
    });
    return jsonResponse(200, {
      status: "duplicate",
      submission_id: existing.id,
      review_status: existing.status,
      message: `This example was already submitted and is ${String(existing.status).replaceAll("_", " ")}.`,
    });
  }

  const screening = screenTrustedContent(
    type as SubmittedContentType,
    redactedContent,
  );
  const { data: submission, error: insertError } = await admin
    .from("example_submissions")
    .insert({
      reporter_id: userId,
      scan_record_id: scanRecordId,
      content_type: type,
      redacted_content: redactedContent,
      content_hash: contentHash,
      submitted_label: label as SubmittedLabel,
      screening_result: screening,
      status: "pending",
    })
    .select("id, status")
    .single();
  if (insertError || !submission) {
    if (insertError?.code === "23505") {
      const { data: duplicate, error: lookupError } = await admin
        .from("example_submissions")
        .select("id, status")
        .eq("reporter_id", userId)
        .eq("content_hash", contentHash)
        .in("status", [
          "pending",
          "under_review",
          "verified_scam",
          "verified_legitimate",
        ])
        .limit(1)
        .maybeSingle();
      if (!lookupError && duplicate) {
        await recordIntelligenceAudit(admin, {
          actorId: userId,
          action: "duplicate_example_submission",
          submissionId: duplicate.id,
          metadata: { content_type: type },
        });
        return jsonResponse(200, {
          status: "duplicate",
          submission_id: duplicate.id,
          review_status: duplicate.status,
          message: `This example was already submitted and is ${String(duplicate.status).replaceAll("_", " ")}.`,
        });
      }
      if (lookupError) {
        console.error("Scam intelligence: concurrent duplicate could not be loaded.");
      }
    }
    console.error("Scam intelligence: trusted example could not be saved.");
    return jsonResponse(500, {
      error: "The example could not be submitted for review.",
    });
  }
  await recordIntelligenceAudit(admin, {
    actorId: userId,
    action: "example_submitted",
    submissionId: submission.id,
    metadata: {
      content_type: type,
      submitted_label: label,
      screening_categories: screening.categories,
    },
  });
  return jsonResponse(200, {
    status: "pending",
    submission_id: submission.id,
    review_status: submission.status,
    message: "Submitted for moderator review; it does not change scan results.",
  });
}

async function loadMyTrustedExamples(
  admin: AdminClient,
  userId: string,
): Promise<Response> {
  const { data, error } = await admin.from("example_submissions")
    .select(
      "id, content_type, submitted_label, status, status_note, created_at, updated_at",
    )
    .eq("reporter_id", userId)
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) {
    console.error("Scam intelligence: user example statuses could not be loaded.");
    return jsonResponse(500, {
      error: "Your example review statuses could not be loaded.",
    });
  }
  return jsonResponse(200, { submissions: data ?? [] });
}

async function loadTrustedReviewQueue(
  admin: AdminClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const requestedLimit = body.limit ?? 30;
  if (
    typeof requestedLimit !== "number" ||
    !Number.isInteger(requestedLimit) ||
    requestedLimit < 1 ||
    requestedLimit > 50
  ) {
    return jsonResponse(400, { error: "Queue limit must be from 1 to 50." });
  }
  const { data: rows, error } = await admin.from("example_submissions")
    .select(
      "id, reporter_id, scan_record_id, content_type, redacted_content, content_hash, submitted_label, status, status_note, screening_result, created_at",
    )
    .in("status", ["pending", "under_review", "disputed"])
    .order("created_at", { ascending: true })
    .limit(requestedLimit);
  if (error) {
    console.error("Scam intelligence: moderator review queue could not be loaded.");
    return jsonResponse(500, { error: "The review queue could not be loaded." });
  }
  const submissionIds = (rows ?? []).map((row) => row.id);
  const { data: reviews, error: reviewsError } = submissionIds.length > 0
    ? await admin.from("example_verifications")
      .select(
        "submission_id, reviewer_id, decision, verification_method, evidence_reference, notes, created_at",
      )
      .in("submission_id", submissionIds)
    : { data: [], error: null };
  if (reviewsError) {
    console.error("Scam intelligence: moderator review history could not be loaded.");
    return jsonResponse(500, {
      error: "Review history could not be loaded.",
    });
  }
  const groupedReviews = new Map<string, Record<string, unknown>[]>();
  for (const review of reviews ?? []) {
    const group = groupedReviews.get(review.submission_id) ?? [];
    group.push(review);
    groupedReviews.set(review.submission_id, group);
  }
  return jsonResponse(200, {
    submissions: (rows ?? []).map((row) => ({
      ...row,
      reviews: groupedReviews.get(row.id) ?? [],
      reviewed_by_current_user: (groupedReviews.get(row.id) ?? []).some(
        (review) => review.reviewer_id === userId,
      ),
    })),
  });
}

async function reviewTrustedExample(
  admin: AdminClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const submissionId = body.submission_id;
  const requestedDecision = body.decision;
  const method = body.verification_method;
  const evidenceReference = typeof body.evidence_reference === "string"
    ? redactTrustedContent(body.evidence_reference)
    : "";
  const notes = typeof body.notes === "string"
    ? redactTrustedContent(body.notes).slice(0, 1000)
    : null;
  if (
    !isUuid(submissionId) ||
    !["verified_scam", "verified_legitimate", "rejected", "disputed"]
      .includes(String(requestedDecision)) ||
    !isVerificationMethod(method) ||
    evidenceReference.length < 12 ||
    evidenceReference.length > 2000 ||
    (typeof body.notes === "string" && body.notes.length > 2000)
  ) {
    return jsonResponse(400, {
      error: "Provide a valid decision, verification method, and evidence.",
    });
  }
  const { data: submission, error: submissionError } = await admin
    .from("example_submissions")
    .select(
      "id, reporter_id, content_type, redacted_content, content_hash, status",
    )
    .eq("id", submissionId)
    .maybeSingle();
  if (submissionError) {
    console.error("Scam intelligence: submitted example could not be loaded.");
    return jsonResponse(500, { error: "The example could not be loaded." });
  }
  if (!submission) return jsonResponse(404, { error: "Example not found." });
  if (submission.reporter_id === userId) {
    return jsonResponse(403, {
      error: "Moderators cannot review their own submissions.",
    });
  }
  if (!["pending", "under_review", "disputed"].includes(submission.status)) {
    return jsonResponse(409, {
      error: "This example has already reached a final review status.",
    });
  }

  const { data: existingReviews, error: existingReviewsError } = await admin
    .from("example_verifications")
    .select("reviewer_id, decision")
    .eq("submission_id", submissionId);
  if (existingReviewsError) {
    console.error("Scam intelligence: prior verification could not be loaded.");
    return jsonResponse(500, {
      error: "Prior reviews could not be checked.",
    });
  }
  if ((existingReviews ?? []).some((review) => review.reviewer_id === userId)) {
    return jsonResponse(409, {
      error: "A moderator can review each example only once.",
    });
  }

  let finalDecision = String(requestedDecision);
  let resultingStatus = finalDecision;
  let conflictDetected = false;
  if (
    finalDecision === "verified_scam" ||
    finalDecision === "verified_legitimate"
  ) {
    const opposite = finalDecision === "verified_scam"
      ? "verified_legitimate"
      : "verified_scam";
    const priorConflict = (existingReviews ?? []).some((review) =>
      review.decision === opposite
    );
    const { data: sameHashSubmissions, error: sameHashError } = await admin
      .from("example_submissions")
      .select("id, status")
      .eq("content_hash", submission.content_hash)
      .neq("id", submissionId);
    if (sameHashError) {
      console.error("Scam intelligence: duplicate verification check failed.");
      return jsonResponse(500, {
        error: "Conflicting examples could not be checked.",
      });
    }
    conflictDetected = priorConflict ||
      (sameHashSubmissions ?? []).some((row) => row.status === opposite);
    if (conflictDetected) {
      finalDecision = "disputed";
      resultingStatus = "disputed";
    }
  }

  const { error: verificationError } = await admin
    .from("example_verifications")
    .insert({
      submission_id: submissionId,
      reviewer_id: userId,
      decision: finalDecision,
      verification_method: method,
      evidence_reference: evidenceReference,
      notes,
    });
  if (verificationError) {
    console.error("Scam intelligence: moderator decision could not be saved.");
    return jsonResponse(500, {
      error: "The moderator decision could not be saved.",
    });
  }

  if (conflictDetected || finalDecision === "disputed" ||
      finalDecision === "rejected") {
    const statusNote = conflictDetected
      ? "Conflicting verified labels require administrator review."
      : notes?.slice(0, 300) ?? null;
    const { error: updateError } = await admin
      .from("example_submissions")
      .update({
        status: resultingStatus,
        status_note: statusNote,
        updated_at: new Date().toISOString(),
      })
      .eq("id", submissionId);
    if (updateError) {
      console.error("Scam intelligence: review status could not be updated.");
      return jsonResponse(500, {
        error: "The decision was saved but the review status could not be updated.",
      });
    }
    await recordIntelligenceAudit(admin, {
      actorId: userId,
      action: conflictDetected ? "example_label_conflict" : "example_reviewed",
      submissionId,
      metadata: {
        decision: finalDecision,
        requested_decision: requestedDecision,
        verification_method: method,
      },
    });
    return jsonResponse(200, {
      status: resultingStatus,
      trusted_for_learning: false,
      message: conflictDetected
        ? "Conflicting decisions were recorded; this example is excluded from trusted data."
        : "The review was recorded; this example is excluded from trusted data.",
    });
  }

  const matchingReviews = (existingReviews ?? []).filter((review) =>
    review.decision === finalDecision
  ).length + 1;
  if (matchingReviews < 2) {
    const { error: updateError } = await admin
      .from("example_submissions")
      .update({
        status: "under_review",
        status_note: "A second independent moderator review is required.",
        updated_at: new Date().toISOString(),
      })
      .eq("id", submissionId);
    if (updateError) {
      console.error("Scam intelligence: pending review status could not be updated.");
      return jsonResponse(500, {
        error: "The decision was saved but the review status could not be updated.",
      });
    }
    await recordIntelligenceAudit(admin, {
      actorId: userId,
      action: "example_reviewed",
      submissionId,
      metadata: {
        decision: finalDecision,
        verification_method: method,
        independent_reviews: matchingReviews,
      },
    });
    return jsonResponse(200, {
      status: "under_review",
      trusted_for_learning: false,
      independent_reviews: matchingReviews,
      required_reviews: 2,
    });
  }

  const screening = screenTrustedContent(
    submission.content_type as SubmittedContentType,
    submission.redacted_content,
  );
  const features = {
    categories: screening.categories.slice(0, 20),
    split: assignDatasetSplit(submission.content_hash),
  };
  const { data: datasetVersionId, error: stageError } = await admin.rpc(
    "stage_trusted_example",
    {
      target_submission_id: submissionId,
      target_actor_id: userId,
      target_label: finalDecision,
      target_features: features,
      target_admin_override: false,
    },
  );
  if (stageError || typeof datasetVersionId !== "string") {
    console.error("Scam intelligence: verified example could not be staged.");
    return jsonResponse(500, {
      error: "The example was reviewed but could not be staged for evaluation.",
    });
  }
  await recordIntelligenceAudit(admin, {
    actorId: userId,
    action: "example_reviewed",
    submissionId,
    datasetVersionId,
    metadata: {
      decision: finalDecision,
      verification_method: method,
      independent_reviews: matchingReviews,
    },
  });
  return jsonResponse(200, {
    status: finalDecision,
    trusted_for_learning: false,
    dataset_version_id: datasetVersionId,
    message: "Verified example staged; it will not affect scans until an administrator evaluates and releases a dataset.",
  });
}

async function resolveTrustedDispute(
  admin: AdminClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const submissionId = body.submission_id;
  const decision = body.decision;
  const evidenceReference = typeof body.evidence_reference === "string"
    ? redactTrustedContent(body.evidence_reference)
    : "";
  if (
    !isUuid(submissionId) ||
    (decision !== "verified_scam" &&
      decision !== "verified_legitimate") ||
    evidenceReference.length < 12 ||
    evidenceReference.length > 2000
  ) {
    return jsonResponse(400, {
      error: "Provide a valid disputed example decision and evidence.",
    });
  }
  const { data: submission, error } = await admin.from("example_submissions")
    .select(
      "id, reporter_id, content_type, redacted_content, content_hash, status",
    )
    .eq("id", submissionId)
    .maybeSingle();
  if (error) {
    console.error("Scam intelligence: disputed example could not be loaded.");
    return jsonResponse(500, {
      error: "The disputed example could not be loaded.",
    });
  }
  if (!submission || submission.status !== "disputed") {
    return jsonResponse(409, {
      error: "Only a disputed example can receive an administrator override.",
    });
  }
  if (submission.reporter_id === userId) {
    return jsonResponse(403, {
      error: "Administrators cannot resolve their own submissions.",
    });
  }

  const screening = screenTrustedContent(
    submission.content_type as SubmittedContentType,
    submission.redacted_content,
  );
  const { data: datasetVersionId, error: overrideError } = await admin.rpc(
    "stage_trusted_example",
    {
      target_submission_id: submissionId,
      target_actor_id: userId,
      target_label: decision,
      target_features: {
        categories: screening.categories.slice(0, 20),
        split: assignDatasetSplit(submission.content_hash),
      },
      target_admin_override: true,
      target_override_evidence: evidenceReference,
    },
  );
  if (overrideError || typeof datasetVersionId !== "string") {
    console.error("Scam intelligence: administrator override could not be staged.");
    return jsonResponse(409, {
      error: "The override conflicts with trusted data or could not be staged.",
    });
  }
  await recordIntelligenceAudit(admin, {
    actorId: userId,
    action: "admin_dispute_override",
    submissionId,
    datasetVersionId,
    metadata: { decision },
  });
  return jsonResponse(200, {
    status: decision,
    dataset_version_id: datasetVersionId,
    trusted_for_learning: false,
    message: "Administrator override recorded and staged for evaluation; it does not affect scans yet.",
  });
}

async function evaluateTrustedDatasetVersion(
  admin: AdminClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const versionId = body.dataset_version_id;
  if (!isUuid(versionId)) {
    return jsonResponse(400, { error: "A valid dataset version is required." });
  }
  const { data: version, error: versionError } = await admin
    .from("dataset_versions")
    .select("id, version_sequence, example_count")
    .eq("id", versionId)
    .maybeSingle();
  if (versionError) {
    console.error("Scam intelligence: dataset version could not be loaded.");
    return jsonResponse(500, { error: "The dataset version could not be loaded." });
  }
  if (!version) return jsonResponse(404, { error: "Dataset version not found." });
  if (version.example_count > 1000) {
    return jsonResponse(413, {
      error: "This dataset exceeds the bounded evaluation limit of 1,000 examples.",
    });
  }

  const { data: versions, error: versionsError } = await admin
    .from("dataset_versions")
    .select("id")
    .lte("version_sequence", version.version_sequence)
    .order("version_sequence", { ascending: true })
    .limit(1000);
  if (versionsError || !versions || versions.length === 0) {
    console.error("Scam intelligence: evaluation dataset versions could not be loaded.");
    return jsonResponse(500, {
      error: "The evaluation dataset could not be loaded.",
    });
  }
  const { data: storedExamples, error: examplesError } = await admin
    .from("trusted_training_examples")
    .select("content_hash, verified_label, features")
    .in("dataset_version_id", versions.map((row) => row.id))
    .limit(1000);
  if (examplesError) {
    console.error("Scam intelligence: evaluation examples could not be loaded.");
    return jsonResponse(500, {
      error: "Trusted examples could not be loaded for evaluation.",
    });
  }
  const examples: EvaluationExample[] = [];
  for (const row of storedExamples ?? []) {
    const features = row.features;
    const contentHash = row.content_hash;
    if (
      typeof contentHash !== "string" ||
      typeof features !== "object" || features === null ||
      Array.isArray(features) ||
      !Array.isArray((features as Record<string, unknown>).categories) ||
      (row.verified_label !== "verified_scam" &&
        row.verified_label !== "verified_legitimate")
    ) {
      return jsonResponse(500, {
        error: "A trusted example has invalid evaluation metadata.",
      });
    }
    examples.push({
      content_hash: contentHash,
      verified_label: row.verified_label,
      categories: (features as Record<string, unknown>).categories as string[],
    });
  }
  const evaluation = evaluateTrustedDataset(examples);
  const evaluationStatus = evaluation.passed ? "passed" : "failed";
  const { data: updated, error: updateError } = await admin
    .from("dataset_versions")
    .update({
      evaluation_status: evaluationStatus,
      evaluation_metrics: evaluation,
      evaluated_at: new Date().toISOString(),
    })
    .eq("id", versionId)
    .select("id")
    .maybeSingle();
  if (updateError || !updated) {
    console.error("Scam intelligence: dataset evaluation could not be recorded.");
    return jsonResponse(500, {
      error: "Evaluation ran but its result could not be recorded.",
    });
  }
  await recordIntelligenceAudit(admin, {
    actorId: userId,
    action: "dataset_evaluated",
    datasetVersionId: versionId,
    metadata: {
      evaluation_status: evaluationStatus,
      metrics: evaluation.metrics,
    },
  });
  return jsonResponse(200, {
    dataset_version_id: versionId,
    evaluation_status: evaluationStatus,
    evaluation,
    release_requires_admin: true,
  });
}

async function releaseTrustedDatasetVersion(
  admin: AdminClient,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const versionId = body.dataset_version_id;
  if (!isUuid(versionId)) {
    return jsonResponse(400, { error: "A valid dataset version is required." });
  }
  const { error } = await admin.rpc("activate_trusted_dataset", {
    target_version_id: versionId,
    target_actor_id: userId,
  });
  if (error) {
    console.error("Scam intelligence: dataset release was rejected.");
    return jsonResponse(409, {
      error: "Only a dataset that passed evaluation can be activated.",
    });
  }
  return jsonResponse(200, {
    dataset_version_id: versionId,
    release_status: "active",
    message: "The evaluated dataset is active. The previous active version was retained for rollback.",
  });
}

async function loadActiveTrustedExamples(
  admin: AdminClient,
): Promise<{
  status: "active" | "not_released" | "unavailable";
  examples: ReturnType<typeof parseTrustedExampleFeatures>;
}> {
  const { data: activeVersion, error: activeError } = await admin
    .from("dataset_versions")
    .select("id, version_sequence, example_count")
    .eq("release_status", "active")
    .maybeSingle();
  if (activeError) {
    console.error("Scam intelligence: active trusted dataset could not be loaded.");
    return { status: "unavailable", examples: [] };
  }
  if (!activeVersion) return { status: "not_released", examples: [] };
  if (activeVersion.example_count > 1000) {
    console.error("Scam intelligence: active trusted dataset exceeds its scan limit.");
    return { status: "unavailable", examples: [] };
  }

  const { data: versions, error: versionsError } = await admin
    .from("dataset_versions")
    .select("id")
    .lte("version_sequence", activeVersion.version_sequence)
    .order("version_sequence", { ascending: true })
    .limit(1000);
  if (versionsError || !versions || versions.length === 0) {
    console.error("Scam intelligence: active dataset membership could not be loaded.");
    return { status: "unavailable", examples: [] };
  }
  const { data: rows, error: examplesError } = await admin
    .from("trusted_training_examples")
    .select("content_hash, verified_label, features")
    .in("dataset_version_id", versions.map((row) => row.id))
    .limit(1000);
  if (examplesError || !rows || rows.length !== activeVersion.example_count) {
    console.error("Scam intelligence: active trusted examples are incomplete.");
    return { status: "unavailable", examples: [] };
  }
  const examples = parseTrustedExampleFeatures(rows);
  return { status: "active", examples };
}

function buildUrlReputationModule(
  indicator: NormalizedIndicator,
  report: UrlReputationResult | null,
  skipReason: "not_requested" | "skipped_non_public" = "not_requested",
): Promise<AnalysisModuleResult> {
  return buildUrlReputationModuleResult(indicator, report, skipReason);
}

async function buildUrlReputationModuleResult(
  indicator: NormalizedIndicator,
  report: UrlReputationResult | null,
  skipReason: "not_requested" | "skipped_non_public",
): Promise<AnalysisModuleResult> {
  const indicatorHash = await hashIndicator(indicator);
  if (report === null) {
    return {
      module: "external_threat_intelligence",
      indicator_type: indicator.type,
      indicator_hash: indicatorHash,
      status: "not_applicable",
      evidence_kind: "not_checked",
      confidence: 0,
      evidence: [skipReason === "not_requested"
        ? "External URL reputation checks were not requested."
        : "External checks were skipped for a private or reserved destination."],
      source: "External URL reputation providers",
      details: { status: skipReason, providers: [] },
      checked_at: new Date().toISOString(),
    };
  }
  const matches = report.providers.filter((provider) =>
    provider.status === "match"
  );
  const hasResponse = report.providers.some((provider) =>
    [
      "match",
      "no_match",
      "not_found",
      "unverified",
      "submitted",
    ].includes(provider.status)
  );
  const checkedProviders = report.providers.filter((provider) =>
    provider.status !== "not_configured"
  );
  const allChecksWereClean = checkedProviders.length > 0 &&
    checkedProviders.every((provider) => provider.status === "no_match");
  return {
    module: "external_threat_intelligence",
    indicator_type: indicator.type,
    indicator_hash: indicatorHash,
    status: !hasResponse ? "unavailable" : "completed",
    evidence_kind: matches.length > 0
      ? "confirmed_detection"
      : !hasResponse
      ? "analysis_unavailable"
      : allChecksWereClean
      ? "no_match"
      : "not_checked",
    confidence: matches.length > 0
      ? Math.min(0.9, 0.65 + 0.05 * (matches.length - 1))
      : 0,
    evidence: matches.length > 0
      ? [
        `External threat-intelligence match from: ${
          matches.map((provider) => provider.provider).join(", ")
        }.`,
      ]
      : allChecksWereClean
      ? ["Configured providers reported no exact threat match; this does not prove safety."]
      : hasResponse
      ? ["Some provider checks had no report or are still processing."]
      : [],
    source: "External URL reputation providers",
    ...(!hasResponse
      ? { error_reason: "Configured URL reputation providers did not return results." }
      : {}),
    ...(matches.length > 0 ? { category: "external_provider_match" } : {}),
    details: {
      status: report.status,
      providers: report.providers.map((provider) => ({
        provider: provider.provider,
        status: provider.status,
        duration_ms: provider.duration_ms,
        findings: provider.findings.slice(0, 3),
        ...(provider.scan_id ? { scan_id: provider.scan_id } : {}),
      })),
    },
    checked_at: new Date().toISOString(),
  };
}

async function handleRequest(request: Request) {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Scam intelligence: Supabase environment is incomplete.");
    return jsonResponse(500, { error: "Scam intelligence is not configured." });
  }
  const accessToken = request.headers
    .get("Authorization")
    ?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) {
    return jsonResponse(401, { error: "Sign in to use Cyvora." });
  }
  const admin = createClient<Database>(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const {
    data: { user },
    error: authError,
  } = await admin.auth.getUser(accessToken);
  if (authError || !user) {
    return jsonResponse(401, { error: "Your session is invalid or expired." });
  }
  if (requiresMfaChallenge(user, accessToken)) {
    return jsonResponse(403, {
      error: "Complete two-factor authentication before using this service.",
    });
  }

  let boundedBody: Awaited<ReturnType<typeof readLimitedBody>>;
  try {
    boundedBody = await readLimitedBody(request, 65536);
  } catch {
    return jsonResponse(400, { error: "Request body must be valid JSON." });
  }
  if ("tooLarge" in boundedBody) {
    return jsonResponse(413, { error: "Request body is too large." });
  }
  let body: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(boundedBody.text);
    if (!isRecord(parsed)) {
      return jsonResponse(400, { error: "Request body must be an object." });
    }
    body = parsed;
  } catch {
    return jsonResponse(400, { error: "Request body must be valid JSON." });
  }

  if (body.action === "submit_example") {
    return await submitTrustedExample(admin, user.id, body);
  }
  if (body.action === "my_examples") {
    return await loadMyTrustedExamples(admin, user.id);
  }
  if (
    body.action === "review_queue" ||
    body.action === "review_example" ||
    body.action === "resolve_dispute" ||
    body.action === "evaluate_dataset" ||
    body.action === "release_dataset"
  ) {
    if (!hasTrustedReviewRole(user)) {
      return jsonResponse(403, {
        error: "A server-assigned moderator role is required.",
      });
    }
    if (
      (body.action === "resolve_dispute" ||
        body.action === "evaluate_dataset" ||
        body.action === "release_dataset") &&
      !hasTrustedAdminRole(user)
    ) {
      return jsonResponse(403, {
        error: "A server-assigned administrator role is required.",
      });
    }
    if (body.action === "review_queue") {
      return await loadTrustedReviewQueue(admin, user.id, body);
    }
    if (body.action === "review_example") {
      return await reviewTrustedExample(admin, user.id, body);
    }
    if (body.action === "resolve_dispute") {
      return await resolveTrustedDispute(admin, user.id, body);
    }
    if (body.action === "evaluate_dataset") {
      return await evaluateTrustedDatasetVersion(admin, user.id, body);
    }
    return await releaseTrustedDatasetVersion(admin, user.id, body);
  }

  if (body.action === "report_indicator") {
    if (
      typeof body.indicator !== "string" ||
      typeof body.category !== "string"
    ) {
      return jsonResponse(400, {
        error: "A URL or domain and report category are required.",
      });
    }
    const { data: allowed, error: quotaError } = await admin.rpc(
      "consume_scam_intelligence_quota",
      { target_user_id: user.id },
    );
    if (quotaError) {
      console.error("Scam intelligence: report limit check failed.", quotaError);
      return jsonResponse(500, { error: "Could not verify the report limit." });
    }
    if (allowed !== true) {
      return jsonResponse(429, {
        error: "This account has reached its limit of 30 reports today.",
      });
    }
    try {
      const submittedCount = await submitCommunityReport(
        admin,
        user.id,
        body.indicator,
        body.category,
      );
      return jsonResponse(200, {
        status: "pending_review",
        submitted_count: submittedCount,
      });
    } catch (error) {
      if (error instanceof TypeError) {
        return jsonResponse(400, { error: error.message });
      }
      throw error;
    }
  }

  if (body.action === "assistant_chat") {
    const messages = parseAssistantMessages(body.messages);
    if (!messages) {
      return jsonResponse(400, {
        error: "Provide a valid conversation ending with a user message.",
      });
    }

    const { data: allowed, error: quotaError } = await admin.rpc(
      "consume_scam_intelligence_quota",
      { target_user_id: user.id },
    );
    if (quotaError) {
      console.error("Scam intelligence: assistant request limit check failed.", quotaError);
      return jsonResponse(500, {
        error: "Could not verify the safety-assistant request limit.",
      });
    }
    if (allowed !== true) {
      return jsonResponse(429, {
        error: "The daily Cyvora request limit has been reached.",
      });
    }

    const response = await chatWithProviders(messages, Deno.env);
    if (response.status !== "available") {
      return jsonResponse(response.status === "rate_limited" ? 429 : 503, {
        error: response.status === "not_configured"
          ? "The AI assistant is not configured. Please try again later."
          : "The AI assistant could not respond right now. Please try again.",
      });
    }
    return jsonResponse(200, { reply: response.reply });
  }

  const type = body.type;
  const input = body.input;
  const useAi = body.use_ai ?? false;
  const useUrlReputation = body.use_url_reputation ?? false;
  if (typeof useAi !== "boolean") {
    return jsonResponse(400, { error: "use_ai must be a boolean." });
  }
  if (typeof useUrlReputation !== "boolean") {
    return jsonResponse(400, {
      error: "use_url_reputation must be a boolean.",
    });
  }
  if (type !== "message" && type !== "url" && type !== "screenshot") {
    return jsonResponse(400, {
      error: "Analysis is available for message, URL, and screenshot scans only.",
    });
  }
  if (useUrlReputation && type !== "url") {
    return jsonResponse(400, {
      error: "External URL reputation checks are available for URL scans only.",
    });
  }
  const maxInputLength = type === "url" ? 2048 : 5000;
  if (
    typeof input !== "string" ||
    input.trim().length === 0 ||
    input.length > maxInputLength
  ) {
    return jsonResponse(400, {
      error: `Enter content between 1 and ${maxInputLength} characters.`,
    });
  }
  if (type === "url" && !parseUrl(input.trim())) {
    return jsonResponse(400, {
      error: "Enter a valid HTTP or HTTPS address without embedded credentials.",
    });
  }

  const { data: allowed, error: quotaError } = await admin.rpc(
    "consume_scam_intelligence_quota",
    { target_user_id: user.id },
  );
  if (quotaError) {
    console.error("Scam intelligence: scan limit check failed.", quotaError);
    return jsonResponse(500, { error: "Could not verify the scan limit." });
  }
  if (allowed !== true) {
    return jsonResponse(429, {
      error: "This account has reached its limit of 30 scans today.",
    });
  }

  const { data: configuredRules, error: rulesError } = await admin
    .from("scam_patterns")
    .select("rule_id, enabled, weight")
    .eq("version", "bantai-rules-1");
  if (rulesError || !configuredRules) {
    console.error("Scam intelligence: detection rules could not be loaded.");
    return jsonResponse(503, {
      error: "The analysis rules are temporarily unavailable.",
    });
  }
  const ruleConfig: Record<string, { enabled: boolean; weight: number }> = {};
  for (const rule of configuredRules) {
    if (
      typeof rule.rule_id !== "string" ||
      typeof rule.enabled !== "boolean" ||
      !Number.isInteger(rule.weight) ||
      rule.weight < 0 ||
      rule.weight > 10
    ) {
      console.error("Scam intelligence: a detection rule is invalid.");
      return jsonResponse(503, {
        error: "The analysis rules are temporarily unavailable.",
      });
    }
    ruleConfig[rule.rule_id] = { enabled: rule.enabled, weight: rule.weight };
  }

  const indicators = extractIndicators(type, input);
  const localResult = classifyScamContent(type === "url" ? "url" : "message", input, ruleConfig);
  const [localLookup, communityLookup, trustedLookup] = await Promise.all([
    loadReviewedMatches(admin, "local_threat_indicators", indicators),
    loadReviewedMatches(admin, "community_threat_reports", indicators),
    loadActiveTrustedExamples(admin),
  ]);
  if (localLookup.error) {
    console.error("Scam intelligence: local threat indicators are unavailable.");
  }
  if (communityLookup.error) {
    console.error("Scam intelligence: reviewed community reports are unavailable.");
  }
  const modules = await buildStaticModules({
    type,
    content: input,
    indicators,
    rules: localResult,
    localThreats: parseThreatMatches(localLookup.matches, false),
    communityThreats: parseThreatMatches(communityLookup.matches, true),
    localDatabaseAvailable: !localLookup.error,
    communityDatabaseAvailable: !communityLookup.error,
    trustedExamples: trustedLookup.examples,
    trustedExamplesStatus: trustedLookup.status,
  });

  const networkTargets = indicators.filter((item) => item.type === "url");
  const networkResults = await Promise.all(
    networkTargets.map((indicator) => analyzeDomainAndTls(indicator)),
  );
  const reputationTarget = networkTargets[0];
  const hasRestrictedDnsAddress = networkResults.flat().some((module) =>
    module.module === "domain_dns" &&
    (module.category === "restricted_address" ||
      module.category === "restricted_dns_address")
  );
  const publicReputationTarget = reputationTarget !== undefined &&
    isPublicReputationTarget(reputationTarget.value) &&
    !hasRestrictedDnsAddress;
  const urlReputation = type === "url" && useUrlReputation &&
      reputationTarget && publicReputationTarget
    ? await analyzeUrlReputation(reputationTarget.value, Deno.env)
    : null;
  const reputationSkipReason = useUrlReputation && !publicReputationTarget
    ? "skipped_non_public"
    : "not_requested";
  const allModules: AnalysisModuleResult[] = [
    ...modules,
    ...networkResults.flat(),
    ...(type === "url" && reputationTarget
      ? [
        await buildUrlReputationModule(
          reputationTarget,
          urlReputation,
          reputationSkipReason,
        ),
      ]
      : []),
  ];
  if (!isModuleResults(allModules)) {
    console.error("Scam intelligence: an internal analysis module returned invalid data.");
    return jsonResponse(502, {
      error: "An analysis module returned an invalid result.",
    });
  }

  const aiResult: AiAnalysisResult | {
    status: "disabled";
    provider: null;
    providers_tried: [];
    provider_attempts: [];
  } =
    useAi
      ? await analyzeWithProviders({
        contentType: type,
        content: type === "url"
          ? indicators.filter((item) => item.type === "url")
            .map((item) => item.value).join("\n")
          : input,
        ruleFindings: localResult.indicators,
        threatFindings: allModules.flatMap((item) => item.evidence).slice(0, 20),
      }, Deno.env)
      : {
        status: "disabled",
        provider: null,
        providers_tried: [],
        provider_attempts: [],
      };
  const unified = assessUnifiedRisk(
    {
      score: localResult.score,
      categories: localResult.categories,
      indicators: localResult.indicators,
      rulesVersion: localResult.rulesVersion,
    },
    allModules,
    aiResult,
  );
  if (!validateUnifiedAssessment(unified)) {
    console.error("Scam intelligence: unified assessment validation failed.");
    return jsonResponse(502, {
      error: "The analysis service returned an invalid result.",
    });
  }
  const recordId = await recordThreatScan(
    admin,
    user.id,
    type,
    localResult,
    unified,
  );
  return jsonResponse(200, {
    ...unified,
    scan_id: recordId,
    record_id: recordId,
  });
}

Deno.serve(async (request) => {
  try {
    return await handleRequest(request);
  } catch (error) {
    console.error(
      "Scam intelligence: unexpected request failure.",
      error instanceof Error ? error.name : "unknown error",
    );
    return jsonResponse(500, {
      error: "The scam intelligence service could not complete this request.",
    });
  }
});
