# 🏗️ IaC en Azure con GitHub Actions — Workshop

Despliega aplicaciones contenerizadas en Azure usando Infraestructura como Código (Bicep y Terraform) automatizada mediante GitHub Actions con autenticación OIDC.

> **Dos rutas de IaC, un mismo patrón de flujo.** Elige Bicep (habilitado por defecto) o Terraform — ambos siguen el mismo flujo PR → Plan/What-If → Merge → Deploy.

```
Rama de Feature → Pull Request → Plan/What-If (automático)
                                      ↓
                   Revisión de Código + Revisión de Infra
                                      ↓
                   Merge a main → Despliegue (automático)
```

## Qué Vas a Construir

| Componente | Descripción |
|-----------|-------------|
| **API** | .NET 8 Minimal API — CRUD de clientes y cuentas bancarias con Swagger UI |
| **Contenedor** | Imagen Docker multi-etapa enviada a Azure Container Registry |
| **Infraestructura** | Grupo de Recursos, ACR, App Service Plan, App Service para Contenedores |
| **CI/CD** | GitHub Actions con autenticación OIDC, plan en PR, despliegue en merge |
| **Opciones IaC** | Bicep (por defecto, activado automáticamente) y Terraform (despacho manual, opt-in automático) |

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                   Repositorio GitHub                     │
│                                                         │
│  src/BankApi/          ── .NET Minimal API + Dockerfile  │
│  infra/bicep/          ── Módulos Bicep (por defecto)    │
│  infra/terraform/      ── Configuración Terraform        │
│  .github/workflows/    ── 3 archivos de workflow         │
│  scripts/              ── Scripts de configuración       │
└────────────┬───────────────────────────┬────────────────┘
             │                           │
        PR abierto                 Merge a main
             │                           │
    ┌────────▼────────┐        ┌─────────▼─────────┐
    │  Plan / What-If │        │  Despliegue Azure  │
    │ (comentario PR) │        │                    │
    └─────────────────┘        └─────────▼─────────┘
                                         │
                          ┌──────────────┼──────────────┐
                          │              │              │
                    ┌─────▼─────┐ ┌──────▼─────┐ ┌─────▼──────┐
                    │    ACR    │ │ App Service │ │  App Svc   │
                    │ (imágenes)│ │   Plan (B1) │ │ Container  │
                    └───────────┘ └────────────┘ └────────────┘
```

## Estructura del Repositorio

```
.
├── .github/workflows/
│   ├── bicep-deploy.yml          # Bicep: what-if en PR, despliegue en merge
│   ├── terraform-deploy.yml      # Terraform: plan en PR, apply en merge
│   └── build-push-image.yml      # CI: construir contenedor, enviar a ACR
├── src/BankApi/
│   ├── Models/
│   │   ├── Customer.cs
│   │   └── Account.cs
│   ├── Services/
│   │   └── BankService.cs
│   ├── Program.cs
│   ├── BankApi.csproj
│   └── Dockerfile
├── infra/
│   ├── bicep/
│   │   ├── main.bicep            # Orquestador (nivel de suscripción)
│   │   ├── main.bicepparam       # Archivo de parámetros
│   │   └── modules/
│   │       ├── acr.bicep
│   │       ├── appserviceplan.bicep
│   │       └── appservice.bicep
│   └── terraform/
│       ├── main.tf               # Todos los recursos
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       └── backend.tf            # Estado remoto en Azure Storage
├── scripts/
│   ├── setup-oidc.sh             # Configura Azure AD + federación OIDC
│   ├── setup-tf-backend.sh       # Inicializa el backend remoto de Terraform
│   └── cleanup.sh                # Elimina todos los recursos
├── docs/
├── .gitignore
└── README.md
```

---

## Requisitos Previos

- Suscripción de Azure ([cuenta gratuita](https://azure.microsoft.com/free/))
- [Azure CLI](https://docs.microsoft.com/es-es/cli/azure/install-azure-cli) (v2.50+)
- [Cuenta de GitHub](https://github.com) con un repositorio nuevo o existente
- [Docker](https://docs.docker.com/get-docker/) (opcional, para pruebas locales)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.5+, solo si usas la ruta de Terraform)

---

## 🚀 Primeros Pasos

### Paso 0: Fork o Clonar

```bash
git clone https://github.com/<tu-org>/iac-azure-workshop.git
cd iac-azure-workshop
```

### Paso 1: Configurar Autenticación OIDC

Este es el paso más importante. OIDC reemplaza los secretos de cliente almacenados con tokens de corta duración que GitHub solicita a Azure AD en tiempo de ejecución. Nada que rotar, nada que filtrar.

```bash
az login

