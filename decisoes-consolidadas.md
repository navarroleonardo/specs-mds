# Decisões consolidadas: Simulação (SIMNEG-366)

**Fonte de verdade.** Fecha os conflitos entre `spec-simulacao-bff.md`, `decisoes-pos-discovery.md`, `discovery-final-plano-revisado.md` e `jira-story.txt`.

## 0. Precedência (do mais forte ao mais fraco)

1. **Este arquivo.**
2. `simulacao-post-request-example.json` (JSON anotado com `//` campo a campo): **verdade para origem e default de cada campo do POST da Core.** É o último alinhamento com PO e TL.
3. Swaggers (Core da simulação e APIs de seguros).
4. `decisoes-pos-discovery.md` (D1 a D4).
5. `discovery-final-plano-revisado.md`: seções 1, 2.2, 3 e 5 valem como **achados factuais do código**; as propostas da seção 2.1 valem só onde este arquivo não decidiu.
6. `spec-simulacao-bff.md`.
7. `jira-story.txt`: onde diverge do que está acima, **a story é que precisa mudar** (lista na seção 4).

Para esta change, **D1 vence `openspec/specs/hexagonal-arch`**: layout legado, sem `contexto/`, sem ArchUnit. A migração é a SIMNEG-9093.

---

## 1. Decisões fechadas

| ID | Decisão |
|---|---|
| C1 | **BFF busca** os dados do cliente (Relacionamento + Dados Adicionais, com o cache existente). O front não envia esses campos. |
| C2 | `valorMinimoFinanciado` é **lido do toggle**. O valor é configuração; nenhum código ou fixture fixa número. |
| C3 | `sazonalidade`: propriedade `simulacao.sazonalidade-padrao`, default `30`. Significado a confirmar com a PO (seção 3), sem bloquear. |
| C4 | Toggle com `value` objeto: **deserializer** no campo `value` do DTO compartilhado que aceita string **ou** objeto e devolve sempre `String` (objeto vira texto JSON). A simulação faz o parse. Nenhum consumidor existente muda. Antes, provar com o payload real dos 4 toggles. |
| C5 | Chaves reais da story: jornada `jrnd-sim-parametros-autosim` (toggles entradamax, valorminfinanciado, carencia, seguroprestamista). Propriedade `simulacao.jornada-id`, no padrão de `filtercdc.jornadaId`. |
| C6 | `prazoRecomendado` = `prazoDesejado` do canal se vier; senão `prazoMaximo` da pré-análise. |
| C7/C13 | **Seguro prestamista (869) entra no MVP** via `produtosAgregados`. Os swaggers de produtos agregados e de elegibilidade de seguro estão em `docs/discovery-simulacao/swaggers/`. A sequência de composição sai dos swaggers. `seguroAuto` = `null` (oferta de Seguro Auto fora do escopo da story). Port de elegibilidade de seguro: `ElegibilidadeSeguroOutboundPort` (não colidir com elegibilidade do `/filtrocdc`). |
| C8 | Campos opcionais do bem **são recebidos do front, opcionais**. Se ausentes: booleanos = `false`, strings = `null`, **exceto `cdUsoVeiculo` = `"2"`**. Seguir o JSON anotado. A proposta de "MVP não aceita esses campos" está **descartada**. |
| C9 | `X-Request-Id` para a Core em **UUID v7** (gerador próprio ou lib `java-uuid-generator`). `Access-Channel-Id`: usar o valor que as outras chamadas já usam com `HeadersConstants.X_ACCESS_CHANNEL_ID`; se não houver, pendência com a Core (seção 3). |
| C10/C11 | GET: Core 404 → BFF **404** com `codigo = SIMULACAO_NAO_ENCONTRADA`. `dados = {idPropostaCredito, status, dataHoraProcessamento, condicoes, erro}`, com `condicoes` = `resultado.listaSimulacoes` repassado sem modelar. Core 422 no POST → `SIMULACAO_REJEITADA_CORE`. |
| C12 | Contrato canal → BFF usa **os nomes do response do `/pre-analise`** (`totalScoreCalculado`, `entradaMinima`, `valorEntradaSugerido`, `valorMaximoParcelaRegular`, `prazoMaximoRegularCalculado`). Mapeia sempre as variantes `Regular` (`modeloPrecificacao = Regular`). |
| JWT/Redis | **Comportamento global**, igual ao `/pre-analise`. O advice da simulação trata só `SimulacaoException` e validação de request. |
| Loja | Agência vem do token (`JwtTokenClaims.getBranch()`). Loja é chamada **em paralelo na 1ª fase**; o campo `agencia` é removido do record `DadosRelacionamento`; o `thenApplyAsync` do D2 está **removido**. |
| PF | MVP **só pessoa física** (`getCpf()`, 11 dígitos). PJ fora do escopo. Confirmar com a PO (seção 4). |
| vlEntrada 1ª simulação | `valorEntrada` do canal se vier; senão `valorEntradaSugerido` da pré-análise (story CA09). |

D1 a D4 de `decisoes-pos-discovery.md` seguem válidos, com as correções acima (Loja paralela; erros mantêm o `CDCResponseDTO{status, mensagem, codigo}`).

---

## 2. Premissas com default (não bloqueiam; confirmar depois)

| Item | Premissa adotada | Confirmar com |
|---|---|---|
| Loja: mapeamento `StoreAgency` → campos da Core | Usar o mapeamento candidato da seção 2.2 item 3 do discovery-final e o mesmo critério do `PreAnalisysClientFeignClientMapper` | TL |
| `segmentoLoja` | Derivado de `cdTipoVeiculo` (AUTO → Leves, MOTO → Motos) | TL |
| `tipoBem` | Valor de `linhaCredito` convertido para `Integer` | Linha de crédito / Core |
| `Access-Channel-Id` (se não houver valor existente) | Deixar configurável por propriedade, sem valor inventado | Core |
| UUID v4 aceito pela Core | Irrelevante: geramos v7 | Core |

---

## 3. Pendências externas

1. PO: significado de `sazonalidade` e se CA13 está com o texto trocado.
2. Core: valor de `Access-Channel-Id` (se não existir no código) e os erros do JSON de exemplo oficial.
3. QA: projeto Jira, Test Set, Test Repository Path, tecnologia e Company para o Xray.

---

## 4. Mudanças na story para a PO

1. **Dados do cliente:** o BFF busca em Relacionamento e Dados Adicionais; o front não envia (story diz o contrário).
2. **CA12:** `valorMinimoFinanciado` vem do toggle (hoje 1); a story diz 0.
3. **CA13:** texto fala de carência sob o título sazonalidade; esclarecer o que é sazonalidade.
4. **prazoRecomendado:** prazo desejado do cliente quando informado; senão o prazo máximo da pré-análise.
5. **Campos opcionais do bem:** recebidos do front de forma opcional, com defaults (false / null / cdUsoVeiculo "2"), não fixos.
6. **Seguro:** prestamista (869) no MVP via produtos agregados; Seguro Auto fora.
7. **Escopo PF:** MVP atende só pessoa física.
8. **GET de simulação inexistente:** responde 404.
