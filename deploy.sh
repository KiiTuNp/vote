#!/bin/bash

# Vote Secret - Script de déploiement automatique pour VPS
# Domaine: https://vote.super-csn.ca
# Repo: https://github.com/KiiTuNp/vote.git

set -e  # Arrêter le script en cas d'erreur

# Configuration
DOMAIN="vote.super-csn.ca"
REPO_URL="https://github.com/KiiTuNp/vote.git"
APP_DIR="/var/www/vote-secret"
USER="www-data"
BACKEND_PORT="8001"
FRONTEND_PORT="3000"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier si on est root
if [[ $EUID -ne 0 ]]; then
   log_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

log_info "🚀 Début du déploiement de Vote Secret sur ${DOMAIN}"

# 1. Mise à jour du système
log_info "📦 Mise à jour du système..."
apt update && apt upgrade -y

# 2. Installation des dépendances système
log_info "🔧 Installation des dépendances système..."
apt install -y \
    curl \
    wget \
    git \
    nginx \
    supervisor \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    bc \
    ufw

# 3. Installation de Node.js 18
log_info "📋 Installation de Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Vérifier l'installation de Node.js
node_version=$(node --version)
npm_version=$(npm --version)
log_success "Node.js installé: ${node_version}, npm: ${npm_version}"

# 4. Installation de Yarn
log_info "🧶 Installation de Yarn..."
npm install -g yarn
yarn --version

# 5. Installation de Python 3.9+ et pip
log_info "🐍 Installation de Python..."
apt install -y python3 python3-pip python3-venv python3-dev
python3 --version
pip3 --version

# 6. Installation de MongoDB (avec fix pour Ubuntu 22.04+)
log_info "🍃 Installation de MongoDB..."

# Détecter la version d'Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
UBUNTU_CODENAME=$(lsb_release -cs)

log_info "Détection: Ubuntu $UBUNTU_VERSION ($UBUNTU_CODENAME)"