# Establece tu repositorio
export GITHUB_REPO="tu-usuario/iac-azure-workshop"

# Ejecuta la configuración
chmod +x scripts/setup-oidc.sh
./scripts/setup-oidc.sh
```

El script generará tres valores. Agrégalos como **Secretos del Repositorio de GitHub**:

| Secreto | Descripción |
|--------|-------------|
| `AZURE_CLIENT_ID` | ID de la aplicación de Azure AD (cliente) |
| `AZURE_TENANT_ID` | ID del tenant de Azure AD |
| `AZURE_SUBSCRIPTION_ID` | ID de la suscripción de Azure |

> **Settings → Secrets and variables → Actions → New repository secret**

### Paso 2: Crear el Entorno `production`

Los Entornos de GitHub habilitan puertas de aprobación antes de que se ejecuten los despliegues.

1. Ve a **Settings → Environments → New environment**
2. Nómbralo `production`
3. (Opcional) Agrégote a ti mismo como revisor requerido

### Paso 3: Elegir Tu Ruta

#### Ruta A: Bicep (Por Defecto — Sin Configuración Extra)

Bicep no requiere backend de estado remoto. Los workflows se activan automáticamente en PR y merge cuando cambian archivos bajo `infra/bicep/`.

Estás listo. Salta a [Ejecutar el Workshop](#-ejecutar-el-workshop).

#### Ruta B: Terraform (Requiere Configuración de Backend)

Terraform necesita un backend de estado remoto. Ejecuta el script de inicialización:

```bash
# Usa el APP_ID del Paso 1 para asignar RBAC automáticamente
export APP_ID="<tu-azure-ad-app-client-id>"

chmod +x scripts/setup-tf-backend.sh
./scripts/setup-tf-backend.sh
```

Luego habilita los disparadores automáticos descomentando líneas en `.github/workflows/terraform-deploy.yml`:

```yaml
on:
  push:                              # ← descomentar
    branches: [main]                 # ← descomentar
    paths: ["infra/terraform/**"]    # ← descomentar
  pull_request:                      # ← descomentar
    branches: [main]                 # ← descomentar
    paths: ["infra/terraform/**"]    # ← descomentar
  workflow_dispatch:
    # ...
```

---

## 🔄 Ejecutar el Workshop

### Ejercicio 1: Desplegar Infraestructura

#### Usando Bicep (automático)

1. Crea una rama de feature:
   ```bash
   git checkout -b feature/deploy-infra
   ```

2. Realiza un cambio en `infra/bicep/main.bicepparam` (p. ej., cambia el prefijo):
   ```bicep
   param prefix = 'miworkshop'
   ```

3. Haz push y crea un PR:
   ```bash
   git add -A && git commit -m "chore: actualizar parámetros bicep"
   git push origin feature/deploy-infra
   ```

4. Abre un Pull Request hacia `main`. Observa cómo se ejecuta el **Análisis What-If** y publica un comentario en tu PR mostrando exactamente qué recursos de Azure se crearán, modificarán o eliminarán.

5. Revisa la salida del What-If y luego haz merge del PR. El job de **Despliegue** se activa automáticamente.

#### Usando Bicep (despacho manual)

1. Ve a **Actions → IaC: Bicep Deploy → Run workflow**
2. Selecciona `what-if` para previsualizar, o `deploy` para ejecutar

#### Usando Terraform (despacho manual)

1. Ve a **Actions → IaC: Terraform Deploy → Run workflow**
2. Selecciona `plan` para previsualizar, `apply` para desplegar, o `destroy` para eliminar

### Ejercicio 2: Construir y Desplegar la Aplicación

Una vez que existe la infraestructura, despliega la API contenerizada:

1. Crea una rama y realiza cualquier cambio en un archivo bajo `src/`:
   ```bash
   git checkout -b feature/update-api
   # Realiza un cambio en src/BankApi/Program.cs
   git add -A && git commit -m "feat: actualizar api"
   git push origin feature/update-api
   ```

2. Abre un PR → la imagen se construye (pero aún no se envía)
3. Merge → la imagen se envía a ACR y App Service se actualiza automáticamente

4. Accede a tu API:
   ```
   https://app-<prefijo>-<hash>.azurewebsites.net/swagger
   ```

### Ejercicio 3: Observar Plan-on-PR

Aquí es donde el flujo demuestra su valor. Realiza un cambio de infraestructura y observa cómo el PR te muestra exactamente qué ocurrirá antes de hacer merge:

1. Cambia el SKU de App Service en `infra/bicep/modules/appserviceplan.bicep`:
   ```bicep
   param skuName string = 'S1'  // era B1
   ```

2. Haz push, crea el PR y lee el comentario del What-If. Verás el plan de actualización de B1 a S1 antes de que ocurra cualquier cambio real.

---

## 🔑 Cómo Funciona la Autenticación OIDC

Enfoque tradicional (inseguro):
```
Secreto GitHub (client_secret) → Login Azure → Despliegue
     ↑
  Puede filtrarse, debe rotarse, de larga duración
