#!/bin/bash
# ==========================================
# Instalador Maestro LoborojoPy - WS Estable + Panel
# ==========================================

echo -e "\e[1;34m[ 🐺 ] 1/6 Preparando el terreno y limpiando puertos...\e[0m"
systemctl stop ws lobo-tracker 2>/dev/null
systemctl disable ws lobo-tracker 2>/dev/null
fuser -k 80/tcp 2>/dev/null

echo -e "\e[1;34m[ 🐺 ] 2/6 Descargando motor estable (ws.bin) desde GitHub...\e[0m"
mkdir -p /opt/lobo_ws
wget -q -O /opt/lobo_ws/ws.bin "https://raw.githubusercontent.com/loborojoparaguay-cyber/Ws_lobo/main/ws.bin"
chmod +x /opt/lobo_ws/ws.bin

echo -e "\e[1;34m[ 🐺 ] 3/6 Creando configuración y base de datos...\e[0m"
echo "{}" > /etc/traffic.json
chmod 666 /etc/traffic.json

cat << 'EOF' > /opt/lobo_ws/config.yml
verbose: 0
traffic_path: "/etc/traffic.json"
listen:
- target_host: 127.0.0.1
  target_port: 22
  listen_port: 80
EOF

echo -e "\e[1;34m[ 🐺 ] 4/6 Instalando rastreador de consumo en segundo plano...\e[0m"
cat << 'EOF' > /usr/local/bin/lobo_tracker.py
import os, time, json, subprocess
TRAFFIC_FILE = "/etc/traffic.json"
last_io = {}

while True:
    try:
        if os.path.exists(TRAFFIC_FILE):
            with open(TRAFFIC_FILE, "r") as f:
                try: traffic_data = json.load(f)
                except: traffic_data = {}
        else: traffic_data = {}

        try: out = subprocess.check_output("ps -eo pid,user,comm,args | grep -E 'sshd|dropbear' | grep -v root", shell=True).decode().strip()
        except: out = ""
        
        current_pids = []
        for line in out.split('\n'):
            if not line: continue
            parts = line.split(maxsplit=3)
            if len(parts) >= 2:
                pid, user = parts[0], parts[1]
                if user == 'root' or user == 'messagebus': continue
                current_pids.append(pid)

                try:
                    with open(f"/proc/{pid}/io", "r") as f:
                        io_data = f.read()
                        rchar = int([x for x in io_data.split('\n') if x.startswith('rchar:')][0].split()[1])
                        wchar = int([x for x in io_data.split('\n') if x.startswith('wchar:')][0].split()[1])
                        total_io = rchar + wchar
                except: continue
                
                if pid in last_io:
                    delta = total_io - last_io[pid]
                    if delta > 0:
                        if user not in traffic_data: traffic_data[user] = {"traffic": 0}
                        elif isinstance(traffic_data[user], (int, float)): traffic_data[user] = {"traffic": traffic_data[user]}
                        traffic_data[user]["traffic"] += delta
                last_io[pid] = total_io
        
        last_io = {p: v for p, v in last_io.items() if p in current_pids}
        with open(TRAFFIC_FILE, "w") as f: json.dump(traffic_data, f)
    except: pass
    time.sleep(3)
EOF
chmod +x /usr/local/bin/lobo_tracker.py

echo -e "\e[1;34m[ 🐺 ] 5/6 Creando Panel de Control (Comando: lobo)...\e[0m"
cat << 'EOF' > /usr/local/bin/lobo
#!/bin/bash
RED='\033[1;31m'; WHITE='\033[1;37m'; GRAY='\033[1;90m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'; NC='\033[0m'
clear
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}                  🐺  ${RED}L O B O R O J O${WHITE}  P Y  🐺                   ${NC}"
echo -e "${GRAY}               PANEL DE CONTROL - MOTOR WS ESTABLE               ${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cpu_usage=$(top -bn1 | grep load | awk '{printf "%.2f%%", $(NF-2)}')
ram_total=$(free -m | awk '/Mem:/ {print $2}')
ram_used=$(free -m | awk '/Mem:/ {print $3}')
echo -e " ${CYAN}CPU Load:${NC} $cpu_usage  |  ${CYAN}RAM Usada:${NC} ${ram_used}MB / ${ram_total}MB"
echo -e "${RED}─────────────────────────────────────────────────────────────────${NC}"

