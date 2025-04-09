# hiasystem-install
Installation script for my Arch Linux stuff.


# Instalation
mkdir -pv /tmp/install && cd /tmp/install
## Zeug hier hin kopieren
git clone etc...
## Config kopieren
cp default.install.json install.json && vim -d /opt/hiasystem/config/install.json install.json && sudo ./install.sh
## Einmalig für jeden Benutzer
cd ~ && ln -s /opt/hiasystem/config/bashrc .bashrc
cd ~ && ln -s /opt/hiasystem/config/vimrc .vimrc
cd ~ && ln -s /opt/hiasystem/config/zshrc.local .zshrc.local
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
