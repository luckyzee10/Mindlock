import type { NextFunction, Request, Response } from 'express';
import rateLimit from 'express-rate-limit';
import { config } from '../lib/config.js';

function unauthorized(res: Response, message = 'Unauthorized') {
  return res.status(401).json({ error: message });
}

export function requireAppKey(req: Request, res: Response, next: NextFunction) {
  const header = req.get('x-app-key');
  if (header !== config.appApiKey) {
    return unauthorized(res);
  }
  return next();
}

export function requireAdminKey(req: Request, res: Response, next: NextFunction) {
  const header = req.get('x-admin-key');
  if (header !== config.adminApiKey) {
    return unauthorized(res);
  }
  return next();
}

export function enforceHttps(req: Request, res: Response, next: NextFunction) {
  if (config.nodeEnv === 'production') {
    const proto = req.get('x-forwarded-proto');
    if (proto && proto !== 'https') {
      return res.status(400).json({ error: 'HTTPS required' });
    }
  }
  return next();
}

export const purchasesRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 60,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: 'Too many purchase attempts, slow down.' }
});
