# 🏗️ IaC en Azure con GitHub Actions — Workshop

Este repositorio es un workshop práctico para aprender a desplegar infraestructura en Azure de forma automatizada, segura y reproducible usando **Infraestructura como Código (IaC)** y **GitHub Actions**.

A lo largo del workshop construirás y desplegarás una API bancaria contenerizada en Azure, recorriendo el mismo flujo de trabajo que usan los equipos de plataforma en producción: cambios revisados mediante Pull Request, previsualización del impacto en infraestructura antes de hacer merge, y despliegue automático al aprobar.

> **¿Por qué este workshop?** Muchos tutoriales enseñan a crear recursos en Azure desde el portal o con scripts. Este workshop te enseña el patrón correcto para entornos reales: infraestructura versionada, revisada en equipo y desplegada de forma automática y auditada.

## ¿Qué aprenderás?

Al completar este workshop serás capaz de:

- Escribir infraestructura en **Bicep** y en **Terraform** para recursos de Azure.
- Configurar **autenticación OIDC** entre GitHub Actions y Azure, eliminando por completo el uso de secretos de cliente de larga duración.
- Diseñar un pipeline de CI/CD que **previsualiza los cambios de infraestructura en el Pull Request** antes de aplicarlos en producción.
- Construir y publicar una imagen Docker en **Azure Container Registry** y desplegarla en **Azure App Service** de forma automática.
- Entender cuándo conviene usar Bicep y cuándo Terraform.

## Flujo de trabajo general

El workshop gira en torno a un patrón central: **todo cambio pasa por Pull Request antes de llegar a producción**, tanto para el código de la aplicación como para la infraestructura.

```
Rama de Feature → Pull Request → Plan/What-If (automático)
                                       ↓
                    Revisión de Código + Revisión de Infra
                                       ↓
                    Merge a main → Despliegue (automático)
```

Cuando abres un Pull Request que modifica archivos de infraestructura (`infra/bicep/**` o `infra/terraform/**`), el workflow automáticamente ejecuta un análisis de impacto (Bicep What-If o Terraform Plan) y publica el resultado como comentario en el PR. Así el revisor ve exactamente qué recursos de Azure se crearán, modificarán o eliminarán antes de aprobar el merge.

## Qué vas a construir

El workshop utiliza una API bancaria simulada como aplicación de ejemplo. No es el foco del aprendizaje, sino el vehículo para practicar el pipeline completo.

| Componente | Descripción |
|---|---|
| **API de ejemplo** | .NET 8 Minimal API con operaciones CRUD de clientes y cuentas. Incluye Swagger UI para explorar los endpoints. |
| **Imagen Docker** | La API se empaqueta en una imagen Docker multi-etapa optimizada para producción. |
| **Azure Container Registry** | Registro privado de contenedores donde se almacenan las imágenes construidas por el pipeline. |
| **Azure App Service** | Servicio PaaS donde se ejecuta el contenedor. Recibe actualizaciones automáticas cuando una nueva imagen llega al ACR. |
| **Infraestructura como Código** | Todos los recursos anteriores se definen en código, en dos sabores: **Bicep** (nativo de Azure, activo por defecto) y **Terraform** (multi-nube, opt-in). |
| **Pipeline CI/CD** | Tres workflows de GitHub Actions que separan responsabilidades: construir imagen, desplegar infraestructura y desplegar aplicación. |

## Arquitectura

El diagrama siguiente muestra cómo se relacionan los componentes. El repositorio de GitHub es el punto de partida; cada cambio fluye a través del pipeline hasta llegar a los recursos en Azure.

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
    │ (comentario PR) │        │  (automático)      │
    └─────────────────┘        └─────────▼─────────┘
                                         │
                          ┌──────────────┼──────────────┐
                          │              │              │
                    ┌─────▼─────┐ ┌──────▼──────┐ ┌────▼───────┐
                    │    ACR    │ │ App Service │ │  App Svc   │
                    │ (imágenes)│ │    Plan     │ │ Container  │
                    └───────────┘ └─────────────┘ └────────────┘
