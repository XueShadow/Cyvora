export default async ({ req, res, log }) => {
  if (req.method !== 'POST') {
    return res.json({ ok: false, error: 'METHOD_NOT_ALLOWED' }, 405);
  }

  const userId = req.headers?.['x-appwrite-user-id'];
  if (!userId) {
    return res.json({ ok: false, error: 'AUTHENTICATION_REQUIRED' }, 401);
  }

  let body;
  try {
    body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  } catch {
    return res.json({ ok: false, error: 'INVALID_REQUEST' }, 400);
  }

  if (!['create','revoke','accept'].includes(body?.action)) {
    return res.json({ ok: false, error: 'INVALID_ACTION' }, 400);
  }

  log(`Family invitation action ${body.action} requested by ${userId}`);
  return res.json({
    ok: false,
    error: 'MIGRATION_PENDING',
    message: 'Appwrite family tables and server permissions are required.',
  }, 503);
};
