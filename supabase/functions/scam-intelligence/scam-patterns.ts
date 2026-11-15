export const analysisIndicators: string[] = [
  "Urgent or coercive language",
  "Requests for passwords or security codes",
  "Requests for money or unusual payment methods",
  "Requests for secrecy or isolation",
  "Unexpected prize, reward, or refund",
  "Suspicious or unusual URL characteristics",
  "Domain or sender claims need independent verification",
  "Potentially misleading link text",
  "Unusual URL structure",
  "Malicious or suspicious link destination",
  "Impersonation or brand spoofing",
  "Account recovery or identity theft pressure",
  "Payment or account-verification trap",
  "Shortened, hidden, or redirecting link",
  "Suspicious sender or domain mismatch",
];

type RiskLevel = "low" | "review" | "high";
type ScanType = "message" | "url";

type Brand = {
  name: string;
  domains: string[];
};

export type ScamAnalysisResult = {
  risk_level: RiskLevel;
  score: number;
  categories: string[];
  indicators: string[];
  summary: string;
  guidance: string;
  rulesVersion: string;
};

const brands: Brand[] = [
  { name: "amazon", domains: ["amazon.com", "amazon.com.ph"] },
  { name: "apple", domains: ["apple.com", "icloud.com"] },
  { name: "bdo", domains: ["bdo.com.ph"] },
  { name: "bpi", domains: ["bpi.com.ph"] },
  { name: "facebook", domains: ["facebook.com", "meta.com"] },
  { name: "gcash", domains: ["gcash.com"] },
  { name: "google", domains: ["google.com", "gmail.com"] },
  { name: "landbank", domains: ["landbank.com"] },
  { name: "lazada", domains: ["lazada.com.ph", "lazada.com"] },
  { name: "maya", domains: ["maya.ph"] },
  {
    name: "microsoft",
    domains: ["microsoft.com", "microsoftonline.com", "live.com", "outlook.com"],
  },
  { name: "pagibig", domains: ["pagibigfund.gov.ph"] },
  { name: "paypal", domains: ["paypal.com"] },
  { name: "philhealth", domains: ["philhealth.gov.ph"] },
  { name: "shopee", domains: ["shopee.ph", "shopee.com"] },
  { name: "sss", domains: ["sss.gov.ph"] },
  { name: "unionbank", domains: ["unionbankph.com"] },
];

const shortenerHosts = new Set([
  "bit.ly",
  "cutt.ly",
  "goo.gl",
  "is.gd",
  "ow.ly",
  "rb.gy",
  "t.co",
  "tiny.cc",
  "tinyurl.com",
]);

const credentialRequestPattern =
  /\b(?:send|share|give|provide|enter|reply with|text|submit|ask for|send mo|ibigay(?: mo)?|ipadala(?: mo)?|ibahagi|ilagay|i-send|isend|hingin)\b[^.!?;\n]{0,50}\b(?:password|passcode|one[- ]time (?:password|code)|verification code|security code|login code|otp|pin)\b/gi;
