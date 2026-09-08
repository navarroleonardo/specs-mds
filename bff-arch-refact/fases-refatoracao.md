# Instruções: divisão da história em duas fases

Colar no agente. Substitui o escopo único da história original.

---

## Contexto que muda decisões anteriores

Levantamento do fluxo real de elegibilidade concluído. Três descobertas que invalidam partes das specs anteriores:

1. **As regras de elegibilidade não são nossas.** Uma API externa recebe o perfil montado e devolve três flags (idade, dispositivo de segurança, razão da conta). A decisão de elegibilidade acontece fora. Não modelar domínio de decisão de elegibilidade.

2. **O contexto é essencialmente uma camada anticorrupção com um miolo pequeno de regra.** São quatro integrações externas: três de busca de dados, uma de decisão, uma de conteúdo de tela. Não inflar o domínio para parecer rico.

3. **A regra própria que existe é pouca e específica:**
   - Cálculo de idade a partir da data de nascimento
   - Validação de "token tem conteúdo", hoje um método privado chamado uma vez por tipo de token
   - Mapeamento das três flags para o código de tela, com prioridade fixa em três ifs
   - Validações de nulo de campos obrigatórios (endereço, UF, município, data de nascimento)

Tudo isso vive hoje dentro do serviço.

---

## Correções às especificações existentes

- **`ddd-spec.md` assume Java 21. O `pom.xml` compila em Java 17.** Não usar `switch` exaustivo sobre tipo selado, que só fecha no 21. Enum resolve.
- **`asToggleParameters()` retornando `Map<String,String>` com chaves da API externa (`uf`, `cidade`, `codCDPS`, `dispseg`) não é domínio.** Essa tradução pertence ao mapper do adaptador de saída. O objeto de domínio expõe dados em tipos de domínio.
- **Não criar objeto de valor para `Cpf`, `uf` e `codCDPS`.** São repasse sem regra. Objeto de valor só onde há regra real e hoje espalhada.
- **O objeto que traduz flags em tela não deve se chamar "elegibilidade".** Ele não decide elegibilidade, traduz veredito externo em código de tela. Nome deve refletir isso.

---

## Fase 1 (agora): hexagonal e domínio tático

Escopo aprovado pelo líder técnico. Endireitar dependência **dentro da estrutura de pastas atual**, sem mover arquivo de lugar.

### Fazer

- Desfazer o serviço. Mover para objetos de domínio:
  - cálculo de idade
  - validação de token ativo
  - os três ifs de flag para código de tela
  - validações de nulo, que viram construtor dos objetos de domínio
- Colocar as quatro integrações externas atrás de portas de saída, com assinatura em tipos de domínio
- Reduzir o caso de uso a orquestrador puro: dispara as chamadas, monta o perfil, chama a decisão, traduz para tela, busca conteúdo, devolve
- Traduzir contratos externos no mapper do adaptador de saída, não no domínio

### Não fazer nesta fase

- Não mover arquivo entre pacotes
- Não criar pacote por contexto
- Não tocar na composição assíncrona (`CompletableFuture`, join, ordem, tratamento de erro)
- Não corrigir bug encontrado no caminho. Registrar em card separado
- Não alterar contrato de API, códigos de erro ou status HTTP

### Sequenciamento interno

1. Dependência primeiro: objetos de domínio e portas, um passo por commit
2. Só depois avaliar se o fluxo assíncrono ainda incomoda

Boa parte da ilegibilidade do assíncrono se resolve sozinha quando a lógica sai do serviço. Se ainda incomodar, extrair método para nomear etapas. **Nunca no mesmo commit que a mudança de dependência.**

### Portão de cada commit

Suíte de caracterização verde. Vermelho significa mudança de comportamento, não teste desatualizado.

---

## Fase 2 (adiada, decidida)

Registrar como decidida, não como possibilidade. Reorganização adiada tende a morrer.

- Reagrupar por contexto: criar `contexto/elegibilidade` com `dominio`, `aplicacao`, `adaptador/entrada`, `adaptador/saida`
- Mover apenas os arquivos exclusivos de elegibilidade
- Resolver compartilhados via `shared` ou duplicação consciente
- Reescrever os alvos das regras de ArchUnit para os novos pacotes

### Pré-requisito

Levantamento de uso (`find usages`) de cada arquivo do `domain` atual, que tem mais de 16 arquivos misturando contextos. Tabela: arquivo, quem usa, destino. Três casos: exclusivo de elegibilidade (move), compartilhado (não move), alheio (não toca).

Atenção a injeção por nome, reflection ou lookup dinâmico, que o `find usages` não enxerga.

**Motivo do adiamento:** decidir fronteira de contexto agora seria decidir no momento de menor conhecimento do fluxo. A fase 1 gera esse conhecimento.

---

## ArchUnit

### Estratégia de dívida legada

- **Freeze para os outros contextos.** `FreezingArchRule` grava a linha de base das violações existentes na primeira execução e passa a reprovar apenas violação nova. A dívida vira catraca: só diminui.
- **Sem freeze para o código de elegibilidade.** Ali a regra deve falhar de verdade e forçar a correção. Não esconder a própria bagunça atrás da linha de base.

### Regras da fase 1

Mirando os pacotes de camada atuais, com nota de que serão reescritos na fase 2:

1. Domínio não importa Spring, Jackson, Feign ou Lombok
2. Domínio não depende de adaptador
3. Aplicação não depende de adaptador
4. Nenhuma classe chama cliente de integração direto, tudo passa por porta
5. Classes anotadas com `@RestController` residem no adaptador de entrada
6. Nenhuma classe com sufixo `Service` dentro do escopo refatorado

As regras de isolamento entre contextos ficam para a fase 2.

### Operacional

- Ligar uma ou duas regras por vez, corrigir, verde, próxima. Nunca as seis de uma vez
- Arquivo de store versionado, entra no commit
- Comentário no PR explicando o que é o store, senão parece que as violações listadas foram introduzidas agora

---

## Critérios de aceite da fase 1

- [ ] Serviço de elegibilidade não existe mais
- [ ] Cálculo de idade, validação de token e mapeamento de tela em objetos de domínio
- [ ] Quatro integrações atrás de portas com assinatura em tipos de domínio
- [ ] Nenhuma classe de domínio importa framework
- [ ] Nenhum DTO externo atravessa a fronteira do adaptador
- [ ] Caso de uso sem cálculo e sem if de negócio
- [ ] Composição assíncrona inalterada, ou alterada em commit próprio e isolado
- [ ] Respostas HTTP idênticas: payload, códigos de erro e status
- [ ] Suíte de caracterização verde e não editada durante a refatoração
- [ ] Regras de ArchUnit ativas, com freeze no legado e sem freeze em elegibilidade
- [ ] Nenhum arquivo movido de pacote
- [ ] Cards abertos para bugs e comportamentos suspeitos encontrados
