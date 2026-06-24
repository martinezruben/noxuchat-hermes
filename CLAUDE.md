# NoxuChat v4.15.1 — Contexto Comprimido

## TL;DR
**NoxuChat** es una plataforma de customer engagement multi-canal basada en Chatwoot. Este es un fork privado (`noxuchat-hermes`) desplegado en Windows 11 con WSL2 + Docker.

---

## Stack Técnico

| Capa | Tech | Version |
|------|------|---------|
| **Backend** | Rails | 7.1 (Ruby 3.4.4) |
| **Frontend** | Vue 3 + Vite + Tailwind | v3.5.12 |
| **DB** | PostgreSQL + pgvector | 16 |
| **Cache** | Redis | alpine |
| **Node/Package** | pnpm | 10.2.0 |
| **Testing** | RSpec (BE) / Vitest (FE) | - |
| **Deployment** | Docker Compose | WSL2 backend |

---

## Estructura Clave

```
/app/javascript/
  └─ dashboard/       # Main SPA (admin/agent interface)
  └─ widget/          # Embeddable chat widget
  └─ portal/          # Customer portal
  └─ sdk/             # JS SDK for clients
  └─ superadmin_pages/# Super admin panel

/app/
  ├─ models/          # ActiveRecord models (Account, Agent, Conversation, Message, etc.)
  ├─ controllers/api/ # RESTful API endpoints
  ├─ services/        # Business logic (e.g., ConversationService, MessageService)
  ├─ jobs/            # Background jobs (sidekiq, but disabled in this fork)
  ├─ mailers/         # Email templates
  └─ builders/        # API response builders

/config/
  ├─ database.yml     # DB config (uses env vars)
  ├─ environments/    # Rails env configs
  └─ locales/         # i18n translations

/db/
  ├─ migrate/         # Schema migrations
  └─ seeds/           # Initial data
```

---

## Primeros Pasos

### Levantar el stack (Windows)
```powershell
cd C:\chatwoot

# Option 1: Docker Compose (WSL2 backend)
docker compose -f docker-compose.production.yaml up -d

# Option 2: Local dev (Rails + Vite en paralelo)
pnpm dev          # Loads Procfile.dev via overmind
```

### URLs Locales
- **App**: http://localhost:3000
- **Admin**: http://localhost:3000/dashboard
- **API**: http://localhost:3000/api/v1
- **Design System Storybook**: `pnpm story:dev` → http://localhost:6006

### Default Credentials (después de seed)
Revisar `.env.example` o logs de Docker después de primer setup.

---

## Importante para el Desarrollo

### Frontend (Vue 3)
- **Entrypoints**: `/app/javascript/entrypoints/` — archivos que Vite compila
- **Router**: `/app/javascript/dashboard/router/` — main SPA routes
- **Store**: Pinia (state management) en `/app/javascript/dashboard/store/`
- **Tailwind**: Configurado en `tailwind.config.js` (utilities + custom components)
- **Linting**: ESLint + Prettier (`pnpm eslint:fix`)

### Backend (Rails)
- **API**: RESTful endpoints en `/app/controllers/api/v1/`
- **Models**: Polymorphic relationships (Conversation, Message, Contact, etc.)
- **Hooks**: PreCommit valida `bin/validate_push` (check git hooks)
- **No Sidekiq**: Background jobs deshabilitados en este fork (ver README)
- **Linting**: RuboCop (`bundle exec rubocop -a`)

### Database
- **Engine**: PostgreSQL con extensión `pgvector` (para embeddings/IA)
- **Migrations**: Usar `rails generate migration` y apply con `rails db:migrate`
- **Seed data**: `rails db:seed` (crea admin/test accounts)

### Environment Variables
Revisar `.env.example` para configuración requerida:
```
RAILS_ENV=development
DATABASE_URL=postgres://...
REDIS_URL=redis://...
RAILS_LOG_TO_STDOUT=true
MAILER_SENDER=...
```

---

## Scripts útiles

```bash
# Frontend
pnpm dev              # Watch mode (Vite + Rails server)
pnpm test             # Run Vitest suite
pnpm test:watch      # Watch mode
pnpm eslint:fix      # Fix linting issues
pnpm build:sdk       # Build JS SDK for external use

# Backend
bundle exec rails s           # Start Rails server
bundle exec rails c           # Rails console
bundle exec rspec spec/       # Run RSpec tests
bundle exec rubocop -a       # Fix Ruby linting

# Database
rails db:create              # Create DB
rails db:migrate             # Run pending migrations
rails db:seed                # Load seed data
```

---

## Limitaciones Conocidas (Este Fork)

1. **Sidekiq deshabilitado** — No hay workers/async jobs activos
2. **Single container** — Rails + Puma, sin separación de procesos
3. **Desarrollo en Windows** — Usar WSL2 Docker backend, no Docker Desktop
4. **Parches aplicados** — Ver `docker/patches/Dockerfile.patch` para changes vs upstream

---

## Decisiones de Diseño

- **Vue 3 Composition API**: Codebase moderno, no Legacy Options API
- **Tailwind + Custom Components**: Usar clases existentes en `tailwind.config.js` antes de agregar nuevas
- **API-first** — Frontend consume REST API (fácil desacoplamiento)
- **Pinia over Vuex**: Store simplificado (pero Vuex aún existe, migración en progreso)
- **Vite over Webpacker**: Builds rápidos, hot reload out-of-the-box

---

## Troubleshooting Común

| Problema | Solución |
|----------|----------|
| Docker no inicia | Verificar WSL2 está habilitado: `wsl -l -v` |
| Postgres no conecta | Check `DATABASE_URL` y que postgres container está up |
| Node modules issues | `rm -rf node_modules pnpm-lock.yaml && pnpm install` |
| Stale Vite cache | `rm -rf public/vite && pnpm dev` |
| Hot reload no funciona | Verificar `localhost:3000/vite-dev-server` accesible |

---

## Enlaces

- **Upstream**: https://github.com/chatwoot/chatwoot
- **Fork**: https://github.com/martinezruben/noxuchat-hermes
- **Docs**: https://www.chatwoot.com/docs
- **API Swagger**: http://localhost:3000/api-docs

---

**Última actualización**: 2026-06-24 | Fork manager: Hermes Agent