```

## Estructura del repositorio

El repositorio está organizado para separar claramente las responsabilidades: código de aplicación, infraestructura, pipelines y scripts de utilidad.

```
.
├── .github/workflows/
│   ├── bicep-deploy.yml          # IaC con Bicep: what-if en PR, despliegue en merge
│   ├── terraform-deploy.yml      # IaC con Terraform: plan en PR, apply en merge
│   └── build-push-image.yml      # CI: construir imagen Docker y publicarla en ACR
├── src/BankApi/
│   ├── Models/                   # Modelos de datos (Customer, Account)
│   ├── Services/                 # Lógica de negocio (BankService)
│   ├── Program.cs                # Definición de endpoints con Minimal API
│   ├── BankApi.csproj
│   └── Dockerfile                # Imagen multi-etapa (build → runtime)
├── infra/
│   ├── bicep/
│   │   ├── main.bicep            # Orquestador al nivel de suscripción
│   │   ├── main.bicepparam       # Parámetros configurables (prefijo, región, etc.)
│   │   └── modules/
│   │       ├── acr.bicep         # Azure Container Registry
│   │       ├── appserviceplan.bicep
│   │       └── appservice.bicep  # App Service configurado para contenedores
│   └── terraform/
│       ├── main.tf               # Definición de todos los recursos
│       ├── variables.tf          # Variables de entrada
│       ├── outputs.tf            # Valores exportados tras el despliegue
│       ├── providers.tf          # Configuración del proveedor AzureRM
│       └── backend.tf            # Backend remoto en Azure Storage
├── scripts/
│   ├── setup-oidc.sh             # Crea la app en Azure AD y configura la federación OIDC
│   ├── setup-tf-backend.sh       # Crea el Storage Account para el estado de Terraform
│   └── cleanup.sh                # Elimina todos los recursos creados
├── docs/
│   ├── oidc-deep-dive.md         # Explicación detallada de la autenticación OIDC
│   └── workflow-patterns.md      # Patrones de workflow de GitHub Actions
├── .gitignore
└── README.md
```

---

## Requisitos previos

Antes de empezar, asegúrate de tener lo siguiente:

| Herramienta | Versión mínima | Para qué se usa |
|---|---|---|
| [Azure CLI](https://docs.microsoft.com/es-es/cli/azure/install-azure-cli) | 2.50+ | Autenticarse en Azure y ejecutar los scripts de configuración |
| [Cuenta de GitHub](https://github.com) | — | Alojar el repositorio y ejecutar los workflows |
| Suscripción de Azure | — | Crear los recursos en la nube ([cuenta gratuita](https://azure.microsoft.com/free/)) |
| [Docker](https://docs.docker.com/get-docker/) | — | Solo si quieres probar la imagen localmente antes de hacer push |
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | 1.5+ | Solo si eliges la ruta de Terraform (Ruta B) |

> **Nota sobre permisos:** Tu cuenta de Azure necesita el rol **Owner** en la suscripción (o al menos **Contributor** + **User Access Administrator**). Esto es necesario para que el script de OIDC pueda asignar roles al service principal.

---

## 🚀 Configuración inicial

Sigue estos pasos en orden. Una vez completados, el pipeline funcionará de forma completamente automática.

### Paso 0: Fork y clonar el repositorio

Haz fork de este repositorio en tu cuenta u organización de GitHub, luego clónalo localmente:

```bash
git clone https://github.com/<tu-org>/iac-azure-workshop.git
cd iac-azure-workshop
```

> Es importante hacer **fork** (no solo clonar) para que los workflows de GitHub Actions tengan permisos de escritura en tu repositorio y puedan publicar comentarios en los Pull Requests.

### Paso 1: Configurar la autenticación OIDC entre GitHub y Azure

Este es el paso más importante del workshop y el que más valor aporta en entornos reales.

**¿Por qué OIDC?** La forma tradicional de autenticar GitHub Actions contra Azure es guardar un `client_secret` como secreto de GitHub. Esto tiene problemas: el secreto tiene larga duración, debe rotarse manualmente y si se filtra compromete toda la suscripción. OIDC elimina este problema completamente: en lugar de secretos, GitHub obtiene un token JWT firmado de corta duración (~10 minutos) que Azure AD valida. No hay nada que rotar ni que filtrar.

El script `setup-oidc.sh` automatiza la configuración completa:
- Crea una aplicación en Azure AD
- Asigna el rol **Contributor** en la suscripción
- Configura tres credenciales federadas (para PRs, para pushes a main y para el entorno production)
- Añade los secretos necesarios a tu repositorio de GitHub

```bash
# Autentícate en Azure
az login

