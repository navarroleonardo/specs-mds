# Arquitetura do BFF

## Objetivo

Padronizar a organização interna do BFF em arquitetura hexagonal com domínio rico, eliminando a ambiguidade atual entre camada de serviços e casos de uso.

## Princípio central

O núcleo de negócio não conhece o mundo externo. Ele expõe e consome **portas** (interfaces), e o mundo externo se conecta a elas por **adaptadores**.

Regra de dependência: as dependências apontam sempre para dentro. Domínio não importa aplicação, não importa adaptador, não importa framework.

## Camadas e responsabilidades

### Domínio

Contém entidades, objetos de valor e portas.

Responsabilidade: regras que são verdadeiras **sempre**, independente de quem chamou ou de qual fluxo está em execução.

O critério de decisão é este: se a regra é verdadeira mesmo que ninguém chame nada, ela é de domínio.

Exemplos:
- "Cliente com restrição não é elegível"
- "Valor de proposta não pode ser negativo"
- "Contrato vencido não aceita simulação"

Restrições:
- Sem anotações de framework (Spring, Jackson, JPA)
- Sem import de pacotes de infraestrutura
- Entidades expõem comportamento, não getters e setters vazios

### Aplicação

Contém os casos de uso.

Responsabilidade: orquestrar um fluxo específico disparado por alguém. Busca dados pelas portas de saída, monta ou recupera entidades, chama os métodos delas, define ordem, trata transação e devolve o resultado.

O critério: se a regra só existe porque alguém pediu algo, ela é caso de uso.

Exemplo: "Ao consultar elegibilidade, busca cadastro, consulta restrições, avalia e registra a consulta para auditoria."

Restrição importante: caso de uso **não calcula regra de negócio**. Se você encontrar cálculo, comparação de valores ou decisão sobre estado dentro de um caso de uso, aquilo pertencia à entidade.

### Adaptadores

Contém entrada (controllers REST, resolvers GraphQL) e saída (clientes HTTP, integrações).

Responsabilidade: traduzir. Converte payload externo em objeto de domínio e vice-versa. Valida formato, não regra.

## A camada de serviços foi eliminada

Existiam dois conceitos sob o mesmo nome:

- **Serviço de aplicação**: sinônimo de caso de uso. Redundante. Não existe mais.
- **Serviço de domínio**: regra que envolve mais de uma entidade e não tem dono natural em nenhuma delas. Permitido, mas raro.

Regra prática: só crie serviço de domínio quando conseguir explicar por que a regra não cabe em nenhuma entidade. Na dúvida, ela cabe na entidade.

Ao migrar código do serviço antigo, ele se parte em dois destinos:
- Regra sobre estado → entidade
- Orquestração do fluxo → caso de uso

## Onde ficou a validação

- Invariante de negócio → entidade (construtor ou método)
- Formato do payload → adaptador de entrada
- Não existe mais pacote `validadores`

## Estrutura de pacotes

Organização por **contexto de negócio** (bounded context), não por camada técnica.

```
br.com.<org>.<bff>
├── config/                    (global, fora dos contextos)
├── shared/                    (global, uso restrito)
└── contexto/
    ├── elegibilidade/
    │   ├── dominio/
    │   ├── aplicacao/
    │   └── adaptador/
    │       ├── entrada/
    │       └── saida/
    ├── prerequisitos/
    ├── featuretoggle/
    ├── conteudotelas/
    └── faq/
```

## Decisão sobre uniformidade

Todos os cinco contextos seguem a mesma estrutura de três subpacotes, inclusive os que hoje só repassam dados (featuretoggle, conteudotelas, faq).

Tradeoff assumido de forma consciente: nos contextos de baixa regra isso gera classes finas e alguma cerimônia. Aceitamos o custo em troca de previsibilidade, leitura uniforme do repositório e ausência de discussão caso a caso sobre qual padrão aplicar.

Consequência prática nos contextos rasos: a entidade pode ser um objeto de valor simples e o caso de uso pode ser quase uma delegação. Isso é aceitável. O que **não** é aceitável é pular a porta e o caso de uso chamando o cliente HTTP direto do controller.

## O que não muda

- Um BFF por canal. Não criamos novo artefato para o mesmo canal.
- `config`, monitoração e wiring do framework permanecem globais.
- Tudo permanece no mesmo repositório e no mesmo artefato Java.
