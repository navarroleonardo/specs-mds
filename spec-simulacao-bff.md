# Spec: Simulação de Financiamento no BFF (`fini-bff-cdcvei-originacao`)

Status: pronto para implementação, com pendências marcadas como **[A CONFIRMAR]**.
Regra para quem implementar: nada marcado como [A CONFIRMAR] deve ser inventado. Implementar com o ponto de extensão indicado e deixar `// TODO [A CONFIRMAR]: <assunto>`.

---

## 1. Escopo

Dois endpoints no BFF, fazendo ponte para o `simulacao-core`:

| Endpoint BFF | Função | Core |
|---|---|---|
| `POST /simulacao` | Monta a proposta completa e dispara a simulação (ou ressimulação) | POST simulação |
| `GET /simulacao/{idPropostaCredito}` | Polling do resultado | GET simulação |

Ressimulação: novo POST com o **mesmo `idPropostaCredito`** substitui a anterior. `uuidSimulacao` vai sempre `null`.

Feature toggle: `feat-cdcvei-sfp`, jornada "Parâmetros da Simulação".

---

## 2. Decisões de arquitetura

1. **Coletar e depois montar.** Nenhum objeto de domínio é populado aos poucos. Cada outbound port devolve um `record` imutável e completo. A montagem acontece num único ponto (`PropostaSimulacao.montar(...)`), e o objeto já nasce válido.
2. **Regras no domínio.** Cálculos (carência, entrada máxima, valor máximo financiado) ficam em value objects do domínio, testáveis sem Spring e sem mock. Mappers só traduzem, não calculam.
3. **Contrato próprio canal → BFF.** Não espelha os nomes da Core (`nuCpfCnpj`, `flPCD` etc.). A tradução para a Core fica só no adapter de saída. Se a Core mudar, o contrato com o app não muda.
4. **Constantes de protocolo da Core no adapter de saída** (`modeloPrecificacao`, `formaPagamento`, `canal`, `jornada`). Não são regra de negócio.
5. **DTOs da Core gerados por OpenAPI** (`openapi-generator-maven-plugin`, só models, sem gerar client). Ninguém digita os campos na mão.
6. **GET é repasse fino.** O domínio só conhece `idPropostaCredito` e `status`. O bloco de condições é repassado ao canal sem virar modelo de domínio (exceção consciente à decisão 3, para não manter um espelho de dezenas de campos sem regra).
7. **Dinheiro e percentuais em `BigDecimal`.** Nunca `double`/`Double`. O BFF não arredonda, repassa a escala recebida.
8. **Tempo injetável.** Toda regra que depende de "hoje" recebe `java.time.Clock` (bean com zona `America/Sao_Paulo`).
9. **Java 17:** records sim; virtual threads não. Paralelismo com `CompletableFuture`, seguindo o padrão já usado no serviço filter CDC de elegibilidade.

---

## 3. Estrutura de pacotes

Seguir a convenção existente do projeto. `application/domain` contém apenas `model`.

```
adapter/
  input/
    SimulacaoController
    dto/  SimulacaoRequest, SimulacaoAceitaResponse, ConsultaSimulacaoResponse
    mapper/ SimulacaoRequestMapper            (request + token -> command)
  output/
    simulacao/  SimulacaoClient (Feign), SimulacaoCoreAdapter, SimulacaoCoreMapper
    linhacredito/, produtosagregados/, elegibilidade/, loja/   (clients + adapters)
    (FeatureToggle, CustomerRelationship, AdditionalCustomerData: reutilizar os existentes)
  config/
    SimulacaoExecutorConfig                   (executor dedicado + TaskDecorator)
    ClockConfig
  exception/
    handler: mapeamento das exceções de domínio para HTTP (seção 8)
application/
  domain/model/
    PropostaSimulacao, CondicoesFinanciamento, ParametrosSimulacao,
    DadosRelacionamento, DadosAdicionaisCliente, DadosLoja, LinhaCredito,
    ProdutoAgregado, Veiculo, DadosPreAnalise, StatusSimulacao, SimulacaoAceita
  port/
    input:  SimulacaoInboundPort, SimularFinanciamentoCommand
    output: SimulacaoOutboundPort, LinhaCreditoOutboundPort,
            ProdutosAgregadosOutboundPort, ElegibilidadeOutboundPort,
            LojaOutboundPort [A CONFIRMAR nome real na branch atualizada],
            FeatureToggleOutboundPort, CustomerRelationshipOutboundPort,
            AdditionalCustomerDataOutboundPort
  service/
    SimulacaoService
core/
  exception: ParametrosSimulacaoIndisponiveisException, CarenciaForaDoLimiteException,
             SimulacaoRejeitadaCoreException, DependenciaIndisponivelException
  converter: data DD-MM-AAAA (dtNascimento da Core)
```

