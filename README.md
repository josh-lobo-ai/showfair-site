# showfair-site — 🛑 DEPRECATED (não é mais o site público)

> **PARE. Este repo NÃO serve mais www.showfair.com.br.** Desde o corte de DNS de 22/07/2026, o site público é o **`showfair-web`** (Next.js/Vercel — `C:\dev\showfair-web`). O DNS aponta o `www` só pra Vercel; **publicar aqui (via `deploy.ps1`) NÃO aparece pra ninguém.**
>
> - Para editar/deployar o site público: use **`showfair-web`** e leia `showfair-web/docs/ARQUITETURA.md` antes de tocar.
> - Este repo fica só como **backup/rollback de emergência do DNS** (o `index.html` legado). Não editar, não deployar, não rodar `deploy.ps1` aqui.
> - O workflow `inject-capture.yml` foi desligado (renomeado `.disabled`).

---

*(Histórico — conteúdo abaixo é da época em que este repo era o site público, mantido só para referência.)*

Site institucional **público/externo** da Show Fair. Foi o site em **https://www.showfair.com.br** via **GitHub Pages** até 22/07/2026.

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

O `deploy.ps1` faz: `pull --rebase` (sincroniza) → envelopa (se preciso) → **trava anti-stale** → stage **explícito** de `index.html`/`CNAME`/`.nojekyll`/`.deploy-meta.json` (nunca `git add -A`) → commit → `pull --rebase` → `push origin main`.

## Segurança / múltiplas sessões (não perder, não sobrescrever)
Garantias da rota quando há várias sessões atuando:
1. **Nada publicado se perde.** Todo deploy é 1 commit. O histórico do git guarda **todas** as versões — qualquer uma volta com `git checkout <sha> -- index.html`.
2. **Não sobrescreve build novo com build velho.** O `deploy.ps1` grava em `.deploy-meta.json` a data do build publicado. Se alguém tentar importar (`-Source`) um build **mais antigo** que o último, o script **aborta** e avisa. Só passa com `-Force` (uso consciente).
3. **Não varre WIP de outra sessão.** Stage é **explícito** (só os arquivos do site), nunca `git add -A`.
4. **Não diverge do remoto.** O script faz `pull --rebase` antes e depois; se outra sessão publicou nesse meio, ele reconcilia em vez de derrubar.
5. **Cuidado com o efêmero.** Builds em `scratchpad` de sessões são temporários. Regra: **assim que melhorar o site, publique** (`deploy.ps1`) — aí o trabalho entra no git e fica salvo. Não deixe a única cópia no scratchpad.

**Fonte da verdade = `index.html` deste repo.** Editar aqui e publicar é o caminho mais seguro (cada mudança já vira backup no git).

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
