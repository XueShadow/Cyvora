import assert from "node:assert/strict";
import test from "node:test";
import { classifyScamContent } from "../functions/scam-intelligence/scam-patterns.ts";

test("a routine bank verification notice is not flagged by the word alone", () => {
  const result = classifyScamContent(
    "message",
    "Please verify your balance in the BPI mobile app.",
  );

  assert.equal(result.risk_level, "low");
  assert.deepEqual(result.indicators, []);
});

test("a legitimate anti-phishing warning is not treated as a credential request", () => {
  const result = classifyScamContent(
    "message",
    "BPI will never ask you to share your OTP. Never send your password.",
  );

  assert.equal(result.risk_level, "low");
  assert.equal(
    result.indicators.includes("Requests for passwords or security codes"),
    false,
  );
});

test("a later credential request is not hidden by an earlier warning", () => {
  const result = classifyScamContent(
    "message",
    "Never share your OTP. Reply with your OTP to reactivate the account.",
  );

  assert.ok(result.indicators.includes("Requests for passwords or security codes"));
});

test("contextual Taglish account, OTP, urgency, and payment cues score high", () => {
  const result = classifyScamContent(
    "message",
    "URGENT! Na-lock ang account mo. Ipadala ang OTP ngayon at magbayad ng fee sa GCash para ma-reactivate: https://bpi-secure-login.example.com",
  );

  assert.equal(result.risk_level, "high");
  assert.ok(result.indicators.includes("Requests for passwords or security codes"));
  assert.ok(result.indicators.includes("Payment or account-verification trap"));
});

test("a trusted brand URL with a verification path is not by itself suspicious", () => {
  const result = classifyScamContent("url", "https://www.bpi.com.ph/verify");

  assert.equal(result.risk_level, "low");
  assert.deepEqual(result.indicators, []);
});

test("brand lookalike domains are identified without opening them", () => {
  const result = classifyScamContent("url", "https://paypa1-login.example");

  assert.ok(result.indicators.includes("Impersonation or brand spoofing"));
});

test("a brand name inside an unrelated larger domain is not enough to flag it", () => {
  const result = classifyScamContent("url", "https://notgoogle.example");

  assert.equal(
    result.indicators.includes("Impersonation or brand spoofing"),
    false,
  );
});

test("static redirect parameters are identified without resolving their target", () => {
  const result = classifyScamContent(
    "url",
    "https://example.com/continue?redirect=https%3A%2F%2Fother.example",
  );

  assert.ok(result.indicators.includes("Shortened, hidden, or redirecting link"));
});

test("a relative continuation on a known login page is not called a redirect chain", () => {
  const result = classifyScamContent(
    "url",
    "https://accounts.google.com/login?continue=%2Fhome",
  );

  assert.equal(
    result.indicators.includes("Shortened, hidden, or redirecting link"),
    false,
  );
});

test("a claimed brand and an unrelated sender domain produce a mismatch warning", () => {
  const result = classifyScamContent(
    "message",
    "BPI alert: verify your account. From: security@bpi-login.example",
  );

  assert.ok(result.indicators.includes("Suspicious sender or domain mismatch"));
});

test("an urgent but otherwise ordinary message stays low risk", () => {
  const result = classifyScamContent(
    "message",
    "Urgent, please call me when you arrive.",
  );

  assert.equal(result.risk_level, "low");
});
