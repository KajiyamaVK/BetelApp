# Mobile deploy — version bump obrigatório

**Toda mudança em `src/mobile/**` que for para main DEVE incluir bump de versão no `pubspec.yaml`.**

## Regra

Antes de commitar qualquer feature, fix, ou chore no app mobile:

1. Incrementar `versionName` (e.g. `1.0.3` → `1.0.4`) se a mudança é visível ao usuário ou muda comportamento
2. Sempre incrementar `versionCode` (`+N`) em 1 — a Play Store rejeita versionCodes repetidos

Formato: `version: <versionName>+<versionCode>`

## Por que

O pipeline Jenkins sobe automaticamente para o Play Store internal track ao detectar mudanças em `src/mobile/**`. Se o versionCode não for incrementado, o upload falha na Play Store com erro de versionCode duplicado — e o build inteiro é desperdiçado.

## Como aplicar

- Ao receber qualquer pedido de mudança no app mobile, verificar o `version:` atual em `pubspec.yaml` e incluir o bump no mesmo commit
- Nunca separar "bump" em commit posterior — o bump deve estar junto com a mudança que o motivou

## Changelog obrigatório (Play Store)

Junto com o bump de versionCode, **sempre** criar o arquivo de changelog:

```
src/mobile/fastlane/metadata/android/pt-BR/changelogs/<versionCode>.txt
```

O `pre-push` do repo **bloqueia** o push para main se o arquivo estiver ausente ou vazio.

- Máximo 500 caracteres (limite da Play Store)
- Escrever em português, para o usuário final — o que mudou, não como
- Exemplo: `Correção no player de áudio ao trocar de lição.`
