# Spec: DDD aplicado ao BFF

Documento de referência para a refatoração. Complementa `architecture.md` (camadas) e `naming-and-structure.md` (convenções). Este arquivo trata de **como modelar o domínio**, não de onde colocar as pastas.

---

## 0. Contexto que muda a aplicação do DDD aqui

Este é um BFF de composição, não um serviço de escrita. Ele não persiste estado: recebe uma requisição, consulta fontes externas, decide e devolve.

Consequências diretas:

- **Não há agregado no sentido clássico.** Agregado pressupõe ciclo de vida, persistência e transação. Aqui os objetos nascem e morrem dentro da requisição.
- **Não há repositório.** As portas de saída são clientes de consulta, não repositórios de agregado.
- **Não há consistência transacional a proteger.** A fronteira relevante é a do contexto, não a do agregado.

O que continua valendo integralmente, e é o foco deste documento: entidade rica, objeto de valor, linguagem ubíqua, contexto delimitado e camada anticorrupção.

Modelo mental correto para elegibilidade: **um objeto que carrega uma decisão e sabe se justificar**. Entram fatos externos, sai um veredito com motivo.

---

## 1. Objeto de valor

É o padrão de maior retorno nesta refatoração. A maior parte da lógica hoje espalhada na camada de serviços é objeto de valor não modelado.

### Definição

Objeto sem identidade própria, definido inteiramente pelo seu conteúdo. Dois objetos de valor com os mesmos campos são o mesmo objeto.

### Regras obrigatórias

1. **Imutável.** Sem setter. Alteração cria nova instância.
2. **Válido por construção.** A validação acontece no construtor. Se instanciou, é válido.
3. **Comparado por conteúdo.** `record` do Java 21 resolve.
4. **Carrega comportamento.** Se existe regra sobre aquele dado, o método é dele.

### Implementação padrão

```java
public record Cpf(String valor) {
    public Cpf {
        if (valor == null || !ehValido(valor)) {
            throw new CpfInvalidoException(valor);
        }
    }
}
```

```java
public record FaixaRenda(BigDecimal minimo, BigDecimal maximo) {
    public FaixaRenda {
        if (minimo.compareTo(maximo) > 0) {
            throw new FaixaRendaInvalidaException(minimo, maximo);
        }
    }

    public boolean contem(BigDecimal renda) {
        return renda.compareTo(minimo) >= 0
            && renda.compareTo(maximo) <= 0;
    }
}
```

### Como identificar candidatos no código atual

Procurar por **obsessão por primitivos**: `String`, `BigDecimal`, `int` ou `boolean` que tenham regra em volta.

Sinais:
- Mesma validação repetida em mais de um lugar
- Regex aplicado a uma String em pontos diferentes
- Constante ou número mágico associado a um campo
- Método utilitário estático recebendo um primitivo
- Comentário explicando o que um valor significa

Cada um desses é um objeto de valor esperando para nascer.

### Regra de decisão

Se o dado tem formato, faixa, unidade ou regra de validade, ele **não** é primitivo. É objeto de valor.

---

## 2. Entidade

Objeto com identidade própria, que permanece o mesmo ainda que seus atributos mudem. Comparação por id, não por conteúdo.

Neste BFF, entidade é escassa. Só modele como entidade quando houver identidade de negócio real e mais de um estado possível ao longo do fluxo.

### Regras

1. Não expor setter público.
2. Não expor coleção interna diretamente. Retornar cópia imutável.
3. Toda regra sobre o próprio estado é método da entidade.
4. Sem anotação de framework. Sem Jackson, sem Spring, sem JPA.
5. Não retornar `null` de método de domínio. Usar `Optional` ou tipo de resultado explícito.

### Entidade anêmica

É o estado atual do código. Diagnóstico: classe só com getters e setters, e a lógica que a manipula vivendo em outra classe.

Correção: mover a regra para dentro. Se um trecho externo lê vários campos da entidade para decidir algo, aquele trecho é um método dela.

**Teste rápido:** se a classe fosse `record` sem nenhum método além dos acessores, ela seria só um DTO. Domínio não é DTO.

---

## 3. Modelagem da decisão de elegibilidade

Recomendação central para o piloto.

O resultado da avaliação não é `boolean`. É um objeto que carrega o veredito e a justificativa, porque o negócio precisa saber **por que** alguém não é elegível.

```java
public sealed interface ResultadoElegibilidade
        permits Elegivel, Inelegivel {

    boolean aprovado();
}

public record Elegivel() implements ResultadoElegibilidade {
    public boolean aprovado() { return true; }
}

public record Inelegivel(List<MotivoInelegibilidade> motivos)
        implements ResultadoElegibilidade {

    public Inelegivel {
        if (motivos == null || motivos.isEmpty()) {
            throw new IllegalArgumentException(
                "Inelegibilidade exige ao menos um motivo");
        }
        motivos = List.copyOf(motivos);
    }

    public boolean aprovado() { return false; }
}
```

`sealed interface` do Java 21 permite `switch` com verificação de exaustividade no adaptador de entrada, sem `if` encadeado.

### Regras de elegibilidade como objetos