Os três Redis (Relacionamento, Dados Adicionais, Loja) continuam como `@Cacheable` dentro dos adapters. O service não sabe que existe cache.

---

## 4. Contrato canal → BFF

### 4.1 `POST /simulacao` (request)

Proposta de nomes. **[A CONFIRMAR] com o time do app** antes de congelar.

```json
{
  "idPropostaCredito": "string, obrigatório",
  "cliente": {
    "pcd": false,
    "possuiCnh": true
  },
  "veiculo": {
    "zeroKm": false,
    "marca": "string",
    "modelo": "string",
    "versao": "string",
    "valorMolicar": 85000.00,
    "anoModelo": "2024",
    "anoFabricacao": "2023",
    "codigoMolicar": "string",
    "codigoFipe": "string | null",
    "blindado": false,
    "codigoCombustivel": "string",
    "codigoTipoVeiculo": "string",
    "taxi": false,
    "kitGas": false,
    "transformado": false,
    "isencaoFiscal": false,
    "placa": null,
    "cepPernoite": null,
    "codigoUsoVeiculo": "2"
  },
  "condicoes": {
    "valorBem": 85000.00,
    "valorEntrada": 20000.00,
    "ufLicenciamento": "SP",
    "quantidadeVeiculos": 1,
    "dataPrimeiroPagamento": "2026-11-20 | null",
    "prazoDesejado": "int | null"
  },
  "preAnalise": {
    "scoreCredito": 700,
    "entradaMinima": 8500.00,
    "entradaRecomendada": 17000.00,
    "valorMaximoParcela": 2500.00,
    "prazoMaximo": 60
  }
}
```

Regras de entrada:
- CPF/CNPJ e tipo de pessoa vêm **do token**, nunca do body.
- Flags do veículo (`taxi`, `kitGas`, `transformado`, `isencaoFiscal`) opcionais; ausentes = `false`. `placa` e `cepPernoite` ausentes = `null`. `codigoUsoVeiculo` ausente = `"2"` **[A CONFIRMAR]**. Defaults aplicados no `SimulacaoRequestMapper` ao criar o command.
- Primeira simulação: `dataPrimeiroPagamento`, `prazoDesejado` e (se o app quiser) `valorEntrada` podem vir nulos. Se `valorEntrada` for obrigatório na Core, **[A CONFIRMAR]** qual valor mandar na primeira chamada (ex.: `entradaRecomendada`).
- Datas no contrato do canal sempre ISO `yyyy-MM-dd`.
- Bean Validation: obrigatórios, `@DecimalMin("0")` nos monetários, `ufLicenciamento` 2 letras maiúsculas, `quantidadeVeiculos >= 1`, `prazoDesejado >= 1`.

Origem de `tipoBem` (linha de crédito): **[A CONFIRMAR]** qual input a API de linha de crédito exige.

### 4.2 `POST /simulacao` (response 200)

```json
{ "idPropostaCredito": "string", "status": "EM_PROCESSAMENTO", "dataHoraProcessamento": "2026-10-16T16:58:00-03:00" }
```

### 4.3 `GET /simulacao/{idPropostaCredito}` (response 200)

