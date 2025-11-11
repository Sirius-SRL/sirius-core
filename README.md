# 🌟 Sirius Core - Master Repository

> Moldavian invoice and payment management system - "Gestioneaza conturile de plata usor si estetic"

[![Website](https://img.shields.io/badge/Website-md.sirius.expert-blue)](https://md.sirius.expert/)
[![Organization](https://img.shields.io/badge/Organization-Sirius--SRL-green)](https://github.com/Sirius-SRL)

## 📋 Overview

Sirius is a comprehensive FinTech solution designed for Moldavian businesses to manage invoices, payments, and financial operations. This monorepo contains all core services and applications that power the Sirius platform.

### 🎯 Mission

Support businesses in determining debtors, establishing amounts owed, and tracking payment deadlines - making financial management easy and aesthetic.

## 🏗️ Repository Structure

This monorepo contains the following projects:

### 🔧 Core Services

#### [einvoice-fastapi/](./einvoice-fastapi)
**FastAPI Backend Service**
- Multi-tenant invoice management API
- E-factura integration (Moldavian electronic invoicing)
- JWT authentication & authorization
- AI-powered document processing
- Bank integrations
- MySQL + Redis

**Tech**: Python 3.13+, FastAPI, SQLAlchemy, Pydantic v2, Alembic, MySQL, Docker

#### [einvoice2-nuxt3/](./einvoice2-nuxt3)
**Nuxt 3 Frontend Application**
- Modern SPA for invoice management
- Multi-language support (RO, RU, EN)
- Invoice & e-factura generators
- Payment tracking & analytics
- AI document upload & extraction
- Responsive design with TailwindCSS

**Tech**: Nuxt 3, Vue 3, TypeScript, Pinia, TailwindCSS, Docker

### 📄 PDF Services

#### [sirius-pdf-generator/](./sirius-pdf-generator)
**Python PDF Generation Service**
- HTML to PDF conversion
- Playwright-based rendering
- Template processing
- High-quality document output

**Tech**: Python, FastAPI, Playwright, Docker

#### [sirius-pdf-templating/](./sirius-pdf-templating)
**Node.js PDF Templating Service**
- PDF template management
- CSS processing with UnoCSS
- Puppeteer-based rendering
- Template asset management

**Tech**: Node.js, Express, Puppeteer, UnoCSS, Docker

### 🛠️ Utilities

#### [sirius-translations-to-sheet/](./sirius-translations-to-sheet)
**Translation Management Utility**
- Sync translations with Google Sheets
- Multi-language support automation
- Translation comparison tools

**Tech**: Python, Google Sheets API

## 🚀 Quick Start

> **📖 New to this monorepo?** Check out [WORKFLOW.md](./WORKFLOW.md) for detailed guide on working with submodules!

### Prerequisites

- Docker & Docker Compose
- Python 3.13+ (for backend development)
- Node.js 18+ (for frontend development)
- Poetry (Python dependency management)
- Git

### Development Setup

Each project can be run independently. Navigate to the specific project directory and follow its README.

```bash
# Backend API
cd einvoice-fastapi
poetry install
# See einvoice-fastapi/README.md for details

# Frontend
cd einvoice2-nuxt3
npm install
# See einvoice2-nuxt3/README.md for details

# PDF Generator
cd sirius-pdf-generator
poetry install
# See sirius-pdf-generator/README.md for details

# PDF Templating
cd sirius-pdf-templating
npm install
# See sirius-pdf-templating/README.md for details
```

### Docker Deployment

Each service has multiple docker-compose configurations:

- `docker-compose.yml` - Production
- `docker-compose.dev.yml` - Development
- `docker-compose.staging.yml` - Staging
- `docker-compose.beta.yml` - Beta
- `docker-compose.local.yml` - Local testing

```bash
# Example: Run backend in development mode
cd einvoice-fastapi
docker-compose -f docker-compose.dev.yml up
```

## 🏢 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Sirius Platform                       │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐         ┌──────────────────────────┐  │
│  │   Frontend   │────────▶│      Backend API         │  │
│  │  (Nuxt 3)    │  REST   │     (FastAPI)            │  │
│  └──────────────┘         └──────────────────────────┘  │
│                                      │                    │
│                                      ├─────────────────┐  │
│                                      │                 │  │
│                           ┌──────────▼────┐  ┌────────▼──┐
│                           │ PDF Generator │  │   Redis   │
│                           │   (Python)    │  │  (Cache)  │
│                           └───────────────┘  └───────────┘
│                                      │                    │
│                           ┌──────────▼────────────────┐   │
│                           │   PDF Templating          │   │
│                           │     (Node.js)             │   │
│                           └───────────────────────────┘   │
│                                                           │
│  ┌──────────────────────────────────────────────────┐    │
│  │              MySQL Database                      │    │
│  └──────────────────────────────────────────────────┘    │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## 🌍 Markets & Languages

### Geographic Focus
- **Primary**: Moldova 🇲🇩
- **Secondary**: Romanian-speaking markets
- **Tertiary**: Russian-speaking markets
- **International**: English support

### Supported Languages
- Romanian (RO) - Default
- Russian (RU)
- English (EN)

## 🔑 Key Features

### Invoice Management
- ✅ Multi-language invoice generation
- ✅ PDF export with custom templates
- ✅ Draft management with autosave
- ✅ Service/product catalog
- ✅ Discount & VAT management
- ✅ Multi-currency support

### E-Factura Integration
- ✅ Moldavian government e-invoice system
- ✅ Digital signature support
- ✅ Status tracking & validation
- ✅ Compliance checking
- ✅ Automatic submission

### AI-Powered Features
- ✅ Document upload & data extraction
- ✅ Automatic field mapping
- ✅ Support for PDF, DOC, images, XML
- ✅ Bank account detection
- ✅ Smart data validation

### Payment Management
- ✅ Payment tracking & status
- ✅ Debtor identification
- ✅ Due date management
- ✅ Payment reminders
- ✅ Bank integration

### Analytics & Reporting
- ✅ Financial dashboards
- ✅ Revenue tracking
- ✅ Payment analytics
- ✅ Business metrics
- ✅ Export capabilities

## 💼 Business Model

### Subscription Tiers
- **BabySteps** - Entry level
- **FrenchStudio** - Small business
- **MiddleClassFancy** - Growing business
- **PenthouseView** - Enterprise
- **YourMajesty** - Premium enterprise

Each tier includes different revenue limits and feature access.

## 🔗 Integrations

### Current Integrations
- Google OAuth (Authentication)
- Sentry (Error tracking)
- PostHog (Analytics)
- Intercom (Customer support)
- Google Analytics (Web analytics)
- Meta Pixel (Marketing)
- reCAPTCHA (Security)
- E-factura API (Government system)
- Bank APIs (Payment processing)

## 🛡️ Security & Compliance

- GDPR compliant
- Moldavian tax regulation compliance
- Role-based access control (RBAC)
- JWT authentication
- Encrypted data storage
- Audit trails
- Regular security updates

## 📚 Documentation

Each project contains its own documentation:

- `README.md` - Project-specific setup and overview
- `project_context.md` - Business context and requirements
- `technical_details.md` - Technical architecture and decisions
- `task_on_hand.md` - Current development tasks
- `development_log.md` - Historical development log
- `docs/` - Additional documentation

### Backend Documentation
- [API Documentation](./einvoice-fastapi/docs/api/)
- [Bank Integration](./einvoice-fastapi/docs/bank-integration/)
- [Technical Details](./einvoice-fastapi/docs/technical/)

### Frontend Documentation
- [Component Documentation](./einvoice2-nuxt3/docs/)
- [Testing Guide](./einvoice2-nuxt3/tests/)

## 🤝 Contributing

This is a private repository for Sirius-SRL organization. For internal development:

1. Create feature branch from `main`
2. Follow project-specific coding standards
3. Update relevant documentation
4. Submit pull request for review
5. Ensure all tests pass
6. Get approval before merging

### Code Standards

#### Backend (Python)
- Modern Python typing (no `Optional`, `List`, `Dict` from typing)
- PEP257 docstrings
- Pydantic v2 conventions
- Ruff for linting
- mypy for type checking
- pytest for testing

#### Frontend (TypeScript/Vue)
- **CRITICAL**: Always use camelCase (never snake_case)
- TypeScript strict mode
- Composition API with `<script setup>`
- ESLint + Prettier
- Vitest for testing
- All UI text in English (use i18n)

## 📞 Support

- **Website**: https://md.sirius.expert/
- **Organization**: Sirius-SRL
- **Market**: Moldova

## 📄 License

Proprietary - All rights reserved by Sirius-SRL

---

**Made with ❤️ in Moldova**

*Last Updated: 2025-11-11*

