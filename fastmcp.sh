Contexto: este repositório é o kit do agente Documentador. A fonte da verdade é o #file:LEIA-ME.md.
O #file:setup-agente-documentacao.md é histórico: se ele contradisser o LEIA-ME, vale o LEIA-ME.
Harness: Local. Terminal: Git Bash (só comandos bash).

Tarefa: instalar e verificar o kit. Não edite nenhum arquivo do kit (prompts/, skills/, *.sh, LEIA-ME.md).
Se algo falhar ou parecer errado, pare e me reporte; não corrija por conta própria.

1. Rode `bash baixar-skills.sh` e mostre a saída (esperado: 30 arquivos, 17 pastas).
2. Rode `bash instalar.sh` e mostre a saída.
3. Verifique e me mostre a listagem:
   - `ls "$APPDATA/Code/User/prompts"` → documentador.agent.md, revisor-doc.agent.md, documentacao.instructions.md
   - `ls "$HOME/.copilot/skills"` → as 17 skills + publicar-confluence-bradesco (18 pastas)
   - `ls "$HOME/.copilot/agents" "$HOME/.copilot/instructions" 2>/dev/null` → deve estar vazio ou não existir; se tiver arquivos do Documentador, liste e não apague
   - procure cópias antigas no workspace: `find . -path ./node_modules -prune -o \( -name "*.agent.md" -o -name "documentacao.instructions.md" \) -print` fora da pasta prompts/
4. Para cada skill, confirme que o nome da pasta é igual ao campo `name:` do SKILL.md.
5. Responda em lista: OK ou FALHA por passo, com a evidência.
