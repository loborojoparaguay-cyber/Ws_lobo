#!/bin/bash
# ==========================================
# Instalador Automático LoborojoPy - WS Estable (ws.bin)
# ==========================================

echo -e "\e[1;34m[ 🐺 ] Preparando el terreno para el motor estable...\e[0m"
systemctl stop ws ws-ssh ws-epro 2>/dev/null
fuser -k 80/tcp 2>/dev/null

echo -e "\e[1;34m[ 🐺 ] Descargando ws.bin desde GitHub...\e[0m"
mkdir -p /opt/lobo_ws
# Descarga directa del binario
wget -q -O /opt/lobo_ws/ws.bin "https://raw.githubusercontent.com/loborojoparaguay-cyber/Ws_lobo/main/ws.bin"
chmod +x /opt/lobo_ws/ws.bin

echo -e "\e[1;34m[ 🐺 ] Creando servicio maestro...\e[0m"
cat <<EOF > /etc/systemd/system/ws.service
[Unit]
Description=WebSocket Estable (ws.bin)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lobo_ws
# Ejecución estándar en el puerto 80
ExecStart=/opt/lobo_ws/ws.bin 80
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo -e "\e[1;34m[ 🐺 ] Encendiendo el motor estable...\e[0m"
systemctl daemon-reload
systemctl enable ws
systemctl restart ws

echo -e "\e[1;32m[ ✔ ] ¡Motor estable instalado y listo para medir consumos!\e[0m"
