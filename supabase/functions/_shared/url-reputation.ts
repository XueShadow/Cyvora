import { isPublicIp } from "./network-analysis.ts";

export const urlReputationProviderIds = [
  "urlhaus",
  "google_safe_browsing",
  "alienvault_otx",
  "openphish",
  "phishtank",
  "urlscan",
  "threatfox",
  "virustotal",
  "pulsedive",
] as const;

export type UrlReputationProviderId = typeof urlReputationProviderIds[number];

export type UrlReputationProviderResult = {
  provider: UrlReputationProviderId;
  duration_ms?: number;
  status:
    | "match"
    | "no_match"
    | "not_found"
    | "unverified"
    | "submitted"
    | "not_configured"
    | "unavailable"
    | "timeout"
    | "rate_limited"
    | "failed";
  findings: string[];
  scan_id?: string;
};

export type UrlReputationResult = {
  status: "available" | "partial" | "unavailable" | "not_configured";
  providers: UrlReputationProviderResult[];
};

type ProviderEnvironment = {
  get(name: string): string | undefined;
};

type ProviderConfig = {
  id: UrlReputationProviderId;
  apiKey: string | null;
};

type Fetcher = typeof fetch;

class ProviderHttpError extends Error {
  readonly status: number;

  constructor(status: number) {
    super("Provider request failed.");
    this.status = status;
  }
}

const providerTimeoutMs = 6000;
const maxJsonBytes = 1024 * 1024;
const maxFeedBytes = 8 * 1024 * 1024;
const feedCacheTtlMs = 10 * 60 * 1000;

let openPhishCache:
  | { expiresAt: number; urls: Set<string> }
  | undefined;

export async function analyzeUrlReputation(
  input: string,
  environment: ProviderEnvironment,
  fetcher: Fetcher = fetch,
): Promise<UrlReputationResult> {
  const url = normalizeUrl(input);
  const providers = urlReputationProviderIds.map((id) =>
    providerConfig(id, environment)
  );
  const results = await Promise.all(providers.map((provider) =>
    provider.apiKey === null && provider.id !== "openphish"
      ? Promise.resolve({
        provider: provider.id,
        status: "not_configured" as const,
        findings: [],
      })
      : checkProvider(provider, url, fetcher)
  ));
  const checked = results.filter((result) =>
    result.status !== "not_configured"
  );
  const completed = checked.filter((result) =>
    ["match", "no_match", "unverified"].includes(result.status)
  );
  const status: UrlReputationResult["status"] = checked.length === 0
    ? "not_configured"
    : completed.length === checked.length
    ? "available"
    : completed.length > 0
    ? "partial"
    : "unavailable";
  return { status, providers: results };
}

export function isPublicReputationTarget(input: string): boolean {
  let url: URL;
  try {
    url = new URL(input.includes("://") ? input : `https://${input}`);
  } catch {
    return false;
  }
  if (
    (url.protocol !== "http:" && url.protocol !== "https:") ||
    !url.hostname ||
    url.username ||
    url.password
  ) return false;
  const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, "")
    .replace(/\.$/, "");
  if (
    !hostname.includes(".") ||
    /(?:^|\.)(?:localhost|local|internal|test|example|invalid|onion)$/i
      .test(hostname) ||
    /(?:^|\.)home\.arpa$/i.test(hostname)
  ) return false;
  if (/^[\d.]+$/.test(hostname) || hostname.includes(":")) {
    return isPublicIp(hostname);
  }
  return true;
}

function providerConfig(
  id: UrlReputationProviderId,
  environment: ProviderEnvironment,
): ProviderConfig {
  const keyName: Partial<Record<UrlReputationProviderId, string>> = {
    urlhaus: "URLHAUS_AUTH_KEY",
    google_safe_browsing: "GOOGLE_SAFE_BROWSING_API_KEY",
    alienvault_otx: "OTX_API_KEY",
    phishtank: "PHISHTANK_API_KEY",
    urlscan: "URLSCAN_API_KEY",
    threatfox: "THREATFOX_AUTH_KEY",
    virustotal: "VIRUSTOTAL_API_KEY",
    pulsedive: "PULSEDIVE_API_KEY",
  };
  return {
    id,
    apiKey: keyName[id] ? environment.get(keyName[id]!)?.trim() || null : null,
  };
}

