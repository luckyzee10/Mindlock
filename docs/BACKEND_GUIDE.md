# MindLock Backend Development Guide 🔧

## Overview

Complete guide for building the Node.js backend API with PostgreSQL database, Apple IAP validation, and charity donation tracking.

---

## Project Setup

### 1. Initialize Node.js Project

```bash
mkdir mindlock-backend
cd mindlock-backend
npm init -y

# Install core dependencies
npm install express cors helmet morgan winston dotenv
npm install pg @prisma/client prisma
npm install firebase-admin
npm install joi bcrypt jsonwebtoken

# Install dev dependencies
npm install -D nodemon jest supertest eslint prettier
```

### 2. Project Structure Setup

```bash
mkdir -p src/{routes,controllers,services,middleware,models,utils,config}
mkdir -p tests prisma
touch src/app.js src/server.js
touch .env .env.example
touch .gitignore README.md
```

### 3. Environment Configuration

#### .env.example
```bash
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/mindlock"

# Firebase
FIREBASE_PROJECT_ID="your-project-id"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk@your-project.iam.gserviceaccount.com"

# Apple
APPLE_SHARED_SECRET="your_shared_secret_from_app_store_connect"
APPLE_TEAM_ID="your_apple_team_id"

# JWT
JWT_SECRET="your-super-secret-jwt-key"
JWT_EXPIRES_IN="7d"

# App Configuration
NODE_ENV="development"
PORT=3000
CORS_ORIGIN="http://localhost:3000"

# Admin
ADMIN_EMAIL="admin@mindlock.com"
```

---

## Database Setup

### 1. Prisma Schema

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id                String    @id @default(cuid())
  firebaseUid       String    @unique
  email             String    @unique
  displayName       String?
  selectedCharityId String?
  isActive          Boolean   @default(true)
  isAnonymous       Boolean   @default(false)
  createdAt         DateTime  @default(now())
  updatedAt         DateTime  @updatedAt
  
  selectedCharity   Charity?  @relation(fields: [selectedCharityId], references: [id])
  purchases         Purchase[]
  
  @@map("users")
}

model Charity {
  id          String    @id @default(cuid())
  name        String    @unique
  description String
  website     String?
  logoUrl     String?
  category    String?
  isActive    Boolean   @default(true)
  isVerified  Boolean   @default(false)
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  
  users           User[]
  purchases       Purchase[]
  monthlyReports  MonthlyReport[]
  
  @@map("charities")
}

model Purchase {
  id                     String    @id @default(cuid())
  userId                 String
  charityId              String
  productId              String
  amountCents            Int       // Total amount paid in cents
  appleFeesCents         Int       // Apple's 30% cut
  netRevenueCents        Int       // Amount after Apple fees
  charityDonationCents   Int       // 15% of net revenue reserved for the selected charity
  platformRevenueCents   Int       // Remaining 85% of net revenue to platform operations
  appleTransactionId     String    @unique
  appleReceiptData       String?
  isValidated            Boolean   @default(false)
  unlockDurationMinutes  Int       // Duration of unlock in minutes
  createdAt              DateTime  @default(now())
  processedAt            DateTime?
  
  user    User    @relation(fields: [userId], references: [id])
  charity Charity @relation(fields: [charityId], references: [id])
  
  @@map("purchases")
}

model MonthlyReport {
  id               String    @id @default(cuid())
  month            Int       // 1-12
  year             Int
  charityId        String
  totalAmountCents Int       // Total donations for this charity/month
  transactionCount Int       // Number of purchases
  status           String    @default("pending") // pending, generated, exported, paid
  generatedAt      DateTime  @default(now())
  exportedAt       DateTime?
  paidAt           DateTime?
  csvFilePath      String?
  
  charity Charity @relation(fields: [charityId], references: [id])
  
  @@unique([month, year, charityId])
  @@map("monthly_reports")
}