# Indica a qué repositorio de GitHub debe conectarse
export GITHUB_REPO="tu-usuario/iac-azure-workshop"

# Ejecuta el script de configuración
chmod +x scripts/setup-oidc.sh
./scripts/setup-oidc.sh
```

El script configurará automáticamente los siguientes secretos en tu repositorio:

| Secreto | Descripción |
|---|---|
| `AZURE_CLIENT_ID` | ID de la aplicación creada en Azure AD |
| `AZURE_TENANT_ID` | ID del tenant (directorio) de Azure AD |
| `AZURE_SUBSCRIPTION_ID` | ID de la suscripción donde se crearán los recursos |

Puedes verificarlos en: **Settings → Secrets and variables → Actions**

### Paso 2: Crear el entorno `production` en GitHub

Los Entornos de GitHub permiten añadir una puerta de aprobación manual antes de que se ejecuten los despliegues a producción. Aunque es opcional para el workshop, es una práctica recomendada en proyectos reales.

1. Ve a **Settings → Environments → New environment**
2. Ponle el nombre exacto `production` (el workflow referencia este nombre)
3. Opcionalmente, agrégrate como **revisor requerido** para que los despliegues esperen tu aprobación

### Paso 3: Elegir tu herramienta de IaC

Este workshop soporta dos herramientas de IaC. Elige la que más te interese aprender, o practica con ambas. El flujo de trabajo (PR → plan → merge → deploy) es idéntico en ambas.

#### Ruta A: Bicep (recomendada para empezar — sin configuración extra)

Bicep es el lenguaje nativo de Azure para IaC. No necesita gestionar estado porque Azure lo hace internamente. Los workflows se activan automáticamente cuando hay cambios en `infra/bicep/`.

No necesitas hacer nada más. Continúa con el siguiente paso.

#### Ruta B: Terraform (requiere configuración de backend)

Terraform necesita almacenar el estado de los recursos en un lugar persistente. El script `setup-tf-backend.sh` crea un Azure Storage Account para este fin y configura los secretos necesarios.

```bash
# Usa el CLIENT_ID generado en el Paso 1
export APP_ID="<AZURE_CLIENT_ID del paso anterior>"

