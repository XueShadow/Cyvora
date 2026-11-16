import assert from "node:assert/strict";
import test from "node:test";
import { classifyScamContent } from "../functions/scam-intelligence/scam-patterns.ts";

const labeledExamples = [
  {
    label: "legitimate",
    type: "message",
    content: "Please verify your balance in the BPI mobile app.",
  },
  {
    label: "legitimate",
    type: "message",
    content: "BPI will never ask you to share your OTP. Never send your password.",
  },
  {
    label: "legitimate",
    type: "message",
    content: "Your parcel is out for delivery. Track it in the courier app.",
  },
  {
    label: "legitimate",
    type: "message",
    content: "We are hiring a cashier. Apply through our company website.",
  },
  {
    label: "legitimate",
    type: "message",
    content: "Your electricity bill is due next week. Pay in the utility's official app.",
  },
  {
    label: "legitimate",
    type: "message",
    content: "Urgent, please call me when you arrive.",
  },
  {
    label: "legitimate",
    type: "url",
    content: "https://www.bpi.com.ph/verify",
  },
  {
    label: "scam",
    type: "message",
    content: "URGENT! Your BPI account is locked. Reply with your OTP now to reactivate: https://bpi-secure-login.example.com",
  },
  {
    label: "scam",
    type: "message",
    content: "Huling babala! Nasuspinde ang account mo. Ipadala ang iyong PIN upang maibalik ang access at magbayad ng fee sa GCash ngayon.",
  },
  {
    label: "scam",
    type: "message",
    content: "Your package is held at customs. Pay the customs fee now to release it: http://parcel-pay.example/track",
  },
  {
    label: "scam",
    type: "message",
    content: "You won a prize! Pay a processing fee to claim your reward.",
  },
  {
    label: "scam",
    type: "message",
    content: "Guaranteed 40% returns. Transfer bitcoin today to secure your investment.",
  },
  {
    label: "scam",
    type: "message",
    content: "Congratulations, you are selected for remote work. Pay a registration fee to receive your salary.",
  },
  {
    label: "scam",
    type: "url",
    content: "https://paypa1-login.example",
  },
];

test("synthetic labeled examples maintain baseline scam-classification metrics", (t) => {
  let truePositive = 0;
  let falsePositive = 0;
  let trueNegative = 0;
  let falseNegative = 0;

  for (const example of labeledExamples) {
    const flagged = classifyScamContent(example.type, example.content)
      .risk_level !== "low";
    if (example.label === "scam" && flagged) truePositive++;
    else if (example.label === "scam") falseNegative++;
    else if (flagged) falsePositive++;
    else trueNegative++;
  }

  const precision = truePositive / (truePositive + falsePositive);
  const recall = truePositive / (truePositive + falseNegative);
  const falsePositiveRate = falsePositive / (falsePositive + trueNegative);
  const falseNegativeRate = falseNegative / (falseNegative + truePositive);
  const accuracy = (truePositive + trueNegative) / labeledExamples.length;
  const metrics = {
    examples: labeledExamples.length,
    truePositive,
    falsePositive,
    trueNegative,
    falseNegative,
    precision,
    recall,
    falsePositiveRate,
    falseNegativeRate,
    accuracy,
  };
  t.diagnostic(JSON.stringify(metrics));

  assert.ok(precision >= 0.8, `precision=${precision}`);
  assert.ok(recall >= 0.8, `recall=${recall}`);
  assert.ok(falsePositiveRate <= 0.1, `falsePositiveRate=${falsePositiveRate}`);
  assert.ok(accuracy >= 0.8, `accuracy=${accuracy}`);
});
