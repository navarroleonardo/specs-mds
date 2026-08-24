# ADR 001: Elegibilidade como piloto da reorganização arquitetural

**Status:** Aceito
**Data:** 2026-08-24

## Contexto

O BFF atual está organizado por camadas técnicas horizontais: `adaptadores` (config, excecoes, entrada, monitoracao, saida), `aplicacao` (dominio, portas, servicos, validadores), `configuracao` e `core` (anotacoes, conversores, excecoes, casos de uso).

Dois problemas decorrem dessa organização:

1. Domínio e casos de uso, que são os elementos mais internos da arquitetura, estão em pacotes diferentes e distantes, com `servicos` e `validadores` fisicamente entre eles.
2. Existe ambiguidade entre a camada de serviços e os casos de uso: ambos carregam regra, sem critério claro de separação.

O resultado observado é entidade de domínio anêmica, caso de uso anêmico e lógica concentrada na camada de serviços.

O BFF atende cinco entradas: elegibilidade, pré-requisitos, feature toggle, conteúdo de telas (GraphQL) e FAQ.

## Decisão

1. Reorganizar o BFF por contexto de negócio, com pacote por contexto contendo `dominio`, `aplicacao` e `adaptador`.
2. Eliminar a camada de serviços de aplicação. Regra sobre estado vai para a entidade; orquestração vai para o caso de uso.
3. Aplicar a estrutura uniformemente aos cinco contextos, inclusive os de baixa regra de negócio.
4. Adotar **elegibilidade** como piloto. Os demais contextos migram sob demanda, quando houver trabalho já previsto neles.
5. `config`, monitoração e wiring do framework permanecem globais, fora dos contextos.
6. Manter um único artefato, respeitando a regra de um BFF por canal.

## Alternativas consideradas

**Migrar tudo de uma vez.** Descartada. O BFF está em produção e o custo de uma entrega grande e travada é maior que o custo da inconsistência temporária.

**Estrutura completa apenas nos contextos com regra real (elegibilidade e pré-requisitos) e estrutura simplificada nos três contextos de repasse.** Descartada. Economiza código, mas cria dois padrões coexistentes e transfere para cada dev a decisão de qual aplicar. A equipe priorizou previsibilidade sobre economia.

## Consequências

Positivas:
- Critério único e verificável sobre onde escrever cada regra
- Domínio isolado de framework, testável sem contexto Spring
- Fronteiras de contexto explícitas, preparando eventual separação futura

Negativas, aceitas:
- Durante a migração, o repositório terá o padrão novo em `contexto/elegibilidade` e o padrão antigo nas demais entradas. **Isso é intencional, não descuido.**
- Nos contextos de repasse, a estrutura completa gera classes finas e alguma cerimônia.

## Como saber que o piloto deu certo

- Testes de caracterização de elegibilidade passando antes e depois, sem alteração
- Regras de ArchUnit ativas e verdes no build
- Nenhuma classe de domínio de elegibilidade importando framework
- Nenhum arquivo de serviço dentro do contexto de elegibilidade

## Revisão

Revisar após a conclusão do piloto, antes de iniciar o segundo contexto.
