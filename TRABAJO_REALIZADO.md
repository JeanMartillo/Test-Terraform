# Resumen del Trabajo Realizado - 9 de Diciembre de 2025

## Objetivo General
Revisar, validar y mejorar el proyecto `joi-news` (una aplicación multi-servicio en Python con infraestructura Terraform en GCP). Se enfatizó en resolver problemas de tests, establecer automatización de CI/CD, y documentar buenas prácticas.

---

## 1. Análisis y Revisión del Proyecto

### 1.1 Exploración de la Estructura
- Identificó 3 subproyectos Python principales: `front-end`, `newsfeed`, `quotes`.
- Cada uno tiene su propio `requirements.txt`, módulo `api/` y tests (unit + integration).
- Infraestructura en Terraform dividida en `infra/base/` (VPC, Artifact Registry) e `infra/news/` (instancias compute, storage bucket).

### 1.2 Tests del Proyecto
Revisó los archivos de test:
- **front-end**: 8 tests (4 unit + 4 integration) — tests para `api.newsfeed.Newsfeed` y `api.quotes.Quotes`.
- **newsfeed**: 7 tests (2 unit + 5 integration) — parseo de feeds RSS, autenticación con token.
- **quotes**: 2 tests (2 integration) — endpoint `/api/quote` con respuestas JSON.

---

## 2. Arreglo de Problemas de Tests

### 2.1 Problema Inicial: Imports Rotos
**Síntoma**: `ModuleNotFoundError: No module named 'api'` al ejecutar `pytest` desde la raíz.

**Causa Raíz**:
- El módulo `api` está dentro de cada subproyecto (ej. `front-end/api`, `newsfeed/api`), no en la raíz.
- `PYTHONPATH` no incluía los subdirectorios que contienen `api`.

**Solución Aplicada**:
1. Creé un **virtualenv centralizado** (`.venv`) e instalé todas las dependencias:
   ```bash
   python3 -m venv .venv
   . .venv/bin/activate
   pip install -r front-end/requirements.txt -r newsfeed/requirements.txt -r quotes/requirements.txt
   ```

2. Limpié caches (`__pycache__`, `.pyc`) que causaban conflictos de importación.

3. Ejecuté tests **por subproyecto** con `PYTHONPATH` ajustado:
   ```bash
   cd front-end && PYTHONPATH=$PWD pytest -q
   cd newsfeed && PYTHONPATH=$PWD pytest -q
   cd quotes && PYTHONPATH=$PWD pytest -q
   ```

**Resultado**: Todos los tests pasaron (17 tests en total: 8 front-end + 7 newsfeed + 2 quotes).

### 2.2 Problema: Rutas Relativas en Provisioning
**Síntoma**: Tests en `quotes` fallaban con `FileNotFoundError: [Errno 2] No such file or directory: './resources/quotes.json'`.

**Causa**: El script de provisioning intentaba cargar archivos con rutas relativas, pero `pytest` se ejecutaba desde la raíz del proyecto.

**Solución**: Actualizar el script de testing para ejecutar `pytest` **desde dentro del directorio del subproyecto**, no desde la raíz.

---

## 3. Automatización de Tests

### 3.1 Script `scripts/run-tests.sh`
Creé un script bash que:
- Activa el virtualenv `.venv` si existe.
- Itera sobre `front-end`, `newsfeed`, `quotes`.
- Para cada subproyecto:
  - Establece `PYTHONPATH=$PWD/<subproject>`.
  - Ejecuta `cd $PWD/<subproject> && PYTHONPATH=... pytest -q`.
- Retorna código de salida diferente de 0 si algún subproyecto falla.

**Uso**:
```bash
cd /home/jean/projects/joi-news
. .venv/bin/activate
./scripts/run-tests.sh
```

### 3.2 Actualización de `Makefile`
Modificó el target `_%.test` para ejecutar tests desde dentro de cada directorio:
```makefile
_%.test:
	cd $* && python3 -m pip install -r requirements.txt && PYTHONPATH=$$PWD python3 -m pytest
```

Añadió un nuevo target `runtests` para ejecutar `_test` (atajos convenientes sin depender de `dojo`).

**Uso**:
```bash
. .venv/bin/activate
make runtests
```

**Resultado**: Todos los tests pasan al ejecutar `make runtests` o `./scripts/run-tests.sh`.

---

## 4. Revisión y Validación de Terraform