async function checkProvider(
  provider: ProviderConfig,
  url: string,
  fetcher: Fetcher,
): Promise<UrlReputationProviderResult> {
  const controller = new AbortController();
  const startedAt = Date.now();
  const elapsedMs = () => Math.max(0, Date.now() - startedAt);
  let timeout: ReturnType<typeof setTimeout> | undefined;
  try {
    const result = await Promise.race([
      queryProvider(provider, url, fetcher, controller.signal),
      new Promise<never>((_, reject) => {
        timeout = setTimeout(() => {
          controller.abort();
          reject(new DOMException("Provider request timed out.", "TimeoutError"));
        }, providerTimeoutMs);
      }),
    ]);
    return {
      provider: provider.id,
      ...result,
      duration_ms: elapsedMs(),
    };
  } catch (error) {
    if (error instanceof ProviderHttpError) {
      return {
        provider: provider.id,
        status: error.status === 429 || error.status === 509
          ? "rate_limited"
          : error.status >= 500
          ? "unavailable"
          : (provider.id === "virustotal" ||
                provider.id === "pulsedive") &&
              error.status === 404
          ? "not_found"
          : "failed",
        findings: [],
      };
    }
    return {
      provider: provider.id,
      status: error instanceof DOMException &&
          (error.name === "AbortError" || error.name === "TimeoutError")
        ? "timeout"
        : "unavailable",
      findings: [],
      duration_ms: elapsedMs(),
    };
  } finally {
    if (timeout !== undefined) clearTimeout(timeout);
  }
}

