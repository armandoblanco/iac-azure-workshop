# Patrones de Workflow Explicados

## Patrón: Plan en PR, Despliegue en Merge

Este es el patrón central del workshop. Refleja cómo funciona la revisión de código, pero aplicado a infraestructura:

```
El desarrollador realiza un cambio de IaC
        │
        ▼
Abre Pull Request ──→ Workflow ejecuta Plan/What-If
        │                       │
        │               ┌───────▼───────┐
        │               │ Comentario PR:│
        │               │ "Creará       │
        │               │  3 recursos,  │
        │               │  modificará 1"│
        │               └───────────────┘
        │
El revisor lee el PR + la salida del Plan
        │
        ▼
Aprueba y hace merge ──→ Workflow ejecuta Deploy/Apply
                                │
                        ┌───────▼───────┐
                        │  Recursos     │
                        │  desplegados  │
                        │  en Azure     │
                        └───────────────┘
```

### Por Qué Esto Importa

Sin este patrón, descubres lo que hará tu IaC DESPUÉS de que se ejecute. Eso significa infraestructura rota, costos inesperados o eliminación accidental de recursos de producción. El patrón Plan-on-PR desplaza ese descubrimiento al momento de la revisión de código.

## Patrón: Disparadores Filtrados por Ruta

Cada workflow usa filtros `paths` para activarse solo cuando cambian archivos relevantes:

```yaml
on:
  push:
    branches: [main]
    paths: ["infra/bicep/**"]     # Solo los cambios de Bicep activan esto
```

Esto evita que el workflow de Bicep se ejecute cuando cambias archivos de Terraform y viceversa. También significa que los cambios en el código de la aplicación (`src/`) solo activan el workflow de build, no los de infraestructura.

## Patrón: Workflow Dispatch para Control Manual

Cada workflow incluye `workflow_dispatch`, que agrega un botón "Run workflow" en la pestaña de Actions:

```yaml
on:
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options:
          - plan
          - apply
          - destroy
```

Esto cumple dos propósitos:
1. **Workshop**: Los participantes pueden activar workflows manualmente para entender cada paso
2. **Operaciones**: Los equipos pueden ejecutar planes ad-hoc o destruir entornos sin hacer push de código

## Patrón: Reglas de Protección de Entorno

Los jobs de deploy/apply declaran `environment: production`:

```yaml
deploy:
  environment: production
  # ...
```

Esto hace tres cosas:
1. Requiere aprobación de revisores designados antes de que el job se ejecute
2. Usa la credencial federada OIDC específica del entorno
3. Crea un registro de auditoría de quién aprobó cada despliegue

## Patrón: Paso de Artefactos (Terraform)

El workflow de Terraform sube el plan como artefacto y lo descarga en el job de apply:

```
Job Plan                          Job Apply
   │                                 │
   ├── terraform plan -out=tfplan    │
   ├── upload-artifact (tfplan)      │
   │                                 │
   │         ┌───────────────────────┤
   │         │                       │
   │         │    download-artifact  ├──
   │         │    terraform apply    ├──
   │         │         tfplan        │
```

Esto garantiza que lo que fue aprobado en el plan es exactamente lo que se aplica. Sin esto, un nuevo commit entre el plan y el apply podría cambiar el resultado.

## Patrón: Bloqueos de Concurrencia (Terraform)

```yaml
concurrency:
  group: terraform-deploy
  cancel-in-progress: false
```

El estado de Terraform admite un solo escritor a la vez. La configuración de concurrencia pone en cola las ejecuciones paralelas en lugar de ejecutarlas simultáneamente (lo que causaría errores de bloqueo de estado) o cancelarlas (lo que podría dejar el estado en mal estado).

## Patrón: Bicep por Defecto, Terraform Opt-In

El workshop habilita los workflows de Bicep por defecto porque:
- No requiere configurar un backend de estado
- No requiere instalar herramientas adicionales
- Modelo operativo más simple para despliegues solo en Azure

Los disparadores de Terraform están comentados y pueden ser habilitados por el participante. Este diseño permite a los principiantes centrarse en el patrón de workflow sin la sobrecarga de la gestión de estado, mientras ofrece a los usuarios avanzados la experiencia completa de Terraform.
