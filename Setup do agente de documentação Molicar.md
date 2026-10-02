# Setup do agente de documentação Molicar

Oct 2, 2026 · @Leonardo de Abreu Navarro

## Objetivo e escopo

Meta: levar a documentação da Molicar no Confluence de fraca para boa, usando o MCP local que já escreve nas páginas. O que muda é o que o agente recebe antes de escrever: skills, instructions e um agente dedicado.

- **Entra agora:** skills do awesome-copilot, arc42-toolkit, agente Documentador, instructions enxutas, diagramas pela macro do draw.io.
- **Fica para depois:** docs-as-code (Markdown no repositório + md2conf), publicação pela esteira, linter automático.
- **Tudo em nível de usuário**, porque a Molicar atravessa três repositórios (Function, ADF, Postgres) e o agente precisa estar disponível em qualquer um deles.

## Checagens na máquina do banco

Faça estas sete checagens antes de instalar qualquer coisa. As respostas da 3 e da 7 são o que eu preciso para escrever o agente e a skill de publicação.

1. **VS Code suporta customizações:** Ctrl+Shift+P → `Chat: Open Customizations`. Se abrir um editor com abas Agents, Skills e Instructions, está ok. Se o comando não existir, o VS Code ou a extensão Copilot Chat estão antigos; agentes customizados exigem VS Code 1.106 ou mais novo.
2. **Qual harness você usa:** no Chat, veja o seletor de destino da sessão (Local ou Copilot). Isso decide onde o VS Code lê os arquivos de usuário. Anote qual aparece.
3. **Nomes das tools do MCP:** abra o `mcp.json` e anote o nome do servidor Atlassian. No chat, clique no ícone de ferramentas e liste as tools dele. Confirme se existe alguma de upload de anexo.
4. **draw.io CLI:** no terminal, `& "C:\Program Files\draw.io\draw.io.exe" --version`. Se o caminho for outro, anote.
5. **Python (opcional):** `python --version`. Só serve para o validador de XML do draw.io e o linter do arc42.
6. **Acesso ao GitHub:** abra `https://raw.githubusercontent.com/github/awesome-copilot/main/skills/drawio/SKILL.md` no navegador. Se abrir, dá para baixar os arquivos. `gh --version` 2.90 ou mais novo permite instalar skills por comando.
7. **Contrato da macro draw.io:** numa página com um C4 feito à mão, … → Visualizar formato de armazenamento. Copie o bloco `drawio` inteiro e a lista de anexos da página (nome e versão).

## Onde cada peça fica

Tudo vai para `%USERPROFILE%\.copilot`, que o VS Code lê como nível de usuário para agentes, skills e instructions. Assim o agente funciona em qualquer repositório que você abrir.

```
%USERPROFILE%\.copilot\
  agents\
    documentador.agent.md          (nosso, coordena o fluxo)
    revisor-doc.agent.md           (nosso, subagente de revisão)
  skills\
    documentation-writer\          (awesome-copilot)
    drawio\                        (awesome-copilot)
    draw-io-diagram-generator\     (awesome-copilot)
    arc42-section-01 … 12\         (arc42-toolkit)
    arc42-review\                  (arc42-toolkit)
    arc42-lint\                    (arc42-toolkit)
    publicar-confluence-bradesco\  (nossa)
  instructions\
    documentacao.instructions.md   (nossa, versão enxuta)
```

- O nome da pasta de cada skill tem que ser igual ao campo `name` do `SKILL.md`. Se não bater, a skill não carrega e não dá erro.
- Se a checagem 2 mostrar o harness **Local**, crie agente e instructions pelo editor de customizações escolhendo **User**. Ele grava no lugar certo para esse harness.
- Para conferir o que carregou: botão direito no Chat → **Diagnostics**.

## Itens do awesome-copilot

O awesome-copilot não se instala inteiro: é um catálogo. Você copia só as pastas que vai usar. São três skills; o resto entra como referência.

