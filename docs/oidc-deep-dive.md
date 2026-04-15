# Análisis Profundo de Autenticación OIDC

## ¿Por Qué No Usar Secretos de Cliente?

Cuando creas un Service Principal en Azure y generas un secreto de cliente, ese secreto es una cadena que vive en los secretos de tu repositorio de GitHub. Tiene estos problemas:

1. **Expiración**: Los secretos expiran (1 año, 2 años o personalizado). Cuando expiran, tus pipelines fallan silenciosamente a las 2 AM de un viernes.
2. **Complejidad de rotación**: Necesitas actualizar el secreto en Azure AD Y en cada repositorio de GitHub que lo use.
3. **Radio de impacto**: Si el secreto se filtra (logs, mensajes de error, accidentes de copiar-pegar), cualquiera con esa cadena puede autenticarse como tu Service Principal hasta que lo revoques.
4. **Sin vinculación de alcance**: El secreto funciona desde cualquier lugar — tu laptop, un sistema CI diferente, una máquina comprometida.

## Cómo OIDC Resuelve Esto

OpenID Connect (OIDC) invierte el modelo de autenticación:

```
┌──────────────┐     1. Solicitar JWT     ┌──────────────┐
│   GitHub     │ ──────────────────────►  │  Proveedor   │
│   Actions    │                          │  OIDC GitHub │
│   Runner     │  ◄──────────────────────  │              │
│              │     2. JWT (corta dur.)  │              │
└──────┬───────┘                          └──────────────┘
       │
       │ 3. Presentar JWT
       ▼
┌──────────────┐     4. Validar claims    ┌──────────────┐
│   Azure AD   │ ──────────────────────►  │  Credencial  │
│              │                          │  Federada    │
│              │     5. Token de Acceso   │  Config      │
│              │  ◄──────────────────────  │              │
└──────┬───────┘                          └──────────────┘
       │
       │ 6. Acceso autenticado
       ▼
┌──────────────┐
│   Recursos   │
│   Azure      │
└──────────────┘
```

El JWT que emite GitHub contiene claims como:

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:tu-org/tu-repo:ref:refs/heads/main",
  "aud": "api://AzureADTokenExchange",
  "ref": "refs/heads/main",
  "repository": "tu-org/tu-repo",
  "actor": "usuario",
  "workflow": "IaC: Bicep Deploy",
  "event_name": "push"
}
```

Azure AD verifica que el claim `sub` coincida con una de las credenciales federadas que configuraste. Si coincide, emite un token de acceso de corta duración (válido ~1 hora). Si no, la autenticación falla.

## Las Tres Credenciales Federadas

Este workshop configura tres credenciales porque GitHub usa diferentes formatos de claim `sub` según el contexto:

| Contexto | Formato del claim subject | Usado por |
|---------|---------------------|---------|
| Pull Request | `repo:owner/repo:pull_request` | Jobs de Plan / What-If |
| Push de rama | `repo:owner/repo:ref:refs/heads/main` | Despliegues por push directo |
| Entorno | `repo:owner/repo:environment:production` | Despliegues con puerta de entorno |

La credencial de `environment` es crítica: cuando un job de workflow declara `environment: production`, GitHub genera el JWT con el subject del entorno. Esto significa que puedes requerir puertas de aprobación en el entorno `production` Y restringir a qué recursos de Azure puede acceder esa credencial específica.

## Qué Ocurre en el Workflow

```yaml
permissions:
  id-token: write     # <- Permite al runner solicitar un JWT
  contents: read

steps:
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}      # Con qué app autenticarse
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}       # En qué tenant de Azure AD
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}  # Suscripción destino
      # Nota: SIN parámetro client-secret. Ese es el objetivo.
```

La action `azure/login` gestiona todo el flujo OIDC internamente:
1. Solicita un JWT al proveedor OIDC de GitHub
2. Lo intercambia con Azure AD por un token de acceso
3. Configura la sesión de Azure CLI con ese token

## Implicaciones de Seguridad

- **Sin secretos almacenados**: Nada en el repo puede ser exfiltrado para obtener acceso a Azure
- **Alcance vinculado**: El token solo funciona desde tu repo, rama o entorno específico
- **Corta duración**: Los tokens de acceso expiran en ~1 hora, los JWT en ~10 minutos
- **Auditable**: Cada solicitud de token queda registrada en GitHub y en Azure AD
- **Sin rotación**: No hay nada que rotar, nunca