chmod +x scripts/setup-tf-backend.sh
./scripts/setup-tf-backend.sh
```

Por defecto, el workflow de Terraform está configurado para ejecutarse solo manualmente (via `workflow_dispatch`). Si quieres que se active automáticamente en PR y merge como Bicep, descomenta las siguientes líneas en `.github/workflows/terraform-deploy.yml`:

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

## 🔄 Ejercicios del workshop

Los ejercicios están diseñados para completarse en orden. Cada uno construye sobre el anterior.

---

### Ejercicio 1: Desplegar la infraestructura

**Objetivo:** Crear todos los recursos de Azure (grupo de recursos, ACR, App Service Plan y App Service) usando IaC y ver cómo el workflow publica el plan en el Pull Request.

#### Con Bicep (flujo automático recomendado)

1. Crea una rama de feature. Por convención, los cambios de infraestructura nunca van directamente a `main`:
   ```bash
   git checkout -b feature/deploy-infra
   ```

2. Abre `infra/bicep/main.bicepparam` y personaliza el prefijo. Este valor se usará como parte del nombre de todos los recursos:
   ```bicep
   param prefix = 'miworkshop'
   ```

3. Haz commit y push de tu cambio:
   ```bash
   git add infra/bicep/main.bicepparam
   git commit -m "chore: configurar prefijo de recursos"
   git push origin feature/deploy-infra
   ```

4. Abre un **Pull Request** hacia `main` en GitHub. En cuestión de segundos verás que el workflow `bicep-deploy.yml` se activa automáticamente. Espera a que termine y busca el **comentario automático** que publica en el PR con el resultado del análisis What-If. El comentario muestra exactamente qué recursos se crearán, modificarán o eliminarán en Azure.

5. Revisa el comentario del What-If. Una vez que estés conforme, haz **merge**. El workflow detecta el merge a `main` y ejecuta automáticamente el despliegue real. En unos minutos, todos los recursos estarán creados en Azure.

#### Con Bicep (ejecución manual)

Si prefieres no trabajar con ramas por ahora, también puedes ejecutar el workflow directamente:
1. Ve a **Actions → IaC: Bicep Deploy → Run workflow**
2. Selecciona `what-if` para previsualizar sin desplegar, o `deploy` para crear los recursos

#### Con Terraform (ejecución manual)

1. Ve a **Actions → IaC: Terraform Deploy → Run workflow**
2. Selecciona `plan` para previsualizar, `apply` para desplegar, o `destroy` para eliminar todos los recursos

---

### Ejercicio 2: Construir y desplegar la aplicación

**Objetivo:** Ver el flujo completo de CI/CD para la aplicación: construcción de la imagen Docker, publicación en ACR y actualización automática del App Service.

> **Prerequisito:** Completa el Ejercicio 1 primero. El App Service debe estar creado antes de poder desplegar la aplicación.

1. Crea una rama y realiza cualquier cambio en el código de la aplicación (bajo `src/`). Puede ser algo tan simple como añadir un cliente de ejemplo en `BankService.cs`:
   ```bash
   git checkout -b feature/update-api
   # Realiza tu cambio en src/
   git add src/
   git commit -m "feat: actualizar datos de ejemplo"
   git push origin feature/update-api
   ```

2. Abre un **Pull Request**. El workflow `build-push-image.yml` se activa, construye la imagen Docker y verifica que compila correctamente. Sin embargo, en esta fase **no publica la imagen** en el ACR. Esto es intencional: evita contaminar el registro con imágenes de código no aprobado.

3. Haz **merge** del PR. Ahora sí: la imagen se construye, se publica en ACR con el SHA del commit como etiqueta, y el App Service se actualiza automáticamente para usar la nueva imagen.

4. Accede a tu API en el navegador (sustituye por tu URL real):
   ```
   https://app-<prefijo>-<hash>.azurewebsites.net/swagger
   ```

---

### Ejercicio 3: Observar el plan-on-PR en acción

**Objetivo:** Entender el valor central del workshop — ver el impacto de un cambio de infraestructura *antes* de aplicarlo.

En este ejercicio realizarás un cambio que modifica un recurso existente (no lo crea desde cero) y observarás cómo el PR te muestra exactamente qué va a cambiar.

1. Crea una rama y abre `infra/bicep/modules/appserviceplan.bicep`. Cambia el SKU del plan:
   ```bicep
   param skuName string = 'P1v3'  // cambia desde S1
   ```

2. Haz commit, push y abre un Pull Request:
   ```bash
   git checkout -b feature/upgrade-plan
   git add infra/bicep/modules/appserviceplan.bicep
   git commit -m "perf: actualizar plan a P1v3"
   git push origin feature/upgrade-plan
   ```

3. Observa el comentario del What-If en el PR. Verás que describe una **modificación** del App Service Plan existente (no una eliminación y recreación). La salida muestra el valor anterior (`S1`) y el nuevo (`P1v3`). Esto te permite revisar el impacto antes de aprobar.

4. Si no quieres aplicar el cambio, simplemente cierra el PR sin hacer merge. Los recursos en Azure permanecen sin cambios.

---

## 🔑 Cómo funciona la autenticación OIDC

Este es el concepto más importante del workshop. Vale la pena entenderlo bien porque es el estándar de la industria para autenticar pipelines de CI/CD contra proveedores cloud.

**Enfoque tradicional (problemático):**
```
Secreto GitHub (client_secret) → Login Azure → Despliegue
         ↑
   Válido durante 1-2 años. Si se filtra en un log
   o en el historial de git, la suscripción queda expuesta.
   Alguien tiene que acordarse de rotarlo.