| Item | Tipo | Para quê na Molicar | Ação |
| --- | --- | --- | --- |
| `documentation-writer` | Skill | Entrevista (tipo, público, objetivo, escopo) e sumário para aprovação antes de escrever. Usar nas páginas de Operações e guias. | Instalar |
| `drawio` | Skill | Gera `.drawio` e exporta PNG com o XML embutido pelo CLI do draw.io. | Instalar + `npm install` na pasta `scripts` |
| `draw-io-diagram-generator` | Skill | Templates por tipo de diagrama, referência de estilos e validador de XML. | Instalar |
| `draw-io.instructions.md` | Instruction | Regras de layout e paleta. Aponta para caminhos de repositório que não existem no nível de usuário. | Não instalar; o generator já cobre |
| `SE: Tech Writer` | Agente | Template de ADR e checklist de escaneabilidade. Genérico demais como agente. | Só referência para a nossa skill |

Instalação manual, no PowerShell (funciona mesmo sem `gh`):

```
cd $env:USERPROFILE
git clone --depth 1 https://github.com/github/awesome-copilot.git
$dst = "$env:USERPROFILE\.copilot\skills"
New-Item -ItemType Directory -Force $dst | Out-Null
foreach ($s in "documentation-writer","drawio","draw-io-diagram-generator") {
  Copy-Item -Recurse -Force ".\awesome-copilot\skills\$s" $dst
}
cd "$dst\drawio\scripts"; npm install
```

Antes de copiar, leia cada `SKILL.md` e os scripts. É conteúdo da comunidade e roda na máquina do banco. Se o `npm install` falhar por bloqueio do registro, a exportação continua funcionando chamando o CLI direto: `draw.io.exe -x -f png -e -b 10 -o saida.png entrada.drawio`.

## arc42-toolkit: instalar e usar

São 14 skills: uma por seção do arc42, mais revisão e linter. Cada uma pergunta antes de gerar, rascunha, roda um checklist e itera com você. Licença MIT.

Instalação:

```
cd $env:USERPROFILE
git clone --depth 1 https://github.com/MSiccDev/arc42-toolkit.git
Get-ChildItem .\arc42-toolkit\skills -Directory |
  ForEach-Object { Copy-Item -Recurse -Force $_.FullName "$env:USERPROFILE\.copilot\skills" }
```

O linter (`scripts\arc42-lint.py`) é opcional, só com Python, e aceita `--lang pt`.

Como usar no chat: digite `/arc42-section-03` (ou outra seção), responda as perguntas e escolha a profundidade **LEAN**. Para a Molicar, o mínimo que vale fazer:

1. Seção 1.2, metas de qualidade (ex.: consulta abaixo de 10 ms, carga sem perda de dado).
2. Seção 3, contexto (C4 nível 1).
3. Seção 5, blocos de construção nível 1 (C4 nível 2).
4. Seção 9, decisões (os ADRs que já existem).
5. Seção 12, glossário (DV, HO, PR, termos da Molicar).

Três ajustes, todos feitos na nossa instruction, sem editar os arquivos do toolkit (assim dá para atualizar depois):

- **Diagramas:** o toolkit usa C4 em PlantUML por padrão. Para nós, sempre draw.io.
- **Saída:** o toolkit escreve em `docs/` do projeto. Para nós, o rascunho vai para uma pasta de trabalho fora dos repositórios e quem publica no Confluence é o agente, pelo MCP.
- **Idioma:** sempre português.

## Peças nossas

Os quatro arquivos estão no kit-documentador.zip (harness Local, servidor mcp-atlassian, contrato da macro drawio lido em 02/10). O nosso `documentacao.instructions.md` atual vira a base deles e deixa de ser anexado na mão com `#file`.

| Arquivo | O que faz | Ferramentas |
| --- | --- | --- |
| `documentador.agent.md` | Agente que você seleciona no chat. Conduz o fluxo abaixo e chama as skills certas. | Leitura e busca no código, edição só na pasta de rascunho, terminal (CLI do draw.io), todas as tools do MCP, subagente |
| `revisor-doc.agent.md` | Subagente escondido do menu. Revisa o rascunho com contexto limpo, contra o código e a regra de legibilidade. Não edita. | Só leitura, incluindo leitura do Confluence |
| `documentacao.instructions.md` | Versão enxuta: hierarquia de confiança, legibilidade (seção 12), nomenclatura e taxonomia DV/HO/PR, os três ajustes do arc42. | — |
| `publicar-confluence-bradesco` | Skill com a mecânica do Confluence: macros permitidas (sem `mermaid`), contrato da macro draw.io e upload do anexo, `excerpt-include`, contagem de macros antes e depois. | Tools do MCP |

Fluxo de uma rodada com o Documentador:

