#!/usr/bin/env bash
# Baixa as skills de terceiros para ~/.copilot/skills pelo raw.githubusercontent.com
# (o proxy do banco bloqueia git clone e codeload).
# Commits fixados: conteudo lido e revisado em 05/10/2026.
# Uso no Git Bash:  bash baixar-skills.sh

destino="$HOME/.copilot/skills"

# O proxy do banco inspeciona TLS com um certificado corporativo que o curl do Git Bash
# (OpenSSL) nao conhece. O curl.exe do Windows usa o repositorio de certificados do
# Windows, onde esse certificado ja esta instalado. Nunca usar -k/--insecure.
if [ -x /c/Windows/System32/curl.exe ]; then
  CURL=(/c/Windows/System32/curl.exe)
else
  CURL=(curl --ca-native)
fi
echo "Usando: ${CURL[*]}"
ok=0; falhas=0

while read -r base arq; do
  [ -z "$arq" ] && continue
  saida="$destino/${arq#skills/}"
  if "${CURL[@]}" -fsSL --create-dirs -o "$saida" "$base/$arq"; then
    ok=$((ok+1))
  else
    echo "FALHA: $arq"; falhas=$((falhas+1))
  fi
done <<'LISTA'
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/documentation-writer/SKILL.md
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/SKILL.md
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/assets/templates/architecture.drawio
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/assets/templates/er-diagram.drawio
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/assets/templates/flowchart.drawio
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/assets/templates/sequence.drawio
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/assets/templates/uml-class.drawio
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/references/drawio-xml-schema.md
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/references/shape-libraries.md
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/references/style-reference.md
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/scripts/README.md
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/scripts/add-shape.py
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/draw-io-diagram-generator/scripts/validate-drawio.py
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/drawio/SKILL.md
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/drawio/scripts/drawio-to-png.mjs
https://raw.githubusercontent.com/github/awesome-copilot/143a3d976b3c1603cc8932984d5e1f28501cb5fc skills/drawio/scripts/package.json
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-lint/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-review/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-01/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-02/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-03/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-04/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-05/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-06/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-07/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-08/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-09/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-10/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-11/SKILL.md
https://raw.githubusercontent.com/MSiccDev/arc42-toolkit/97492c34cdbdb87dc6ea97ae6edbd9673167aed5 skills/arc42-section-12/SKILL.md
LISTA

echo "Baixados: $ok arquivos em $destino"
[ "$falhas" -gt 0 ] && { echo "Falhas: $falhas"; exit 1; }
ls -1 "$destino"
