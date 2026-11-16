export type LimitedBodyResult = { text: string } | { tooLarge: true };

export async function readLimitedBody(
  request: Request,
  maxBytes: number,
): Promise<LimitedBodyResult> {
  const contentLength = request.headers.get("Content-Length");
  if (
    contentLength &&
    /^\d+$/.test(contentLength) &&
    Number(contentLength) > maxBytes
  ) return { tooLarge: true };

  const reader = request.body?.getReader();
  if (!reader) return { text: "" };
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel();
        return { tooLarge: true };
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return { text: new TextDecoder().decode(bytes) };
}

export type JsonObjectBodyResult =
  | { ok: true; value: Record<string, unknown> }
  | { ok: false; status: 400 | 413; error: string };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export async function readJsonObjectBody(
  request: Request,
  maxBytes: number,
): Promise<JsonObjectBodyResult> {
  const boundedBody = await readLimitedBody(request, maxBytes);
  if ("tooLarge" in boundedBody) {
    return {
      ok: false,
      status: 413,
      error: "Request body is too large.",
    };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(boundedBody.text);
  } catch {
    return {
      ok: false,
      status: 400,
      error: "Request body must be valid JSON.",
    };
  }
  if (!isRecord(parsed)) {
    return {
      ok: false,
      status: 400,
      error: "Request body must be a JSON object.",
    };
  }
  return { ok: true, value: parsed };
}
