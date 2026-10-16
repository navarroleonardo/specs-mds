# Decisões pós-discovery: Simulação (SIMNEG-366)

Complementa `spec-simulacao-bff.md`. Em caso de conflito, **este arquivo vence**.

Princípio: MVP "arroz com feijão bem feito". Correção e isolamento entram agora; tuning, métricas e resiliência avançada ficam no plano pós-implantação (seção 5).

---

## D1. Estrutura de pacotes

Layout legado (`adapter/` + `application/domain/model` + `application/service` + `core/exception`).
`application/domain/model` **sem nenhuma dependência de Spring**, para a migração futura para `contexto/simulacao` (SIMNEG-9093) ser só mover pacote.

---

## D2. Paralelismo

### Contexto
- `FilterCDCService` usa `supplyAsync` sem executor (commonPool, `parallelism=200` via `ForkJoinConfig`) e repassa token/correlationId por parâmetro.
- `FeatureToggleClient`, `LinhaCreditoClient` e `PreAnalisysClient` leem `JwtTokenClaims` e `CorrelationIdHolder` (`@RequestScope`) **por dentro**. Em thread de pool não existe request vinculada: quebram com `No thread-bound request found`, e o MDC se perde.
- **Não alterar** `FilterCDCService`, `ForkJoinConfig` nem a assinatura dos clients compartilhados nesta história.

### Decisão: executor dedicado + TaskDecorator

**`SimulacaoExecutorConfig`** cria o bean `simulacaoExecutor` (`ThreadPoolTaskExecutor`):

| Propriedade | Valor | Motivo |
|---|---|---|
| `corePoolSize` = `maxPoolSize` | `${simulacao.executor.tamanho:30}` | Pool fixo. O `ThreadPoolTaskExecutor` só cresce acima do core quando a fila enche; com core < max, o pool roda no mínimo com a fila acumulando |
| `queueCapacity` | `${simulacao.executor.fila:50}` | Fila limitada. Fila infinita = memória infinita |
| `threadNamePrefix` | `simulacao-` | Identificar as threads em log e thread dump |
| `rejectedExecutionHandler` | `AbortPolicy` | Pool cheio vira 503 imediato (`SIMULACAO_SOBRECARREGADA`). **Não usar `CallerRunsPolicy`**: com dependência lenta, as threads do Tomcat (compartilhadas por todo o BFF) ficariam presas executando as chamadas e derrubariam as outras rotas |
| `taskDecorator` | `ContextoRequestTaskDecorator` | Propagar request e MDC |

**`ContextoRequestTaskDecorator`** (copia o contexto na thread da request, restaura na thread do pool, **sempre limpa no `finally`**):

```java
public class ContextoRequestTaskDecorator implements TaskDecorator {

    @Override
    public Runnable decorate(Runnable tarefa) {
        RequestAttributes request = RequestContextHolder.getRequestAttributes();
        Map<String, String> mdc = MDC.getCopyOfContextMap();
        return () -> {
            try {
                if (request != null) RequestContextHolder.setRequestAttributes(request);
                if (mdc != null) MDC.setContextMap(mdc);
                tarefa.run();
            } finally {
                RequestContextHolder.resetRequestAttributes();
                MDC.clear();
            }
        };
    }
}
```

Regras:
- A limpeza no `finally` é obrigatória: threads são reutilizadas, e sem limpeza a próxima tarefa (de outro cliente) herda o token do anterior.
- O service **sempre** aguarda (`join`) todas as tarefas antes de responder. Proibido "dispara e esquece": a request precisa estar viva enquanto as tarefas rodam.

### Uso no `SimulacaoService`

- Toda chamada paralela usa `supplyAsync(() -> ..., simulacaoExecutor)`. Nunca `supplyAsync` sem executor.
- Loja: `relacionamentoF.thenApplyAsync(r -> lojaPort.buscar(r.agencia()), simulacaoExecutor)`. A dependência da agência vir do Relacionamento é **hipótese [A CONFIRMAR]**; isolar nessa linha.
- Orçamento total: `CompletableFuture.allOf(...).orTimeout(${simulacao.timeout-total-ms:8000}, MILLISECONDS).join()`.
  - Atenção: `orTimeout` faz o future desistir, mas **não cancela a chamada HTTP**. A thread do pool continua presa até o timeout do Feign. O `orTimeout` protege o tempo de resposta; o limite do pool protege a aplicação.
- Desembrulhar `CompletionException` e lançar a causa real (exceção de domínio), para o handler mapear o HTTP correto.
- `TimeoutException` vira `SimulacaoTempoEsgotadoException` (504).
- `TaskRejectedException` vira `SimulacaoSobrecarregadaException` (503).

### Clock
`ClockConfig` expõe `Clock.system(ZoneId.of("America/Sao_Paulo"))`. Toda regra que usa "hoje" recebe o `Clock` injetado.

