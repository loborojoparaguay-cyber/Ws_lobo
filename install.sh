#!/bin/bash
# ==========================================
# Instalador Automático LoborojoPy - WS Crudo
# ==========================================

echo -e "\e[1;31m[ 🐺 ] Preparando el terreno...\e[0m"
systemctl stop ws ws-ssh ws-epro 2>/dev/null
fuser -k 80/tcp 2>/dev/null

echo -e "\e[1;31m[ 🐺 ] Descargando Motor Crudo...\e[0m"
wget -q -O /usr/local/bin/raw_ws_bridge "https://raw.githubusercontent.com/loborojoparaguay-cyber/TU_REPOSITORIO/main/raw_ws_bridge"
chmod +x /usr/local/bin/raw_ws_bridge

echo -e "\e[1;31m[ 🐺 ] Creando servicio maestro...\e[0m"
cat <<EOF > /etc/systemd/system/ws-ssh.service
[Unit]
Description=WebSocket Falso Ligero (Motor Go)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/raw_ws_bridge -listen :80 -ssh 127.0.0.1:22
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo -e "\e[1;31m[ 🐺 ] Encendiendo turbinas...\e[0m"
systemctl daemon-reload
systemctl enable ws-ssh
systemctl restart ws-ssh

echo -e "\e[1;32m[ ✔ ] ¡Instalación de LoborojoPy completada a máxima velocidad!\e[0m"
