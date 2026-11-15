import {
  createModuleResult,
  hashIndicator,
  type AnalysisModuleResult,
  type NormalizedIndicator,
} from "./analysis-modules.ts";

type DnsRecordType = "A" | "AAAA";

export type DnsTlsTools = {
  resolve(hostname: string, type: DnsRecordType): Promise<string[]>;
  verifyTls(address: string, hostname: string, timeoutMs: number): Promise<void>;
};

const dnsTimeoutMs = 5000;
const tlsTimeoutMs = 7000;

export async function analyzeDomainAndTls(
  indicator: NormalizedIndicator,
  tools: DnsTlsTools = runtimeDnsTlsTools(),
): Promise<AnalysisModuleResult[]> {
  const hash = await hashIndicator(indicator);
  const hostname = indicator.type === "url"
    ? new URL(indicator.value).hostname.replace(/^\[|\]$/g, "")
    : indicator.value.replace(/^\[|\]$/g, "");
  if (isIpLiteral(hostname)) {
    const publicAddress = isPublicIp(hostname);
    return [
      createModuleResult(
        "domain_dns",
        "completed",
        publicAddress ? "no_match" : "suspicious_signal",
        [publicAddress
          ? "The URL uses a public IP address instead of a domain."
          : "A private or reserved IP literal was blocked from active probing."],
        {
          indicator,
          indicatorHash: hash,
          confidence: publicAddress ? 0.35 : 0.8,
          category: publicAddress ? "ip_literal" : "restricted_address",
        },
      ),
      createModuleResult(
        "ssl_tls",
        "not_applicable",
        "not_checked",
        [],
        {
          indicator,
          indicatorHash: hash,
          errorReason: "TLS probing is limited to DNS names, not IP literals.",
        },
      ),
    ];
  }

  if (!isSafeHostname(hostname)) {
    return [
      createModuleResult(
        "domain_dns",
        "unavailable",
        "analysis_unavailable",
        [],
        {
          indicator,
          indicatorHash: hash,
          errorReason: "Local or malformed hostnames are not resolved.",
        },
      ),
      unavailableTls(indicator, hash, "No public DNS hostname is available."),
    ];
  }

  let addresses: string[];
  try {
    const [a, aaaa] = await withTimeout(
      Promise.all([
        resolveRecord(tools, hostname, "A"),
        resolveRecord(tools, hostname, "AAAA"),
      ]),
      dnsTimeoutMs,
    );
    addresses = [...new Set([...a, ...aaaa])].slice(0, 16);
  } catch (error) {
    return [
      createModuleResult(
        "domain_dns",
        "unavailable",
        "analysis_unavailable",
        [],
        {
          indicator,
          indicatorHash: hash,
          errorReason: isTimeout(error)
            ? "DNS resolution timed out."
            : "DNS resolution is unavailable in this environment.",
        },
      ),
      unavailableTls(
        indicator,
        hash,
        "TLS probing was skipped because DNS could not be verified.",
      ),
    ];
  }

  if (addresses.length === 0) {
    const tlsResult = indicator.type === "url" &&
        new URL(indicator.value).protocol === "http:"
      ? unencryptedHttpTls(indicator, hash)
      : unavailableTls(
        indicator,
        hash,
        "TLS probing was skipped because no IP addresses resolved.",
      );
    return [
      createModuleResult(
        "domain_dns",
        "completed",
        "suspicious_signal",
        ["The hostname did not return A or AAAA records."],
        {
          indicator,
          indicatorHash: hash,
          confidence: 0.7,
          category: "no_dns_records",
        },
      ),
      tlsResult,
    ];
  }

  const restrictedAddresses = addresses.filter((address) =>
    !isPublicIp(address)
  );
  if (restrictedAddresses.length > 0) {
    return [
      createModuleResult(
        "domain_dns",
        "completed",
        "suspicious_signal",
        ["DNS returned a private or reserved address; active connection was blocked."],
        {
          indicator,
          indicatorHash: hash,
          confidence: 0.8,
          category: "restricted_dns_address",
          details: { resolved_address_count: addresses.length },
        },
      ),
      unavailableTls(
        indicator,
        hash,
        "TLS probing was blocked because DNS included a private or reserved address.",
      ),
    ];
  }

  const dnsResult = createModuleResult(
    "domain_dns",
    "completed",
    "no_match",
    [`DNS resolved to ${addresses.length} public address(es).`],
    {
      indicator,
      indicatorHash: hash,
      confidence: 0.4,
      details: { resolved_address_count: addresses.length },
    },
  );
  if (indicator.type === "url" && !new URL(indicator.value).protocol.startsWith("https:")) {
    return [
      dnsResult,
      unencryptedHttpTls(indicator, hash),
    ];
  }

  try {
    await withTimeout(
      tools.verifyTls(addresses[0], hostname, tlsTimeoutMs),
      tlsTimeoutMs,
    );
    return [
      dnsResult,
      createModuleResult(
        "ssl_tls",
        "completed",
        "no_match",
        ["TLS handshake and hostname certificate validation succeeded."],
        {
          indicator,
          indicatorHash: hash,
          confidence: 0.55,
          details: { certificate_metadata: "not exposed by the runtime" },
        },
      ),
    ];
  } catch (error) {
    const unavailable = isTimeout(error) || isNetworkCapabilityError(error);
    return [
      dnsResult,
      createModuleResult(
        "ssl_tls",
        unavailable ? "unavailable" : "failed",
        unavailable ? "analysis_unavailable" : "analysis_failed",
        [],
        {
          indicator,
          indicatorHash: hash,
          errorReason: isTimeout(error)
            ? "TLS certificate validation timed out."
            : isNetworkCapabilityError(error)
            ? "TLS verification is unavailable in this runtime."
            : "TLS handshake or hostname certificate validation failed.",
        },
      ),
    ];
  }
}

