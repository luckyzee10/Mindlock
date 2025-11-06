# MindLock 🔒

> Productivity app that uses Screen Time API + payments to reduce social media addiction while supporting charities

## Overview

MindLock is a comprehensive iOS productivity app featuring a 4-section architecture: Setup, Analytics, Social, and Profile. Users set per-app daily limits using Apple's Screen Time API. When they exceed limits, they can unlock more time by paying a small fee (based on their chosen difficulty level). A percentage goes to their selected charity, creating positive impact even during moments of weakness.

## Quick Start

```bash
# Clone and setup
git clone [repository-url]
cd mindlock

# iOS App
cd ios
open MindLock.xcodeproj

# Backend
cd backend
npm install
npm run dev
```

## Documentation

- 🔄 [**User Flow Logic**](./docs/USER_FLOW_LOGIC.md) - Core flows, wireframes & system architecture ⭐
- 📋 [Product Roadmap](./docs/ROADMAP.md) - Development phases and timelines  
- 📱 [App Structure](./docs/APP_STRUCTURE.md) - 4-section architecture and features
- 🛠️ [Tech Stack](./docs/TECH_STACK.md) - Complete technology breakdown
- 🏗️ [Architecture](./docs/ARCHITECTURE.md) - System design and data flow
- 📱 [iOS Development](./docs/IOS_GUIDE.md) - iOS implementation details
- 🔧 [Backend Guide](./docs/BACKEND_GUIDE.md) - Server setup and API docs
- 💳 [Payment Integration](./docs/PAYMENT_GUIDE.md) - Apple IAP implementation
- 📊 [Admin Dashboard](./docs/ADMIN_GUIDE.md) - Reporting and management

## Project Structure

```
mindlock/
├── ios/                    # iOS Swift app
├── backend/               # Node.js API server
├── admin/                 # React admin dashboard
├── docs/                  # Project documentation
└── scripts/              # Deployment and utility scripts
```

## Current Status

🟡 **Phase 1 - Core MVP** (In Progress)
- [ ] iOS app foundation
- [ ] Screen Time integration
- [ ] Basic UI implementation

See [ROADMAP.md](./docs/ROADMAP.md) for detailed progress tracking.

## Team

- Development: [Your Name]
- Design: TBD
- Business: TBD

## License

Private project - All rights reserved 