1. **Entrevista e sumário** (só leitura): lê código e página atual, usa `documentation-writer` ou a seção do arc42 que couber, propõe o esqueleto da página.
2. **Você aprova** o esqueleto.
3. **Rascunho:** escreve o texto na pasta de trabalho e gera o diagrama com `drawio`.
4. **Revisão:** chama o `revisor-doc`. Se ele apontar problema, volta ao passo 3.
5. **Publicação:** usa a skill de publicação e grava pelo MCP, com changelog no rodapé.

O subagente de revisão pode usar um modelo mais forte que o Luna, porque roda poucas vezes. Decidimos isso quando virmos o consumo de créditos da primeira rodada.

## Mapa arc42 para a árvore Molicar

A árvore atual fica como está: o arc42 define o conteúdo de cada página, não a hierarquia. Nada é renomeado nem movido agora.

| Página no Confluence | Seção arc42 | Skill |
| --- | --- | --- |
| Visão Geral | 1 (objetivo e metas de qualidade) + 12 (glossário) + status por componente | `arc42-section-01`, `arc42-section-12` |
| Arquitetura / C4 Nível 1 | 3, contexto | `arc42-section-03` |
| Arquitetura / C4 Nível 2 | 5, blocos nível 1 | `arc42-section-05` |
| Arquitetura / Fluxo E2E | 6, visão de execução | `arc42-section-06` |
| ADRs 001 a 006 | 9, decisões | `arc42-section-09` |
| Azure Function, PostgreSQL e filhos, Azure Data Factory (a criar) | 5, blocos nível 2 (caixa-branca de cada componente) | `arc42-section-05` |
| Operações (circuit breakers, integridade pós-carga) | Fora do arc42: guia how-to | `documentation-writer` |

Os dois pontos técnicos em aberto (`runOnStartup: true` e o timer que não captura exceção) entram na seção 11, riscos e débito técnico, como uma seção curta da Visão Geral.

A ordem das rodadas continua a combinada: reformatar Azure Function, reformatar PostgreSQL, criar ADF, reconciliar ADRs e Operações, Visão Geral por último.

## Verificação e primeiro teste

O primeiro teste para no esqueleto aprovado, sem publicar nada. Só depois de ver o esqueleto bom a gente libera a publicação.

- [ ] Editor de customizações lista as 3 skills do awesome-copilot, as 14 do arc42 e as nossas.
- [ ] Chat → botão direito → Diagnostics sem erro de carregamento.
- [ ] Digitar `/` no chat mostra `/documentation-writer` e `/arc42-section-03`.
- [ ] Teste de diagrama: pedir um diagrama de três caixas com a skill `drawio`, exportar PNG e abrir o PNG no draw.io. Tem que abrir editável.
- [ ] Primeira rodada real com o Documentador na página Azure Function, até o esqueleto. Comparar com a página atual.
- [ ] Anotar quantos créditos a rodada consumiu.

## Cuidados e riscos

- **Conteúdo de terceiros:** leia cada `SKILL.md` e script antes de copiar, e não libere aprovação automática de terminal para esses scripts. Confirme se a política do banco permite trazer repositórios públicos.
- **Contexto e créditos:** instalar 20 skills não pesa. O Copilot lê só nome e descrição de cada uma e carrega o corpo apenas quando usa.
- **arc42-toolkit é jovem:** cerca de 30 estrelas e um mantenedor. Por isso os ajustes ficam na nossa instruction e os arquivos dele ficam intactos.
- **Diagrama na página depende do anexo:** sem tool de upload no MCP, o agente gera o `.drawio` e o PNG, mas a inserção na página fica manual até resolvermos a chamada à API de anexos.

## Fontes

- [awesome-copilot: catálogo de skills](https://raw.githubusercontent.com/github/awesome-copilot/main/docs/README.skills.md)
- [Skill documentation-writer](https://raw.githubusercontent.com/github/awesome-copilot/main/skills/documentation-writer/SKILL.md)
- [Skill drawio](https://raw.githubusercontent.com/github/awesome-copilot/main/skills/drawio/SKILL.md)
- [arc42-toolkit](https://github.com/MSiccDev/arc42-toolkit)
- [VS Code: Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [VS Code: custom agents](https://code.visualstudio.com/docs/agent-customization/custom-agents)
- [VS Code: custom instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions)
