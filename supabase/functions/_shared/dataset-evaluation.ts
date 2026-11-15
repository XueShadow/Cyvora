export type EvaluationExample = {
  content_hash: string;
  verified_label: "verified_scam" | "verified_legitimate";
  categories: string[];
};

export type DatasetEvaluation = {
  algorithm: "trusted-category-similarity-v1";
  passed: boolean;
  metrics: {
    accuracy: number;
    precision: number;
    recall: number;
    f1: number;
    false_positive_rate: number;
    train_count: number;
    test_count: number;
    true_positive: number;
    true_negative: number;
    false_positive: number;
    false_negative: number;
    training_scam_count: number;
    training_legitimate_count: number;
    test_scam_count: number;
    test_legitimate_count: number;
  };
  requirements: {
    minimum_train_examples: number;
    minimum_test_examples: number;
    minimum_training_examples_per_label: number;
    minimum_test_examples_per_label: number;
    minimum_accuracy: number;
    minimum_precision: number;
    minimum_recall: number;
    maximum_false_positive_rate: number;
  };
  reason: string;
};

const requirements = {
  minimum_train_examples: 20,
  minimum_test_examples: 5,
  minimum_training_examples_per_label: 5,
  minimum_test_examples_per_label: 2,
  minimum_accuracy: 0.8,
  minimum_precision: 0.8,
  minimum_recall: 0.7,
  maximum_false_positive_rate: 0.1,
} as const;

export function assignDatasetSplit(contentHash: string): "train" | "test" {
  const prefix = Number.parseInt(contentHash.slice(0, 8), 16);
  return Number.isFinite(prefix) && prefix % 5 === 0 ? "test" : "train";
}

export function evaluateTrustedDataset(
  examples: EvaluationExample[],
): DatasetEvaluation {
  const byHash = new Map<string, EvaluationExample>();
  for (const example of examples) {
    if (
      !/^[0-9a-f]{64}$/.test(example.content_hash) ||
      (example.verified_label !== "verified_scam" &&
        example.verified_label !== "verified_legitimate") ||
      !Array.isArray(example.categories) ||
      example.categories.length > 20 ||
      example.categories.some((category) =>
        typeof category !== "string" || category.length > 80
      )
    ) continue;
    byHash.set(example.content_hash, {
      ...example,
      categories: [...new Set(example.categories)],
    });
  }
  const cleanExamples = [...byHash.values()];
  const training = cleanExamples.filter((example) =>
    assignDatasetSplit(example.content_hash) === "train"
  );
  const testing = cleanExamples.filter((example) =>
    assignDatasetSplit(example.content_hash) === "test"
  );

  let truePositive = 0;
  let trueNegative = 0;
  let falsePositive = 0;
  let falseNegative = 0;
  for (const example of testing) {
    const prediction = predictFromTrustedExamples(example, training);
    const actualScam = example.verified_label === "verified_scam";
    if (prediction && actualScam) truePositive++;
    else if (!prediction && !actualScam) trueNegative++;
    else if (prediction) falsePositive++;
    else falseNegative++;
  }

  const total = testing.length;
  const accuracy = total === 0 ? 0 : (truePositive + trueNegative) / total;
  const precision = truePositive + falsePositive === 0
    ? 0
    : truePositive / (truePositive + falsePositive);
  const recall = truePositive + falseNegative === 0
    ? 0
    : truePositive / (truePositive + falseNegative);
  const f1 = precision + recall === 0
    ? 0
    : (2 * precision * recall) / (precision + recall);
  const falsePositiveRate = falsePositive + trueNegative === 0
    ? 0
    : falsePositive / (falsePositive + trueNegative);
  const metrics = {
    accuracy: round(accuracy),
    precision: round(precision),
    recall: round(recall),
    f1: round(f1),
    false_positive_rate: round(falsePositiveRate),
    train_count: training.length,
    test_count: total,
    true_positive: truePositive,
    true_negative: trueNegative,
    false_positive: falsePositive,
    false_negative: falseNegative,
    training_scam_count: training.filter((example) =>
      example.verified_label === "verified_scam"
    ).length,
    training_legitimate_count: training.filter((example) =>
      example.verified_label === "verified_legitimate"
    ).length,
    test_scam_count: testing.filter((example) =>
      example.verified_label === "verified_scam"
    ).length,
    test_legitimate_count: testing.filter((example) =>
      example.verified_label === "verified_legitimate"
    ).length,
  };
  const passed = training.length >= requirements.minimum_train_examples &&
    total >= requirements.minimum_test_examples &&
    metrics.training_scam_count >=
      requirements.minimum_training_examples_per_label &&
    metrics.training_legitimate_count >=
      requirements.minimum_training_examples_per_label &&
    metrics.test_scam_count >= requirements.minimum_test_examples_per_label &&
    metrics.test_legitimate_count >=
      requirements.minimum_test_examples_per_label &&
    accuracy >= requirements.minimum_accuracy &&
    precision >= requirements.minimum_precision &&
    recall >= requirements.minimum_recall &&
    falsePositiveRate <= requirements.maximum_false_positive_rate;
  return {
    algorithm: "trusted-category-similarity-v1",
    passed,
    metrics,
    requirements,
    reason: passed
      ? "The held-out evaluation met every release threshold."
      : "The dataset is too small or the held-out results did not meet every release threshold.",
  };
}

function predictFromTrustedExamples(
  example: EvaluationExample,
  training: EvaluationExample[],
): boolean {
  const categories = new Set(example.categories);
  if (categories.size < 2) return false;
  let scamMatches = 0;
  let legitimateMatches = 0;
  for (const trusted of training) {
    const trustedCategories = new Set(trusted.categories);
    if (trustedCategories.size < 2) continue;
    const overlap = [...categories].filter((category) =>
      trustedCategories.has(category)
    ).length;
    const similarity = overlap /
      (categories.size + trustedCategories.size - overlap);
    if (overlap < 2 || similarity < 0.6) continue;
    if (trusted.verified_label === "verified_scam") scamMatches++;
    else legitimateMatches++;
  }
  return scamMatches >= 2 && scamMatches > legitimateMatches;
}

function round(value: number): number {
  return Math.round(value * 10000) / 10000;
}
