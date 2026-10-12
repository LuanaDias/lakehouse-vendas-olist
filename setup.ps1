# ============================================================
# Setup inicial do projeto Lakehouse de Vendas Olist
# ============================================================

# Diretório raiz do projeto
$Projeto = $PSScriptRoot

Write-Host ""
Write-Host "============================================"
Write-Host "  Lakehouse de Vendas Olist"
Write-Host "============================================"
Write-Host ""

# ============================================================
# 1. Entrar na pasta do Terraform
# ============================================================

Write-Host "1. Inicializando o Terraform..." -ForegroundColor Cyan

Set-Location "$Projeto\terraform"

terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao executar terraform init." -ForegroundColor Red
    exit 1
}

# ============================================================
# 2. Provisionar a infraestrutura
# ============================================================

Write-Host ""
Write-Host "2. Provisionando a infraestrutura..." -ForegroundColor Cyan

terraform apply

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao executar terraform apply." -ForegroundColor Red
    exit 1
}

# ============================================================
# 3. Voltar para a raiz do projeto
# ============================================================

Set-Location $Projeto

# ============================================================
# 4. Entrar na pasta do script de carga
# ============================================================

Write-Host ""
Write-Host "3. Preparando a carga inicial do Olist..." -ForegroundColor Cyan

Set-Location "$Projeto\olist\scripts-olist"

# ============================================================
# 5. Selecionar o profile AWS
# ============================================================

$env:AWS_PROFILE = "lab"

Write-Host ""
Write-Host "AWS Profile: $env:AWS_PROFILE" -ForegroundColor Green

# ============================================================
# 6. Executar a carga inicial
# ============================================================

Write-Host ""
Write-Host "4. Carregando as 9 tabelas da Olist no RDS PostgreSQL..." -ForegroundColor Cyan

py load_excel_to_rds.py

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao executar o script de carga." -ForegroundColor Red
    exit 1
}

# ============================================================
# Final
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Processo concluido com sucesso!"
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# ============================================================
# 7. VERIFICAR STATUS DO DMS
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "VERIFICANDO STATUS DO DMS"
Write-Host "============================================" -ForegroundColor Cyan

$DmsTaskId = "luana-lab-rds-to-s3-landing"
$AwsRegion = "us-east-1"

$DmsStatus = aws dms describe-replication-tasks `
    --filters "Name=replication-task-id,Values=$DmsTaskId" `
    --query "ReplicationTasks[0].Status" `
    --output text `
    --region $AwsRegion `
    --profile $env:AWS_PROFILE `
    --no-cli-pager

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro ao consultar o DMS." -ForegroundColor Red
    exit 1
}

$DmsStatus = $DmsStatus.Trim().ToLowerInvariant()

Write-Host "Status da tarefa DMS: $DmsStatus"

# ============================================================
# 8. REPROCESSAR SOMENTE SE ESTIVER COM ERRO
# ============================================================

if ($DmsStatus -eq "failed") {

    Write-Host ""
    Write-Host "DMS está com erro. Iniciando Reload Target..." -ForegroundColor Yellow

    $DmsTaskArn = aws dms describe-replication-tasks `
        --filters "Name=replication-task-id,Values=$DmsTaskId" `
        --query "ReplicationTasks[0].ReplicationTaskArn" `
        --output text `
        --region $AwsRegion `
        --profile $env:AWS_PROFILE `
        --no-cli-pager

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao obter ARN da tarefa DMS." -ForegroundColor Red
        exit 1
    }

    $DmsTaskArn = $DmsTaskArn.Trim()

    Write-Host "Parando a tarefa DMS..."

    aws dms stop-replication-task `
        --replication-task-arn $DmsTaskArn `
        --region $AwsRegion `
        --profile $env:AWS_PROFILE `
        --no-cli-pager

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao parar a tarefa DMS." -ForegroundColor Red
        exit 1
    }

    Write-Host "Aguardando DMS ficar parado..."

    do {

        Start-Sleep -Seconds 10

        $DmsStatus = aws dms describe-replication-tasks `
            --filters "Name=replication-task-id,Values=$DmsTaskId" `
            --query "ReplicationTasks[0].Status" `
            --output text `
            --region $AwsRegion `
            --profile $env:AWS_PROFILE `
            --no-cli-pager

        $DmsStatus = $DmsStatus.Trim().ToLowerInvariant()

        Write-Host "Status atual: $DmsStatus"

    } while ($DmsStatus -eq "stopping")

    if ($DmsStatus -ne "stopped") {
        Write-Host "DMS não ficou parado. Status: $DmsStatus" -ForegroundColor Red
        exit 1
    }

    Write-Host "Executando Reload Target..."

    aws dms start-replication-task `
        --replication-task-arn $DmsTaskArn `
        --start-replication-task-type reload-target `
        --region $AwsRegion `
        --profile $env:AWS_PROFILE `
        --no-cli-pager

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao executar Reload Target." -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "Reload Target iniciado com sucesso." -ForegroundColor Green

}
elseif ($DmsStatus -eq "running") {

    Write-Host ""
    Write-Host "DMS está funcionando normalmente." -ForegroundColor Green
    Write-Host "Nenhum reload será executado."

}
else {

    Write-Host ""
    Write-Host "DMS está com status: $DmsStatus" -ForegroundColor Yellow
    Write-Host "Nenhum reload automático será executado."

}