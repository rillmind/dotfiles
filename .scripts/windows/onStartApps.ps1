# Inicia os aplicativos que não precisam de privilégios
Start-Process -FilePath "C:\Users\raios\AppData\Local\FlowLauncher\Flow.Launcher.exe"
Start-Process -FilePath "C:\Program Files\Zen Browser\zen.exe"
Start-Process -FilePath "C:\Users\sackr\AppData\Roaming\Spotify\Spotify.exe"

# Inicia o Riot Client com seus argumentos específicos
$riotArgs = @(
    "--launch-product=league_of_legends",
    "--launch-patchline=live"
)
Start-Process -FilePath "C:\Riot Games\Riot Client\RiotClientServices.exe" -ArgumentList $riotArgs

# Inicia o GlazeWM solicitando elevação de administrador (UAC)
# O -Verb RunAs é o equivalente a "Executar como administrador"
Start-Process -FilePath "C:\Program Files\glzr.io\GlazeWM\glazewm.exe"