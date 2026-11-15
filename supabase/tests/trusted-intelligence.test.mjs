import assert from "node:assert/strict";
import test from "node:test";
import {
  hashTrustedContent,
  parseTrustedExampleFeatures,
  redactTrustedContent,
  screenTrustedContent,
} from "../functions/_shared/trusted-intelligence.ts";
import {
  assignDatasetSplit,
  evaluateTrustedDataset,
} from "../functions/_shared/dataset-evaluation.ts";

test("submission redaction removes contact details, secrets, and URL parameters", () => {
  const redacted = redactTrustedContent(
    "OTP 123456 for maria@example.com; call +1 (415) 555-0132 at https://shop.example/login?token=private#code. Name: Maria Santos, account number: 1234567",
  );
  assert.doesNotMatch(
    redacted,
    /123456|maria@example\.com|555-0132|token=private|#code|Maria Santos|1234567/i,
  );
  assert.match(redacted, /shop\.example\/login/);
});

test("screening a submitted example returns only bounded rule features", () => {
  const result = screenTrustedContent(
    "message",
    "Urgent: verify your account and send your one-time code.",
  );
  assert.ok(["low", "review", "high"].includes(result.risk_level));
  assert.ok(result.categories.length <= 12);
  assert.ok(result.indicators.length <= 12);
});

test("trusted feature loading accepts only released training examples", () => {
  const rows = [
    {
      content_hash: "a".repeat(64),
      verified_label: "verified_scam",
      features: { categories: ["urgency", "payment"], split: "train" },
    },
    {
      content_hash: "b".repeat(64),
      verified_label: "verified_scam",
      features: { categories: ["urgency", "payment"], split: "test" },
    },
  ];
  assert.deepEqual(parseTrustedExampleFeatures(rows), [{
    label: "verified_scam",
    categories: ["urgency", "payment"],
  }]);
});

test("dataset evaluation fails closed when evidence is too small", () => {
  const result = evaluateTrustedDataset([]);
  assert.equal(result.passed, false);
  assert.equal(result.metrics.train_count, 0);
  assert.match(result.reason, /too small|did not meet/i);
});

test("dataset evaluation uses a deterministic held-out set and release gates", async () => {
  const hashFor = (split, index) => {
    const prefix = split === "test"
      ? (index + 1) * 5
      : (index + 1) * 5 + 1;
    return prefix.toString(16).padStart(8, "0") + "0".repeat(56);
  };
  assert.equal(assignDatasetSplit(hashFor("test", 0)), "test");
  assert.equal(assignDatasetSplit(hashFor("train", 0)), "train");

  const examples = [];
  for (let index = 0; index < 25; index++) {
    examples.push({
      content_hash: hashFor("train", index),
      verified_label: "verified_scam",
      categories: ["urgency", "payment"],
    });
    examples.push({
      content_hash: hashFor("train", index + 100),
      verified_label: "verified_legitimate",
      categories: ["greeting", "routine"],
    });
  }
  for (let index = 0; index < 5; index++) {
    examples.push({
      content_hash: hashFor("test", index + 200),
      verified_label: "verified_scam",
      categories: ["urgency", "payment"],
    });
    examples.push({
      content_hash: hashFor("test", index + 300),
      verified_label: "verified_legitimate",
      categories: ["greeting", "routine"],
    });
  }
  const result = evaluateTrustedDataset(examples);
  assert.equal(result.passed, true);
  assert.equal(result.metrics.accuracy, 1);
  assert.equal(result.metrics.test_count, 10);
  assert.equal(
    evaluateTrustedDataset(
      examples.filter((example) =>
        example.verified_label === "verified_scam"
      ),
    ).passed,
    false,
  );
  assert.equal(
    await hashTrustedContent("  Safe   example "),
    await hashTrustedContent("safe example"),
  );
});
