# ==========================================
#   SIMULATEUR DE TRAFIC MLOPS (DEMO)
# ==========================================

# --- CONFIGURATION (Change l'IP ici !) ---
$IP_API = "Adresse ip de l'instance API"  
$URL = "http://$IP_API/predict"

# --- DONNÉES ---
# 1. Données Valides (Iris Setosa)
$json_ok = '{"sepal_length": 5.1, "sepal_width": 3.5, "petal_length": 1.4, "petal_width": 0.2}'

# 2. Données "Poison" (Provoque une erreur 400/500)
# On envoie du texte à la place des chiffres pour faire planter l'IA
$json_error = '{"sepal_length": "CRASH", "sepal_width": "BUG", "petal_length": 0, "petal_width": 0}'

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "      MLOPS TRAFFIC GENERATOR             " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Cible : $URL" -ForegroundColor Gray
    Write-Host ""
    Write-Host " [1] Trafic NORMAL (Vert - Succès 200 OK)" -ForegroundColor Green
    Write-Host " [2] Trafic ERREUR (Rouge - Crash 400)"    -ForegroundColor Red
    Write-Host " [3] Trafic MIXTE  (Aléatoire)"            -ForegroundColor Yellow
    Write-Host " [Q] Quitter"
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Choisis une option"

    if ($choice -eq "Q") { break }

    Write-Host "`nLancement de la simulation... (Appuie sur Ctrl+C pour revenir au menu)`n" -ForegroundColor Gray
    
    # Boucle infinie de génération de trafic
    while ($true) {
        try {
            if ($choice -eq "1") {
                # --- MODE 1 : NORMAL ---
                Invoke-RestMethod -Uri $URL -Method Post -Body $json_ok -ContentType "application/json" | Out-Null
                Write-Host "v" -NoNewline -ForegroundColor Green 
            }
            elseif ($choice -eq "2") {
                # --- MODE 2 : ERREUR ---
                try {
                    Invoke-RestMethod -Uri $URL -Method Post -Body $json_error -ContentType "application/json" | Out-Null
                } catch {
                    # On attrape l'erreur pour ne pas arrêter le script, et on affiche un X rouge
                    Write-Host "x" -NoNewline -ForegroundColor Red 
                }
            }
            elseif ($choice -eq "3") {
                # --- MODE 3 : MIXTE (90% OK, 10% Erreur) ---
                $random = Get-Random -Minimum 1 -Maximum 10
                if ($random -le 9) {
                    Invoke-RestMethod -Uri $URL -Method Post -Body $json_ok -ContentType "application/json" | Out-Null
                    Write-Host "v" -NoNewline -ForegroundColor Green
                } else {
                    try {
                        Invoke-RestMethod -Uri $URL -Method Post -Body $json_error -ContentType "application/json" | Out-Null
                    } catch {
                        Write-Host "x" -NoNewline -ForegroundColor Red
                    }
                }
            }
            
            # Pause pour rendre l'affichage fluide (et ne pas DDOS ta machine)
            Start-Sleep -Milliseconds 200
        }
        catch {
            # Si on fait Ctrl+C, on sort proprement de la boucle interne
            break
        }
    }
}