```

**Enfoque OIDC (este workshop):**
```
GitHub solicita JWT firmado → Azure AD valida el token → Token de acceso ~10 min
         ↑
   No hay secretos almacenados. Cada ejecución genera
   un token nuevo. Aunque alguien lo intercepte, expira
   en minutos y solo sirve para este repositorio.
```

**¿Cómo funciona técnicamente?**

1. El workflow declara `permissions: id-token: write`. Esto autoriza a GitHub a generar un token JWT firmado para esa ejecución.
2. La acción `azure/login` solicita ese JWT a GitHub y lo envía a Azure AD.
3. Azure AD comprueba que el claim `subject` del JWT coincida con alguna de las **credenciales federadas** registradas. El subject incluye el repositorio, la rama o el entorno desde donde se ejecuta el workflow.
4. Si coincide, Azure AD emite un token de acceso de corta duración.

Las tres credenciales federadas que configura el script cubren los tres contextos de ejecución:

| Credencial federada | Cuándo se usa |
|---|---|
| `repo:<owner>/<repo>:pull_request` | Workflows que se ejecutan en contexto de PR (para el what-if/plan) |
| `repo:<owner>/<repo>:ref:refs/heads/main` | Workflows que se ejecutan tras merge a main (para el despliegue) |
| `repo:<owner>/<repo>:environment:production` | Workflows que usan el entorno `production` con aprobación manual |

Para una explicación más detallada, incluyendo la anatomía del JWT y cómo depurar errores comunes, consulta [docs/oidc-deep-dive.md](docs/oidc-deep-dive.md).

---

## 📊 Bicep vs Terraform: cuándo usar cada uno

Una pregunta frecuente en equipos que trabajan con Azure es cuándo usar Bicep y cuándo Terraform. La respuesta depende principalmente del contexto del equipo, no de las capacidades técnicas de cada herramienta.

| Aspecto | Bicep | Terraform |
|---|---|---|
| **Gestión de estado** | No requiere estado externo (lo gestiona Azure internamente) | Requiere un backend remoto para almacenar el estado |
| **Multi-nube** | Solo Azure | AWS, GCP, Azure y más de 3000 providers |
| **Curva de aprendizaje** | Menor si el equipo ya conoce Azure | Moderada, pero el conocimiento es transferible a cualquier nube |
| **Previsualizar cambios** | Comando `what-if` nativo en Azure CLI | Comando `plan` integrado en el flujo de trabajo |
| **Detectar deriva** | No integrado (requiere scripts adicionales) | `terraform plan` detecta diferencias entre el estado y la realidad |
| **Módulos reutilizables** | Azure Verified Modules (catálogo oficial de Microsoft) | Terraform Registry (enorme ecosistema comunitario) |
| **Eliminar recursos** | Manual desde CLI o portal | `terraform destroy` automatizable en pipeline |
| **Instalación** | Incluido en Azure CLI, sin instalación adicional | Requiere instalar el binario de Terraform |

**Recomendación práctica:**
- Elige **Bicep** si tu equipo trabaja exclusivamente con Azure y quieres la opción con menos configuración inicial.
- Elige **Terraform** si tu organización ya usa HashiCorp, si necesitas gestionar recursos fuera de Azure, o si valoras el ecosistema de módulos comunitarios.
- En proyectos reales, **no hay respuesta incorrecta**: el patrón de flujo (PR → plan → merge → deploy) que enseña este workshop aplica igual a los dos.

---

## 🧹 Limpieza de recursos

Cuando termines el workshop, elimina los recursos de Azure para evitar costes innecesarios. Tienes dos opciones:

**Opción 1 — Script de limpieza** (elimina el grupo de recursos y la app de Azure AD):
```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

**Opción 2 — Workflow de Terraform** (solo si usaste la ruta Terraform):
1. Ve a **Actions → IaC: Terraform Deploy → Run workflow**
2. Selecciona la acción `destroy` y confirma

