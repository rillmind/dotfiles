Get-ChildItem "C:\Users\raios\dotfiles\.config\komorebi" | ForEach-Object {
  New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\$($_.Name)" -Target $_.FullName -Force
}