```

Enfoque OIDC (este workshop):
```
GitHub Actions solicita JWT → Azure AD valida el token → Acceso de corta duración
     ↑
  Sin secretos almacenados, token válido ~10 min, limitado al repositorio
```

El workflow declara `permissions: id-token: write`, lo que permite a GitHub generar un JWT. Azure AD verifica que el claim `subject` del token coincida con la credencial federada (repositorio, rama o entorno) y emite un token de acceso de corta duración.

Se configuran tres credenciales federadas:
- `repo:<owner>/<repo>:pull_request` — para plan/what-if en PRs
- `repo:<owner>/<repo>:ref:refs/heads/main` — para pushes a main
- `repo:<owner>/<repo>:environment:production` — para despliegues con puerta de entorno

---

## 📊 Bicep vs Terraform: Cuándo Usar Cada Uno

| Aspecto | Bicep | Terraform |
|--------|-------|-----------|
| **Gestión de estado** | Ninguna (Azure lo gestiona) | Backend remoto requerido |
| **Multi-nube** | Solo Azure | AWS, GCP, Azure, etc. |
| **Curva de aprendizaje** | Menor para equipos nativos de Azure | Moderada, pero universal |
| **Previsualizar cambios** | `what-if` | `plan` |
| **Detección de deriva** | No integrada | `plan` detecta deriva |
| **Ecosistema de módulos** | Azure Verified Modules | Terraform Registry (enorme) |
| **Flujo de destrucción** | Manual vía CLI | `terraform destroy` en pipeline |
| **Herramientas** | Sin instalación (integrado en Azure CLI) | Requiere binario de terraform |

Para despliegues solo en Azure, Bicep tiene menos sobrecarga operativa. Para multi-nube o equipos ya invertidos en el ecosistema de HashiCorp, Terraform es la elección pragmática.

---

## 🧹 Limpieza

Elimina todos los recursos de Azure creados por este workshop:

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

O usa el workflow de destrucción de Terraform:
1. **Actions → IaC: Terraform Deploy → Run workflow → destroy**

---

## Referencia de Workflows

| Workflow | Disparador | Acción en PR | Acción en Merge |
|----------|---------|-----------|--------------|
| `bicep-deploy.yml` | Auto en `infra/bicep/**` | What-If → comentario en PR | Despliegue |
| `terraform-deploy.yml` | Manual (opt-in auto) | Plan → comentario en PR | Apply |
| `build-push-image.yml` | Auto en `src/**` | Build (sin push) | Build + Push + Actualizar App |

Los tres workflows soportan `workflow_dispatch` para ejecución manual desde la pestaña de Actions.

---

## Solución de Problemas

**"AADSTS70021: No matching federated identity record found"**
El claim subject de OIDC no coincide con ninguna credencial federada. Verifica que:
- El nombre del repositorio en la credencial federada coincida exactamente con tu repositorio
- Para PRs: exista la credencial con tipo de entidad `pull_request`
- Para despliegues con entorno: exista la credencial del entorno `production`

**"Error: Backend configuration changed"** (Terraform)
Ejecuta `terraform init -reconfigure` en el directorio de Terraform.

**App Service muestra "Application Error"**
Verifica que la imagen del contenedor exista en ACR y que `WEBSITES_PORT` esté configurado en `8080`.

---

## Licencia

MIT

---

> Creado para workshops prácticos de IaC. Forkéalo, rómpelo, aprende de ello.
