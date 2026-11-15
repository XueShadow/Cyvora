import { classifyScamContent } from "../scam-intelligence/scam-patterns.ts";

export type SubmittedContentType = "message" | "url" | "screenshot";
export type SubmittedLabel = "scam" | "legitimate" | "unsure";

export type TrustedExampleFeatures = {
  label: "verified_scam" | "verified_legitimate";
  categories: string[];
};

export function redactTrustedContent(value: string): string {
  return value
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, " ")
    .replace(
      /\b(?:bearer\s+)?(?:access[_ -]?token|refresh[_ -]?token)\s*[:=]\s*\S+/gi,
      "[redacted token]",
    )
    .replace(
      /\b(password|passcode|one[- ]time (?:password|code)|verification code|security code|login code|otp|pin)\b\s*(?:is|:|=)?\s*\S+/gi,
      "$1 [redacted]",
    )
    .replace(
      /\b(account number|bank account(?: number)?|card number|social security number|passport number|national id)\b\s*(?:is|:|#|no\.?)\s*[a-z0-9][a-z0-9 -]{4,24}/gi,
      "$1 [redacted]",
    )
    .replace(
      /\b(full name|account holder|recipient|name)\s*(?:is|:|-)\s*[^\r\n,;.!?]{2,60}/gi,
      "$1 [redacted]",
    )
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[redacted email]")
    .replace(
      /(?<!\w)\+?\d[\d\s().-]{7,}\d(?!\w)/g,
      "[redacted number]",
    )
    .replace(
      /\b(?:https?:\/\/|www\.)[^\s<>"']+/gi,
      redactUrl,
    )
    .replace(/[ \t]{2,}/g, " ")
    .trim()
    .slice(0, 5000);
}

function redactUrl(value: string): string {
  const normalized = value.startsWith("www.") ? `https://${value}` : value;
  try {
    const url = new URL(normalized);
    if (url.protocol !== "http:" && url.protocol !== "https:") {
      return "[redacted link]";
    }
    url.username = "";
    url.password = "";
    url.search = "";
    url.hash = "";
    url.pathname = url.pathname.split("/").map((segment) =>
      segment.length > 40 || /^[a-zA-Z0-9_-]{24,}$/.test(segment)
        ? "[redacted]"
        : segment
    ).join("/");
    return url.toString();
  } catch {
    return "[redacted link]";
  }
}

export async function hashTrustedContent(value: string): Promise<string> {
  const normalized = value.toLowerCase().replace(/\s+/g, " ").trim();
  const digest = new Uint8Array(
    await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(normalized),
    ),
  );
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function screenTrustedContent(
  type: SubmittedContentType,
  redactedContent: string,
): {
  risk_level: string;
  categories: string[];
  indicators: string[];
} {
  const result = classifyScamContent(
    type === "url" ? "url" : "message",
    redactedContent,
  );
  return {
    risk_level: result.risk_level,
    categories: result.categories.slice(0, 12),
    indicators: result.indicators.slice(0, 12),
  };
}

export function parseTrustedExampleFeatures(
  value: unknown,
): TrustedExampleFeatures[] {
  if (!Array.isArray(value)) return [];
  const seenHashes = new Set<string>();
  return value.flatMap((item) => {
    if (
      typeof item !== "object" || item === null || Array.isArray(item) ||
      !("verified_label" in item) || !("features" in item) ||
      !("content_hash" in item)
    ) return [];
    const row = item as Record<string, unknown>;
    const features = row.features;
    const contentHash = row.content_hash;
    if (
      (row.verified_label !== "verified_scam" &&
        row.verified_label !== "verified_legitimate") ||
      typeof contentHash !== "string" ||
      !/^[0-9a-f]{64}$/.test(contentHash) ||
      seenHashes.has(contentHash) ||
      typeof features !== "object" || features === null ||
      Array.isArray(features)
    ) return [];
    const categories = (features as Record<string, unknown>).categories;
    const split = (features as Record<string, unknown>).split;
    if (
      !Array.isArray(categories) ||
      categories.length > 20 ||
      split !== "train" ||
      categories.some((category) =>
        typeof category !== "string" || category.length > 80
      )
    ) return [];
    seenHashes.add(contentHash);
    return [{
      label: row.verified_label,
      categories: [...new Set(categories as string[])],
    }];
  });
}
