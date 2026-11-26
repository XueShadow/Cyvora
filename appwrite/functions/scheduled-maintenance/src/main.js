export default async ({ req, res, log }) => {
  if (req.method !== 'POST') {
    return res.json({ ok: false, error: 'METHOD_NOT_ALLOWED' }, 405);
  }

  log('Scheduled maintenance invoked');
  return res.json({
    ok: true,
    deleted: {
      expiredScanHistory: 0,
      expiredNotificationMetadata: 0,
      expiredCacheRows: 0,
    },
  });
};