function unavailableTls(
  indicator: NormalizedIndicator,
  hash: string,
  errorReason: string,
): AnalysisModuleResult {
  return createModuleResult(
    "ssl_tls",
    "unavailable",
    "analysis_unavailable",
    [],
    { indicator, indicatorHash: hash, errorReason },
  );
}

function unencryptedHttpTls(
  indicator: NormalizedIndicator,
  hash: string,
): AnalysisModuleResult {
  return createModuleResult(
    "ssl_tls",
    "completed",
    "suspicious_signal",
    ["The URL uses unencrypted HTTP; no TLS certificate can be verified."],
    {
      indicator,
      indicatorHash: hash,
      confidence: 0.6,
      category: "unencrypted_http",
    },
  );
}

async function resolveRecord(
  tools: DnsTlsTools,
  hostname: string,
  type: DnsRecordType,
): Promise<string[]> {
  try {
    return await tools.resolve(hostname, type);
  } catch (error) {
    if (error instanceof Error && error.name === "NotFound") return [];
    throw error;
  }
}

function runtimeDnsTlsTools(): DnsTlsTools {
  return {
    resolve: createDnsOverHttpsResolver(),
    async verifyTls(address, hostname, timeoutMs) {
      let rawConnection: Deno.TcpConn | undefined;
      let timedOut = false;
      const timer = setTimeout(() => {
        timedOut = true;
        try {
          rawConnection?.close();
        } catch {
          // A concurrent close during timeout is expected.
        }
      }, timeoutMs);
      try {
        rawConnection = await Deno.connect({
          transport: "tcp",
          hostname: address,
          port: 443,
        }) as Deno.TcpConn;
        if (timedOut) throw new DOMException("Timed out", "TimeoutError");
        const tlsConnection = await Deno.startTls(rawConnection, { hostname });
        tlsConnection.close();
        if (timedOut) throw new DOMException("Timed out", "TimeoutError");
      } finally {
        clearTimeout(timer);
        try {
          rawConnection?.close();
        } catch {
          // The TLS connection may already have closed the underlying socket.
        }
      }
    },
  };
}

export function createDnsOverHttpsResolver(
  fetcher: typeof fetch = fetch,
): DnsTlsTools["resolve"] {
  return async (hostname, type) => {
    const endpoint = new URL("https://cloudflare-dns.com/dns-query");
    endpoint.searchParams.set("name", hostname);
    endpoint.searchParams.set("type", type);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), dnsTimeoutMs);
    try {
      const response = await fetcher(endpoint, {
        headers: { Accept: "application/dns-json" },
        redirect: "error",
        signal: controller.signal,
      });
      if (!response.ok) throw new Error("DNS-over-HTTPS request failed.");
      const body: unknown = await response.json();
      if (
        !isRecord(body) ||
        typeof body.Status !== "number" ||
        !Number.isInteger(body.Status)
      ) {
        throw new TypeError("DNS-over-HTTPS returned an invalid response.");
      }
      if (body.Status === 3) return [];
      if (body.Status !== 0) {
        throw new Error("DNS-over-HTTPS could not resolve the hostname.");
      }
      if (body.Answer === undefined) return [];
      if (!Array.isArray(body.Answer)) {
        throw new TypeError("DNS-over-HTTPS returned invalid answers.");
      }
      const expectedRecordType = type === "A" ? 1 : 28;
      return [...new Set(body.Answer.flatMap((answer) =>
        isRecord(answer) &&
          answer.type === expectedRecordType &&
          typeof answer.data === "string" &&
          isValidDnsAddress(answer.data, type)
          ? [answer.data]
          : []
      ))].slice(0, 16);
    } finally {
      clearTimeout(timer);
    }
  };
}

