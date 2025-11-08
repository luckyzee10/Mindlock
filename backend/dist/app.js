import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import { config } from './lib/config.js';
import { purchasesRouter } from './routes/purchases.js';
import { reportsRouter } from './routes/reports.js';
import { healthRouter } from './routes/health.js';
import { debugRouter } from './routes/debug.js';
import { enforceHttps } from './middleware/auth.js';
import { errorHandler } from './middleware/errorHandler.js';
const app = express();
// Rate limiters and IP-based middleware require a non-permissive trust proxy.
// Render sits behind a single reverse proxy, so trust the first hop only.
app.set('trust proxy', 1);
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({
    origin: '*'
}));
app.use(morgan(config.nodeEnv === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '2mb' }));
app.use(enforceHttps);
app.use((_, res, next) => {
    res.setHeader('Cache-Control', 'no-store');
    next();
});
app.use('/v1/purchases', purchasesRouter);
app.use('/v1/reports', reportsRouter);
app.use(debugRouter);
app.use(healthRouter);
app.use(errorHandler);
if (process.env.NODE_ENV !== 'test') {
    app.listen(config.port, () => {
        console.log(`[api] listening on ${config.port} (${config.nodeEnv})`);
    });
}
export { app };