```json
{
  "idPropostaCredito": "string",
  "status": "PROCESSADO_SUCESSO",
  "condicoes": [ /* repasse do bloco de condições por prazo da Core */ ]
}
```

`status` (enum): `EM_PROCESSAMENTO`, `PROCESSADO_SUCESSO`, `FALHA_PROCESSAMENTO`, `SIMULACAO_NAO_ENCONTRADA`, `CONDICAO_NAO_ENCONTRADA`, `RESULTADO_SIMULACAO_INVALIDO`. O header opcional de filtro de condição da Core **não** é usado.

---

## 5. Modelo de domínio (`application/domain/model`)

Todos `record`, imutáveis.

```java
record ParametrosSimulacao(
    BigDecimal valorMinimoFinanciado,     // toggle, hoje R$1.000
    int sazonalidade,                     // toggle, hoje 30
    BigDecimal parametroEntradaMaxima,    // toggle SEPARADO, hoje R$1.000
    int carenciaMinima, int carenciaPadrao, int carenciaMaxima,  // toggle, padrão 30
    String codigoProdutoSeguro            // toggle, hoje "869"
) {}

record DadosRelacionamento(boolean funcionarioBradesco, int sequenciaTitular,
    boolean contratoBancoAtivo, boolean correntista,
    String agencia) {}  // agencia: HIPÓTESE de que vem daqui [A CONFIRMAR]

record DadosAdicionaisCliente(String sexo, LocalDate dataNascimento) {}
    // estadoCivil NÃO retorna da API: não modelar, Core recebe null

record DadosLoja(String segmentoLoja, int codigoRegional, String carteira,
    String codigoFilial, String codigoPosto, String codigoLoja, String nomePromotor) {}

record LinhaCredito(int tipoBem) {}

record ProdutoAgregado(/* campos do schema produtosAgregados da Core, nomes em português claro;
    percentualMaxAgregado como BigDecimal fração 0 a 1 */) {}
```

### 5.1 `CondicoesFinanciamento` (onde moram as regras)

```java
record CondicoesFinanciamento(
    BigDecimal valorBem, BigDecimal valorEntrada,
    BigDecimal entradaMinima, BigDecimal entradaMaxima, BigDecimal entradaRecomendada,
    BigDecimal valorMinimoFinanciado, BigDecimal valorMaximoFinanciado,
    BigDecimal valorMaximoParcela, int carencia, int sazonalidade,
    Integer prazoMaximo, Integer prazoRecomendado) {

  static CondicoesFinanciamento calcular(CondicoesInformadas informadas,
        DadosPreAnalise preAnalise, ParametrosSimulacao parametros, Clock clock) { ... }
}
```

Regras:

| Campo | Regra |
|---|---|
| `entradaMaxima` | `valorBem - parametros.parametroEntradaMaxima` |
| `valorMaximoFinanciado` | `valorBem - preAnalise.entradaMinima` |
| `valorMinimoFinanciado` | `parametros.valorMinimoFinanciado` |
| `sazonalidade` | `parametros.sazonalidade` |
| `carencia` | Se `dataPrimeiroPagamento` nula: `carenciaPadrao`. Senão: dias corridos entre `LocalDate.now(clock)` (zona São Paulo) e a data. Se `< carenciaMinima` ou `> carenciaMaxima`: lançar `CarenciaForaDoLimiteException` (422) |
| `prazoRecomendado` | `prazoDesejado` do canal (prazo quebrado), pode ser nulo |

Fora do MVP (decisão de PO): validar `valorBem < valorMinimoFinanciado`, `entradaMaxima` negativa e tolerância `valorBem` x Molicar. **Não implementar.**

### 5.2 `PropostaSimulacao` (agregado)

```java
record PropostaSimulacao(String idPropostaCredito, ClienteProposta cliente, Veiculo veiculo,
    CondicoesFinanciamento condicoes, DadosLoja loja, LinhaCredito linhaCredito,
    List<ProdutoAgregado> produtosAgregados) {

  static PropostaSimulacao montar(SimularFinanciamentoCommand cmd, ParametrosSimulacao parametros,
        DadosRelacionamento relacionamento, DadosAdicionaisCliente adicionais, DadosLoja loja,
        LinhaCredito linhaCredito, List<ProdutoAgregado> agregados, Clock clock) { ... }
}
```

