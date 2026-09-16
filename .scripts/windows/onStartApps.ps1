# O '-Verb RunAs' é o equivalente a "Executar como administrador"

# Em uso:

Start-Process syncthing -ArgumentList "--no-browser" -WindowStyle Hidden
Start-Process -FilePath "C:\Program Files\glzr.io\GlazeWM\glazewm.exe"
yasb
Start-Process -FilePath "C:\Program Files (x86)\Thermal Control Center\tcc-g15.exe" -Verb RunAs

# Em desuso:

#Start-Process -FilePath "C:\Users\raios\AppData\Local\FlowLauncher\Flow.Launcher.exe"
#komorebic start --whkd
