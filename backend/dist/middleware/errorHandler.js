// Basic error handler so we do not leak stack traces in production logs.
export function errorHandler(err, _req, res, _next) {
    console.error('[api] unhandled error', err);
    res.status(500).json({ error: 'Internal server error' });
}