Composição de `produtosAgregados` (seguro 869 vindo do toggle + `ProdutosAgregadosOutboundPort` + `ElegibilidadeOutboundPort`): **[A CONFIRMAR]** a sequência exata (lista primeiro e elegibilidade depois, ou o inverso, e se o 869 filtra a lista).

---

## 6. Orquestração (`SimulacaoService.simular`)

Grafo de dependências:

```
token ─┬─> FeatureToggle (parâmetros)       ─┐
       ├─> Relacionamento ──> Loja (agência)*├─> montar ─> Core
       ├─> Dados Adicionais                  │
       ├─> Linha de Crédito                  │
       └─> Produtos Agregados ─> Elegibilidade**
```
\* Dependência Relacionamento → Loja é **hipótese [A CONFIRMAR]**. Se a agência vier de outra fonte, Loja vira chamada paralela da primeira fase. Isolar essa decisão numa única linha (`thenComposeAsync` vs `supplyAsync`).
\*\* Ordem entre agregados e elegibilidade **[A CONFIRMAR]**.

Esqueleto:

```java
public SimulacaoAceita simular(SimularFinanciamentoCommand cmd) {
    var parametrosF     = supplyAsync(featureTogglePort::buscarParametrosSimulacao, executor);
    var relacionamentoF = supplyAsync(() -> relationshipPort.buscar(cmd.documento()), executor);
    var adicionaisF     = supplyAsync(() -> additionalDataPort.buscar(cmd.documento()), executor);
    var linhaCreditoF   = supplyAsync(() -> linhaCreditoPort.buscar(/* [A CONFIRMAR] */), executor);
    var lojaF           = relacionamentoF.thenApplyAsync(r -> lojaPort.buscar(r.agencia()), executor); // HIPÓTESE
    var agregadosF      = supplyAsync(() -> /* [A CONFIRMAR] */, executor);

    aguardar(parametrosF, relacionamentoF, adicionaisF, linhaCreditoF, lojaF, agregadosF);

    var proposta = PropostaSimulacao.montar(cmd, parametrosF.join(), relacionamentoF.join(),
        adicionaisF.join(), lojaF.join(), linhaCreditoF.join(), agregadosF.join(), clock);

    return simulacaoPort.simular(proposta);
}
```

Cuidados obrigatórios:
1. **Executor dedicado** (`ThreadPoolTaskExecutor`), nunca o `ForkJoinPool.commonPool()`: as chamadas Feign são bloqueantes.
2. **Propagação de contexto:** token, headers e MDC vivem em `ThreadLocal`. Configurar `TaskDecorator` que copia `RequestContextHolder` e `MDC` para as threads do executor, senão os interceptors Feign perdem o token. **Antes de criar, verificar como o filter CDC resolveu e reutilizar o mesmo bean/padrão.**
3. **Desembrulhar exceções:** `aguardar(...)` faz `allOf(...).join()` e converte `CompletionException` na causa real, para o handler mapear o HTTP correto.
4. **Timeout por chamada** coerente com os timeouts Feign já configurados (não somar timeouts maiores que o do canal).
5. Feature toggle indisponível **e** sem cache: `ParametrosSimulacaoIndisponiveisException`, não chama a Core.

### `SimulacaoService.consultar`

Chama `simulacaoPort.consultar(idPropostaCredito)` e devolve. Sem regra.

---

## 7. Mapeamento domínio → Core (`SimulacaoCoreMapper`)