model AppConfig {
  id          String    @id @default(cuid())
  key         String    @unique
  value       String
  description String?
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  
  @@map("app_config")
}

model AdminUser {
  id          String    @id @default(cuid())
  email       String    @unique
  passwordHash String
  role        String    @default("admin") // admin, super_admin
  isActive    Boolean   @default(true)
  lastLoginAt DateTime?
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  
  @@map("admin_users")
}
```

### 3. Donation Reserve Workflow

1. **Receipt validation:** When the iOS app confirms an in-app purchase, send the Apple receipt to the backend. The `/payments/verify` endpoint validates the receipt, records the `Purchase`, and calculates:
   - `appleFeesCents` = round(gross × 30%)
   - `netRevenueCents` = gross − Apple fees
   - `charityDonationCents` = round(net × 15%)
   - `platformRevenueCents` = net − donation reserve
2. **Monthly roll-up:** Each validated purchase increments the active `MonthlyReport` for the user’s selected charity (`totalAmountCents += charityDonationCents`, `transactionCount += 1`). Reports are unique per month/year/charity.
3. **Payout prep:** At month end, mark the previous month’s reports as `generated`, export a CSV, and hand off to finance so 15% of net revenue flows to each charity exactly as recorded.
4. **Audit trail:** Keep related `Purchase` rows for reconciliation. If a refund occurs, mark the purchase and subtract its donation amount from the corresponding monthly report.

This flow means the database already knows how much must be donated—just sum `totalAmountCents` for the month when you run payouts.

### 2. Database Initialization

```bash
# Initialize Prisma
npx prisma init

# Generate and run migrations
npx prisma migrate dev --name init

# Generate Prisma client
npx prisma generate

# Seed initial data
npx prisma db seed
```

### 3. Database Seeding

```javascript
// prisma/seed.js
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();