if (( $(echo "$UBUNTU_VERSION >= 22.04" | bc -l) )); then
    log_warning "Ubuntu 22.04+ détecté - Installation de libssl1.1 requise"
    
    # Méthode 1: Essayer plusieurs sources pour libssl1.1
    cd /tmp
    
    # Liste des URLs de fallback pour libssl1.1
    LIBSSL_URLS=(
        "http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.20_amd64.deb"
        "http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.19_amd64.deb"
        "http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.17_amd64.deb"
        "http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb"
        "http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.20_amd64.deb"
        "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/openssl/1.1.1f-1ubuntu2.20/libssl1.1_1.1.1f-1ubuntu2.20_amd64.deb"
    )
    
    LIBSSL_INSTALLED=false
    
    for url in "${LIBSSL_URLS[@]}"; do
        log_info "Tentative de téléchargement: $(basename "$url")"
        if wget -q --timeout=10 "$url"; then
            filename=$(basename "$url")
            if dpkg -i "$filename" 2>/dev/null; then
                log_success "✅ libssl1.1 installé depuis: $url"
                LIBSSL_INSTALLED=true
                break
            else
                log_warning "Échec d'installation de $filename"
                rm -f "$filename"
            fi
        else
            log_warning "Téléchargement échoué: $url"
        fi
    done
    
    # Méthode 2: Si toutes les tentatives échouent, utiliser les repos Ubuntu 20.04
    if [ "$LIBSSL_INSTALLED" = false ]; then
        log_warning "Toutes les tentatives directes ont échoué. Utilisation des repos Ubuntu 20.04..."
        
        # Ajouter temporairement le repo Ubuntu 20.04
        echo "deb http://archive.ubuntu.com/ubuntu focal main" >> /etc/apt/sources.list.d/focal-temp.list
        apt update
        
        if apt install -y libssl1.1; then
            log_success "✅ libssl1.1 installé depuis les repos Ubuntu 20.04"
            LIBSSL_INSTALLED=true
        else
            log_error "❌ Impossible d'installer libssl1.1 depuis les repos"
        fi
        
        # Nettoyer le repo temporaire
        rm -f /etc/apt/sources.list.d/focal-temp.list
        apt update
    fi
    
    # Méthode 3: Si toujours pas installé, installer MongoDB directement depuis le binaire
    if [ "$LIBSSL_INSTALLED" = false ]; then
        log_error "❌ Impossible d'installer libssl1.1. Basculement vers MongoDB Community Server (binaire)"
        
        # Télécharger et installer MongoDB Community Server directement
        wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-ubuntu2004-6.0.3.tgz
        tar -zxvf mongodb-linux-x86_64-ubuntu2004-6.0.3.tgz
        
        # Créer les répertoires MongoDB
        mkdir -p /usr/local/mongodb
        cp -R mongodb-linux-x86_64-ubuntu2004-6.0.3/* /usr/local/mongodb/
        
        # Créer les liens symboliques
        ln -sf /usr/local/mongodb/bin/* /usr/local/bin/
        
        # Créer l'utilisateur MongoDB
        useradd mongodb || true
        
        # Créer les répertoires de données
        mkdir -p /var/lib/mongodb
        mkdir -p /var/log/mongodb
        chown mongodb:mongodb /var/lib/mongodb
        chown mongodb:mongodb /var/log/mongodb
        
        # Créer le fichier de configuration
        cat > /etc/mongod.conf << 'EOF'
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo
EOF

        # Créer le service systemd
        cat > /etc/systemd/system/mongod.service << 'EOF'
[Unit]
Description=MongoDB Database Server
Documentation=https://docs.mongodb.org/manual
After=network-online.target
Wants=network-online.target

[Service]
User=mongodb
Group=mongodb
EnvironmentFile=-/etc/default/mongod
ExecStart=/usr/local/bin/mongod --config /etc/mongod.conf
PIDFile=/var/run/mongodb/mongod.pid
LimitFSIZE=infinity
LimitCPU=infinity
LimitAS=infinity
LimitNOFILE=64000
LimitNPROC=64000
LimitMEMLOCK=infinity
TasksMax=infinity
TasksAccounting=false
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

        # Créer le répertoire PID
        mkdir -p /var/run/mongodb
        chown mongodb:mongodb /var/run/mongodb
        
        systemctl daemon-reload
        log_success "✅ MongoDB installé depuis les binaires"
        
    else
        # Installation MongoDB normale avec libssl1.1 disponible
        log_info "Installation de MongoDB 6.0 avec libssl1.1..."
        
        # Utiliser le repo focal (Ubuntu 20.04) pour MongoDB car il est compatible avec libssl1.1
        wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
        apt update
        
        # Installation avec versions spécifiques
        apt install -y \
            mongodb-org=6.0.3 \
            mongodb-org-database=6.0.3 \
            mongodb-org-server=6.0.3 \
            mongodb-org-mongos=6.0.3 \
            mongodb-org-shell=6.0.3 \
            mongodb-org-tools=6.0.3
        
        # Verrouiller les versions
        echo "mongodb-org hold" | dpkg --set-selections
        echo "mongodb-org-database hold" | dpkg --set-selections
        echo "mongodb-org-server hold" | dpkg --set-selections
        echo "mongodb-org-mongos hold" | dpkg --set-selections
        echo "mongodb-org-shell hold" | dpkg --set-selections
        echo "mongodb-org-tools hold" | dpkg --set-selections
    fi
    
else
    log_info "Ubuntu < 22.04 - Installation MongoDB classique"
    # Installation classique pour Ubuntu 20.04 et antérieures
    wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/5.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-5.0.list
    apt update
    apt install -y mongodb-org
fi

# Démarrer et activer MongoDB
systemctl start mongod
systemctl enable mongod
log_success "MongoDB installé et démarré"

# 7. Clone du repository
log_info "📥 Clone du repository..."
if [ -d "$APP_DIR" ]; then
    log_warning "Le répertoire $APP_DIR existe déjà, suppression..."
    rm -rf "$APP_DIR"
fi

git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"
chown -R $USER:$USER "$APP_DIR"

# 8. Configuration Backend
log_info "⚙️ Configuration du Backend..."
cd "$APP_DIR/backend"

# Création de l'environnement virtuel Python
python3 -m venv venv
source venv/bin/activate

# Installation des dépendances Python
pip install -r requirements.txt

# Configuration des variables d'environnement backend
cat > .env << EOF
MONGO_URL=mongodb://localhost:27017
DB_NAME=vote_secret_production
LOG_LEVEL=INFO
CORS_ORIGINS=https://$DOMAIN
EOF

log_success "Backend configuré"
deactivate

# 9. Configuration Frontend
log_info "🎨 Configuration du Frontend..."
cd "$APP_DIR/frontend"

# Installation des dépendances
yarn install

# Configuration des variables d'environnement frontend
cat > .env << EOF
REACT_APP_BACKEND_URL=https://$DOMAIN
WDS_SOCKET_PORT=443
GENERATE_SOURCEMAP=false
EOF

# Build de production
yarn build
log_success "Frontend configuré et buildé"

# 10. Configuration Nginx
log_info "🌐 Configuration de Nginx..."
cd "$APP_DIR"

cat > /etc/nginx/sites-available/vote-secret << 'EOF'
server {
    listen 80;
    server_name vote.super-csn.ca;
    
    # Redirection HTTP vers HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name vote.super-csn.ca;

    # Certificats SSL (seront générés par Certbot)
    ssl_certificate /etc/letsencrypt/live/vote.super-csn.ca/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vote.super-csn.ca/privkey.pem;
    
    # Configuration SSL sécurisée
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Headers de sécurité
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Limite de taille des uploads
    client_max_body_size 10M;

    # Logs
    access_log /var/log/nginx/vote-secret.access.log;
    error_log /var/log/nginx/vote-secret.error.log;

    # Frontend - Servir les fichiers statiques React
    location / {
        root /var/www/vote-secret/frontend/build;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
        
        # Cache pour les assets statiques
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Backend API - Proxy vers FastAPI
    location /api {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket support (si nécessaire)
    location /ws {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Activation du site
ln -sf /etc/nginx/sites-available/vote-secret /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test de la configuration Nginx
nginx -t
log_success "Configuration Nginx créée"

# 11. Configuration Supervisor
log_info "👥 Configuration de Supervisor..."

cat > /etc/supervisor/conf.d/vote-secret.conf << EOF
[program:vote-secret-backend]
command=$APP_DIR/backend/venv/bin/python -m uvicorn server:app --host 127.0.0.1 --port $BACKEND_PORT --workers 2
directory=$APP_DIR/backend
user=$USER
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/vote-secret-backend.err.log
stdout_logfile=/var/log/supervisor/vote-secret-backend.out.log
environment=PATH="$APP_DIR/backend/venv/bin"
killasgroup=true
stopasgroup=true

[group:vote-secret]
programs=vote-secret-backend
priority=999
EOF

# Recharger la configuration Supervisor
supervisorctl reread
supervisorctl update
log_success "Configuration Supervisor créée"

# 12. Installation et configuration SSL avec Certbot
log_info "🔐 Installation de Certbot pour SSL..."
apt install -y certbot python3-certbot-nginx

# Génération des certificats SSL
log_info "Génération des certificats SSL pour $DOMAIN..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@super-csn.ca --redirect

# Configuration du renouvellement automatique
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
log_success "Certificats SSL configurés avec renouvellement automatique"

# 13. Configuration du firewall
log_info "🔥 Configuration du firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'
ufw status
log_success "Firewall configuré"

# 14. Démarrage des services
log_info "🚀 Démarrage des services..."

# Démarrer le backend
supervisorctl start vote-secret-backend

# Redémarrer Nginx
systemctl restart nginx
systemctl enable nginx

# 15. Vérification du déploiement
log_info "🔍 Vérification du déploiement..."

# Vérifier MongoDB
if systemctl is-active --quiet mongod; then
    log_success "✅ MongoDB: ACTIF"
else
    log_error "❌ MongoDB: INACTIF"
fi

# Vérifier le backend
if supervisorctl status vote-secret-backend | grep -q RUNNING; then
    log_success "✅ Backend: ACTIF"
else
    log_error "❌ Backend: INACTIF"
fi

# Vérifier Nginx
if systemctl is-active --quiet nginx; then
    log_success "✅ Nginx: ACTIF"
else
    log_error "❌ Nginx: INACTIF"
fi

# Test de connectivité API
sleep 5
if curl -f -s "https://$DOMAIN/api/" > /dev/null; then
    log_success "✅ API: ACCESSIBLE"
else
    log_warning "⚠️ API: PEUT ÊTRE EN COURS DE DÉMARRAGE"
fi

# 16. Création des scripts de gestion
log_info "📝 Création des scripts de gestion..."

# Script de gestion des services
cat > "$APP_DIR/manage.sh" << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "🚀 Démarrage de Vote Secret..."
        sudo supervisorctl start vote-secret:*
        sudo systemctl start nginx
        ;;
    stop)
        echo "🛑 Arrêt de Vote Secret..."
        sudo supervisorctl stop vote-secret:*
        ;;
    restart)
        echo "🔄 Redémarrage de Vote Secret..."
        sudo supervisorctl restart vote-secret:*
        sudo systemctl restart nginx
        ;;
    status)
        echo "📊 Statut des services:"
        echo "--- Backend ---"
        sudo supervisorctl status vote-secret:*
        echo "--- Nginx ---"
        sudo systemctl status nginx --no-pager -l
        echo "--- MongoDB ---"
        sudo systemctl status mongod --no-pager -l
        ;;
    logs)
        echo "📋 Logs du backend:"
        sudo tail -f /var/log/supervisor/vote-secret-backend.out.log
        ;;
    update)
        echo "🔄 Mise à jour de l'application..."
        cd /var/www/vote-secret
        git pull origin main
        cd frontend
        yarn install
        yarn build
        cd ../backend
        source venv/bin/activate
        pip install -r requirements.txt
        deactivate
        sudo supervisorctl restart vote-secret:*
        echo "✅ Mise à jour terminée"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
EOF

chmod +x "$APP_DIR/manage.sh"

# Script de sauvegarde
cat > "$APP_DIR/backup.sh" << 'EOF'
#!/bin/bash

BACKUP_DIR="/backup/vote-secret"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "💾 Sauvegarde de la base de données..."
mongodump --db vote_secret_production --out "$BACKUP_DIR/db_$DATE"

echo "📦 Sauvegarde des logs..."
cp -r /var/log/supervisor/vote-secret* "$BACKUP_DIR/logs_$DATE/"

echo "✅ Sauvegarde terminée: $BACKUP_DIR"
EOF

chmod +x "$APP_DIR/backup.sh"

# 17. Messages finaux
echo ""
echo "========================================"
log_success "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS!"
echo "========================================"
echo ""
log_info "📱 Application accessible sur: https://$DOMAIN"
log_info "🗂️ Répertoire de l'app: $APP_DIR"
log_info "🔧 Script de gestion: $APP_DIR/manage.sh"
log_info "💾 Script de sauvegarde: $APP_DIR/backup.sh"
echo ""
log_info "📋 Commandes utiles:"
echo "   • Statut des services: $APP_DIR/manage.sh status"
echo "   • Redémarrer l'app: $APP_DIR/manage.sh restart"
echo "   • Voir les logs: $APP_DIR/manage.sh logs"
echo "   • Mettre à jour: $APP_DIR/manage.sh update"
echo "   • Sauvegarde: $APP_DIR/backup.sh"
echo ""
log_info "📊 Logs importants:"
echo "   • Backend: /var/log/supervisor/vote-secret-backend.out.log"
echo "   • Nginx: /var/log/nginx/vote-secret.access.log"
echo "   • SSL: /var/log/letsencrypt/letsencrypt.log"
echo ""
log_success "✅ Vote Secret est maintenant déployé et prêt à être utilisé!"
echo ""