| Objeto Core | Campo | Origem |
|---|---|---|
| metadados | jornada | constante **[A CONFIRMAR valor]** |
| metadados | idFI, parceiro, tecnologia, cidadeAcesso, estadoAcesso | **[A CONFIRMAR]** origem ou null |
| metadados | uuidSimulacao | sempre `null` |
| cliente | tipoPessoa, nuCpfCnpj | token **[A CONFIRMAR formato: com/sem máscara]** |
| cliente | flPCD, flCNH | canal |
| cliente | scoreCreditoCliente | canal (pré-análise) |
| cliente | flFunBradesco, cdSeqTitularClie, flContratoBancoAtivo, flCorrentista | Relacionamento |
| cliente | sexo, dtNascimento | Dados Adicionais; dtNascimento em **DD-MM-AAAA com hífen** |
| cliente | estadoCivil | `null` |
| bem | qtdeVeic, vlBem, ufLicenciamento | canal |
| bem | fl0km, marca, modelo, versao, vlMolicar, anoModelo, anoFabricacao, codMolicar, codFipe, flBlindagem, cdCombustivel | canal (dados FIP/Molicar) |
| bem | flTaxi, flKitGas, flVeiculoTransformado, flIsencaoFiscal, placa, cepPernoite, cdUsoVeiculo | canal com default |
| bem | tipoBem | Linha de Crédito |
| proposta | vlEntrada | canal |
| proposta | entradaMin, vlEntradaRecomendada, valorMaximoParcela, prazoMax, idPropostaCredito | canal (pré-análise) |
| proposta | entradaMax, valorMaxFinanciado, valorMinimoFinanciado, carencia, sazonalidade | `CondicoesFinanciamento` |
| proposta | prazoRecomendado | canal (`prazoDesejado`) |
| proposta | cdTipoVeiculo | canal (dados veículo) |
| proposta | modeloPrecificacao `"Regular"`, formaPagamento `"DC"` | constantes MVP |
| proposta | cdCupom | `null` |
| loja | segmentoLoja, cdCR, carteira, cdFilial, cdPosto, cdLoja, nomePromotor | Loja |
| loja | canal | constante `"agencia"` |
| loja | flNotaFiscal | `false` |
| loja | cnpjLoja | `null` |
| seguroAuto | (objeto inteiro) | `null` |
| produtosAgregados | lista | `PropostaSimulacao.produtosAgregados` |

Valores aceitos de strings sem enum (`tipoPessoa`, `sexo`, `cdCombustivel`, `cdUsoVeiculo`, `formaPagamento`, `canal`, `carteira`): **[A CONFIRMAR] com a Core**. Até lá, repassar como recebido, sem validação no BFF.

**Não usar o JSON de exemplo oficial da Core como massa de teste**: tem chave `metadadados` duplicada, `cnpjLoja` com 11 dígitos (pattern exige 14) e `qtdeVeic` 1000.

---

## 8. Erros

Proposta de códigos; seguir o formato de erro já padronizado no BFF.

| Situação | HTTP | Código |
|---|---|---|
| Body inválido (Bean Validation) | 400 | padrão atual do BFF |
| Carência fora de min/max | 422 | `CARENCIA_FORA_DO_LIMITE` |
| Toggle indisponível e sem cache | 503 | `PARAMETROS_SIMULACAO_INDISPONIVEIS` |
| Relacionamento, Dados Adicionais, Loja, Linha de Crédito ou Agregados falharam | 503 | `DEPENDENCIA_INDISPONIVEL` (log com o nome da dependência) |
| Core respondeu 400 | 422 | `SIMULACAO_REJEITADA_CORE` (log com o corpo de erro da Core + métrica própria; nunca 500 genérico) |
| Core 5xx / timeout | 502 | `SIMULACAO_CORE_INDISPONIVEL` |

Status de negócio do GET (`SIMULACAO_NAO_ENCONTRADA` etc.) chegam no body com 200 e são repassados. **[A CONFIRMAR]** se o canal prefere 404 para `SIMULACAO_NAO_ENCONTRADA`.

---

## 9. Testes

