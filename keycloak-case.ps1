    "keycloak" {
        # ═══════════════════════════════════════════════════════════════════════
        # KEYCLOAK DUAL-CREDENTIAL ROTATION (ESO-Native)
        # ═══════════════════════════════════════════════════════════════════════
        # Rotates BOTH credentials in a single run:
        #   1. keycloak-pgpass         (PostgreSQL `keycloak` user password)
        #   2. keycloak-admin-password  (Keycloak master realm admin password)
        #
        # Architecture (source of truth = ESO, not PowerShell):
        #
        #   ESO password-gen  ──►  K8s Secret  ──►  PowerShell READS  ──►  ALTER USER / kcadm.sh
        #
        # The script NEVER generates a password. ESO's Password generator
        # (password-gen) is the single source of truth. We trigger ESO to
        # regenerate via the force-sync annotation, poll the Secret until the
        # value changes, then propagate that value to Postgres / Keycloak.
        #
        # This eliminates the three defects identified in audit ANR-2553:
        #   L1 — PowerShell is now a consumer, not a producer, of the password
        #   L3 — No kubectl delete/create (ESO owns the Secret lifecycle)
        #   L4 — DB ALTER happens AFTER the Secret already has the new value,
        #        so new pods read the correct password on first boot
        #
        # Prerequisites (verify before first run — see testing runbook):
        #   • ESO >= v0.10.0  (force-sync annotation support)
        #   • password-gen Password generator exists in auth namespace
        #   • Both ExternalSecrets exist, point to password-gen, refreshInterval: 0s
        #   • Both K8s Secrets are ESO-owned (ownerReferences + managed label)
        #   • Keycloak image has curl  (for health check)
        #   • ArgoCD sync PAUSED on keycloak-standalone-core Application
        #   • Service connection has Set permission on target Key Vault
        # ═══════════════════════════════════════════════════════════════════════

        $namespace = "auth"

        Write-Host ""
        Write-Host "=== Keycloak dual-credential rotation (ESO-native) ===" -ForegroundColor Cyan

        # ─────────────────────────────────────────────────────────────────────────
        # PRE-ROTATION: resolve pods, capture current passwords for rollback
        # ─────────────────────────────────────────────────────────────────────────
        Write-Host "[1/13] Resolving pods and capturing pre-rotation state..."

        $dbPod = Exec kubectl get pods -n $namespace `
            -l "app.kubernetes.io/name=keycloak-db" `
            -o jsonpath="{.items[0].metadata.name}"
        if (-not $dbPod) {
            throw "Could not resolve keycloak-db pod via label 'app.kubernetes.io/name=keycloak-db'"
        }

        $oldDbB64 = Exec kubectl get secret keycloak-pgpass -n $namespace `
            -o jsonpath="{.data.keycloak-pgpass}"
        $oldAdminB64 = Exec kubectl get secret keycloak-admin-password -n $namespace `
            -o jsonpath="{.data.keycloak-admin-password}"
        if (-not $oldDbB64 -or -not $oldAdminB64) {
            throw "Could not read pre-rotation K8s Secrets"
        }

        $oldDbPass    = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($oldDbB64))
        $oldAdminPass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($oldAdminB64))

        Write-Host "  -> DB pod: $dbPod"
        Write-Host "  -> Recorded old DB + admin passwords for rollback"

        # ─────────────────────────────────────────────────────────────────────────
        # PHASE 1: DB PASSWORD ROTATION
        #   ESO regenerates Secret -> read new value -> ALTER USER -> rollout
        #   -> verify health -> back-vault (with rollback on failure)
        # ─────────────────────────────────────────────────────────────────────────

        # [2] Force ESO to regenerate keycloak-pgpass via force-sync annotation
        Write-Host "[2/13] Triggering ESO regeneration of keycloak-pgpass..."
        $epoch = [DateTimeOffset]::Now.ToUnixTimeSeconds()
        $null = Exec kubectl annotate externalsecret keycloak-pgpass -n $namespace `
            "force-sync=$epoch" --overwrite

        # [3] Poll until Secret value changes (confirms password-gen actually ran)
        Write-Host "[3/13] Polling for new DB password value..."
        $newDbB64 = $oldDbB64
        $pollDeadline = (Get-Date).AddSeconds(60)
        while ((Get-Date) -lt $pollDeadline -and $newDbB64 -eq $oldDbB64) {
            Start-Sleep -Seconds 2
            $newDbB64 = Exec kubectl get secret keycloak-pgpass -n $namespace `
                -o jsonpath="{.data.keycloak-pgpass}"
        }
        if ($newDbB64 -eq $oldDbB64) {
            throw "ESO did not regenerate keycloak-pgpass within 60s. " +
                  "Check: ESO version >= v0.10.0? ESO controller logs? password-gen healthy?"
        }
        $newDbPass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($newDbB64))
        Write-Host "  -> New DB password generated by ESO password-gen"

        # [4] ALTER USER in PostgreSQL (with exit-code + output verification)
        # NOTE: ESO's password-gen character set '!@#.-_+:=,?:' excludes the
        # single-quote, so single-quote wrapping is SQL-safe. If the character
        # set is ever widened to include ', switch to dollar-quoting: $$<pw>$$
        Write-Host "[4/13] ALTER USER keycloak WITH PASSWORD (new value)..."
        $sqlCmd = "ALTER USER keycloak WITH PASSWORD '$newDbPass';"
        $psqlOut = $sqlCmd | kubectl exec -i $dbPod -n $namespace -- psql -U keycloak 2>&1
        if ($LASTEXITCODE -ne 0 -or $psqlOut -notmatch "ALTER ROLE") {
            throw "ALTER USER failed (exit=$LASTEXITCODE). psql output: $psqlOut"
        }
        Write-Host "  -> DB catalog updated"

        # [5] Rollout restart Keycloak + wait for Ready
        Write-Host "[5/13] Rolling restart Keycloak deployment..."
        $null = Exec kubectl rollout restart deployment/keycloak -n $namespace
        $null = Exec kubectl rollout status deployment/keycloak -n $namespace --timeout=300s

        # [6] Resolve new pod name + wait for master realm healthy
        $newKcPod = Exec kubectl get pods -n $namespace `
            -l "app.kubernetes.io/name=keycloak" `
            -o jsonpath="{.items[0].metadata.name}"
        Write-Host "[6/13] Waiting for Keycloak master realm healthy on $newKcPod..."
        $healthy = $false
        $healthDeadline = (Get-Date).AddSeconds(120)
        while ((Get-Date) -lt $healthDeadline) {
            $code = kubectl exec $newKcPod -n $namespace -- curl -s -o /dev/null -w "%{http_code}" `
                http://localhost:8080/realms/master 2>$null
            if ($code -eq "200") { $healthy = $true; break }
            Start-Sleep -Seconds 3
        }
        if (-not $healthy) {
            throw "Keycloak master realm not healthy after 120s"
        }
        Write-Host "  -> Master realm healthy"

        # [7] Verify DB pool health via logs (broader pattern than just 28P01)
        Write-Host "[7/13] Verifying DB pool health in Keycloak logs..."
        $logs = Exec kubectl logs $newKcPod -n $namespace --tail=100
        $failPattern = "28P01|FATAL|password authentication failed|HikariPool.*fail|Agroal.*fail|connection.*refused"
        if ($logs -match $failPattern) {
            throw "DB pool health check failed. Keycloak logs match failure pattern: $($matches[0])"
        }
        Write-Host "  -> DB pool healthy"

        # [8] Back-vault DB password immediately (with rollback on failure)
        Write-Host "[8/13] Back-vaulting DB password to Azure Key Vault..."
        try {
            $dbSecure = ConvertTo-SecureString $newDbPass -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "keycloak-pgpass" -SecretValue $dbSecure | Out-Null
            Write-Host "  -> DB password back-vaulted"
        } catch {
            Write-Error "DB back-vault failed: $_"
            Write-Warning "Rolling back DB password to old value..."
            $rollbackSql = "ALTER USER keycloak WITH PASSWORD '$oldDbPass';"
            $null = $rollbackSql | kubectl exec -i $dbPod -n $namespace -- psql -U keycloak 2>&1
            $null = Exec kubectl rollout restart deployment/keycloak -n $namespace
            $null = Exec kubectl rollout status deployment/keycloak -n $namespace --timeout=300s
            throw "DB password rotation aborted and rolled back. Keycloak is on old DB password."
        }

        # ─────────────────────────────────────────────────────────────────────────
        # PHASE 2: ADMIN PASSWORD ROTATION
        #   ESO regenerates Secret -> read new value -> kcadm.sh set-password
        #   -> verify token issuance -> back-vault (with rollback on failure)
        # ─────────────────────────────────────────────────────────────────────────

        # [9] Force ESO to regenerate keycloak-admin-password
        Write-Host "[9/13] Triggering ESO regeneration of keycloak-admin-password..."
        $epoch2 = [DateTimeOffset]::Now.ToUnixTimeSeconds()
        $null = Exec kubectl annotate externalsecret keycloak-admin-password -n $namespace `
            "force-sync=$epoch2" --overwrite

        # [10] Poll for new admin password
        Write-Host "[10/13] Polling for new admin password value..."
        $newAdminB64 = $oldAdminB64
        $pollDeadline2 = (Get-Date).AddSeconds(60)
        while ((Get-Date) -lt $pollDeadline2 -and $newAdminB64 -eq $oldAdminB64) {
            Start-Sleep -Seconds 2
            $newAdminB64 = Exec kubectl get secret keycloak-admin-password -n $namespace `
                -o jsonpath="{.data.keycloak-admin-password}"
        }
        if ($newAdminB64 -eq $oldAdminB64) {
            throw "ESO did not regenerate keycloak-admin-password within 60s"
        }
        $newAdminPass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($newAdminB64))
        Write-Host "  -> New admin password generated by ESO password-gen"

        # [11] kcadm.sh set-password with retry
        # Authenticates with OLD password, sets NEW password.
        # --no-config prevents token caching to ~/.keycloak/kcadm.config (STIG-safe).
        # --user + --password = auth credentials; --username = whose password to change.
        Write-Host "[11/13] Rotating Keycloak admin password via kcadm.sh..."
        $kcadmSuccess = $false
        for ($i = 1; $i -le 5; $i++) {
            $kcadmOut = kubectl exec $newKcPod -n $namespace -- /opt/keycloak/bin/kcadm.sh set-password `
                --no-config `
                --server http://localhost:8080 `
                --realm master `
                --user admin `
                --password $oldAdminPass `
                --username admin `
                --new-password $newAdminPass 2>&1
            if ($LASTEXITCODE -eq 0) { $kcadmSuccess = $true; break }
            Write-Warning "kcadm.sh attempt $i/5 failed (exit $LASTEXITCODE). Output: $kcadmOut"
            Start-Sleep -Seconds 5
        }
        if (-not $kcadmSuccess) {
            throw "kcadm.sh failed after 5 attempts. Admin password in Keycloak DB is still OLD. " +
                  "K8s Secret has NEW value — manual intervention required."
        }
        Write-Host "  -> Admin password rotated in Keycloak DB"

        # [12] Verify admin login with new password (token issuance test)
        Write-Host "[12/13] Verifying new admin login (token issuance test)..."
        try {
            $tokenBody = "username=admin&password=$newAdminPass&grant_type=password&client_id=admin-cli"
            $tokenResp = kubectl exec $newKcPod -n $namespace -- curl -s -X POST `
                "http://localhost:8080/realms/master/protocol/openid-connect/token" `
                -H "Content-Type: application/x-www-form-urlencoded" `
                -d $tokenBody 2>&1
            if ($tokenResp -notmatch "access_token") {
                throw "Admin login with new password failed. Response: $tokenResp"
            }
            Write-Host "  -> New admin password verified (token issued)"
        } catch {
            Write-Error "Admin login verification failed: $_"
            Write-Warning "Rolling back admin password in Keycloak DB to old value..."
            $null = kubectl exec $newKcPod -n $namespace -- /opt/keycloak/bin/kcadm.sh set-password `
                --no-config --server http://localhost:8080 --realm master --user admin `
                --password $newAdminPass --username admin --new-password $oldAdminPass 2>&1
            throw "Admin rotation failed and rolled back. Keycloak admin password is back to old value."
        }

        # [13] Back-vault admin password (with rollback on failure)
        Write-Host "[13/13] Back-vaulting admin password to Azure Key Vault..."
        try {
            $adminSecure = ConvertTo-SecureString $newAdminPass -AsPlainText -Force
            Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "keycloak-admin-password" -SecretValue $adminSecure | Out-Null
            Write-Host "  -> Admin password back-vaulted"
        } catch {
            Write-Error "Admin back-vault failed: $_"
            Write-Warning "Rolling back admin password in Keycloak DB to old value..."
            $null = kubectl exec $newKcPod -n $namespace -- /opt/keycloak/bin/kcadm.sh set-password `
                --no-config --server http://localhost:8080 --realm master --user admin `
                --password $newAdminPass --username admin --new-password $oldAdminPass 2>&1
            throw "Admin back-vault failed and admin password rolled back. Manual recovery required."
        }

        # Bind to script-scope variable expected by the outer framework.
        # The framework's post-switch back-vault writes to "$toolLower-admin-password"
        # = "keycloak-admin-password" — same value, idempotent, harmless duplicate.
        $newPassword = $newAdminPass

        Write-Host ""
        Write-Host "=== KEYCLOAK ROTATION COMPLETE ===" -ForegroundColor Green
        Write-Host "  DB password:    rotated via ESO + ALTER USER, back-vaulted to KV"
        Write-Host "  Admin password: rotated via ESO + kcadm.sh, back-vaulted to KV"
        Write-Host "  Both K8s Secrets are ESO-owned, immutable, and consistent with DB/Keycloak state."
    }