async function main() {
  // Seed charities
  const charities = [
    {
      name: "American Red Cross",
      description: "Disaster relief and emergency assistance",
      website: "https://www.redcross.org",
      category: "disaster_relief",
      isVerified: true
    },
    {
      name: "Doctors Without Borders",
      description: "Medical humanitarian aid worldwide",
      website: "https://www.doctorswithoutborders.org",
      category: "healthcare",
      isVerified: true
    },
    {
      name: "World Wildlife Fund",
      description: "Conservation and environmental protection",
      website: "https://www.worldwildlife.org",
      category: "environment",
      isVerified: true
    },
    {
      name: "Feeding America",
      description: "Fighting hunger in the United States",
      website: "https://www.feedingamerica.org",
      category: "hunger",
      isVerified: true
    }
  ];

  for (const charity of charities) {
    await prisma.charity.upsert({
      where: { name: charity.name },
      update: {},
      create: charity
    });
  }

  // Seed admin user
  const adminPassword = await bcrypt.hash('admin123', 10);
  await prisma.adminUser.upsert({
    where: { email: 'admin@mindlock.com' },
    update: {},
    create: {
      email: 'admin@mindlock.com',
      passwordHash: adminPassword,
      role: 'super_admin'
    }
  });

  // Seed app config
  const appConfigs = [
    { key: 'apple_shared_secret', value: process.env.APPLE_SHARED_SECRET || '', description: 'Apple shared secret for receipt validation' },
    { key: 'charity_percentage', value: '10', description: 'Percentage of net revenue donated to charity' },
    { key: 'min_unlock_minutes', value: '15', description: 'Minimum unlock duration in minutes' },
    { key: 'max_unlock_minutes', value: '240', description: 'Maximum unlock duration in minutes' }
  ];

  for (const config of appConfigs) {
    await prisma.appConfig.upsert({
      where: { key: config.key },
      update: {},
      create: config
    });
  }

  console.log('Database seeded successfully');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

---

## Express App Setup

### 1. Main App Configuration

```javascript
// src/app.js
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const authRoutes = require('./routes/auth');
const purchaseRoutes = require('./routes/purchases');
const charityRoutes = require('./routes/charities');
const userRoutes = require('./routes/users');
const adminRoutes = require('./routes/admin');

const errorHandler = require('./middleware/errorHandler');
const logger = require('./utils/logger');

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
});
app.use(limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) }}));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/purchases', purchaseRoutes);
app.use('/api/charities', charityRoutes);
app.use('/api/users', userRoutes);
app.use('/api/admin', adminRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handling
app.use(errorHandler);

module.exports = app;
```

### 2. Server Entry Point

```javascript
// src/server.js
const app = require('./app');
const logger = require('./utils/logger');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});
```

---

## Authentication & Middleware

### 1. Firebase Service

```javascript
// src/services/firebaseService.js
const admin = require('firebase-admin');

class FirebaseService {
  constructor() {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        }),
      });
    }
  }

  async verifyIdToken(idToken) {
    try {
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      return decodedToken;
    } catch (error) {
      throw new Error('Invalid Firebase token');
    }
  }

  async getUserByUid(uid) {
    try {
      const userRecord = await admin.auth().getUser(uid);
      return userRecord;
    } catch (error) {
      throw new Error('User not found');
    }
  }
}

module.exports = new FirebaseService();
```

### 2. JWT Middleware

```javascript
// src/middleware/auth.js
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      include: { selectedCharity: true }
    });

    if (!user || !user.isActive) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
};

const authenticateAdmin = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Admin access token required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    if (decoded.role !== 'admin' && decoded.role !== 'super_admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const admin = await prisma.adminUser.findUnique({
      where: { id: decoded.adminId }
    });

    if (!admin || !admin.isActive) {
      return res.status(401).json({ error: 'Invalid admin token' });
    }

    req.admin = admin;
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired admin token' });
  }
};

module.exports = { authenticateToken, authenticateAdmin };
```

---

## API Routes & Controllers

### 1. Authentication Routes

```javascript
// src/routes/auth.js
const express = require('express');
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

router.post('/firebase-login', authController.firebaseLogin);
router.get('/user-profile', authenticateToken, authController.getUserProfile);
router.post('/refresh-token', authController.refreshToken);
router.post('/logout', authenticateToken, authController.logout);

module.exports = router;
```

```javascript
// src/controllers/authController.js
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const firebaseService = require('../services/firebaseService');
const logger = require('../utils/logger');

const prisma = new PrismaClient();

class AuthController {
  async firebaseLogin(req, res) {
    try {
      const { idToken } = req.body;
      
      if (!idToken) {
        return res.status(400).json({ error: 'Firebase ID token required' });
      }

      // Verify Firebase token
      const decodedToken = await firebaseService.verifyIdToken(idToken);
      
      // Find or create user
      let user = await prisma.user.findUnique({
        where: { firebaseUid: decodedToken.uid },
        include: { selectedCharity: true }
      });

      if (!user) {
        user = await prisma.user.create({
          data: {
            firebaseUid: decodedToken.uid,
            email: decodedToken.email || `${decodedToken.uid}@anonymous.com`,
            displayName: decodedToken.name,
            isAnonymous: !decodedToken.email
          },
          include: { selectedCharity: true }
        });
      }

      // Generate JWT
      const jwtToken = jwt.sign(
        { userId: user.id, firebaseUid: user.firebaseUid },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN }
      );

      logger.info(`User logged in: ${user.id}`);

      res.json({
        token: jwtToken,
        user: {
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          selectedCharity: user.selectedCharity,
          isAnonymous: user.isAnonymous
        }
      });
    } catch (error) {
      logger.error('Login error:', error);
      res.status(401).json({ error: 'Authentication failed' });
    }
  }

  async getUserProfile(req, res) {
    try {
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        include: { 
          selectedCharity: true,
          purchases: {
            orderBy: { createdAt: 'desc' },
            take: 5
          }
        }
      });

      res.json({ user });
    } catch (error) {
      logger.error('Get profile error:', error);
      res.status(500).json({ error: 'Failed to get user profile' });
    }
  }

  async refreshToken(req, res) {
    // Implement token refresh logic
    res.json({ message: 'Token refresh not implemented yet' });
  }

  async logout(req, res) {
    // Implement logout logic (token blacklisting if needed)
    res.json({ message: 'Logged out successfully' });
  }
}

module.exports = new AuthController();
```

### 2. Purchase Routes & Controller

```javascript
// src/routes/purchases.js
const express = require('express');
const purchaseController = require('../controllers/purchaseController');
const { authenticateToken } = require('../middleware/auth');
const validation = require('../middleware/validation');

const router = express.Router();

router.post('/validate', authenticateToken, validation.validatePurchase, purchaseController.validatePurchase);
router.get('/history', authenticateToken, purchaseController.getPurchaseHistory);
router.get('/stats', authenticateToken, purchaseController.getPurchaseStats);

module.exports = router;
```

```javascript
// src/controllers/purchaseController.js
const { PrismaClient } = require('@prisma/client');
const appleIAPService = require('../services/appleIAPService');
const donationService = require('../services/donationService');
const logger = require('../utils/logger');

const prisma = new PrismaClient();

class PurchaseController {
  async validatePurchase(req, res) {
    try {
      const { transactionId, receiptData, productId } = req.body;
      const userId = req.user.id;

      // Check if transaction already exists
      const existingPurchase = await prisma.purchase.findUnique({
        where: { appleTransactionId: transactionId }
      });

      if (existingPurchase) {
        return res.json({
          success: true,
          unlockDurationMinutes: existingPurchase.unlockDurationMinutes,
          charityDonationAmount: existingPurchase.charityDonationCents / 100
        });
      }

      // Validate with Apple
      const appleValidation = await appleIAPService.verifyReceipt(receiptData, transactionId);
      
      if (!appleValidation.isValid) {
        return res.status(400).json({ error: 'Invalid purchase receipt' });
      }

      // Get user's selected charity
      const user = await prisma.user.findUnique({
        where: { id: userId },
        include: { selectedCharity: true }
      });

      if (!user.selectedCharity) {
        return res.status(400).json({ error: 'No charity selected' });
      }

      // Calculate amounts and unlock duration
      const calculations = donationService.calculatePurchaseAmounts(appleValidation.amount, productId);

      // Create purchase record
      const purchase = await prisma.purchase.create({
        data: {
          userId: userId,
          charityId: user.selectedCharityId,
          productId: productId,
          amountCents: calculations.amountCents,
          appleFeesCents: calculations.appleFeesCents,
          netRevenueCents: calculations.netRevenueCents,
          charityDonationCents: calculations.charityDonationCents,
          platformRevenueCents: calculations.platformRevenueCents,
          appleTransactionId: transactionId,
          appleReceiptData: receiptData,
          isValidated: true,
          unlockDurationMinutes: calculations.unlockDurationMinutes,
          processedAt: new Date()
        }
      });

      logger.info(`Purchase validated: ${purchase.id} for user ${userId}`);

      res.json({
        success: true,
        unlockDurationMinutes: purchase.unlockDurationMinutes,
        charityDonationAmount: purchase.charityDonationCents / 100
      });
    } catch (error) {
      logger.error('Purchase validation error:', error);
      res.status(500).json({ error: 'Purchase validation failed' });
    }
  }

  async getPurchaseHistory(req, res) {
    try {
      const userId = req.user.id;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;
      const skip = (page - 1) * limit;

      const [purchases, total] = await Promise.all([
        prisma.purchase.findMany({
          where: { userId },
          include: { charity: true },
          orderBy: { createdAt: 'desc' },
          skip,
          take: limit
        }),
        prisma.purchase.count({ where: { userId } })
      ]);

      res.json({
        purchases,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit)
        }
      });
    } catch (error) {
      logger.error('Get purchase history error:', error);
      res.status(500).json({ error: 'Failed to get purchase history' });
    }
  }

  async getPurchaseStats(req, res) {
    try {
      const userId = req.user.id;

      const stats = await prisma.purchase.aggregate({
        where: { userId },
        _sum: {
          amountCents: true,
          charityDonationCents: true,
          unlockDurationMinutes: true
        },
        _count: true
      });

      res.json({
        totalSpent: (stats._sum.amountCents || 0) / 100,
        totalDonated: (stats._sum.charityDonationCents || 0) / 100,
        totalUnlockMinutes: stats._sum.unlockDurationMinutes || 0,
        totalPurchases: stats._count
      });
    } catch (error) {
      logger.error('Get purchase stats error:', error);
      res.status(500).json({ error: 'Failed to get purchase stats' });
    }
  }
}

module.exports = new PurchaseController();
```

---

## Core Services

### 1. Apple IAP Service

```javascript
// src/services/appleIAPService.js
const https = require('https');
const logger = require('../utils/logger');

class AppleIAPService {
  constructor() {
    this.sandboxUrl = 'https://sandbox.itunes.apple.com/verifyReceipt';
    this.productionUrl = 'https://buy.itunes.apple.com/verifyReceipt';
    this.sharedSecret = process.env.APPLE_SHARED_SECRET;
  }

  async verifyReceipt(receiptData, transactionId) {
    try {
      // Try production first
      let result = await this._makeRequest(this.productionUrl, receiptData);
      
      // If sandbox receipt, try sandbox endpoint
      if (result.status === 21007) {
        result = await this._makeRequest(this.sandboxUrl, receiptData);
      }

      if (result.status !== 0) {
        logger.error(`Apple receipt validation failed: ${result.status}`);
        return { isValid: false, error: 'Receipt validation failed' };
      }

      // Find the specific transaction
      const transaction = this._findTransaction(result.receipt, transactionId);
      
      if (!transaction) {
        return { isValid: false, error: 'Transaction not found in receipt' };
      }

      return {
        isValid: true,
        amount: this._getProductAmount(transaction.product_id),
        productId: transaction.product_id,
        transactionId: transaction.transaction_id,
        purchaseDate: new Date(parseInt(transaction.purchase_date_ms))
      };
    } catch (error) {
      logger.error('Apple IAP verification error:', error);
      return { isValid: false, error: 'Verification failed' };
    }
  }

  async _makeRequest(url, receiptData) {
    return new Promise((resolve, reject) => {
      const postData = JSON.stringify({
        'receipt-data': receiptData,
        'password': this.sharedSecret,
        'exclude-old-transactions': true
      });

      const options = {
        hostname: new URL(url).hostname,
        path: new URL(url).pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData)
        }
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (error) {
            reject(error);
          }
        });
      });

      req.on('error', reject);
      req.write(postData);
      req.end();
    });
  }

  _findTransaction(receipt, transactionId) {
    const allTransactions = receipt.in_app || [];
    return allTransactions.find(t => t.transaction_id === transactionId);
  }

  _getProductAmount(productId) {
    // Map product IDs to their prices (in cents)
    const productPrices = {
      'mindlock.unlock.30min': 99,   // $0.99
      'mindlock.unlock.1hour': 199,  // $1.99
      'mindlock.unlock.2hour': 299   // $2.99
    };
    
    return productPrices[productId] || 0;
  }
}

module.exports = new AppleIAPService();
```

### 2. Donation Service

```javascript
// src/services/donationService.js
const { PrismaClient } = require('@prisma/client');
const logger = require('../utils/logger');

const prisma = new PrismaClient();

class DonationService {
  calculatePurchaseAmounts(amountCents, productId) {
    // Apple takes 30% of all in-app purchases
    const appleFeesCents = Math.round(amountCents * 0.30);
    const netRevenueCents = amountCents - appleFeesCents;
    
    // 10% of net revenue goes to charity
    const charityDonationCents = Math.round(netRevenueCents * 0.10);
    const platformRevenueCents = netRevenueCents - charityDonationCents;
    
    // Determine unlock duration based on product
    const unlockDurationMinutes = this._getUnlockDuration(productId);
    
    return {
      amountCents,
      appleFeesCents,
      netRevenueCents,
      charityDonationCents,
      platformRevenueCents,
      unlockDurationMinutes
    };
  }

  async generateMonthlyReports(month, year) {
    try {
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0, 23, 59, 59);

      // Get all purchases for the month grouped by charity
      const charityDonations = await prisma.purchase.groupBy({
        by: ['charityId'],
        where: {
          createdAt: {
            gte: startDate,
            lte: endDate
          },
          isValidated: true
        },
        _sum: {
          charityDonationCents: true
        },
        _count: true
      });

      const reports = [];

      for (const donation of charityDonations) {
        // Check if report already exists
        const existingReport = await prisma.monthlyReport.findUnique({
          where: {
            month_year_charityId: {
              month,
              year,
              charityId: donation.charityId
            }
          }
        });

        if (!existingReport) {
          const report = await prisma.monthlyReport.create({
            data: {
              month,
              year,
              charityId: donation.charityId,
              totalAmountCents: donation._sum.charityDonationCents || 0,
              transactionCount: donation._count,
              status: 'generated'
            },
            include: { charity: true }
          });
          reports.push(report);
        }
      }

      logger.info(`Generated ${reports.length} monthly reports for ${month}/${year}`);
      return reports;
    } catch (error) {
      logger.error('Generate monthly reports error:', error);
      throw error;
    }
  }

  async exportMonthlyReportsToCSV(month, year) {
    try {
      const reports = await prisma.monthlyReport.findMany({
        where: { month, year },
        include: { charity: true },
        orderBy: { totalAmountCents: 'desc' }
      });

      const csvData = this._generateCSV(reports, month, year);
      
      // In a real implementation, you'd save this to cloud storage
      // For now, we'll just return the CSV data
      return {
        csvData,
        filename: `mindlock-donations-${year}-${month.toString().padStart(2, '0')}.csv`
      };
    } catch (error) {
      logger.error('Export CSV error:', error);
      throw error;
    }
  }

  _getUnlockDuration(productId) {
    const durations = {
      'mindlock.unlock.30min': 30,
      'mindlock.unlock.1hour': 60,
      'mindlock.unlock.2hour': 120
    };
    
    return durations[productId] || 30;
  }

  _generateCSV(reports, month, year) {
    const header = 'Charity Name,Website,Total Amount,Transaction Count,Status\n';
    
    const rows = reports.map(report => {
      const amount = (report.totalAmountCents / 100).toFixed(2);
      return `"${report.charity.name}","${report.charity.website || ''}","$${amount}",${report.transactionCount},"${report.status}"`;
    }).join('\n');
    
    return header + rows;
  }
}

module.exports = new DonationService();
```

---

## Deployment

### 1. Railway Deployment

```yaml
# railway.toml
[build]
builder = "NIXPACKS"

[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3

[env]
NODE_ENV = "production"
```

### 2. Docker Configuration (Optional)

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S backend -u 1001

USER backend

EXPOSE 3000

CMD ["npm", "start"]
```

### 3. Package.json Scripts

```json
{
  "scripts": {
    "dev": "nodemon src/server.js",
    "start": "node src/server.js",
    "build": "prisma generate",
    "migrate": "prisma migrate deploy",
    "seed": "node prisma/seed.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix"
  }
}
```

This backend guide provides a complete foundation for the MindLock API with proper authentication, payment validation, charity management, and reporting capabilities. 
