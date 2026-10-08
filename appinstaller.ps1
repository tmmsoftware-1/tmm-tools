# ============================================================
# TMM APP INSTALLER - DOWNLOAD PARALELO
# Maximo de 3 downloads simultaneos
# Instalacao sequencial
# ============================================================



# ============================================================
# PROTECAO DO CONSOLE - DESATIVAR QUICKEDIT
# Evita pausar o script ao clicar dentro do PowerShell classico.
# ============================================================

try {

    if (-not ("TMMConsoleMode" -as [type])) {

        Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class TMMConsoleMode
{
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(
        IntPtr hConsoleHandle,
        out uint lpMode
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(
        IntPtr hConsoleHandle,
        uint dwMode
    );
}
"@
    }

    $STD_INPUT_HANDLE = -10
    $ENABLE_QUICK_EDIT_MODE = 0x0040
    $ENABLE_EXTENDED_FLAGS = 0x0080

    $consoleInput = [TMMConsoleMode]::GetStdHandle($STD_INPUT_HANDLE)
    $consoleMode = 0

    if (
        [TMMConsoleMode]::GetConsoleMode(
            $consoleInput,
            [ref]$consoleMode
        )
    ) {

        $script:TMMConsoleInputHandle = $consoleInput
        $script:TMMConsoleModeOriginal = [uint32]$consoleMode
        $script:TMMQuickEditAlterado = $true

        $novoModo = (
            $consoleMode -bor $ENABLE_EXTENDED_FLAGS
        ) -band (
            -bnot $ENABLE_QUICK_EDIT_MODE
        )

        [TMMConsoleMode]::SetConsoleMode(
            $consoleInput,
            [uint32]$novoModo
        ) | Out-Null
    }
}
catch {

    # Se o console nao suportar essa configuracao,
    # o TMM continua funcionando normalmente.
    $script:TMMQuickEditAlterado = $false
}


# Restaurar configuracao original quando o PowerShell encerrar.
Register-EngineEvent `
    -SourceIdentifier PowerShell.Exiting `
    -Action {

        if ($script:TMMQuickEditAlterado) {

            try {

                [TMMConsoleMode]::SetConsoleMode(
                    $script:TMMConsoleInputHandle,
                    [uint32]$script:TMMConsoleModeOriginal
                ) | Out-Null
            }
            catch {}
        }

    } | Out-Null


# ============================================================
# FUNCAO - EXECUTAR WINGET COM TIMEOUT
# ============================================================

function Invoke-WingetTMM {

    param (
        [string[]]$Argumentos,
        [int]$Timeout = 30
    )

    $wingetPath = (Get-Command winget.exe -ErrorAction SilentlyContinue).Source

    if (-not $wingetPath) {
        return @{
            Sucesso = $false
            Timeout = $false
            Codigo  = -1
            Saida   = "WinGet nao encontrado."
        }
    }

    $job = Start-Job -ScriptBlock {

        param (
            $CaminhoWinget,
            $ArgsWinget
        )

        $saida = & $CaminhoWinget @ArgsWinget 2>&1
        $codigo = $LASTEXITCODE

        [PSCustomObject]@{
            Codigo = $codigo
            Saida  = ($saida | Out-String)
        }

    } -ArgumentList $wingetPath, (,$Argumentos)


    $resultadoJob = Wait-Job $job -Timeout $Timeout


    if (-not $resultadoJob) {

        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue

        return @{
            Sucesso = $false
            Timeout = $true
            Codigo  = -1
            Saida   = "TIMEOUT"
        }
    }


    $resultado = Receive-Job $job

    Remove-Job $job -Force -ErrorAction SilentlyContinue


    return @{
        Sucesso = ($resultado.Codigo -eq 0)
        Timeout = $false
        Codigo  = $resultado.Codigo
        Saida   = $resultado.Saida
    }
}


# ============================================================
# TESTAR WINGET
# ============================================================

function Testar-Winget {

    return Invoke-WingetTMM `
        -Argumentos @(
            "search",
            "--id",
            "7zip.7zip",
            "-e",
            "--source",
            "winget",
            "--accept-source-agreements"
        ) `
        -Timeout 20
}


# ============================================================
# CABECALHO
# ============================================================

Clear-Host

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "          TMM APP INSTALLER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Solucoes simples para grandes resultados."
Write-Host ""

Write-Host "Preparando ambiente..." -ForegroundColor Yellow
Write-Host ""


# ============================================================
# VERIFICAR WINGET
# ============================================================

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {

    Write-Host "[ERRO] WinGet nao encontrado." -ForegroundColor Red
    Write-Host ""
    Write-Host "Codigo TMM: TMM-AI-001"

    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "[OK] WinGet encontrado." -ForegroundColor Green

Write-Host "[...] Verificando catalogo do WinGet..." -ForegroundColor Yellow

$testeWinget = Testar-Winget

if (-not $testeWinget.Sucesso) {

    Write-Host ""
    Write-Host "[ERRO] O catalogo do WinGet nao esta funcionando." -ForegroundColor Red
    Write-Host ""
    Write-Host "Codigo TMM: TMM-AI-002"

    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "[OK] Catalogo do WinGet funcionando." -ForegroundColor Green
Write-Host ""
Write-Host "[OK] Ambiente pronto." -ForegroundColor Green
Write-Host ""


# ============================================================
# CATALOGO
# ============================================================

$catalogo = @{

    "1"  = @{ Nome = "Google Chrome";        Id = "Google.Chrome" }
    "2"  = @{ Nome = "Mozilla Firefox";      Id = "Mozilla.Firefox" }
    "3"  = @{ Nome = "Opera";                Id = "Opera.Opera" }
    "4"  = @{ Nome = "Brave";                Id = "Brave.Brave" }

    "5"  = @{ Nome = "7-Zip";                Id = "7zip.7zip" }
    "6"  = @{ Nome = "WinRAR";               Id = "RARLab.WinRAR" }

    "7"  = @{ Nome = "VLC";                  Id = "VideoLAN.VLC" }
    "8"  = @{ Nome = "Spotify";              Id = "Spotify.Spotify" }
    "9"  = @{ Nome = "OBS Studio";           Id = "OBSProject.OBSStudio" }

    "10" = @{ Nome = "Discord";              Id = "Discord.Discord" }
   
    "12" = @{ Nome = "Telegram";             Id = "Telegram.TelegramDesktop" }
    "13" = @{ Nome = "Zoom";                 Id = "Zoom.Zoom" }
    "14" = @{ Nome = "Microsoft Teams";      Id = "Microsoft.Teams" }

    "15" = @{ Nome = "Steam";                Id = "Valve.Steam" }
    "16" = @{ Nome = "Epic Games Launcher";  Id = "EpicGames.EpicGamesLauncher" }

    "17" = @{ Nome = "Visual Studio Code";    Id = "Microsoft.VisualStudioCode" }
    "18" = @{ Nome = "Git";                  Id = "Git.Git" }
    "19" = @{ Nome = "Python";               Id = "Python.Python.3.14" }
    "20" = @{ Nome = "Node.js LTS";          Id = "OpenJS.NodeJS.LTS" }
    "21" = @{ Nome = "PuTTY";                Id = "PuTTY.PuTTY" }

    "22" = @{ Nome = "Microsoft PowerToys";  Id = "Microsoft.PowerToys" }
    "23" = @{ Nome = "Notepad++";            Id = "Notepad++.Notepad++" }
    "24" = @{ Nome = "Everything";           Id = "voidtools.Everything" }
    "25" = @{ Nome = "ShareX";               Id = "ShareX.ShareX" }
    "26" = @{ Nome = "CPU-Z";                Id = "CPUID.CPU-Z" }
    "27" = @{ Nome = "HWiNFO";               Id = "REALiX.HWiNFO" }
    "28" = @{ Nome = "Revo Uninstaller";     Id = "RevoUninstaller.RevoUninstaller" }
    "30" = @{ Nome = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit" }
    "31" = @{ Nome = "LibreOffice";          Id = "TheDocumentFoundation.LibreOffice" }

    "32" = @{ Nome = "AnyDesk";              Id = "AnyDesk.AnyDesk" }
    "33" = @{ Nome = "RustDesk";             Id = "RustDesk.RustDesk" }
    "34" = @{ Nome = "TeamViewer";           Id = "TeamViewer.TeamViewer" }
}


# ============================================================
# MENU PRINCIPAL
# ============================================================

Write-Host "[1] Atualizar aplicativos"
Write-Host "[2] Instalar aplicativos"
Write-Host "[0] Sair"
Write-Host ""

$opcao = Read-Host "Escolha uma opcao"


# ============================================================
# ATUALIZAR
# ============================================================

if ($opcao -eq "1") {

    Clear-Host

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       ATUALIZAR APLICATIVOS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    winget upgrade `
        --source winget `
        --accept-source-agreements

    Write-Host ""

    $confirmacao = Read-Host "Deseja atualizar todos? (S/N)"

    if ($confirmacao -match "^[Ss]$") {

        winget upgrade `
            --all `
            --source winget `
            --accept-package-agreements `
            --accept-source-agreements
    }
}


# ============================================================
# INSTALAR
# ============================================================

elseif ($opcao -eq "2") {

    Clear-Host

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       INSTALAR APLICATIVOS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "NAVEGADORES" -ForegroundColor Yellow
    Write-Host "[1] Google Chrome"
    Write-Host "[2] Mozilla Firefox"
    Write-Host "[3] Opera"
    Write-Host "[4] Brave"
    Write-Host ""

    Write-Host "COMPACTACAO" -ForegroundColor Yellow
    Write-Host "[5] 7-Zip"
    Write-Host "[6] WinRAR"
    Write-Host ""

    Write-Host "MULTIMIDIA" -ForegroundColor Yellow
    Write-Host "[7] VLC"
    Write-Host "[8] Spotify"
    Write-Host "[9] OBS Studio"
    Write-Host ""

    Write-Host "COMUNICACAO" -ForegroundColor Yellow
    Write-Host "[10] Discord"
    Write-Host "[12] Telegram"
    Write-Host "[13] Zoom"
    Write-Host "[14] Microsoft Teams"
    Write-Host ""

    Write-Host "JOGOS" -ForegroundColor Yellow
    Write-Host "[15] Steam"
    Write-Host "[16] Epic Games Launcher"
    Write-Host ""

    Write-Host "DESENVOLVIMENTO" -ForegroundColor Yellow
    Write-Host "[17] Visual Studio Code"
    Write-Host "[18] Git"
    Write-Host "[19] Python"
    Write-Host "[20] Node.js"
    Write-Host "[21] PuTTY"
    Write-Host ""

    Write-Host "UTILITARIOS" -ForegroundColor Yellow
    Write-Host "[22] Microsoft PowerToys"
    Write-Host "[23] Notepad++"
    Write-Host "[24] Everything"
    Write-Host "[25] ShareX"
    Write-Host "[26] CPU-Z"
    Write-Host "[27] HWiNFO"
    Write-Host "[28] Revo Uninstaller"
    Write-Host ""

    Write-Host "DOCUMENTOS" -ForegroundColor Yellow
    Write-Host "[30] Adobe Acrobat Reader"
    Write-Host "[31] LibreOffice"
    Write-Host ""

    Write-Host "ACESSO REMOTO" -ForegroundColor Yellow
    Write-Host "[32] AnyDesk"
    Write-Host "[33] RustDesk"
    Write-Host "[34] TeamViewer"
    Write-Host ""

    Write-Host "[0] Voltar"
    Write-Host ""

    $entrada = Read-Host "Aplicativos separados por virgula"

    if ($entrada -eq "0") {
        exit
    }


    # ========================================================
    # VALIDAR SELECAO
    # ========================================================

    $numeros = $entrada -split ","

    $selecionados = @()
    $invalidos = @()


    foreach ($numero in $numeros) {

        $numero = $numero.Trim()

        if ($catalogo.ContainsKey($numero)) {

            if (-not ($selecionados | Where-Object { $_.Numero -eq $numero })) {

                $selecionados += [PSCustomObject]@{
                    Numero = $numero
                    Nome   = $catalogo[$numero].Nome
                    Id     = $catalogo[$numero].Id
                }
            }
        }
        else {

            $invalidos += $numero
        }
    }


    if ($selecionados.Count -eq 0) {

        Write-Host ""
        Write-Host "[ERRO] Nenhum aplicativo valido selecionado." -ForegroundColor Red

        Read-Host "Pressione ENTER para sair"
        exit
    }


    # ========================================================
    # PASTA DOWNLOADS
    # ========================================================

    $pastaDownloads = Join-Path $env:USERPROFILE "Downloads\TMM - Downloads"

    if (-not (Test-Path $pastaDownloads)) {

        New-Item `
            -ItemType Directory `
            -Path $pastaDownloads `
            -Force |
            Out-Null
    }


    # ========================================================
    # FASE 1 - DOWNLOAD PARALELO
    # ========================================================

    Clear-Host

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "         BAIXANDO APLICATIVOS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Maximo de downloads simultaneos: 3"
    Write-Host ""

    $wingetPath = (Get-Command winget.exe).Source

   $fila = New-Object System.Collections.Queue

$diretos = @()
$baixados = @()
$falhasDownload = @()
$jobsAtivos = @()

foreach ($app in $selecionados) {

    $config = $catalogo[$app.Numero]

    if ($config.ContainsKey("Direto") -and $config.Direto -eq $true) {

        Write-Host "[DIRETO] $($app.Nome) sera instalado sem download previo." -ForegroundColor Cyan

        $diretos += $app
    }
    else {

        $fila.Enqueue($app)
    }
}

    $maxDownloads = 3


    while (
        $fila.Count -gt 0 -or
        $jobsAtivos.Count -gt 0
    ) {

        # ----------------------------------------------------
        # INICIAR NOVOS DOWNLOADS
        # ----------------------------------------------------

        while (
            $fila.Count -gt 0 -and
            $jobsAtivos.Count -lt $maxDownloads
        ) {

            $app = $fila.Dequeue()

            Write-Host "[INICIANDO] $($app.Nome)" -ForegroundColor Yellow

            $job = Start-Job -ScriptBlock {

                param (
                    $WingetPath,
                    $AppNumero,
                    $AppNome,
                    $AppId,
                    $Pasta
                )

                $saida = & $WingetPath `
                    download `
                    --id $AppId `
                    -e `
                    --source winget `
                    --download-directory $Pasta `
                    --accept-package-agreements `
                    --accept-source-agreements `
                    2>&1

                $codigo = $LASTEXITCODE

                [PSCustomObject]@{
                    Numero = $AppNumero
                    Nome   = $AppNome
                    Id     = $AppId
                    Codigo = $codigo
                    Saida  = ($saida | Out-String)
                }

            } -ArgumentList `
                $wingetPath,
                $app.Numero,
                $app.Nome,
                $app.Id,
                $pastaDownloads

            $jobsAtivos += [PSCustomObject]@{
                Job = $job
                App = $app
            }
        }


        # ----------------------------------------------------
        # VERIFICAR DOWNLOADS FINALIZADOS
        # ----------------------------------------------------

        foreach ($registro in @($jobsAtivos)) {

            if ($registro.Job.State -eq "Completed") {

                $resultado = Receive-Job $registro.Job

                Remove-Job $registro.Job -Force -ErrorAction SilentlyContinue

                if (
                    $resultado -and
                    $resultado.Codigo -eq 0
                ) {

                    Write-Host "[OK] $($registro.App.Nome) baixado." -ForegroundColor Green

                    $baixados += $registro.App
                }
                else {

                    Write-Host "[FALHA] $($registro.App.Nome)" -ForegroundColor Red

                    $falhasDownload += $registro.App
                }


                $jobsAtivos = @(
                    $jobsAtivos |
                    Where-Object {
                        $_.Job.Id -ne $registro.Job.Id
                    }
                )
            }

            elseif ($registro.Job.State -eq "Failed") {

                Write-Host "[FALHA] $($registro.App.Nome)" -ForegroundColor Red

                $falhasDownload += $registro.App

                Remove-Job $registro.Job -Force -ErrorAction SilentlyContinue

                $jobsAtivos = @(
                    $jobsAtivos |
                    Where-Object {
                        $_.Job.Id -ne $registro.Job.Id
                    }
                )
            }
        }


        Start-Sleep -Milliseconds 300
    }


    # ========================================================
    # RESULTADO DOWNLOAD
    # ========================================================

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "          DOWNLOAD CONCLUIDO" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""


    if ($baixados.Count -gt 0) {
 
     foreach ($app in $baixados) {

            Write-Host "[OK] $($app.Nome)" -ForegroundColor Green
        }
    }


    if ($falhasDownload.Count -gt 0) {

        Write-Host ""
        Write-Host "FALHAS NO DOWNLOAD" -ForegroundColor Red

        foreach ($app in $falhasDownload) {

            Write-Host "[FALHA] $($app.Nome)" -ForegroundColor Red
        }
    }


    if ($baixados.Count -eq 0 -and $diretos.Count -eq 0) {

        Write-Host ""
        Write-Host "[ERRO] Nenhum aplicativo foi baixado." -ForegroundColor Red

        Read-Host "Pressione ENTER para sair"
        exit
    }


    Write-Host ""
    Write-Host "Os downloads terminaram."
    Write-Host ""

    if ($diretos.Count -gt 0) {
        Write-Host "Aplicativos com instalacao direta:" -ForegroundColor Cyan
        foreach ($app in $diretos) {
            Write-Host "[DIRETO] $($app.Nome)" -ForegroundColor Cyan
        }
        Write-Host ""
    }

    Write-Host "A instalacao sera iniciada somente apos sua confirmacao."
    Write-Host ""

    Read-Host "Pressione ENTER para iniciar as instalacoes"


    # ========================================================
    # FASE 2 - INSTALACAO SEQUENCIAL
    # ========================================================

    Clear-Host

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       INSTALANDO APLICATIVOS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $sucessos = @()
    $falhas = @()

    $paraInstalar = @($baixados) + @($diretos)

    foreach ($app in $paraInstalar) {



        Write-Host ""
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Host "Instalando $($app.Nome)..." -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor DarkGray


        $saidaWinget = @()

        & winget install `
            --id $app.Id `
            -e `
            --source winget `
            --accept-package-agreements `
            --accept-source-agreements `
            2>&1 |
            Tee-Object -Variable saidaWinget

        $codigo = $LASTEXITCODE


        if ($codigo -eq 0) {

            Write-Host ""
            Write-Host "[OK] $($app.Nome)" -ForegroundColor Green

            $sucessos += $app

            continue
        }


        # ====================================================
        # VERIFICAR SE JA ESTAVA INSTALADO
        # ====================================================

        $lista = @()

        & winget list `
            --id $app.Id `
            -e `
            2>&1 |
            Tee-Object -Variable lista |
            Out-Null

        $codigoLista = $LASTEXITCODE
        $textoLista = $lista | Out-String


        if (
            $codigoLista -eq 0 -and
            $textoLista -match [regex]::Escape($app.Id)
        ) {

            Write-Host ""
            Write-Host "[OK] $($app.Nome) - Ja instalado e atualizado." -ForegroundColor Green

            $sucessos += $app
        }
        else {

            Write-Host ""
            Write-Host "[FALHA] $($app.Nome)" -ForegroundColor Red

            $falhas += $app
        }
    }


    # ========================================================
    # RESULTADO FINAL
    # ========================================================

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "        RESULTADO DA INSTALACAO" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""


    if ($sucessos.Count -gt 0) {

        Write-Host "SUCESSO" -ForegroundColor Green

        foreach ($app in $sucessos) {

            Write-Host "[OK] $($app.Nome)" -ForegroundColor Green
        }

        Write-Host ""
    }


    if ($falhas.Count -gt 0) {

        Write-Host "FALHAS NA INSTALACAO" -ForegroundColor Red

        foreach ($app in $falhas) {

            Write-Host "[FALHA] $($app.Nome)" -ForegroundColor Red
        }

        Write-Host ""
    }


    if ($falhasDownload.Count -gt 0) {

        Write-Host "FALHAS NO DOWNLOAD" -ForegroundColor Yellow

        foreach ($app in $falhasDownload) {

            Write-Host "[FALHA] $($app.Nome)" -ForegroundColor Yellow
        }

        Write-Host ""
    }


    if ($invalidos.Count -gt 0) {

        Write-Host "OPCOES INVALIDAS" -ForegroundColor Yellow

        foreach ($numero in $invalidos) {

            Write-Host "[INVALIDA] $numero" -ForegroundColor Yellow
        }

        Write-Host ""
    }


    Write-Host "Resumo:"
    Write-Host "Downloads OK: $($baixados.Count)" -ForegroundColor Green
    Write-Host "Instalados:   $($sucessos.Count)" -ForegroundColor Green
    Write-Host "Falhas:       $($falhas.Count)" -ForegroundColor Red
}


# ============================================================
# SAIR
# ============================================================

elseif ($opcao -eq "0") {

    exit
}


else {

    Write-Host ""
    Write-Host "[ERRO] Opcao invalida." -ForegroundColor Red
}


Write-Host ""
Read-Host "Pressione ENTER para sair"