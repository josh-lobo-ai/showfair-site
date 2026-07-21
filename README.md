# showfair-site — site institucional (externo)

Site institucional **público/externo** da Show Fair. No ar em **https://www.showfair.com.br** via **GitHub Pages**.

> ⚠️ Não confundir com o Show Fair do **youni.my**, que é o acervo **interno** (atrás de login). Aquele é interno; **este repo é o site público institucional**.

## Arquitetura
- **Fonte da verdade:** `index.html` (documento único, self-contained — fontes e imagens embutidas em base64, zero dependência externa).
- **Host:** GitHub Pages, branch `main`, raiz. Deploy automático a cada push (~30s + SSL automático).
- **Domínio:** `www.showfair.com.br` (arquivo `CNAME`). Titular do domínio: BioPayments; DNS no Registro.br.
- `.nojekyll` impede o Jekyll de processar o HTML.

## A rota: qualquer sessão melhora o mockup e publica
Dois modos, ambos terminam em `www.showfair.com.br`:

**A) Editar direto no repo** (recomendado a partir de agora)
1. Abra e melhore `index.html`.
2. Publique:
   ```
   powershell -ExecutionPolicy Bypass -File deploy.ps1
   ```

**B) Importar um build novo** (ex.: HTML gerado por um artifact / outra sessão)
```
powershell -ExecutionPolicy Bypass -File deploy.ps1 -Source "C:\caminho\para\build.html"
```
Se o arquivo for um **fragmento de artifact** (começa com `<title>`/`<style>`, sem `<!doctype>`), o script **envelopa automaticamente** com `head.tmpl.html` (charset UTF-8, viewport, título, meta OG). Se já for um documento HTML completo, publica como está.

O `deploy.ps1` faz: envelopa (se preciso) → stage **explícito** de `index.html`/`CNAME`/`.nojekyll` (nunca `git add -A`) → commit → `pull --rebase` → `push origin main`.

## Bootstrap numa máquina nova
```
gh repo clone josh-lobo-ai/showfair-site C:\dev\showfair-site
```
(precisa do `gh` autenticado como `josh-lobo-ai`.)

## Verificar
Com o CNAME ativo, a URL `josh-lobo-ai.github.io/showfair-site` redireciona para o domínio. Para testar o build cru sem depender do DNS, adicione `?nocache=<n>` para furar o 301 em cache, ou consulte o status:
```
gh api /repos/josh-lobo-ai/showfair-site/pages/builds/latest --jq '{status:.status, error:.error.message}'
```
