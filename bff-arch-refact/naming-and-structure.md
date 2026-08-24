# Nomenclatura e Estrutura

## Pacotes

Raiz por contexto de negócio, em minúsculas, sem separador:

```
contexto/elegibilidade
contexto/prerequisitos
contexto/featuretoggle
contexto/conteudotelas
contexto/faq
```

Dentro de cada contexto, exatamente três subpacotes:

```
dominio/
aplicacao/
adaptador/entrada/
adaptador/saida/
```

Não criar `servicos`, `validadores`, `helpers`, `utils` ou `core` dentro de contexto.

## Sufixos de classe

| Tipo | Sufixo | Pacote | Exemplo |
|---|---|---|---|
| Entidade | nenhum | dominio | `Cliente`, `Elegibilidade` |
| Objeto de valor | nenhum | dominio | `Cpf`, `FaixaRenda` |
| Porta de entrada | `UseCase` | dominio | `ConsultarElegibilidadeUseCase` |
| Porta de saída | `Port` | dominio | `RestricaoPort` |
| Caso de uso (impl) | `UseCaseImpl` | aplicacao | `ConsultarElegibilidadeUseCaseImpl` |
| Serviço de domínio | `Service` | dominio | raro, exige justificativa |
| Controller REST | `Controller` | adaptador/entrada | `ElegibilidadeController` |
| Resolver GraphQL | `Resolver` | adaptador/entrada | `ConteudoTelasResolver` |
| Cliente externo | `Client` | adaptador/saida | `RestricaoClient` |
| DTO de entrada | `Request` | adaptador/entrada | `ElegibilidadeRequest` |
| DTO de saída | `Response` | adaptador/entrada | `ElegibilidadeResponse` |
| Contrato externo | `Dto` | adaptador/saida | `RestricaoDto` |
| Conversor | `Mapper` | adaptador | `ElegibilidadeMapper` |
| Exceção de negócio | `Exception` | dominio | `ClienteInelegivelException` |

## Nomes de caso de uso

Verbo no infinitivo mais o objeto de negócio: `ConsultarElegibilidade`, `ValidarPreRequisitos`, `ObterFaq`.

Evitar `Processar`, `Executar`, `Handle`, `Manager`, `Processor`. São nomes que não dizem nada e atraem responsabilidade extra.

Um caso de uso tem um método público. Se tiver dois, provavelmente são dois casos de uso.

## Regras de importação

Permitido:
- `adaptador` → `aplicacao`, `dominio`
- `aplicacao` → `dominio`
- `dominio` → nada além de JDK e do próprio domínio

Proibido:
- `dominio` importar `aplicacao`, `adaptador`, Spring, Jackson, Feign, JPA
- `aplicacao` importar `adaptador` ou anotações web
- Qualquer contexto importar classe de outro contexto

Contextos se comunicam apenas via `shared`, e `shared` só recebe código quando dois ou mais contextos realmente precisam. Na dúvida, duplique.

## Conversão entre camadas

O objeto que entra pelo controller não é o objeto que circula no domínio, e não é o objeto que sai para o cliente externo. A conversão acontece no adaptador, nas duas pontas.

Não vazar `Request` ou `Dto` para dentro do caso de uso.

## Exceções

Exceção de negócio nasce no domínio e é traduzida para HTTP no adaptador de entrada, via handler global em `config`.

Domínio não conhece código de status HTTP.
