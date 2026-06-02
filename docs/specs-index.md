# Specs Index

Este arquivo é o ponto de entrada para todas as specs do projeto. A IA deve consultá-lo no início de qualquer sessão de trabalho para identificar quais specs são relevantes para a task em questão.

## Como usar

1. Leia este index para identificar specs relevantes ao domínio da task
2. Leia as specs identificadas antes de tomar qualquer decisão de implementação
3. Em caso de conflito entre uma spec e o código existente, sinalize explicitamente antes de prosseguir
4. Ao final da sessão, sugira atualizações para specs que foram impactadas pelo trabalho realizado

## Specs por projeto

### Infraestrutura compartilhada (`docs/specs/`)

| Arquivo | Governa |
|---------|---------|
| `infra.md` | CI/CD pipeline (Jenkins), Docker Compose, hosting, topologia de serviços, scripts compartilhados |

### Mobile (`src/mobile/specs/`)

| Arquivo | Governa |
|---------|---------|
| `ui.md` | Navegação, componentes visuais, comportamento de telas, padrões de interação |
| `business.md` | Fluxos, validações, comportamentos da aplicação independente de UI ou dados |
| `data.md` | Modelos locais, sincronização com API, cache, persistência |
| `infra.md` | Signing, Play Store deploy, CI Docker image, Fastlane, Gradle config |

### S3-UI (`src/s3-ui/specs/`)

| Arquivo | Governa |
|---------|---------|
| `ui.md` | Componentes, layouts, padrões visuais, comportamento de telas do painel web |
| `business.md` | Fluxos de autenticação, permissões, validações, comportamentos do painel web |
| `data.md` | Modelos Prisma, queries, schema, integrações com S3/MinIO |
| `infra.md` | Dockerfile, build stages, Docker Compose, deploy, env vars |

### Backend (`src/backend/specs/`)

| Arquivo | Governa |
|---------|---------|
| `ui.md` | Contratos de API — formatos de request/response, convenções de endpoints |
| `business.md` | Lógica de domínio, fluxos de processamento, comportamentos dos serviços |
| `data.md` | Modelos, migrações, queries, integrações com bancos de dados |
| `infra.md` | Dockerfile, deploy, runtime config (quando implementado) |

## Regras de governança

- **Conflito spec vs código:** Sinalizar explicitamente ao usuário antes de prosseguir — nunca resolver silenciosamente
- **Spec desatualizada:** Sinalizar e sugerir atualização ao final da sessão
- **Decisão nova:** Registrar na spec correspondente antes de encerrar a sessão
- **Gap ou dívida técnica identificada:** Antes de registrar um ⚠️ na spec, verificar se já existe uma issue aberta no GitHub cobrindo o mesmo ponto. Se não existir, sugerir ao usuário a criação de uma issue para rastreamento