### 9.1 Unitários (obrigatórios)
- `CondicoesFinanciamento.calcular`: Clock fixo; data nula usa padrão; data no limite mínimo e máximo passa; um dia fora de cada limite lança 422; virada de dia considerando fuso São Paulo (ex.: 23h30 de SP já é dia seguinte em UTC).
- `entradaMaxima` e `valorMaximoFinanciado` com `BigDecimal` (comparar com `compareTo`, não `equals`).
- `PropostaSimulacao.montar`: objeto completo com todas as fontes.
- `SimulacaoCoreMapper`: JSON gerado bate campo a campo com um JSON esperado **corrigido** (constantes, nulls, formato DD-MM-AAAA).
- `SimulacaoService`: cada dependência falhando gera a exceção certa; toggle falhando não chama a Core; `CompletionException` desembrulhada.
- `SimulacaoRequestMapper`: defaults aplicados quando campos ausentes.

### 9.2 Integrados em DEV contra a Core real (critério de aceite da história)
1. Ressimulação: POST, polling até sucesso, novo POST com mesmo id e dado alterado; o polling volta a `EM_PROCESSAMENTO` e depois traz o novo resultado.
2. Corrida: GET imediatamente após o segundo POST não pode devolver o resultado antigo como se fosse o novo.
3. Novo POST sem mudança relevante: verificar o que a Core devolve.
4. Adulteração da pré-análise: mandar score/entradaMin diferentes dos reais da pré-análise. Se a Core aceitar, abrir bug.

---

## 10. Pendências abertas

1. Agência que é chave do Redis Loja vem mesmo do Relacionamento?
2. Nome real do outbound port de Loja.
3. `cdUsoVeiculo` default `"2"`.
4. Input da API de linha de crédito (`tipoBem`).
5. Sequência de composição de `produtosAgregados` com o seguro 869.
6. Valor de `vlEntrada` na primeira simulação, se obrigatório.
7. Origem dos campos de `metadados` além de `jornada` e o valor de `jornada`.
8. Formato de `nuCpfCnpj` (com/sem máscara) e valores aceitos das strings sem enum.
9. Nomes do contrato canal → BFF validados com o time do app.
10. Toggle em HOMOL (aguardando Jorge).
11. Avisar a Core dos erros no exemplo oficial do contrato.

---

## 11. Prompt para o Luna (GitHub Copilot)

```
Leia o arquivo docs/discovery-simulacao/spec-simulacao-bff.md inteiro antes de escrever código.

Contexto: BFF Java 17, Spring Boot, arquitetura hexagonal (adapter / application / core),
objetos de domínio em application/domain/model. Siga as convenções já existentes no
repositório (nomes de pacote, formato de erro, configuração Feign, cache Redis).

Implemente em etapas, parando ao fim de cada uma para eu revisar:
1. Domain: records da seção 5 e CondicoesFinanciamento com as regras da tabela 5.1,
   com os testes unitários da seção 9.1 correspondentes. Sem Spring nessa camada.
2. Ports de entrada e saída (seção 3). Antes de criar, procure os ports já existentes
   (FeatureToggle, CustomerRelationship, AdditionalCustomerData) e reutilize.
3. Adapter de saída da Core: models gerados via openapi-generator a partir do contrato,
   SimulacaoCoreMapper conforme tabela da seção 7, com teste de mapper.
4. SimulacaoService com CompletableFuture conforme seção 6. Antes, localize no código como
   o filter CDC de elegibilidade faz chamadas paralelas (executor, propagação de token/MDC)
   e reutilize o mesmo padrão.
5. Controller, DTOs de entrada/saída (seção 4) e handler de erros (seção 8).

Regras:
- BigDecimal para dinheiro e percentuais, nunca double.
- Clock injetado em toda regra que usa a data de hoje, zona America/Sao_Paulo.
- Nenhum objeto de domínio populado aos poucos: coletar tudo, montar uma vez.
- Itens marcados [A CONFIRMAR] não devem ser inventados: deixe TODO com o assunto e me avise.
- Não implemente validações listadas como fora do MVP.
- Se algo na spec conflitar com o código existente, pare e pergunte.
```
