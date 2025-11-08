import type { NextFunction, Request, Response } from 'express';

// Basic error handler so we do not leak stack traces in production logs.
export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  console.error('[api] unhandled error', err);
  res.status(500).json({ error: 'Internal server error' });
}
