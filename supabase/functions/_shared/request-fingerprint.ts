const encoder = new TextEncoder();

export async function createRequestFingerprint(
  keyMaterial: string,
  userId: string,
  operation: string,
  payload: unknown,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(keyMaterial),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signed = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(JSON.stringify({ userId, operation, payload })),
  );
  return Array.from(new Uint8Array(signed), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}