const negatedRequestPattern =
  /\b(?:never|do not|don't|does not|doesn't|will not|won't|huwag|wag|hindi kailanman)\s+(?:ever\s+)?(?:ask|request|send|share|give|provide|enter|reply|text|submit|hingi|hingin|ipadala|ibigay|ibahagi|ilagay)\b/;

function isNegatedRequest(text: string, matchIndex: number): boolean {
  const before = text.slice(0, matchIndex);
  const boundary = Math.max(
    before.lastIndexOf("."),
    before.lastIndexOf("!"),
    before.lastIndexOf("?"),
    before.lastIndexOf(";"),
    before.lastIndexOf("\n"),
  );
  const context = text.slice(
    Math.max(boundary + 1, matchIndex - 45),
    matchIndex + 20,
  );
  return negatedRequestPattern.test(context);
}

function normalizeHost(host: string): string {
  return host.toLowerCase().replace(/\.$/, "");
}

function isOfficialDomain(host: string, brand: Brand): boolean {
  return brand.domains.some((domain) =>
    host === domain || host.endsWith(`.${domain}`)
  );
}

function editDistanceAtMostOne(left: string, right: string): boolean {
  if (Math.abs(left.length - right.length) > 1 || left === right) return false;
  if (left.length === right.length) {
    const mismatches: number[] = [];
    for (let index = 0; index < left.length; index++) {
      if (left[index] !== right[index]) mismatches.push(index);
    }
    if (
      mismatches.length === 2 &&
      mismatches[1] === mismatches[0] + 1 &&
      left[mismatches[0]] === right[mismatches[1]] &&
      left[mismatches[1]] === right[mismatches[0]]
    ) {
      return true;
    }
  }
  let leftIndex = 0;
  let rightIndex = 0;
  let edits = 0;
  while (leftIndex < left.length && rightIndex < right.length) {
    if (left[leftIndex] === right[rightIndex]) {
      leftIndex++;
      rightIndex++;
      continue;
    }
    if (++edits > 1) return false;
    if (left.length > right.length) leftIndex++;
    else if (right.length > left.length) rightIndex++;
    else {
      leftIndex++;
      rightIndex++;
    }
  }
  return edits +
      Number(leftIndex < left.length || rightIndex < right.length) <=
    1;
}

function parseLinks(text: string): URL[] {
  const links = text.match(/https?:\/\/[^\s<>"']+/gi) ?? [];
  const parsed: URL[] = [];
  for (const link of links) {
    const cleaned = link.replace(/[),.!?;:]+$/, "");
    try {
      parsed.push(new URL(cleaned));
    } catch {
      continue;
    }
  }
  return parsed;
}

function claimedBrands(text: string): Brand[] {
  return brands.filter((brand) => {
    const pattern = new RegExp(`\\b${brand.name}\\b`, "i");
    return pattern.test(text);
  });
}

function classifyUrl(
  url: URL,
  addFinding: (label: string, points: number, category: string) => void,
) {
  const host = normalizeHost(url.hostname);
  const labels = host.split(".");
  if (url.protocol !== "https:") {
    addFinding(
      "Suspicious or unusual URL characteristics",
      1,
      "transport",
    );
  }
  if (host.startsWith("xn--") || host.includes(".xn--")) {
    addFinding("Unusual URL structure", 2, "encoded-domain");
  }
  if (
    shortenerHosts.has(host) ||
    [...shortenerHosts].some((shortener) => host.endsWith(`.${shortener}`))
  ) {
    addFinding(
      "Shortened, hidden, or redirecting link",
      2,
      "shortener",
    );
  }
  if (/^\d{1,3}(?:\.\d{1,3}){3}$/.test(host)) {
    addFinding(
      "Suspicious or unusual URL characteristics",
      2,
      "ip-host",
    );
  }
  if (url.username || url.password) {
    addFinding(
      "Domain or sender claims need independent verification",
      2,
      "embedded-credentials",
    );
  }
  if (url.port && url.port !== "80" && url.port !== "443") {
    addFinding("Unusual URL structure", 1, "unusual-port");
  }
  if (labels.length > 5) {
    addFinding("Unusual URL structure", 1, "deep-subdomain");
  }

  const params = [...url.searchParams.keys()].map((key) => key.toLowerCase());
  const redirectParameters = new Set([
    "continue",
    "dest",
    "destination",
    "next",
    "redirect",
    "redirect_uri",
    "return",
    "returnto",
    "target",
    "to",
    "url",
  ]);
  if (
    params.some((key) => {
      if (!redirectParameters.has(key)) return false;
      const value = url.searchParams.get(key) ?? "";
      return /^(?:https?:\/\/|\/\/)/i.test(value) ||
        /https?%3a%2f%2f/i.test(value);
    })
  ) {
    addFinding(
      "Shortened, hidden, or redirecting link",
      2,
      "redirect-parameter",
    );
  }

  for (const brand of brands) {
    const containsBrand = labels.some((label) =>
      label.split(/[-_]/).includes(brand.name)
    );
    if (containsBrand && !isOfficialDomain(host, brand)) {
      addFinding("Impersonation or brand spoofing", 3, `brand-${brand.name}`);
      break;
    }

    if (isOfficialDomain(host, brand)) continue;
    const hostLabels = labels.flatMap((label) =>
      label.split(/[-_]/).filter((part) => part.length >= 4)
    );
    if (hostLabels.some((label) => editDistanceAtMostOne(label, brand.name))) {
      addFinding("Impersonation or brand spoofing", 3, `lookalike-${brand.name}`);
      break;
    }
  }
}

function asRiskLevel(score: number, categories: Set<string>): RiskLevel {
  if (score >= 6 && categories.size >= 2) return "high";
  if (score >= 3) return "review";
  return "low";
}

export function classifyScamContent(
  type: ScanType,
  input: string,
  ruleConfig: Record<string, { enabled: boolean; weight: number }> = {},
) {
  const text = input.trim();
  const lower = text.toLowerCase();
  const indicators = new Set<string>();
  const categories = new Set<string>();
  let score = 0;

  const addFinding = (label: string, points: number, category: string) => {
    const config = ruleConfig[label];
    if (config?.enabled === false) return;
    indicators.add(label);
    categories.add(category);
    score += config?.weight ?? points;
  };
  const addPattern = (
    label: string,
    pattern: RegExp,
    points: number,
    category: string,
  ) => {
    const match = pattern.exec(lower);
    if (match) addFinding(label, points, category);
  };

  addPattern(
    "Urgent or coercive language",
    /\b(urgent|immediately|act now|within \d+ (?:minutes?|hours?)|final warning|today only|last chance|do not delay|expires soon|within 24 hours|reply now|agaran|agad|ngayon na|kaagad|huling babala|sa loob ng \d+ (?: minuto|minuto|oras)|hanggang ngayon|mawawala na)\b/,
    1,
    "urgency",
  );
  addPattern(
    "Account recovery or identity theft pressure",
    /\b(account[^.!?;\n]{0,35}(?:locked|disabled|suspended|limited|na-lock|na-block|nasuspinde|na-suspend)|(?:na-lock|na-block|na-suspend|na-disable)[^.!?;\n]{0,30}account|(?:verify|update|reactivate|confirm)[^.!?;\n]{0,30}account|i-verify[^.!?;\n]{0,25}account|kumpirmahin[^.!?;\n]{0,25}account|i-update[^.!?;\n]{0,25}account|mawawala[^.!?;\n]{0,25}account)\b/,
    2,
    "account-pressure",
  );

  const hasCredentialRequest = Array.from(
    lower.matchAll(
      new RegExp(credentialRequestPattern.source, credentialRequestPattern.flags),
    ),
  ).some((match) => !isNegatedRequest(lower, match.index ?? 0));
  if (hasCredentialRequest) {
    addFinding(
      "Requests for passwords or security codes",
      4,
      "credential-request",
    );
  }

  addPattern(
    "Payment or account-verification trap",
    /\b(?:pay|send|transfer|wire|cash in|settle|magbayad|bayaran|magpadala|ipadala|i-send|padala|mag-load|loadan)[^.!?;\n]{0,55}\b(?:money|payment|fee|tax|gift card|bitcoin|crypto|gcash|maya|cash app|zelle|venmo|bank|bayad|pera|halaga|load|tubos|delivery|customs|parcel|shipping)\b|\b(?:payment|processing|verification|delivery|customs|shipping|parcel)\s+fee\b|\b(?:bayad|bayaran|singil|tubos)[^.!?;\n]{0,35}\b(?:gcash|maya|load|padala|ngayon|agad|account|parcel|delivery)\b/,
    3,
    "payment-request",
  );
  addPattern(
    "Requests for secrecy or isolation",
    /\b(keep this secret|do not tell|tell no one|do not contact|avoid calling|private only|between us|share with nobody|huwag sabihin|wag sabihin|huwag ipaalam|wag ipaalam|lihim lang|sa atin lang|huwag tawagan|wag tawagan)\b/,
    2,
    "secrecy",
  );
  addPattern(
    "Unexpected prize, reward, or refund",
    /\b(prize|winner|reward|refund|claim your bonus|cashback|free gift|lottery|inheritance|donation payout|nanalo ka|premyo|libreng regalo|raffle winner|cash prize|i-claim|claim mo|pabuya|gantimpala)\b/,
    1,
    "unexpected-benefit",
  );

  const links = type === "url"
    ? (() => {
      try {
        const normalized = text.includes("://") ? text : `https://${text}`;
        return [new URL(normalized)];
      } catch {
        addFinding(
          "Suspicious or unusual URL characteristics",
          1,
          "invalid-url",
        );
        return [];
      }
    })()
    : parseLinks(text);

  for (const link of links) classifyUrl(link, addFinding);

  if (type === "message" && links.length > 0) {
    const claims = claimedBrands(text);
    if (
      claims.some((brand) =>
        links.some((link) => !isOfficialDomain(normalizeHost(link.hostname), brand))
      )
    ) {
      addFinding(
        "Suspicious sender or domain mismatch",
        3,
        "claimed-brand-link-mismatch",
      );
      addFinding("Impersonation or brand spoofing", 1, "brand-link-mismatch");
    }
  }

  if (type === "message") {
    const emails = text.match(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi) ?? [];
    const claims = claimedBrands(text);
    if (
      emails.some((email) => {
        const domain = normalizeHost(email.split("@")[1]);
        return claims.some((brand) => !isOfficialDomain(domain, brand));
      })
    ) {
      addFinding(
        "Suspicious sender or domain mismatch",
        3,
        "sender-domain-mismatch",
      );
    }
  }

  const riskLevel = asRiskLevel(score, categories);
  const indicatorList = Array.from(indicators).slice(0, 10);
  const summary =
    riskLevel === "high"
      ? "Multiple strong scam indicators were detected in this content."
      : riskLevel === "review"
        ? "Some contextual warning signs need independent verification."
        : "No strong scam indicators were found in this content.";
  const guidance =
    riskLevel === "high"
      ? "Do not reply, click, share codes, or send money until you verify through a contact method you already trust."
      : riskLevel === "review"
        ? "Check the sender and request through the official app, website, or phone number you already trust. This check does not resolve or open links."
        : "No strong warning signs were detected. This is not proof that the content or link is safe.";

  return {
    risk_level: riskLevel,
    score,
    categories: [...categories],
    indicators: indicatorList,
    summary,
    guidance,
    rulesVersion: "bantai-rules-1",
  };
}