Cada regra de negócio vira uma implementação, e o conjunto é avaliado pelo domínio:

```java
public interface RegraElegibilidade {
    Optional<MotivoInelegibilidade> avaliar(SolicitacaoElegibilidade solicitacao);
}
```

Vantagens: cada regra é testável isoladamente, o nome da classe documenta a regra, e incluir ou remover regra não altera o caso de uso.

**Importante:** só adotar esse desenho se o mapeamento confirmar que existem múltiplas regras independentes. Se houver uma ou duas, um método na entidade basta. Não antecipar estrutura.

---

## 4. Linguagem ubíqua

Usar no código exatamente os termos que o negócio usa, com o mesmo significado.

### Entregável obrigatório antes de codificar

Um glossário de elegibilidade, com três colunas:

| Termo do negócio | Significado | Onde aparece hoje no código |
|---|---|---|

Regras:
- Termo que não puder ser preenchido é lacuna de entendimento. Marcar e levar para o líder técnico e para produto.
- Nome no código sai deste glossário, não do contrato da API externa nem do banco.

### Proibido no domínio

- `Processor`, `Manager`, `Handler`, `Helper`, `Util`, `Data`, `Info`
- Nomes genéricos: `dados`, `objeto`, `valor`, `flag`, `tipo`
- Números mágicos ou enums opacos representando estado de negócio
- Nomes herdados de API externa que o negócio não reconhece

### Teste de validação

Ler um método do domínio em voz alta para alguém de produto. Se a pessoa entende e consegue apontar erro, a linguagem está correta.

---

## 5. Contexto delimitado

Cada um dos cinco pacotes é um contexto. A linguagem vale dentro do contexto, não globalmente.

Regras:
1. Um contexto **nunca** importa classe de outro contexto. Verificado por ArchUnit.
2. Duplicação de conceito entre contextos é esperada e correta. `Cliente` em elegibilidade não é `Cliente` em FAQ.
3. Relação entre contextos, se necessária, é por identidade (id), nunca por objeto compartilhado.
4. `shared` só recebe código quando dois ou mais contextos comprovadamente precisam do mesmo conceito com o mesmo significado. Na dúvida, duplicar.

---

## 6. Camada anticorrupção

O modelo de sistema externo não entra no domínio. A tradução acontece no adaptador de saída.

### Regras

1. O `Dto` do cliente HTTP não passa da fronteira do adaptador.
2. A porta de saída, declarada em `dominio`, tem assinatura em tipos de domínio, tanto na entrada quanto no retorno.
3. A conversão fica no adaptador de saída, em `Mapper`.
4. Erro de integração é traduzido para exceção de domínio antes de subir.

### Formato da porta

```java
// dominio
public interface RestricaoPort {
    SituacaoRestricao consultar(Cpf cpf);
}
```

Não aceitável: porta devolvendo `RestricaoDto`, `ResponseEntity`, `Map` ou tipo do cliente HTTP.

Benefício concreto: mudança na API externa afeta apenas o adaptador. O domínio e os testes dele não mudam.

---

## 7. Antipadrões a eliminar durante a refatoração

| Antipadrão | Sintoma | Correção |
|---|---|---|
| Domínio anêmico | Entidade só com getter e setter | Mover regra para dentro |
| Obsessão por primitivos | String ou BigDecimal com regra em volta | Criar objeto de valor |
| Serviço gordo | Classe de serviço concentrando a lógica | Partir entre entidade e caso de uso |
| Vazamento de DTO | `Dto` externo dentro do caso de uso | Anticorrupção no adaptador |
| Domínio acoplado a framework | Anotação Spring ou Jackson em `dominio` | Remover, mover para o adaptador |
| Modelo canônico | Uma classe atendendo todos os contextos | Um modelo por contexto |
| Booleano cego | Método devolvendo `true`/`false` sem motivo | Tipo de resultado explícito |
| Validação espalhada | Mesma checagem em vários pontos | Validar no construtor do objeto de valor |

---

## 8. Ordem de aplicação no piloto

1. Glossário de elegibilidade, validado com líder técnico e produto
2. Extrair objetos de valor a partir dos primitivos com regra
3. Modelar o resultado da decisão como tipo explícito
4. Puxar as regras do serviço para as entidades e objetos de valor
5. Extrair portas de saída em tipos de domínio
6. Reduzir o caso de uso a orquestração pura
7. Remover a classe de serviço, agora vazia

Cada passo em um commit, com a suíte de caracterização verde. Ver `estrategia-refatoracao.md`.

---

## 9. Restrições que se aplicam a tudo acima

- Refatoração **não altera comportamento**. Comportamento estranho encontrado vira registro, não correção.
- Nada aqui é aplicado por antecipação. Estrutura só nasce quando o mapeamento comprovar a necessidade.
- Java 21 e Spring Boot 4 disponíveis: usar `record`, `sealed`, pattern matching em `switch`.

---

## Referências

- Eric Evans, *Domain-Driven Design*
- Vaughn Vernon, *Implementing Domain-Driven Design*
- Michael Feathers, *Working Effectively with Legacy Code*