async function queryProvider(
  provider: ProviderConfig,
  url: string,
  fetcher: Fetcher,
  signal: AbortSignal,
): Promise<Omit<UrlReputationProviderResult, "provider">> {
  switch (provider.id) {
    case "urlhaus": {
      const body = await fetchJson(
        fetcher,
        "https://urlhaus-api.abuse.ch/v1/url/",
        {
          method: "POST",
          headers: {
            "Auth-Key": provider.apiKey!,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({ url }),
          signal,
        },
      );
      if (!isRecord(body)) throw new TypeError("Invalid URLhaus response.");
      if (body.query_status === "ok") {
        return {
          status: "match",
          findings: ["URLhaus lists this URL as a malware indicator."],
        };
      }
      if (body.query_status === "no_results") {
        return { status: "no_match", findings: [] };
      }
      throw new TypeError("Invalid URLhaus response.");
    }
    case "google_safe_browsing": {
      const endpoint = new URL(
        "https://safebrowsing.googleapis.com/v4/threatMatches:find",
      );
      endpoint.searchParams.set("key", provider.apiKey!);
      const body = await fetchJson(fetcher, endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          client: { clientId: "cyvora", clientVersion: "1.0" },
          threatInfo: {
            threatTypes: ["MALWARE", "SOCIAL_ENGINEERING"],
            platformTypes: ["ANY_PLATFORM"],
            threatEntryTypes: ["URL"],
            threatEntries: [{ url }],
          },
        }),
        signal,
      });
      if (!isRecord(body) || (body.matches !== undefined &&
        !Array.isArray(body.matches))) {
        throw new TypeError("Invalid Safe Browsing response.");
      }
      const matches = Array.isArray(body.matches) ? body.matches : [];
      return matches.length > 0
        ? {
          status: "match",
          findings: distinctStrings(
            matches.flatMap((item) =>
              isRecord(item) &&
                  (item.threatType === "MALWARE" ||
                    item.threatType === "SOCIAL_ENGINEERING")
                ? [item.threatType]
                : []
            ),
          ).slice(0, 3).map((type) =>
            `Google Safe Browsing reports ${type}.`
          ),
        }
        : { status: "no_match", findings: [] };
    }
    case "alienvault_otx": {
      const endpoint =
        `https://otx.alienvault.com/api/v1/indicators/url/${encodeURIComponent(url)}/general`;
      const body = await fetchJson(fetcher, endpoint, {
        headers: { "X-OTX-API-KEY": provider.apiKey! },
        signal,
      });
      if (!isRecord(body) || !isRecord(body.pulse_info)) {
        throw new TypeError("Invalid OTX response.");
      }
      const count = body.pulse_info.count;
      if (typeof count !== "number" || !Number.isInteger(count) || count < 0) {
        throw new TypeError("Invalid OTX response.");
      }
      return count > 0
        ? {
          status: "match",
          findings: [`AlienVault OTX reports ${count} threat pulse(s).`],
        }
        : { status: "no_match", findings: [] };
    }
    case "openphish": {
      const urls = await getOpenPhishUrls(fetcher, signal);
      return urls.has(url)
        ? {
          status: "match",
          findings: ["OpenPhish lists this URL in its community feed."],
        }
        : { status: "no_match", findings: [] };
    }
    case "phishtank": {
      const body = await fetchJson(
        fetcher,
        "https://checkurl.phishtank.com/checkurl/",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "Cyvora URL Reputation/1.0",
          },
          body: new URLSearchParams({
            url,
            format: "json",
            app_key: provider.apiKey!,
          }),
          signal,
        },
      );
      if (!isRecord(body) || !isRecord(body.results)) {
        throw new TypeError("Invalid PhishTank response.");
      }
      const result = body.results;
      if (!isTrueFlag(result.in_database)) {
        return { status: "no_match", findings: [] };
      }
      return isTrueFlag(result.verified) && isTrueFlag(result.valid)
        ? {
          status: "match",
          findings: ["PhishTank lists this URL as verified and active phishing."],
        }
        : {
          status: "unverified",
          findings: ["PhishTank has a listing that is not verified as active."],
        };
    }
    case "urlscan": {
      const body = await fetchJson(
        fetcher,
        "https://urlscan.io/api/v1/scan/",
        {
          method: "POST",
          headers: {
            "API-Key": provider.apiKey!,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ url, visibility: "private" }),
          signal,
        },
      );
      if (!isRecord(body)) throw new TypeError("Invalid urlscan.io response.");
      if (typeof body.visibility === "string" && body.visibility !== "private") {
        throw new TypeError("urlscan.io did not accept private visibility.");
      }
      const task = isRecord(body.task) ? body.task : body;
      const scanId = typeof task.uuid === "string" &&
          /^[a-f0-9-]{36}$/i.test(task.uuid)
        ? task.uuid
        : undefined;
      return {
        status: "submitted",
        findings: [
          "A private urlscan.io scan was submitted; results may still be processing.",
        ],
        ...(scanId ? { scan_id: scanId } : {}),
      };
    }
    case "threatfox": {
      const body = await fetchJson(
        fetcher,
        "https://threatfox-api.abuse.ch/api/v1/",
        {
          method: "POST",
          headers: {
            "Auth-Key": provider.apiKey!,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ query: "search_ioc", search_term: url }),
          signal,
        },
      );
      if (!isRecord(body) || typeof body.query_status !== "string") {
        throw new TypeError("Invalid ThreatFox response.");
      }
      if (body.query_status === "no_result") {
        return { status: "no_match", findings: [] };
      }
      if (body.query_status !== "ok" || !Array.isArray(body.data)) {
        throw new TypeError("Invalid ThreatFox response.");
      }
      const matches = body.data.filter((item) =>
        isRecord(item) && typeof item.ioc === "string" &&
        normalizeUrl(item.ioc) === url
      );
      return matches.length > 0
        ? {
          status: "match",
          findings: ["ThreatFox reports an exact URL threat indicator."],
        }
        : { status: "no_match", findings: [] };
    }
    case "virustotal": {
      const id = btoa(url).replace(/\+/g, "-").replace(/\//g, "_")
        .replace(/=+$/, "");
      const body = await fetchJson(
        fetcher,
        `https://www.virustotal.com/api/v3/urls/${id}`,
        { headers: { "x-apikey": provider.apiKey! }, signal },
      );
      if (!isRecord(body) || !isRecord(body.data) ||
        !isRecord(body.data.attributes) ||
        !isRecord(body.data.attributes.last_analysis_stats)) {
        throw new TypeError("Invalid VirusTotal response.");
      }
      const stats = body.data.attributes.last_analysis_stats;
      const malicious = integerOrZero(stats.malicious);
      const suspicious = integerOrZero(stats.suspicious);
      return malicious + suspicious > 0
        ? {
          status: "match",
          findings: [
            `VirusTotal reports ${malicious} malicious and ${suspicious} suspicious engine result(s).`,
          ],
        }
        : { status: "no_match", findings: [] };
    }
    case "pulsedive": {
      const endpoint = new URL("https://pulsedive.com/api/indicator.php");
      endpoint.searchParams.set("indicator", url);
      endpoint.searchParams.set("key", provider.apiKey!);
      const body = await fetchJson(fetcher, endpoint, { signal });
      if (!isRecord(body)) throw new TypeError("Invalid Pulsedive response.");
      const risk = body.risk_recommended ?? body.risk;
      if (
        typeof risk !== "string" ||
        !["unknown", "very low", "low", "medium", "high", "critical"]
          .includes(risk.toLowerCase())
      ) {
        throw new TypeError("Invalid Pulsedive response.");
      }
      const normalizedRisk = risk.toLowerCase();
      if (normalizedRisk === "high" || normalizedRisk === "critical") {
        return {
          status: "match",
          findings: [`Pulsedive reports a ${normalizedRisk} risk rating.`],
        };
      }
      return {
        status: "unverified",
        findings: [`Pulsedive risk rating: ${normalizedRisk}.`],
      };
    }
  }
}

