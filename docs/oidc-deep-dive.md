# OIDC Authentication Deep Dive

## Why Not Client Secrets?

When you create a Service Principal in Azure and generate a client secret, that secret is a string that lives in your GitHub repository secrets. It has these problems:

1. **Expiration**: Secrets expire (1 year, 2 years, or custom). When they expire, your pipelines break silently at 2 AM on a Friday.
2. **Rotation complexity**: You need to update the secret in Azure AD AND in every GitHub repo that uses it.
3. **Blast radius**: If the secret leaks (logs, error messages, copy-paste accidents), anyone with that string can authenticate as your Service Principal until you revoke it.
4. **No scope binding**: The secret works from anywhere — your laptop, a different CI system, a compromised machine.

## How OIDC Solves This

OpenID Connect (OIDC) flips the authentication model:

```
┌──────────────┐     1. Request JWT      ┌──────────────┐
│   GitHub      │ ───────────────────────→│  GitHub OIDC  │
│   Actions     │                         │  Provider     │
│   Runner      │ ←──────────────────────│               │
│               │     2. JWT (short-lived)│               │
└───────┬───────┘                         └──────────────┘
        │
        │ 3. Present JWT
        ▼
┌──────────────┐     4. Validate claims   ┌──────────────┐
│   Azure AD   │ ───────────────────────→│  Federated    │
│              │                          │  Credential   │
│              │     5. Access Token       │  Config       │
│              │ ←───────────────────────│               │
└───────┬──────┘                          └──────────────┘
        │
        │ 6. Authenticated access
        ▼
┌──────────────┐
│   Azure      │
│   Resources  │
└──────────────┘
```

The JWT that GitHub issues contains claims like:

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:your-org/your-repo:ref:refs/heads/main",
  "aud": "api://AzureADTokenExchange",
  "ref": "refs/heads/main",
  "repository": "your-org/your-repo",
  "actor": "username",
  "workflow": "IaC: Bicep Deploy",
  "event_name": "push"
}
```

Azure AD checks that the `sub` claim matches one of the federated credentials you configured. If it matches, it issues a short-lived access token (valid for ~1 hour). If not, authentication fails.

## The Three Federated Credentials

This workshop configures three credentials because GitHub uses different `sub` claim formats depending on the context:

| Context | Subject claim format | Used by |
|---------|---------------------|---------|
| Pull Request | `repo:owner/repo:pull_request` | Plan / What-If jobs |
| Branch push | `repo:owner/repo:ref:refs/heads/main` | Direct push deployments |
| Environment | `repo:owner/repo:environment:production` | Environment-gated deploys |

The `environment` credential is critical: when a workflow job declares `environment: production`, GitHub mints the JWT with the environment subject. This means you can require approval gates on the `production` environment AND restrict which Azure resources that specific credential can access.

## What Happens in the Workflow

```yaml
permissions:
  id-token: write     # ← Allows the runner to request a JWT
  contents: read

steps:
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}      # Which app to authenticate as
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}       # Which Azure AD tenant
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}  # Target subscription
      # Note: NO client-secret parameter. That's the point.
```

The `azure/login` action handles the entire OIDC flow internally:
1. Requests a JWT from GitHub's OIDC provider
2. Exchanges it with Azure AD for an access token
3. Sets up the Azure CLI session with that token

## Security Implications

- **No stored secrets**: Nothing in the repo can be exfiltrated to gain Azure access
- **Scope bound**: The token only works from your specific repo, branch, or environment
- **Short-lived**: Access tokens expire in ~1 hour, JWTs in ~10 minutes
- **Auditable**: Every token request is logged in both GitHub and Azure AD
- **No rotation**: There's nothing to rotate, ever
