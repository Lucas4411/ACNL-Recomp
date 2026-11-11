# Publicar o ACNL-Recomp no GitHub

Esta pasta é o **repositório de código**. Ela **não contém** ROM, assets, saves
ou caminhos pessoais. Os arquivos da release são gerados pelos scripts em
`build\` (veja `docs\COMO-COMPILAR.md`).

## Arquivos da release

| Arquivo | Para que serve |
| :--- | :--- |
| `ACNL-Setup-2.0.exe` | Instalador (recomendado para a maioria dos usuários) — `build\build-installer.ps1` |
| `ACNL-Portable-2.0.zip` | Versão portátil, sem instalador — `build\build-portable.ps1` |
| `ACNL-Installer-v2.0.zip` | O instalador + documentação, em ZIP |
| `SHA256SUMS.txt` | Hashes para verificar os downloads |
| `README.md` | Texto principal do repositório |
| `docs\LEIA-ME.txt` | Instruções para o usuário final |
| `THIRD-PARTY-NOTICES.txt` | Créditos e licenças de terceiros |
| `LICENSE` | Licença MIT do projeto |

---

## 1. Criar o repositório

1. Acesse <https://github.com/new>.
2. Nome sugerido: `ACNL-Recomp`.
3. Visibilidade: **Public**.
4. Descrição sugerida:
   > Launcher e instalador para PC do ACNL-Recomp — recompilação estática de Animal Crossing: New Leaf. Sem ROM ou assets.
5. Envie todo o conteúdo de `ACNL-Recomp-Source` (código, docs e scripts de
   build) para o repositório.
   - **Não** envie ROM, `game-data\`, `output\`, `zakuro\`, `tools\` nem
     `installer\3dsrecomp.exe` (o `.gitignore` já bloqueia esses itens).

> Dica: o `README.md` já contém o aviso legal e as instruções. Se quiser, adicione uma captura de tela do launcher no topo.

---

## 2. Criar a release `v2.0`

1. No repositório, abra **Releases** → **Draft a new release**.
2. **Choose a tag**: `v2.0` → **Create new tag on publish**.
3. **Target**: `main`.
4. **Release title**: `ACNL-Recomp v2.0`.
5. Anexe os arquivos:
   - `ACNL-Setup-2.0.exe`
   - `ACNL-Portable-2.0.zip`
   - `ACNL-Installer-v2.0.zip`
   - `SHA256SUMS.txt`
6. Marque como **Latest release** e publique.

---

## 3. Texto sugerido para a release

```markdown
## ACNL-Recomp v2.0

Instalador e launcher para PC do ACNL-Recomp, a recompilação estática de
Animal Crossing: New Leaf (Nintendo 3DS) para x86_64.

### O que o instalador faz
- Instala o launcher e o recompilador `3dsrecomp`.
- Baixa automaticamente o runtime Zakuro e o compilador w64devkit (GCC).
- Verifica os downloads por SHA256, com até 3 tentativas e exibição de velocidade/ETA.
- Abre o launcher ao terminar.

### Novidades
- Janela do jogo com o título limpo ("Animal Crossing: New Leaf") e ícone da folha.
- Progresso real da recompilação (X de Y arquivos e porcentagem).
- Botão Cancelar durante a recompilação.
- Downloads mais confiáveis (SHA256 + retry).
- Versão portátil em ZIP.

### Como usar
1. Baixe `ACNL-Setup-2.0.exe` e execute.
2. Selecione a sua própria ROM (`.3ds` ou `.cxi`).
3. Clique em Recompilar e depois em JOGAR.

### Aviso legal
Este projeto não contém e não distribui ROM, assets ou qualquer material
protegido por direitos autorais da Nintendo. É necessário possuir uma cópia
legítima do jogo e gerar o seu próprio dump.

### Verificação
Confira os hashes em `SHA256SUMS.txt`.
```

---

## 4. Checklist antes de publicar

- [ ] Testar o instalador em uma **VM ou PC limpo** (sem MSYS2/GCC instalado).
- [ ] Confirmar que `ACNL-Setup-2.0.exe` instala, abre o launcher e desinstala.
- [ ] Confirmar que a desinstalação preserva `game-data\`, `output\` e `launcher_config.json`.
- [ ] Testar a versão portátil (`INICIAR.cmd`) em uma pasta nova.
- [ ] Conferir os hashes de `SHA256SUMS.txt`.
- [ ] Confirmar que nenhum arquivo da release contém ROM, assets, saves ou caminhos pessoais.
- [ ] Revisar o aviso legal no `README.md` e no `LEIA-ME.txt`.
- [ ] (Opcional) Assinar o executável para reduzir o aviso do SmartScreen.
- [ ] (Opcional) Criar um workflow de GitHub Actions para gerar o instalador a cada tag.

---

## 5. Verificar os hashes (Windows)

No PowerShell, dentro da pasta dos arquivos baixados:

```powershell
Get-FileHash .\ACNL-Setup-2.0.exe -Algorithm SHA256
Get-FileHash .\ACNL-Portable-2.0.zip -Algorithm SHA256
Get-FileHash .\ACNL-Installer-v2.0.zip -Algorithm SHA256
```

Compare com o conteúdo de `SHA256SUMS.txt`.

---

## 6. Observações

- **SmartScreen:** como o executável não tem assinatura de código, o Windows pode exibir um aviso na primeira execução. Isso é esperado; a assinatura exige um certificado (geralmente pago).
- **Atualizações de dependências:** o bootstrap consulta a API do GitHub para pegar a versão mais recente do Zakuro e do w64devkit. Se a API falhar, usa URLs e hashes fixos de fallback.
- **ROM:** nunca anexe ROM, assets, saves ou a pasta `game-data\` na release.
