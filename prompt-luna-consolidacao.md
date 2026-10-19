# Prompt: consolidação + OpenSpec (SIMNEG-366)

NÃO ALTERE CÓDIGO. Esta sessão só trata documentação.

## Fontes

Leia nesta ordem, **uma vez cada**, e não releia arquivos inteiros depois:
1. `docs/discovery-simulacao/decisoes-consolidadas.md`: **fonte de verdade**. A seção 0 define a precedência entre todos os outros documentos.
2. `docs/discovery-simulacao/simulacao-post-request-example.json` (origem e default de cada campo).
3. `docs/discovery-simulacao/swaggers/` (Core e seguros).
4. `decisoes-pos-discovery.md`, `discovery-final-plano-revisado.md`, `spec-simulacao-bff.md`, `jira-story.txt`.

## Etapa 1: conflitos residuais

Procure **apenas** conflitos que `decisoes-consolidadas.md` NÃO resolve, incluindo o que surgir dos swaggers de seguros (sequência de composição de `produtosAgregados` com o 869).
- Não me pergunte nada que o arquivo já decidiu.
- Pergunte em caixas de pergunta, no máximo 4 por rodada. Cada caixa: o achado em 1 ou 2 linhas, as opções e qual você recomenda.
- Se não houver conflito residual, diga isso e siga para a Etapa 2.

Ao fim da Etapa 1, acrescente minhas respostas em `decisoes-consolidadas.md` (seção 1) e **pare** esperando meu "ok".

## Etapa 2: OpenSpec

Crie a change `simulacao-financiamento` seguindo as convenções de `openspec/` do repo: proposal, design, tasks e spec da capability.
- Para esta change, D1 vence `openspec/specs/hexagonal-arch` (layout legado).
- Premissas da seção 2 do arquivo consolidado entram no design como premissas explícitas, com o default adotado.
- Tasks na ordem dos passos 0 a 7 do discovery-final, ajustadas pelo arquivo consolidado.

## Etapa 3: limpeza

- Mova `spec-simulacao-bff.md`, `decisoes-pos-discovery.md` e `discovery-final-plano-revisado.md` para `docs/discovery-simulacao/historico/`, com esta primeira linha em cada: `> OBSOLETO. Fonte de verdade: openspec/changes/simulacao-financiamento. Não usar para implementação.`
- Gere `docs/discovery-simulacao/mudancas-story-po.md` a partir da seção 4 do consolidado, em texto pronto para eu enviar à PO.

## Regras

- Nunca invente valor. O que faltar vira premissa explícita ou pergunta.
- Respostas curtas: diga o que mudou e onde, sem repetir o conteúdo dos arquivos.
