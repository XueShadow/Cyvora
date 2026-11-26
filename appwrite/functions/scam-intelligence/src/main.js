export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.json({ ok: false, error: 'METHOD_NOT_ALLOWED' }, 405);
  }

  const headers = req.headers || {};
  if (!headers['x-appwrite-user-id'] && !headers['x-appwrite-user-jwt']) {
    return res.json({ ok: false, error: 'AUTHENTICATION_REQUIRED' }, 401);
  }

  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  } catch {
    return res.json({ ok: false, error: 'INVALID_REQUEST' }, 400);
  }

  const action = body?.action;
  if (!['analyze','trusted_submit','trusted_review','trusted_release','delete_account'].includes(action)) {
    return res.json({ ok: false, error: 'INVALID_ACTION' }, 400);
  }

  if (action === 'delete_account') {
    return res.json({ ok: false, error: 'NOT_CONFIGURED' }, 501);
  }

  if (!body?.payload || typeof body.payload !== 'object') {
    return res.json({ ok: false, error: 'INVALID_PAYLOAD' }, 400);
  }

  log(`Scam intelligence action: ${action}`);
  return res.json({
    ok: false,
    error: 'MIGRATION_PENDING',
    message: 'Appwrite resource and provider configuration required.',
  }, 503);
};
