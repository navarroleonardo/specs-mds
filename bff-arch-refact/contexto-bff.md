# Contexto do BFF (handoff)

Documento de contextualização para iniciar o trabalho de refatoração. Ler junto com `estrategia-refatoracao.md`.

## Aplicação

BFF em Java, artefato único, atendendo um canal. Regra vigente na organização: um BFF por canal, e não se cria novo BFF para um canal já atendido. Toda a reorganização acontece dentro deste repositório.

## Estrutura atual

Organizada por camadas técnicas horizontais:

```
adaptadores/
├── config
├── excecoes
├── entrada
├── monitoracao
└── saida

aplicacao/
├── dominio
├── portas
├── servicos
└── validadores

configuracao/

core/
├── anotacoes
├── conversores
├── excecoes
└── casos de uso
```

## Diagnóstico

1. `dominio` está dentro de `aplicacao`, e os casos de uso estão em `core`. Os dois elementos mais internos da arquitetura estão em pacotes separados, com `servicos` e `validadores` no meio.
2. Entidades de domínio anêmicas: getters e setters, sem comportamento.
3. Casos de uso anêmicos.
4. Camada `servicos` concentra praticamente toda a lógica de negócio.
5. Ambiguidade não resolvida entre `servicos` e casos de uso: ambos carregam regra, sem critério de separação.

Leitura: hexagonal no nome das pastas, não na dependência real.

## Entradas atendidas

| Entrada | Protocolo | Densidade de regra |
|---|---|---|
| Elegibilidade | REST | Alta. Regra de produto real. |
| Pré-requisitos | REST | Alta. |
| Feature toggle | REST | Baixa. Repasse. |
| Conteúdo de telas | GraphQL | Baixa. Repasse. |
| FAQ | REST | Baixa. Repasse. |

## Escopo definido

Piloto: **elegibilidade apenas**. Definido pelo líder técnico.

Demais entradas permanecem intocadas e migram sob demanda.

## Alvo

Estrutura por contexto de negócio, uniforme nos cinco contextos:

```
contexto/<nome>/
├── dominio/       entidades ricas + portas
├── aplicacao/     casos de uso
└── adaptador/
    ├── entrada/
    └── saida/
```

Sem camada de serviços de aplicação. Sem pacote de validadores. `config` e monitoração permanecem globais.

Detalhamento em `architecture.md` e `naming-and-structure.md`.

## Limitação relevante de quem executa

Recém-chegado à equipe. Não desenvolveu o código. Conhecimento baixo das regras de negócio de cada fluxo.

Consequência direta: **o mapeamento do comportamento atual precede qualquer alteração de código**, e a validação desse mapeamento com o líder técnico e com produto é etapa obrigatória, não opcional.

## Restrições operacionais

- Trabalho executado em máquina corporativa, com instância corporativa do Claude. Sem continuidade de contexto entre ambientes. Documentos markdown são o meio de transporte.
- Prazo não é a restrição principal. Qualidade e reversibilidade são.
- Sprint iniciada em 24/08/2026.