### 4.1 Inspección de Módulos
Revisó todos los archivos `.tf` en:
- **`infra/base/`**: VPC, subnets, router NAT, Artifact Registry, outputs.
- **`infra/news/`**: Instancias compute, firewall rules, bucket GCS estático, service account.

### 4.2 Validación con Terraform CLI
Ejecutó en ambos directorios:
```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

**Resultado**: Ambos módulos son válidos tras aplicar `terraform fmt`.

### 4.3 Hallazgos de Seguridad y Mejoras Recomendadas

#### Riesgos Identificados:
1. **Firewall rules abiertas**: Permiten `0.0.0.0/0` a puertos 8080, 8081, 8082.
   - Recomendación: Usar Load Balancer + Cloud Armor o restringir a rangos IP específicos.

2. **Service account scopes amplios**: Incluyen `cloud-platform.read_only`, viola principio de mínimo privilegio.
   - Recomendación: Usar IAM roles específicos en lugar de scopes amplios.

3. **Secretos hardcoded en scripts**: `provision-front_end.sh` incluye `NEWSFEED_SERVICE_TOKEN` en texto plano.
   - Recomendación: Usar Google Secret Manager y recuperar en startup scripts.

4. **`local_file` para `gcr-url.txt`**: Genera archivos en el módulo; puede requerir limpiar.
   - Recomendación: Usar outputs de Terraform o exportar en CI/CD.

---

## 5. Control de Versiones y Git

### 5.1 Commits Realizados
1. **Commit 1** (`a1750de`): Añadió `.terraform.lock.hcl` files y CI workflow inicial.
   ```
   chore(ci): add Terraform lockfiles and CI workflow (validate infra + run tests)
   ```

2. **Commit 2** (`833538b`): Cambios de infra y actualizaciones de Makefile/requirements.
   ```
   chore: apply infra review changes and CI workflow; update Makefile and requirements
   ```

3. **Commit 3** (`ba50355`): Añadió script de tests y `.gitignore`.
   ```
   chore: add scripts/run-tests.sh and .gitignore to ignore venv and caches
   ```

4. **Commit 4** (`842a281`): Workflow de Terraform plan con secretos de GCP.
   ```
   ci: add terraform plan job using GCP secrets (plan only, uploads plans)
   ```

### 5.2 Configuración de Remoto
- Agregó remoto `origin` → `https://github.com/JeanMartillo/Test-Terraform.git`.
- Empujó rama `master` a GitHub.

### 5.3 `.gitignore` Creado
Añadió entradas para:
```
.venv/
__pycache__/
*.pyc
```

---

## 6. CI/CD con GitHub Actions

### 6.1 Workflow: `.github/workflows/ci.yml`
Definió 2 jobs:

#### Job 1: `terraform` (siempre ejecuta)
- Ejecuta en `push` y `pull_request` a `main`/`master`.
- Para cada directorio `infra/base` e `infra/news`:
  - `terraform init -backend=false`
  - `terraform fmt -check -recursive`
  - `terraform validate`
- Propósito: Validar sintaxis y formato de Terraform sin tocar backend real.

#### Job 2: `tests` (siempre ejecuta, tras terraform)
- Crea virtualenv, instala dependencias.
- Ejecuta `./scripts/run-tests.sh`.
- Propósito: Ejecutar tests Python de todos los subproyectos.

#### Job 3: `terraform_plan` (condicional, si secrets presentes)
- Se ejecuta solo si GitHub Secrets están configurados: `GCP_CREDENTIALS`, `TF_STATE_BUCKET`, `TF_PROJECT`, `TF_REGION`.
- Pasos:
  1. Autentica con GCP usando `google-github-actions/setup-gcloud` + service account JSON.
  2. Ejecuta `terraform init` con backend real.
  3. Ejecuta `terraform plan` para `infra/base` e `infra/news`.
  4. Sube plan outputs como artefactos.
- Propósito: Validar cambios contra estado remoto, sin hacer `apply`.

### 6.2 Cómo Activar `terraform_plan`
1. En GitHub, ve a **Settings > Secrets and variables > Actions**.
2. Añade los siguientes secrets:
   - `GCP_CREDENTIALS`: JSON del service account (con permisos de Terraform).
   - `TF_STATE_BUCKET`: Nombre del bucket GCS para estado.
   - `TF_PROJECT`: ID del proyecto GCP.
   - `TF_REGION`: Región (ej. `us-central1`).
   - `RESOURCE_PREFIX` (opcional): Prefijo para nombres de recursos.

---

## 7. Dependencias y Versiones

