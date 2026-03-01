# Inicia os aplicativos que não precisam de privilégios
Start-Process -FilePath "C:\Program Files\Zen Browser\zen.exe"
Start-Process -FilePath "C:\Users\raios\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Spotify.lnk"
Start-Process -FilePath "C:\Program Files\glzr.io\GlazeWM\glazewm.exe"
Start-Process -FilePath "C:\Users\raios\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord Inc\Discord.lnk"

# # Inicia o Riot Client com seus argumentos específicos
# $riotArgs = @(
#     "--launch-product=league_of_legends",
#     "--launch-patchline=live"
# )

# Start-Process -FilePath "C:\Riot Games\Riot Client\RiotClientServices.exe" -ArgumentList $riotArgs

# Inicia o GlazeWM solicitando elevação de administrador (UAC)
# O -Verb RunAs é o equivalente a "Executar como administrador"