### Feign: client da Core
O `FeignConfig` aplica a todos os clients connect/read de 6000ms e `LoggingRetryer(3, 200)` (até 3 tentativas). No POST da Core isso significa: reenvio de POST após timeout de leitura (a Core pode já ter processado e o recálculo é disparado de novo) e até ~18s por chamada.

Só para o client da Core da simulação:

```yaml
spring.cloud.openfeign.client.config:
  simulacao-core:          # usar o nome real do @FeignClient
    connectTimeout: 1000
    readTimeout: 3000
    retryer: <pacote>.SemRetry
```

```java
public class SemRetry implements Retryer {
    @Override
    public void continueOrPropagate(RetryableException e) { throw e; }
    @Override
    public Retryer clone() { return this; }
}
```

- **Obrigatório:** teste provando que o client da Core sai com esses timeouts e sem retry (precedência entre YAML e beans do `FeignConfig` precisa ser verificada, não presumida).
- Clients compartilhados (toggle, relacionamento, dados adicionais, linha de crédito, loja): **sem alteração** nesta história.

### Testes de D2
1. Decorator: executor de 1 thread, tarefa A com contexto, tarefa B sem contexto; B não pode enxergar o token/MDC de A.
2. Decorator: dentro da tarefa, o `JwtTokenClaims` (request scope) é acessível.
3. Pool cheio gera 503 `SIMULACAO_SOBRECARREGADA`.
4. Estouro do orçamento total gera 504 `SIMULACAO_TEMPO_ESGOTADO`.
5. Client da Core sem retry e com timeouts próprios.

---

## D3. Erros

- `CDCResponseDTO` ganha campo opcional `codigo` (String) com `@JsonInclude(NON_NULL)`. Mudança aditiva: as outras rotas não enviam o campo e seguem iguais.
- Hierarquia própria em `core/exception`: `abstract class SimulacaoException extends RuntimeException` com `HttpStatus status` e `String codigo`. **Não estender `BusinessException`** (ela usa código numérico como status HTTP).
- `SimulacaoExceptionHandler`: `@RestControllerAdvice(assignableTypes = SimulacaoController.class)` + `@Order(Ordered.HIGHEST_PRECEDENCE)`. Escopado para não afetar outras rotas; precedência para vencer o advice global.
- Corpo de erro: `CDCResponseDTO{status, mensagem, codigo}`.
- Mensagem ao canal: genérica, sem detalhe técnico e sem dados pessoais. Detalhe vai para o log, com CPF/CNPJ mascarado.

| HTTP | `codigo` | Quando |
|---|---|---|
| 400 | `REQUISICAO_INVALIDA` | Bean Validation do request (tratar `MethodArgumentNotValidException` neste advice) |
| 422 | `CARENCIA_FORA_DO_LIMITE` | Data do 1º pagamento fora de min/max |
| 422 | `SIMULACAO_REJEITADA_CORE` | Core respondeu 400 (logar o corpo de erro da Core) |
| 502 | `SIMULACAO_CORE_INDISPONIVEL` | Core 5xx ou timeout |
| 503 | `PARAMETROS_SIMULACAO_INDISPONIVEIS` | Feature toggle indisponível e sem cache |
| 503 | `DEPENDENCIA_INDISPONIVEL` | Relacionamento, dados adicionais, loja, linha de crédito ou agregados falharam (logar qual) |
| 503 | `SIMULACAO_SOBRECARREGADA` | Pool da simulação cheio |
| 504 | `SIMULACAO_TEMPO_ESGOTADO` | Orçamento total estourado |

---

## D4. Envelope de sucesso

Mesmo padrão de `/pre-analise` e `/filtrocdc`: `CDCResponseDTO{status, dados}`.

- `POST /simulacao` → `dados = {idPropostaCredito, status, dataHoraProcessamento}`
- `GET /simulacao/{idPropostaCredito}` → `dados = {idPropostaCredito, status, condicoes}`

Substitui o "corpo cru" das seções 4.2 e 4.3 do spec. Testes E2E assertam `dados.*`.

---

## 5. Plano pós-implantação (fora do MVP)

O produto ainda não tem tráfego produtivo, então os valores acima são ponto de partida e serão calibrados:

1. Métricas Micrometer do `simulacaoExecutor` (threads ativas, fila, rejeições) e contagem de erros por `codigo`.
2. Teste de performance antes da abertura para clientes: única fonte de dados enquanto não há tráfego real.
3. Calibrar `simulacao.executor.tamanho`, `fila`, `timeout-total-ms` e os timeouts da Core com o p99 medido.
4. Confirmar com a plataforma o timeout do gateway e ajustar o orçamento total abaixo dele.
5. Avaliar Resilience4j (circuit breaker) para dependências críticas.
6. Levar ao TL o risco global: `LoggingRetryer(3, 200)` com 6s em todos os clients segura threads por até ~18s por chamada em qualquer rota.