### Python
- Python 3.12 (detectado en el entorno).
- Paquetes instalados:
  - Flask 3.0.0
  - pytest 7.1.2
  - iso8601 1.0.2
  - feedparser 6.0.11
  - Otras dependencias según `requirements.txt` de cada subproyecto.

### Terraform
- Versión: 1.12.2 (en el entorno local).
- Versión en workflow: 1.12.2 (ajustable en `.github/workflows/ci.yml`).
- Providers:
  - `hashicorp/google` 7.12.0
  - `hashicorp/google-beta` 7.12.0
  - `hashicorp/local` 2.6.1 (infra/base)
  - `hashicorp/template` 2.2.0 (infra/news)

---

## 8. Archivos Creados/Modificados

### Creados
- `.github/workflows/ci.yml` — Workflow de GitHub Actions para CI/CD.
- `scripts/run-tests.sh` — Script bash para ejecutar tests por subproyecto.
- `.gitignore` — Ignora `.venv`, `__pycache__`, `*.pyc`.
- `infra/base/.terraform.lock.hcl` — Lockfile de providers (versionado).
- `infra/news/.terraform.lock.hcl` — Lockfile de providers (versionado).

### Modificados
- `Makefile` — Actualizado target `_%.test` con `PYTHONPATH` y añadido `runtests`.
- `front-end/requirements.txt` — Deduplicada entrada `iso8601` (línea vacía eliminada).
- Varios archivos `.tf` en `infra/` — Formateo aplicado con `terraform fmt`.

---

## 9. Próximos Pasos Recomendados

1. **Agregar job de `apply` con aprobación manual**:
   - Usar `workflow_dispatch` o branch protection + required reviews.
   - Permitir `terraform apply` solo en circunstancias específicas.

2. **Implementar Secret Manager**:
   - Mover `NEWSFEED_SERVICE_TOKEN` y otros secretos a Google Secret Manager.
   - Actualizar `provision-*.sh` para recuperar secretos de forma segura.

3. **Mejorar seguridad de firewall**:
   - Usar Cloud Load Balancer + Cloud Armor.
   - Exponer solo puerto 443 (HTTPS) al público; servicios internos en puertos privados.

4. **Convertir subproyectos en paquetes instalables**:
   - Añadir `pyproject.toml` o `setup.py` a cada subproyecto.
   - Instalar con `pip install -e .` para simplificar imports y eliminar necesidad de `PYTHONPATH`.

5. **Documentación de despliegue**:
   - Crear `DEPLOY.md` con instrucciones paso a paso para provisionar infraestructura.
   - Incluir ejemplos de cómo proveer GCP credentials en diferentes entornos (local, CI/CD, etc.).

6. **Monitoreo y logging**:
   - Configurar Cloud Logging y Cloud Monitoring para las instancias.
   - Agregar health checks y alertas.

---

## 10. Comandos Útiles (Referencia Rápida)

### Setup Local
```bash
cd /home/jean/projects/joi-news
python3 -m venv .venv
. .venv/bin/activate
pip install -r front-end/requirements.txt -r newsfeed/requirements.txt -r quotes/requirements.txt
```

### Ejecutar Tests
```bash
# Opción 1: Script bash
./scripts/run-tests.sh

# Opción 2: Makefile
make runtests

# Opción 3: Por subproyecto
cd front-end && PYTHONPATH=$PWD pytest -q
cd ../newsfeed && PYTHONPATH=$PWD pytest -q
cd ../quotes && PYTHONPATH=$PWD pytest -q
```

### Validar Terraform
```bash
# infra/base
cd infra/base
terraform init -backend=false
terraform fmt -check -recursive
terraform validate

# infra/news
cd ../news
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

### Git
```bash
git status
git log --oneline
git push origin master
```

---

## Resumen de Impacto

| Área | Antes | Después |
|------|-------|---------|
| Tests | ❌ Fallaban por imports rotos | ✅ 17/17 tests pasan |
| Automatización | ❌ Sin CI/CD | ✅ Workflow de GA con validación TF + tests |
| Terraform | ⚠️ Sin validación sistemática | ✅ Validado, formatted, lockfiles versionados |
| Seguridad | ⚠️ Sin secretos seguros en CI | ✅ Job de plan con autenticación GCP |
| Documentación | ⚠️ Mínima | ✅ Este documento + comentarios en código |

---

**Fecha**: 9 de Diciembre de 2025  
**Estado**: Completado y empujado a GitHub  
**Repositorio**: https://github.com/JeanMartillo/Test-Terraform.git