python3 -c '
import json, os, subprocess
try: online_raw = subprocess.check_output("ps -ef | grep -E \"sshd:|dropbear\" | grep -v root", shell=True).decode().lower()
except: online_raw = ""

if os.path.exists("/etc/traffic.json"):
    try:
        with open("/etc/traffic.json", "r") as f: data = json.load(f)
        print("  \033[1;37m{:<18} │ {:<15} │ {}\033[0m".format("USUARIO", "CONSUMO", "ESTADO"))
        print(" \033[1;90m ───────────────────┼─────────────────┼────────────\033[0m")
        for user, info in data.items():
            if user in ["159bb33169230e0e413c95b68efe05f8", "active_connection", "rx_bytes", "tx_bytes", "active_connections", "sshd", "messagebus"]: continue
            traffic = info.get("traffic", 0) if isinstance(info, dict) else info if isinstance(info, (int, float)) else 0
            if traffic > 1073741824: t_str = f"{traffic/1073741824:.2f} GB"
            elif traffic > 1048576: t_str = f"{traffic/1048576:.2f} MB"
            else: t_str = f"{traffic/1024:.2f} KB"
            if user.lower() in online_raw: print("  \033[1;32m{:<18}\033[0m │ \033[1;36m{:<15}\033[0m │ \033[1;32m● ONLINE\033[0m".format(user[:17], t_str))
            else: print("  \033[0;37m{:<18}\033[0m │ \033[1;36m{:<15}\033[0m │ \033[1;90m○ OFFLINE\033[0m".format(user[:17], t_str))
    except: pass
'
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " [1] Actualizar Vista"
echo -e " [2] Cambiar Puerto del ws.bin"
echo -e " [3] Reiniciar Motor WS"
echo -e " [0] Salir"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p " Elige una opción: " opcion

case $opcion in
    1) lobo ;;
    2)
        read -p " Ingresa el nuevo puerto (ej. 8080): " np
        cat <<CONFIG > /opt/lobo_ws/config.yml
verbose: 0
traffic_path: "/etc/traffic.json"
listen:
- target_host: 127.0.0.1
  target_port: 22
  listen_port: $np
CONFIG
        systemctl restart ws
        echo -e "${GREEN}¡Puerto cambiado al $np! Reiniciando motor...${NC}"
        sleep 2
        lobo ;;
    3) systemctl restart ws; echo -e "${GREEN}Motor reiniciado.${NC}"; sleep 2; lobo ;;
    0) clear; exit 0 ;;
    *) lobo ;;
esac
EOF
chmod +x /usr/local/bin/lobo

echo -e "\e[1;34m[ 🐺 ] 6/6 Configurando auto-arranque (Persistencia al reiniciar)...\e[0m"
# Servicio WS
cat << 'EOF' > /etc/systemd/system/ws.service
[Unit]
Description=WebSocket Estable (ws.bin)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lobo_ws
ExecStart=/opt/lobo_ws/ws.bin -f /opt/lobo_ws/config.yml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Servicio Tracker
cat << 'EOF' > /etc/systemd/system/lobo-tracker.service
[Unit]
Description=Rastreador de Trafico LoborojoPy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/lobo_tracker.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
# Aquí habilitamos AMBOS servicios para que arranquen con el sistema
systemctl enable ws lobo-tracker > /dev/null 2>&1
systemctl restart ws lobo-tracker

echo -e "\e[1;32m[ ✔ ] ¡Instalación exitosa! Escribe 'lobo' en la terminal para abrir el panel.\e[0m"
