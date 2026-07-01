# noxuchat-hermes

> Fork privado de [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot) v4.15.1
> parcheado y desplegado sobre **WSL2 + Docker Engine** en Windows 11.
> Gestionado íntegramente vía [Hermes Agent](https://hermes-agent.nousresearch.com).

> ⚠️ Este NO es un fork oficial de Chatwoot. NoxuChat es una copia de trabajo personalizada basada en Chatwoot.
> Para upstream/issues originales: https://github.com/chatwoot/chatwoot/issues

---

## TL;DR

```powershell
# Clonar (una vez)
git clone https://github.com/martinezruben/noxuchat-hermes.git C:\chatwoot
cd C:\chatwoot

# Levantar el stack
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml up -d

# Esperar 30-60 segundos y abrir
start http://localhost:3000

# Login con el admin creado (ver credenciales locales más abajo)
```

---

## Tabla de contenidos

1. [Arquitectura](#arquitectura)
2. [Requisitos](#requisitos)
3. [Setup desde cero](#setup-desde-cero)
4. [Estructura del repo](#estructura-del-repo)
5. [Parches aplicados](#parches-aplicados)
6. [Configuración (.env y secretos)](#configuración-env-y-secretos)
7. [Workflow diario](#workflow-diario)
8. [Comandos útiles](#comandos-útiles)
9. [Troubleshooting](#troubleshooting)
10. [Decisiones técnicas y por qué](#decisiones-técnicas-y-por-qué)
11. [Limitaciones conocidas](#limitaciones-conocidas)
12. [Migrar a otro equipo](#migrar-a-otro-equipo)

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│  Windows 11 Pro (host)                                  │
│  ├─ Docker Desktop instalado pero NO usado              │
│  ├─ WSL2 backend (Hyper-V + VirtualMachinePlatform)     │
│  └─ Hermes Agent (este script)                          │
└────────────────┬────────────────────────────────────────┘
                 │  wsl.exe -d Ubuntu-Docker
                 ▼
┌─────────────────────────────────────────────────────────┐
│  WSL2 distro: Ubuntu-Docker (Ubuntu 22.04 LTS)          │
│  ├─ Docker Engine v29.6.0 + Compose v5.1.4             │
│  └─ Containers:                                          │
│      ├─ chatwoot-rails-1   (chatwoot/chatwoot:patched) │
│      ├─ chatwoot-postgres-1 (pgvector/pgvector:pg16)    │
│      └─ chatwoot-redis-1    (redis:alpine)              │
│                                                         │
│  ⚠️ Sidekiq NO incluido (ver Limitaciones conocidas)    │
└─────────────────────────────────────────────────────────┘
                 ▲
                 │  127.0.0.1:3000 → Windows
                 │
            Browser / API clients
```

**Imagen Docker**: `chatwoot/chatwoot:patched` (basada en `chatwoot/chatwoot:latest`
v4.15.1, construida con `docker/patches/Dockerfile.patch`).

---

## Requisitos

| Componente | Versión / Detalle |
|---|---|
| Windows | 11 Pro, Enterprise o Education (necesita Hyper-V) |
| WSL2 | Habilitado (kernel de Linux 5.15+) |
| Virtualización | Habilitada en BIOS/UEFI (`Intel VT-x` o `AMD-V`) |
| RAM | Mínimo 8 GB (4 GB reales quedan para Docker, los demás para Windows) |
| Disco | ~6 GB para imágenes + vhdx de WSL2 + ~1 GB para postgres/redis volumes |
| Docker Engine | v29.6.0 (dentro de WSL2, NO Docker Desktop) |
| pnpm | v10.2.0 (instalado dentro de la imagen patched) |

---

## Setup desde cero

### 1. Habilitar WSL2 (como Administrador en PowerShell)

```powershell
# Verificar features (deben estar Enabled)
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

# Si alguna está Disabled:
Enable-WindowsOptionalFeature -Online -FeatureName <nombre> -NoRestart
# (algunas requieren reboot)
```

### 2. Instalar Docker Engine en WSL2

Hermes ya tiene este proceso automatizado y documentado. Resumen:

```bash
# Descargar Ubuntu 22.04 rootfs
curl -L -o /tmp/ubuntu.tar.gz \
  https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz
sha256sum -c <(curl -s https://cloud-images.ubuntu.com/wsl/jammy/current/SHA256SUMS | grep jammy-wsl-amd64)

# Importar como distro WSL2
wsl --import Ubuntu-Docker C:\WSL\Ubuntu\install C:\WSL\Ubuntu\ubuntu-jammy.rootfs.tar.gz

# Arrancar, crear usuario, instalar Docker CE
wsl -d Ubuntu-Docker --user root -- bash /mnt/c/WSL/Ubuntu/bootstrap.sh
wsl --shutdown
# (re-arranca, ahora con systemd)

# Dentro de Ubuntu-Docker:
sudo apt-get update
sudo apt-get install -y curl gnupg ca-certificates apt-transport-https
# (bootstrap.sh ya lo hace)
```

### 3. Wrappers de Windows (acceso desde CMD/PowerShell)

Crear `C:\Program Files\docker-wsl\docker.cmd`:
```cmd
@echo off
wsl.exe -d Ubuntu-Docker --user dockeradmin -- bash -lc "docker %*"
```

(Opcional) Añadir `C:\Program Files\docker-wsl` al PATH para usar `docker` directamente.

### 4. Clonar este repo y levantar

```powershell
git clone https://github.com/martinezruben/noxuchat-hermes.git C:\chatwoot
cd C:\chatwoot

# Crear .env desde el ejemplo (ver [Configuración](#configuración-env-y-secretos))
cp .env.example .env
# Editar .env con tus secretos

# Build de la imagen patched (~3 min la primera vez)
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml build

# Levantar stack
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml up -d

# Esperar 30s y curl health check
Start-Sleep 30
curl http://localhost:3000
```

### 5. Crear el primer superadmin

```powershell
# Opción A: vía signup web (más lento, UI first time)
start http://localhost:3000/app/auth/signup

# Opción B: vía rails runner (más rápido, sin UI)
$script = @"
Rails.application.eager_load!
account = Account.find_or_create_by!(name: 'Mi Empresa')
user = User.find_or_initialize_by(email: 'admin@example.com')
user.name = 'Admin'
user.type = 'SuperAdmin'
user.password = 'CAMBIAR_ESTA_PASSWORD'
user.password_confirmation = 'CAMBIAR_ESTA_PASSWORD'
user.skip_confirmation!
user.confirmed_at = Time.current
user.save!
AccountUser.find_or_create_by!(account_id: account.id, user_id: user.id) { |au| au.role = :administrator }
puts "OK user_id=#{user.id} account_id=#{account.id}"
"@
& "C:\Program Files\docker-wsl\docker.cmd" exec -i chatwoot-rails-1 bundle exec rails runner -
# (pegar $script en stdin)
```

⚠️ **No commitear `admin-credentials.txt` ni `.env`** — están en `.gitignore`.

---

## Estructura del repo

```
noxuchat-hermes/
├── README.md                                     ← este archivo
├── .gitignore                                    ← endurecido para excluir secretos/binarios
├── .env.example                                  ← plantilla (sin secretos reales)
├── Gemfile, Gemfile.lock                         ← originales de Chatwoot 4.15.1
├── app/, bin/, config/, db/, lib/, ...           ← código fuente de Chatwoot
│
├── docker-compose.production.yaml                ← compose principal (stack de prod)
├── docker-compose.memoverride.yaml               ← override temporal: mem_limit para precompilar
├── docker-compose.precompile.yaml                ← override temporal: mem_limit para precompile
│
├── docker/patches/
│   ├── Dockerfile.patch                         ← build de chatwoot/chatwoot:patched
│   ├── 20231211010807_add_cached_labels_list.rb  ← migración parcheada (fuente para COPY)
│   └── pnpm.README                              ← nota sobre el binario pnpm (excluido del repo)
│
└── db/migrate/20231211010807_add_cached_labels_list.rb  ← misma migración parcheada, en su sitio
```

### ¿Por qué hay dos archivos de migración iguales?

El `Dockerfile.patch` necesita el archivo en el contexto del build (lo `COPY`ea a
`/app/db/migrate/` dentro de la imagen), mientras que Rails en runtime también lo
necesita en `/app/db/migrate/`. Ambos archivos son **idénticos byte a byte** y
deben mantenerse sincronizados. El `docker/patches/` es para el build; `db/migrate/`
es para Rails al arrancar.

---

## Parches aplicados

### Parche 1: Migración rota por `acts-as-taggable-on 12.x`

**Archivo**: `db/migrate/20231211010807_add_cached_labels_list.rb`
(equivalente en `docker/patches/`)

**Problema**: La imagen oficial `chatwoot/chatwoot:latest` (v4.15.1) trae
`acts-as-taggable-on 12.0.0`, que **eliminó** la clase `ActsAsTaggableOn::Taggable::Cache`.
La migración original hace `ActsAsTaggableOn::Taggable::Cache.included(Conversation)`,
lo que crashea con `NameError`.

**Fix**: Comentamos esa línea. La columna `cached_label_list` se crea igualmente;
sólo se omite el backfill (que es opcional, se regenera al guardar).

```ruby
# diff:
   def change
     add_column :conversations, :cached_label_list, :string
     Conversation.reset_column_information
-    ActsAsTaggableOn::Taggable::Cache.included(Conversation)
+    # ActsAsTaggableOn::Taggable::Cache.included(Conversation)
+    # Patched by Hermes: ActsAsTaggableOn 12.x removed ActsAsTaggableOn::Taggable::Cache.
+    # The cached_label_list backfill is optional (only used as a denormalized cache);
+    # it is rebuilt lazily on save. Skip the backfill to allow db:migrate to complete.
   end
```

### Parche 2: Imagen patched con pnpm y NODE_OPTIONS

**Archivo**: `docker/patches/Dockerfile.patch`

```dockerfile
FROM chatwoot/chatwoot:latest

# (1) Patch the failing migration
COPY 20231211010807_add_cached_labels_list.rb /app/db/migrate/20231211010807_add_cached_labels_list.rb

# (2) Install pnpm at the exact version Chatwoot requires
COPY pnpm /usr/local/bin/pnpm
RUN chmod +x /usr/local/bin/pnpm

# (3) Give Node/vite enough heap to compile 4675 modules on a 7.6 GB host.
ENV NODE_OPTIONS=--max-old-space-size=3072
```

**Por qué**:
- La imagen oficial sólo trae `node`, ni `npm` ni `corepack` ni `pnpm`.
- `package.json` exige `pnpm@10.2.0` exacto (lo trae `corepack prepare`).
- `assets:precompile` corre `vite build` sobre 4675 módulos JS; sin heap extra,
  vite muere con `Out of memory`.

**Build**:
```bash
cd docker/patches
# pnpm (descargar si no existe):
curl -L -o pnpm https://github.com/pnpm/pnpm/releases/download/v10.2.0/pnpm-linuxstatic-x64
chmod +x pnpm
docker build -t chatwoot/chatwoot:patched -f Dockerfile.patch .
```

⚠️ El binario `pnpm` (~64 MB) está en `.gitignore`. Cada máquina que clone
el repo debe descargarlo localmente antes de buildear.

### Parche 3: docker-compose sin sidekiq

**Archivo**: `docker-compose.production.yaml`

**Problema original**: Con `sidekiq` + `rails` en el compose, `rails s` arranca
y muere silenciosamente justo después del "Rails application starting in
production" (logs sólo muestran el entrypoint, no el error real). El
`restart: always` lo buclea indefinidamente. Sin sidekiq, rails arranca limpio.

**Solución actual**: Sidekiq **eliminado** del compose. Ver
[Limitaciones conocidas](#limitaciones-conocidas).

Otros cambios menores en el compose:
- Servicio `postgres`: añadido `env_file: .env` (el oficial hardcodeaba `POSTGRES_PASSWORD=`)
- Servicio `rails`: añadido `mem_limit: 4g` (preventivo)

### Parche 4: .gitignore endurecido

Excluye:
- `.env`, `admin-credentials.txt`, `*.bak`, `chatwoot-secrets.txt`
- `docker/patches/pnpm` (binario de 64 MB)
- `vendor/db/*.onnx` (modelo de sentiment, 65 MB)
- `.github/workflows/` (no aplican a fork privado)
- `node_modules/`, `log/`, `tmp/`, `public/{packs,assets,vite}/`

---

## Configuración (.env y secretos)

### Crear `.env`

```bash
cp .env.example .env
```

### Variables mínimas requeridas

```bash
# Postgres
POSTGRES_PASSWORD=<random 24+ chars>
POSTGRES_USER=postgres
POSTGRES_HOST=postgres

# Redis
REDIS_PASSWORD=<random 24+ chars>

# Rails
SECRET_KEY_BASE=<output of: ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'>
FRONTEND_URL=http://localhost:3000
RAILS_ENV=production
INSTALLATION_ENV=docker
ACTIVE_STORAGE_SERVICE=local
```

### Generar SECRET_KEY_BASE

Dentro del container (o cualquier Ruby):
```bash
docker exec chatwoot-rails-1 ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

O desde WSL:
```bash
wsl -d Ubuntu-Docker ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

### ⚠️ NUNCA commitear `.env`

Está en `.gitignore`. Verificar antes de cada `git add`:
```bash
git check-ignore -v .env
# Output esperado: .gitignore:2:.env	.env
```

---

## Workflow diario

### Modificar código y subir a GitHub

```powershell
# 1) Editar archivos en C:\chatwoot (VSCode, Notepad, etc.)

# 2) Ver cambios
cd C:\chatwoot
git status
git diff

# 3) Commit + push
git add -A
git commit -m "feat: cambio X"
git push origin main
```

### Aplicar cambios al stack

**Cambios en código Rails (Ruby)** — sólo restart:
```powershell
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml restart rails
```

**Cambios en JS/Vue/assets** — rebuild assets:
```powershell
& "C:\Program Files\docker-wsl\docker.cmd" exec chatwoot-rails-1 bundle exec rails assets:precompile
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml restart rails
```

**Cambios en Gemfile** — rebuild image:
```powershell
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml build rails
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml up -d rails
```

**Cambios en Dockerfile.patch o migraciones nuevas**:
```powershell
# Re-build imagen desde cero
cd C:\chatwoot\docker\patches
& "C:\Program Files\docker-wsl\docker.cmd" build -t chatwoot/chatwoot:patched -f Dockerfile.patch .

# Re-arrancar rails (NO recrear postgres/redis)
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml up -d --force-recreate rails

# Si la migración es nueva, se aplica automáticamente al arrancar (entrypoint hace db:prepare)
```

---

## Comandos útiles

### Estado del stack

```powershell
# Containers
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml ps

# Uso de memoria/CPU
& "C:\Program Files\docker-wsl\docker.cmd" stats --no-stream

# Health check
curl http://localhost:3000

# Logs en vivo
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml logs -f rails
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml logs -f postgres
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml logs -f redis
```

### Ejecutar comandos Rails

```powershell
# Rails console (REPL interactivo)
& "C:\Program Files\docker-wsl\docker.cmd" exec -it chatwoot-rails-1 bundle exec rails console

# Database console
& "C:\Program Files\docker-wsl\docker.cmd" exec -it chatwoot-postgres-1 psql -U postgres -d chatwoot_production

# Ver todas las migraciones
& "C:\Program Files\docker-wsl\docker.cmd" exec chatwoot-rails-1 bundle exec rails db:migrate:status

# Crear un usuario desde CLI (one-liner)
& "C:\Program Files\docker-wsl\docker.cmd" exec chatwoot-rails-1 bundle exec rails runner "puts User.count"
```

### Backups

```powershell
# Dump de Postgres
& "C:\Program Files\docker-wsl\docker.cmd" exec chatwoot-postgres-1 pg_dump -U postgres chatwoot_production > backup-YYYY-MM-DD.sql

# Restore
Get-Content backup-YYYY-MM-DD.sql | & "C:\Program Files\docker-wsl\docker.cmd" exec -i chatwoot-postgres-1 psql -U postgres chatwoot_production
```

### Reset completo (⚠️ borra TODO)

```powershell
# Bajar containers y borrar volumes (postgres, redis, storage)
cd C:\chatwoot
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml down -v

# Re-construir todo
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml build
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml up -d
```

---

## Troubleshooting

### `docker` no encontrado desde PowerShell

Síntoma: `docker : The term 'docker' is not recognized`
Causa: el wrapper `docker.cmd` no está en el PATH o no se creó.

Fix:
```powershell
Test-Path "C:\Program Files\docker-wsl\docker.cmd"  # debe ser True
# Si no, recrear (ver Setup paso 3)
```

### WSL arranca pero `execvp /bin/bash failed 2`

Síntoma: `WSL (12) ERROR: getpwuid(0) failed 2`
Causa: distro de WSL rota (probablemente `docker-desktop-data` intentando arrancar).

Fix:
```powershell
wsl --shutdown
# Verificar
wsl -l -v
# Si docker-desktop está Stopped, déjalo así. Sólo Ubuntu-Docker debe estar Running.
```

### `curl http://localhost:3000` devuelve "connection refused"

1. Verificar que rails-1 está Up:
   ```powershell
   & "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml ps
   ```
2. Ver logs:
   ```powershell
   & "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml logs --tail=50 rails
   ```
3. Buscar: ¿Aparece `Listening on http://0.0.0.0:3000`?

Si no aparece → Rails crasheó. Causa más común: OOM durante `bundle install`.
Fix: matar sidekiq (si existe) o aumentar RAM del host.

### `database "chatwoot_production" does not exist`

Esto sólo pasa la PRIMERA vez. El entrypoint debería crearla automáticamente,
pero si falla:

```powershell
& "C:\Program Files\docker-wsl\docker.cmd" exec chatwoot-rails-1 bundle exec rails db:create
& "C:\Program Files\docker-wsl\docker.cmd" exec chatwoot-rails-1 bundle exec rails db:migrate
```

### `acts-as-taggable-on 12.x removed ActsAsTaggableOn::Taggable::Cache`

Este error significa que la imagen no es la patched. Verificar:
```powershell
& "C:\Program Files\docker-wsl\docker.cmd" inspect chatwoot/chatwoot:patched --format "{{.Config.Env}}" | findstr NODE_OPTIONS
# Debe mostrar: NODE_OPTIONS=--max-old-space-size=3072

# Si no, rebuildear:
cd C:\chatwoot\docker\patches
& "C:\Program Files\docker-wsl\docker.cmd" build -t chatwoot/chatwoot:patched -f Dockerfile.patch .
```

### `vite build ... Reached heap limit Allocation failed - JavaScript heap out of memory`

Ocurre durante `assets:precompile`. Causa: no se aplicó `NODE_OPTIONS` o hay
otros containers consumiendo RAM.

Fix:
```powershell
# Parar todo lo no esencial (sidekiq si existiera, otros containers)
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml stop rails

# Precompilar con override de memoria (sólo esta corrida)
cd C:\chatwoot
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml -f docker-compose.precompile.yaml run --rm --no-deps --entrypoint="" rails bundle exec rails assets:precompile

# Re-arrancar
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml up -d rails
```

### Postgres rechaza conexiones

```powershell
# Ver logs
& "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml logs --tail=20 postgres

# Si dice "Database is uninitialized and superuser password is not specified":
# El POSTGRES_PASSWORD no llegó al container. Verificar .env
Get-Content C:\chatwoot\.env | Select-String POSTGRES_PASSWORD
# Debe existir. Si no, editar y re-arrancar postgres
```

---

## Decisiones técnicas y por qué

| Decisión | Razón |
|---|---|
| **WSL2 + Docker Engine (no Docker Desktop)** | Docker Desktop consume 1-2 GB en idle y requiere login en empresas >250 empleados. Docker Engine puro es más ligero y suficiente para un container-host. |
| **Ubuntu 22.04 LTS (no 24.04)** | La rootfs WSL de 22.04 (jammy) está disponible como `.tar.gz` directo en `cloud-images.ubuntu.com`. La de 24.04 (noble) sólo tiene manifest, hay que importarla vía winget/Microsoft Store, que añade fricción. |
| **`chatwoot/chatwoot:patched` (custom build)** | La imagen oficial tiene 2 bugs que rompen el deploy en este host: la migración rota con `acts-as-taggable-on` 12.x, y la falta de pnpm (sólo trae `node`). El `Dockerfile.patch` aplica 3 fixes mínimos encima de `:latest`. |
| **Sidekiq NO incluido** | Con sidekiq + rails en el mismo compose, rails-1 entra en restart-loop silencioso al final del boot (probable conflicto de bootsnap/tmp cache). Sin sidekiq, rails arranca en 30s y responde 200 OK. Sidekiq procesa jobs background (emails, webhooks) — ver [Limitaciones](#limitaciones-conocidas). |
| **`mem_limit: 4g` en rails** | Preventivo. Con 7.6 GB de host, vite necesita garantizarse 3 GB para precompilar 4675 módulos JS. |
| **`.gitignore` endurecido** | El repo upstream trae archivos grandes (`vendor/db/sentiment-analysis.onnx`, 65 MB) y workflows de GitHub Actions que no aplican. Subirlos haría el repo pesado y el push fallaría por el límite de GitHub. |
| **Sin `version:` en compose** | Docker Compose v2 ignora el campo `version:` y avisa. Chatwoot lo trae por compatibilidad con v1. |

---

## Limitaciones conocidas

### 1. Sin Sidekiq

Sidekiq procesa jobs en background. Sin él, **no funcionan**:
- Envío de emails (notificaciones a agentes cuando llega un mensaje nuevo)
- Webhooks salientes
- Reports/exportaciones
- Campañas
- Avatar fetching (Gravatar) — los avatars quedan vacíos
- Event dispatcher interno (algunos contadores UI no se actualizan)

**Impacto**: La UI funciona, login funciona, puedes leer/escribir mensajes. Pero no recibirás emails automáticos.

**Workaround para producción real**: Crear un `docker-compose.sidekiq.yaml` separado que monte `tmp/cache` con `:nocopy` o use un volume distinto, y arrancar sidekiq ahí. Pendiente de investigar.

### 2. Sólo ~3 GB efectivos para containers

El host tiene 7.6 GB visibles para WSL2. Con postgres (~100 MB), redis (~10 MB), rails (~300 MB), quedan ~3 GB. Vite precompile necesita 3 GB peak; **durante el precompile NO debe haber otros containers pesados corriendo**.

### 3. NODE_OPTIONS hardcodeado en imagen

Está fijado a `--max-old-space-size=3072` en `Dockerfile.patch`. Si necesitas
más (e.g. assets crecen mucho), rebuild con valor mayor.

### 4. Binario pnpm no está en el repo

Cada máquina que clone el repo debe descargarlo antes de buildear la imagen.
Está automatizado en `docker/patches/pnpm.README`. Si quieres automatizarlo,
añade un `setup.ps1` o `Makefile`.

### 5. WSL2 distro: sólo una (Ubuntu-Docker)

Las distros `docker-desktop` y `docker-desktop-data` siguen registradas pero
Stopped. No estorban pero ocupan ~10 GB en disco. Limpieza opcional:
```powershell
wsl --unregister docker-desktop-data
wsl --unregister docker-desktop
```

### 6. No hay HTTPS

Chatwoot sirve HTTP en `127.0.0.1:3000`. Para HTTPS (necesario para webhooks,
integraciones externas) hay que poner un reverse proxy (nginx, Caddy) delante.
Pendiente.

---

## Migrar a otro equipo

### Lo que necesitas copiar

**Archivos**:
- `C:\chatwoot\.env` (secretos)
- `C:\chatwoot\admin-credentials.txt` (admin login)
- `C:\chatwoot\docker\patches\pnpm` (binario, 64 MB) — opcional, regenerable

**Volumes Docker** (postgres, redis, storage):
- `chatwoot_postgres_data`
- `chatwoot_redis_data`
- `chatwoot_storage_data`

**WSL2 distro**: `Ubuntu-Docker` (exportable via `wsl --export`)

### Pasos

1. **Setup del nuevo host**: habilitar WSL2, instalar Docker Engine en Ubuntu (ver [Setup desde cero](#setup-desde-cero))
2. **Clonar el repo**:
   ```powershell
   git clone https://github.com/martinezruben/noxuchat-hermes.git C:\chatwoot
   ```
3. **Copiar `.env`** desde el backup
4. **Descargar pnpm** si no existe:
   ```powershell
   cd C:\chatwoot\docker\patches
   Invoke-WebRequest -UseBasicParsing -OutFile pnpm https://github.com/pnpm/pnpm/releases/download/v10.2.0/pnpm-linuxstatic-x64
   ```
5. **Build + up**:
   ```powershell
   & "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml build
   & "C:\Program Files\docker-wsl\docker.cmd" compose -f docker-compose.production.yaml up -d
   ```
6. **Crear admin** (o restaurar el admin-credentials.txt existente)
7. **Migrar volúmenes** (opcional, si quieres los datos del host anterior):
   - Exportar del host viejo: `docker run --rm -v chatwoot_postgres_data:/from -v $(pwd):/to alpine tar cvf /to/postgres.tar /from`
   - Importar al nuevo: inverso

---

## Recursos

- **Repo original**: https://github.com/chatwoot/chatwoot
- **Documentación oficial**: https://www.chatwoot.com/developers/
- **Docker Hub**: https://hub.docker.com/r/chatwoot/chatwoot
- **Este fork**: https://github.com/martinezruben/noxuchat-hermes
- **Hermes Agent**: https://hermes-agent.nousresearch.com/docs

---

## Changelog

- **2026-06-24**: Setup inicial. Parches aplicados: migración acts-as-taggable-on, pnpm+NODE_OPTIONS, postgres env_file, sidekiq removido. Stack estable, admin creado.
