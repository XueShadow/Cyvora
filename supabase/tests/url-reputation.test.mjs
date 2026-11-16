import assert from "node:assert/strict";
import test from "node:test";
import {
  analyzeUrlReputation,
  isPublicReputationTarget,
} from "../functions/_shared/url-reputation.ts";

const apiKeys = {
  URLHAUS_AUTH_KEY: "urlhaus-key",
  GOOGLE_SAFE_BROWSING_API_KEY: "google-key",
  OTX_API_KEY: "otx-key",
  PHISHTANK_API_KEY: "phishtank-key",
  URLSCAN_API_KEY: "urlscan-key",
  THREATFOX_AUTH_KEY: "threatfox-key",
  VIRUSTOTAL_API_KEY: "virustotal-key",
  PULSEDIVE_API_KEY: "pulsedive-key",
};

function environment(values = apiKeys) {
  return { get: (name) => values[name] };
}

test("URL reputation checks aggregate all configured sources in fixed order", async () => {
  const submittedUrl = "https://Example.com/login?token=private#client-fragment";
  const normalizedUrl = "https://example.com/login?token=private";
  const calls = [];
  const report = await analyzeUrlReputation(
    submittedUrl,
    environment(),
    async (input, init = {}) => {
      const requestUrl = String(input);
      calls.push({ requestUrl, init });
      if (requestUrl === "https://openphish.com/feed.txt") {
        return new Response(`${normalizedUrl}\n`, { status: 200 });
      }
      if (requestUrl === "https://urlhaus-api.abuse.ch/v1/url/") {
        assert.equal(new URLSearchParams(init.body).get("url"), normalizedUrl);
        assert.equal(init.headers["Auth-Key"], apiKeys.URLHAUS_AUTH_KEY);
        assert.equal(
          init.headers["Content-Type"],
          "application/x-www-form-urlencoded",
        );
        return Response.json({ query_status: "ok" });
      }
      if (requestUrl.startsWith("https://safebrowsing.googleapis.com/")) {
        const body = JSON.parse(init.body);
        assert.equal(
          body.threatInfo.threatEntries[0].url,
          normalizedUrl,
        );
        assert.equal(new URL(requestUrl).searchParams.get("key"), "google-key");
        return Response.json({
          matches: [{ threatType: "SOCIAL_ENGINEERING" }],
        });
      }
      if (requestUrl.includes("otx.alienvault.com")) {
        assert.equal(init.headers["X-OTX-API-KEY"], apiKeys.OTX_API_KEY);
        return Response.json({ pulse_info: { count: 0 } });
      }
      if (requestUrl === "https://checkurl.phishtank.com/checkurl/") {
        const body = new URLSearchParams(init.body);
        assert.equal(
          init.headers["Content-Type"],
          "application/x-www-form-urlencoded",
        );
        assert.equal(body.get("url"), normalizedUrl);
        assert.equal(body.get("app_key"), apiKeys.PHISHTANK_API_KEY);
        return Response.json({
          results: { in_database: true, verified: "y", valid: "y" },
        });
      }
      if (requestUrl === "https://urlscan.io/api/v1/scan/") {
        const body = JSON.parse(init.body);
        assert.equal(body.url, normalizedUrl);
        assert.equal(body.visibility, "private");
        assert.equal(init.headers["API-Key"], apiKeys.URLSCAN_API_KEY);
        return Response.json({
          visibility: "private",
          task: { uuid: "12345678-1234-4234-9234-123456789abc" },
        });
      }
      if (requestUrl === "https://threatfox-api.abuse.ch/api/v1/") {
        assert.deepEqual(JSON.parse(init.body), {
          query: "search_ioc",
          search_term: normalizedUrl,
        });
        assert.equal(init.headers["Auth-Key"], apiKeys.THREATFOX_AUTH_KEY);
        return Response.json({ query_status: "no_result" });
      }
      if (requestUrl.includes("www.virustotal.com/api/v3/urls/")) {
        assert.equal(init.headers["x-apikey"], apiKeys.VIRUSTOTAL_API_KEY);
        return Response.json({
          data: {
            attributes: {
              last_analysis_stats: {
                malicious: 0,
                suspicious: 0,
              },
            },
          },
        });
      }
      if (requestUrl.startsWith("https://pulsedive.com/api/indicator.php")) {
        const endpoint = new URL(requestUrl);
        assert.equal(endpoint.searchParams.get("indicator"), normalizedUrl);
        assert.equal(endpoint.searchParams.get("key"), apiKeys.PULSEDIVE_API_KEY);
        return Response.json({
          risk: "medium",
          risk_recommended: "high",
        });
      }
      assert.fail(`Unexpected provider endpoint: ${requestUrl}`);
    },
  );

  assert.equal(report.status, "partial");
  assert.deepEqual(report.providers.map((item) => item.provider), [
    "urlhaus",
    "google_safe_browsing",
    "alienvault_otx",
    "openphish",
    "phishtank",
    "urlscan",
    "threatfox",
    "virustotal",
    "pulsedive",
  ]);
  assert.deepEqual(
    report.providers.filter((item) => item.status === "match").map((item) =>
      item.provider
    ),
    [
      "urlhaus",
      "google_safe_browsing",
      "openphish",
      "phishtank",
      "pulsedive",
    ],
  );
  assert.equal(report.providers[5].status, "submitted");
  assert.equal(report.providers[5].scan_id, "12345678-1234-4234-9234-123456789abc");
  assert.ok(report.providers.every((provider) =>
    Number.isSafeInteger(provider.duration_ms) && provider.duration_ms >= 0
  ));
  assert.equal(calls.length, 9);
  assert.equal(JSON.stringify(report).includes("token=private"), false);
  assert.equal(JSON.stringify(report).includes("client-fragment"), false);
});

