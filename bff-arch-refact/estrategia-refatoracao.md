# Estratégia de Refatoração (handoff)

## Princípio orientador

O objetivo não é uma refatoração perfeita, é uma refatoração **reversível**. Entregas pequenas, cada uma com teste e com rollback óbvio, valem mais que uma entrega grande e travada, especialmente em um fluxo cujas regras ainda estão sendo aprendidas.

## Fases

### Fase 1: Mapeamento (sem alterar código)

- Ler o fluxo de elegibilidade de ponta a ponta: controller, serviço, caso de uso, integrações
- Documentar o comportamento observado: entradas, decisões, chamadas externas, saídas, casos de erro
- Listar as regras de negócio identificadas, com o trecho de código correspondente
- Marcar explicitamente o que não foi compreendido

**Saída:** documento de comportamento atual de elegibilidade.

**Portão de saída:** revisão com o líder técnico e com quem conhece o produto. Errar aqui é barato. Errar em deploy não é.

### Fase 2: Caracterização

- Escrever testes que congelam o comportamento atual, incluindo as esquisitices
- Cobrir caminho feliz, alternativos e erros
- Comportamento suspeito vira registro em lista de pendências, não correção

**Portão de saída:** suíte verde contra o código atual, sem nenhuma linha de produção alterada.

### Fase 3: Estrutura e trilhos

- Criar `contexto/elegibilidade` com `dominio`, `aplicacao`, `adaptador`
- Adicionar ArchUnit com as regras de `testing.md`, inicialmente restritas ao novo pacote
- Ainda sem mover lógica

### Fase 4: Migração incremental

Ordem sugerida, um passo por commit:

1. Mover as entidades para `dominio`, ainda anêmicas
2. Puxar as regras de estado do serviço para dentro das entidades, uma por vez
3. Extrair as portas de saída e adaptar os clientes
4. Transformar o caso de uso em orquestrador real
5. Remover o serviço, agora vazio
6. Ajustar o adaptador de entrada

Após cada passo: suíte de caracterização verde e ArchUnit verde. Suíte vermelha significa mudança de comportamento, não teste desatualizado.

### Fase 5: Fechamento

- Atualizar o ADR com o resultado
- Ampliar as regras de ArchUnit para exigirem conformidade do que já foi migrado
- Levar a lista de comportamentos suspeitos para produto, como demanda separada

## Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Desconhecimento das regras de negócio pelo executor | Fase 1 com validação obrigatória pelo líder e por produto antes de qualquer código |
| Mudança de comportamento sem perceber | Caracterização completa antes da Fase 4; suíte roda a cada commit |
| Corrigir bug durante a refatoração | Proibido. Bug vira registro separado. Refatoração não altera comportamento. |
| Entrega grande e difícil de revisar | Um passo por commit, cada um reversível |
| Inconsistência visual no repositório durante a migração | ADR 001 declara o piloto explicitamente |
| Padrão se perder após a saída do executor | Regras em ArchUnit, executáveis no build, não apenas em documento |
| Escopo crescer para outras entradas | Escopo fixado pelo líder técnico: elegibilidade apenas |

## Não fazer

- Não corrigir bug encontrado no caminho
- Não alterar contrato de API
- Não otimizar performance
- Não renomear coisa fora do pacote novo
- Não tocar nas outras quatro entradas
- Não escrever teste de caracterização com o comportamento que "deveria" existir

## Trabalho paralelo, alavancagem para o time

Independente do piloto, e provavelmente com retorno maior:

- Especificações de arquitetura versionadas no repositório (`architecture.md`, `naming-and-structure.md`, `testing.md`, ADR)
- Regras de ArchUnit quebrando o build
- Workshop com o time sobre SDD e uso das especificações como input de desenvolvimento assistido por IA

O documento não sustenta o padrão sozinho. O teste de arquitetura sustenta.

## Referência

Michael Feathers, *Working Effectively with Legacy Code*, sobre testes de caracterização.
