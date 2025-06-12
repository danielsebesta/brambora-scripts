# Brambora Scripts

### `BramboraSetup.sh` 🥔

Instalační a nastavovací skript pro nový Ubuntu VPS. Tento skript:

- Provede aktualizaci systému a instalaci základních nástrojů (curl, wget, git, unzip, atd.)
- Nainstaluje a nakonfiguruje webový server **nginx** nebo **Apache2**
- Nainstaluje nejnovější verzi **PHP** včetně běžně používaných rozšíření
- Nastaví a spustí **fail2ban** pro základní ochranu
- Nastaví firewall **UFW**, povolí porty 22 (SSH), 80 (HTTP), 443 (HTTPS) a 8080 (alternativní HTTP)
- Nainstaluje a aktivuje **Docker** a **docker-compose** pro další rozšíření serveru
- Aktivuje **unattended-upgrades** pro automatické bezpečnostní aktualizace systému

---

### `BramboraWeb.sh` 🌐

Skript pro rychlé nastavení webů na již připraveném serveru. Funkce:

- Podpora webserverů **nginx** i **Apache2** (detekce nebo manuální výběr)
- Zadání hlavní domény a volitelných aliasů
- Zadání emailu správce
- Výběr mezi dvěma režimy:
  - **Statický web** - zadáš cestu ke složce s webem
  - **Reverse proxy** - zadáš port na localhostu, kam bude proxy nasměrována
- Vytvoří příslušnou konfiguraci pro vybraný webserver, povolí potřebné moduly (u Apache2) a reloadne službu
- Na konci nabídne automatické vytvoření a nasazení HTTPS certifikátu přes **Let's Encrypt (certbot)**

---

## Použití

doplnim.