test("Pulsedive low-confidence data is not treated as a confirmed match", async () => {
  const report = await analyzeUrlReputation(
    "https://another.example/path",
    environment({ PULSEDIVE_API_KEY: "pulsedive-key" }),
    async (input) => {
      assert.ok(String(input).startsWith(
        "https://pulsedive.com/api/indicator.php?",
      ));
      return Response.json({ risk_recommended: "medium" });
    },
  );
  assert.equal(report.providers.at(-1)?.status, "unverified");
  assert.match(report.providers.at(-1)?.findings[0] ?? "", /medium/i);
});

test("Pulsedive 404 responses are reported as not found", async () => {
  const report = await analyzeUrlReputation(
    "https://another.example/not-found",
    environment({ PULSEDIVE_API_KEY: "pulsedive-key" }),
    async () => new Response("not found", { status: 404 }),
  );
  assert.equal(report.providers.at(-1)?.status, "not_found");
});

test("providers without keys are skipped while the OpenPhish feed is checked locally", async () => {
  let fetchCalls = 0;
  const report = await analyzeUrlReputation(
    "https://another.example/path",
    environment({}),
    async () => {
      fetchCalls++;
      return Response.json({ query_status: "no_results" });
    },
  );

  assert.equal(fetchCalls, 0);
  assert.equal(report.status, "available");
  assert.deepEqual(
    report.providers.filter((item) => item.status !== "not_configured").map((
      item,
    ) => item.provider),
    ["openphish"],
  );
  assert.equal(report.providers[3].status, "no_match");
});

test("rate limits are reported per provider without failing other checks", async () => {
  const report = await analyzeUrlReputation(
    "https://another.example/rate-limited",
    environment({ GOOGLE_SAFE_BROWSING_API_KEY: "google-key" }),
    async (input) => {
      if (String(input).startsWith("https://safebrowsing.googleapis.com/")) {
        return new Response("rate limited", { status: 429 });
      }
      return new Response("temporary error", { status: 503 });
    },
  );

  assert.equal(report.providers[1].status, "rate_limited");
  assert.equal(report.providers[3].status, "no_match");
  assert.equal(report.status, "partial");
});

test("private, reserved, and local destinations are never eligible for external checks", () => {
  for (const url of [
    "http://localhost/",
    "http://printer.local/",
    "https://service.internal/",
    "https://example.test/",
    "https://192.168.1.1/",
    "https://[::1]/",
    "https://198.51.100.10/",
  ]) {  
    assert.equal(isPublicReputationTarget(url), false, url);
  }
  assert.equal(isPublicReputationTarget("https://example.com/"), true);
});
