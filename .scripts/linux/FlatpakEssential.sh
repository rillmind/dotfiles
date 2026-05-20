essential=(
  com.github.tchx84.Flatseal
  app.zen_browser.zen
  com.google.Chrome
  com.mattjakeman.ExtensionManager
  com.nextcloud.desktopclient.nextcloud
  com.spotify.Client
  com.unicornsonlsd.finamp
  io.github.vikdevelop.SaveDesktop
  io.missioncenter.MissionCenter
  it.mijorus.gearlever
  net.davidotek.pupgui2
  io.github.flattool.Warehouse
  md.obsidian.Obsidian
  org.equicord.equibop
  org.pulseaudio.pavucontrol
  org.freedownloadmanager.Manager
)

notEssential=(
  org.gnome.Boxes
  io.github.kolunmi.Bazaar
  org.kde.kdenlive
  com.rustdesk.RustDesk
  io.github.giantpinkrobots.flatsweep
  org.gnome.eog
  io.github.realmazharhussain.GdmSettings
  com.github.wwmm.easyeffects
  com.parsecgaming.parsec
  org.onlyoffice.desktopeditors
  com.ranfdev.DistroShelf
  com.stremio.Stremio
)

packages=()
packages+=("${essential[@]}")
packages+=("${notEssential[@]}")

flatpak install flathub "${packages[@]}"
