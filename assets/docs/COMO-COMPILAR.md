# Como compilar

Passo a passo para gerar o launcher, o instalador e a versão portátil a partir
do código-fonte.

---

## 1. Requisitos

| Item | Observação |
| :--- | :--- |
| Windows 10/11 64 bits | O launcher é WPF/PowerShell e o alvo é x86_64 |
| Windows PowerShell 5.1 | Já vem no Windows (`powershell.exe`) |
| [ps2exe](https://github.com/MScholtes/PS2EXE) | Compila os `.ps1` em `.exe` |
| [Inno Setup 6](https://jrsoftware.org/isinfo.php) | Gera o `ACNL-Setup-2.0.exe` |
| `3dsrecomp.exe` | Recompilador (MIT). Não é redistribuído aqui |

Instale o ps2exe uma vez:

```powershell
Install-Module ps2exe -Scope CurrentUser
```

### Sobre o `3dsrecomp.exe`

O repositório oficial <https://github.com/fearkov/3dsrecomp> não publica binário
pronto. Duas opções:

- **Compilar:** `cargo build --release` no repositório do 3dsrecomp e copiar
  `target\release\3dsrecomp.exe`.
- **Extrair do instalador oficial:** rode `ACNL-Setup-2.0.exe` (da página de
  releases) e copie o `3dsrecomp.exe` da pasta de instalação.

Coloque o arquivo em `installer\3dsrecomp.exe`.

---

## 2. Compilar o launcher e o bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File build\build-launcher.ps1
```

Saída em `installer\`:

- `ACNL-Launcher.exe`
- `ACNL-Bootstrap.exe`

O script usa `ps2exe` com as flags `-x64 -STA -noConsole -DPIAware -supportOS
-noConfigFile` e garante que os `.ps1` fiquem em UTF-8 com BOM (necessário para
os acentos no Windows PowerShell).

---

## 3. Gerar o instalador

```powershell
powershell -ExecutionPolicy Bypass -File build\build-installer.ps1
```

Saída: `installer\output\ACNL-Setup-2.0.exe`.

Se o Inno Setup estiver em outro lugar:

```powershell
powershell -ExecutionPolicy Bypass -File build\build-installer.ps1 -Iscc "C:\caminho\ISCC.exe"
```

---

## 4. Gerar a versão portátil (opcional)

```powershell
powershell -ExecutionPolicy Bypass -File build\build-portable.ps1
```

Saída:

- `dist\ACNL-Portable-2.0\` — pasta pronta para usar
- `dist\ACNL-Portable-2.0.zip`

---

## 5. Testar sem compilar

O launcher roda direto como script, o que ajuda a depurar a interface:

```powershell
powershell -ExecutionPolicy Bypass -File launcher\ACNL-Launcher.ps1
```

Para o launcher encontrar o projeto, ele deve estar na mesma pasta de
`zakuro\zakuro.exe` (ou selecione a pasta quando ele pedir).

---

## Estrutura gerada

```
installer\
  ACNL-Launcher.exe        (build)
  ACNL-Bootstrap.exe       (build)
  3dsrecomp.exe            (você fornece)
  leaf.ico
  installer.iss
  output\
    ACNL-Setup-2.0.exe     (build)
dist\
  ACNL-Portable-2.0\
  ACNL-Portable-2.0.zip
```

---

## Problemas comuns

- **`Import-Module ps2exe` falha:** instale com
  `Install-Module ps2exe -Scope CurrentUser` e confirme com
  `Get-Module ps2exe -ListAvailable`.
- **Acentos quebrados no `.exe`:** os `.ps1` precisam de BOM UTF-8; o
  `build-launcher.ps1` já cuida disso.
- **`ISCC.exe nao encontrado`:** instale o Inno Setup 6 ou use `-Iscc`.
- **Instalador não compila por falta de arquivo:** rode
  `build\build-launcher.ps1` antes e confirme que `installer\3dsrecomp.exe`
  existe.