async function getOpenPhishUrls(
  fetcher: Fetcher,
  signal: AbortSignal,
): Promise<Set<string>> {
  if (openPhishCache && openPhishCache.expiresAt > Date.now()) {
    return openPhishCache.urls;
  }
  const response = await fetcher("https://openphish.com/feed.txt", {
    headers: { "User-Agent": "Cyvora URL Reputation/1.0" },
    redirect: "error",
    signal,
  });
  if (!response.ok) throw new ProviderHttpError(response.status);
  const text = await readTextBounded(response, maxFeedBytes);
  const urls = new Set<string>();
  for (const line of text.split(/\r?\n/)) {
    const candidate = line.trim();
    if (!candidate) continue;
    try {
      urls.add(normalizeUrl(candidate));
    } catch {
      continue;
    }
  }
  if (urls.size === 0) throw new TypeError("The OpenPhish feed was empty.");
  openPhishCache = { expiresAt: Date.now() + feedCacheTtlMs, urls };
  return urls;
}

async function fetchJson(
  fetcher: Fetcher,
  input: string | URL,
  init: RequestInit,
): Promise<unknown> {
  const response = await fetcher(input, { ...init, redirect: "error" });
  if (!response.ok) {
    await response.body?.cancel();
    throw new ProviderHttpError(response.status);
  }
  const text = await readTextBounded(response, maxJsonBytes);
  try {
    return JSON.parse(text);
  } catch {
    throw new TypeError("Provider returned invalid JSON.");
  }
}

async function readTextBounded(
  response: Response,
  maxBytes: number,
): Promise<string> {
  const length = response.headers.get("Content-Length");
  if (length && /^\d+$/.test(length) && Number(length) > maxBytes) {
    await response.body?.cancel();
    throw new TypeError("Provider response exceeded its size limit.");
  }
  const reader = response.body?.getReader();
  if (!reader) return "";
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) {
        await reader.cancel();
        throw new TypeError("Provider response exceeded its size limit.");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

function normalizeUrl(input: string): string {
  const url = new URL(input.includes("://") ? input : `https://${input}`);
  if (
    (url.protocol !== "http:" && url.protocol !== "https:") ||
    !url.hostname ||
    url.username ||
    url.password
  ) throw new TypeError("A valid HTTP or HTTPS URL is required.");
  url.hash = "";
  return url.href;
}

function isTrueFlag(value: unknown): boolean {
  return value === true || value === "true" || value === "y";
}

function integerOrZero(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
    ? value
    : 0;
}

function distinctStrings(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