> **Importante:** El script de limpieza elimina también la aplicación de Azure AD creada para OIDC. Si quieres reutilizarla en el futuro, ejecuta `az ad app delete --id <AZURE_CLIENT_ID>` manualmente en lugar de usar el script.

---

## Referencia de workflows

El repositorio incluye tres workflows independientes, cada uno con una responsabilidad clara:

| Workflow | Activador automático | Qué hace en un PR | Qué hace al hacer merge |
|---|---|---|---|
| `bicep-deploy.yml` | Cambios en `infra/bicep/**` | Ejecuta `az deployment sub what-if` y publica el resultado como comentario | Despliega la infraestructura con `az deployment sub create` |
| `terraform-deploy.yml` | Manual por defecto (opt-in automático) | Ejecuta `terraform plan` y publica el resultado como comentario | Ejecuta `terraform apply -auto-approve` |
| `build-push-image.yml` | Cambios en `src/**` | Construye la imagen Docker para verificar que compila | Construye, tagea con el SHA del commit, publica en ACR y actualiza el App Service |

Los tres workflows pueden ejecutarse manualmente desde **Actions → [nombre del workflow] → Run workflow**, lo que es útil para el primer despliegue o para depurar.

---

## Solución de problemas

Estos son los errores más comunes y cómo resolverlos:

---

**`AADSTS70021: No matching federated identity record found`**

Este error aparece en el paso de `azure/login` y significa que el `subject` del token JWT de GitHub no coincide con ninguna credencial federada registrada en Azure AD.

Causas frecuentes:
- El nombre del repositorio en la credencial federada no coincide exactamente (distingue mayúsculas/minúsculas).
- Estás ejecutando el workflow desde un contexto no cubierto: por ejemplo, desde una rama distinta a `main` sin una credencial que la cubra.
- La credencial para PRs no está configurada: falta la de tipo `pull_request`.

Solución: Ejecuta de nuevo `setup-oidc.sh` o verifica las credenciales federadas en el portal de Azure en **Azure AD → Registros de aplicaciones → [tu app] → Certificados y secretos → Credenciales federadas**.

---

**`Error: Backend configuration changed`** (Terraform)

Ocurre cuando el archivo `backend.tf` cambió o cuando inicializas desde una máquina nueva. Terraform detecta que la configuración del backend es diferente a la que se usó la última vez.

Solución:
```bash
cd infra/terraform
terraform init -reconfigure
```

---

**App Service muestra "Application Error" o error 503**

El contenedor no pudo iniciarse. Las causas más comunes son:

1. **La imagen no llegó al ACR correcto.** Verifica con:
   ```bash
   az acr repository list --name <nombre-del-acr> -o table
   ```
2. **El workflow de build guardó la imagen en un ACR equivocado** si hay varios ACR en la suscripción. Asegúrate de que el workflow filtre por grupo de recursos: `az acr list --resource-group <rg> --query "[0].name"`.
3. **El puerto no coincide.** La API escucha en el puerto `8080`. Verifica que `WEBSITES_PORT=8080` esté configurado en las variables de entorno del App Service:
   ```bash
   az webapp config appsettings list --name <app> --resource-group <rg> --query "[?name=='WEBSITES_PORT']"
   ```

---

## Recursos adicionales

Para profundizar en los conceptos de este workshop:

- [docs/oidc-deep-dive.md](docs/oidc-deep-dive.md) — Explicación detallada de cómo funciona OIDC, anatomía del JWT y cómo depurar errores de autenticación.
- [docs/workflow-patterns.md](docs/workflow-patterns.md) — Patrones avanzados de GitHub Actions: matrices, reutilización de workflows, concurrencia y estrategias de aprobación.
- [Documentación oficial de Bicep](https://learn.microsoft.com/es-es/azure/azure-resource-manager/bicep/)
- [Documentación oficial de Terraform en Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions: Seguridad con OIDC](https://docs.github.com/es/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## Licencia

MIT

---

> Creado para workshops prácticos de IaC. Forkéalo, rómpelo, aprende de ello.
