# Estratégia de Testes

## Três tipos, três propósitos

| Tipo | Quando usar | O que garante |
|---|---|---|
| Caracterização | Antes de refatorar código existente | Que o comportamento atual não mudou |
| TDD | Código novo | Que o comportamento novo é o desejado |
| Arquitetura (ArchUnit) | Sempre, no build | Que as regras estruturais não são violadas |

## Testes de caracterização

Referência: Michael Feathers, *Working Effectively with Legacy Code*.

É um teste que documenta o que o código faz **hoje**, sem julgar se está certo.

Processo:
1. Escolher um fluxo e uma entrada
2. Executar o código atual
3. Observar a saída real
4. Se a saída é plausível, congelar como valor esperado
5. Repetir para os caminhos alternativos e de erro

Importante: o objetivo não é validar a regra de negócio, é detectar mudança. Um comportamento estranho preservado é melhor que um comportamento "corrigido" sem querer.

Regras:
- Não escrever o teste como você acha que deveria funcionar. Escrever como funciona.
- Comportamento suspeito vira pergunta para o líder técnico e para o time de produto, registrada à parte. Não vira correção durante a refatoração.
- Cobrir feliz, alternativo e erro antes de tocar em qualquer linha de produção.

Efeito colateral desejado: os testes de caracterização são a forma mais confiável de aprender as regras de negócio de um fluxo que você não desenvolveu.

## TDD

Aplicável apenas a código novo: entidades ricas que estão nascendo, novos casos de uso, novas portas.

Não aplicável como rede de proteção de refatoração. Para isso existe caracterização.

## Testes de arquitetura (ArchUnit)

Regras que devem quebrar o build:

1. Classes em `dominio` não podem depender de `org.springframework`, `com.fasterxml.jackson`, `feign`, `javax.persistence`
2. Classes em `dominio` não podem depender de `aplicacao` nem de `adaptador`
3. Classes em `aplicacao` não podem depender de `adaptador`
4. Nenhum contexto pode depender de outro contexto
5. Classes anotadas com `@RestController` devem residir em `adaptador.entrada`
6. Classes com sufixo `UseCaseImpl` devem residir em `aplicacao`
7. Interfaces com sufixo `Port` e `UseCase` devem residir em `dominio`
8. Não deve existir classe com sufixo `Service` fora de `dominio`
9. Não deve existir pacote chamado `servicos`, `validadores` ou `utils` dentro de contexto

Dependência sugerida: `com.tngtech.archunit:archunit-junit5`.

Os testes de arquitetura valem mais que qualquer documento, porque são executáveis. Este arquivo descreve a intenção; o ArchUnit a torna obrigatória.

## Cobertura

Não perseguir percentual. A pergunta útil é: se eu mover essa lógica de lugar, algum teste falha?

Se a resposta for não, falta caracterização.