async function withTimeout<T>(
  promise: Promise<T>,
  milliseconds: number,
): Promise<T> {
  let timeout: ReturnType<typeof setTimeout>;
  const expired = new Promise<never>((_resolve, reject) => {
    timeout = setTimeout(
      () => reject(new DOMException("Timed out", "TimeoutError")),
      milliseconds,
    );
  });
  try {
    return await Promise.race([promise, expired]);
  } finally {
    clearTimeout(timeout!);
  }
}

function isTimeout(error: unknown): boolean {
  return error instanceof DOMException &&
    (error.name === "TimeoutError" || error.name === "AbortError");
}

function isNetworkCapabilityError(error: unknown): boolean {
  return error instanceof Error &&
    (error.name === "NotCapable" || error.name === "PermissionDenied");
}

function isValidDnsAddress(
  address: string,
  type: DnsRecordType,
): boolean {
  if (type === "A") {
    const octets = address.split(".");
    return octets.length === 4 && octets.every((octet) =>
      /^\d{1,3}$/.test(octet) && Number(octet) <= 255
    );
  }
  if (!address.includes(":") || address.includes("%")) return false;
  try {
    return new URL(`https://[${address}]/`).hostname.length > 2;
  } catch {
    return false;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isSafeHostname(hostname: string): boolean {
  return hostname.length > 0 &&
    hostname.length <= 253 &&
    !hostname.endsWith(".") &&
    !hostname.includes("%") &&
    !isIpLiteral(hostname) &&
    !/^(?:localhost|.*\.localhost|.*\.local|.*\.internal)$/i.test(hostname) &&
    hostname.split(".").every((label) =>
      label.length >= 1 && label.length <= 63 &&
      /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/i.test(label)
    );
}

function isIpLiteral(value: string): boolean {
  return /^\d{1,3}(?:\.\d{1,3}){3}$/.test(value) ||
    value.includes(":");
}

export function isPublicIp(value: string): boolean {
  if (/^\d{1,3}(?:\.\d{1,3}){3}$/.test(value)) {
    const octets = value.split(".").map(Number);
    if (octets.some((octet) => octet < 0 || octet > 255)) return false;
    const [a, b, c] = octets;
    return !(
      a === 0 || a === 10 || a === 127 || a >= 224 ||
      a === 100 && b >= 64 && b <= 127 ||
      a === 169 && b === 254 ||
      a === 172 && b >= 16 && b <= 31 ||
      a === 192 && (b === 0 || b === 168) ||
      a === 192 && b === 88 && c === 99 ||
      a === 198 && (b === 18 || b === 19) ||
      a === 198 && b === 51 && c === 100 ||
      a === 203 && b === 0 && c === 113
    );
  }
  const groups = expandIpv6(value);
  if (!groups || groups.length !== 8) return false;
  const first = groups[0];
  return first >= 0x2000 && first <= 0x3fff &&
    !(first === 0x2001 &&
      (groups[1] <= 0x01ff || groups[1] === 0x0db8)) &&
    first !== 0x2002;
}

function expandIpv6(value: string): number[] | null {
  const normalized = value.toLowerCase();
  if (!normalized.includes(":")) return null;
  const halves = normalized.split("::");
  if (halves.length > 2) return null;
  const left = halves[0] ? halves[0].split(":") : [];
  const right = halves.length === 2 && halves[1] ? halves[1].split(":") : [];
  const values = [...left, ...right];
  const groups: number[] = [];
  for (const part of values) {
    if (part.includes(".")) {
      const octets = part.split(".").map(Number);
      if (octets.length !== 4 || octets.some((octet) => octet > 255)) return null;
      groups.push((octets[0] << 8) | octets[1], (octets[2] << 8) | octets[3]);
    } else {
      if (!/^[\da-f]{1,4}$/.test(part)) return null;
      groups.push(parseInt(part, 16));
    }
  }
  if (halves.length === 1) return groups.length === 8 ? groups : null;
  const zeros = 8 - groups.length;
  return zeros < 1 ? null : [...left.map((part) => parseInt(part, 16)), ...Array(zeros).fill(0), ...right.map((part) => parseInt(part, 16))];
}
