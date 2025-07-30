#!/bin/bash

# Vote Secret - Script de déploiement avec Docker (Alternative)
# Utilise Docker pour éviter les problèmes de dépendances MongoDB
# Domaine: https://vote.super-csn.ca
# Repo: https://github.com/KiiTuNp/vote.git

set -e

# Configuration
DOMAIN="vote.super-csn.ca"
REPO_URL="https://github.com/KiiTuNp/vote.git"
APP_DIR="/var/www/vote-secret"
USER="www-data"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log_info "🚀 Déploiement Vote Secret avec Docker sur ${DOMAIN}"

# 1. Mise à jour du système
log_info "📦 Mise à jour du système..."
apt update && apt upgrade -y

# 2. Installation des dépendances de base
log_info "🔧 Installation des dépendances système..."
apt install -y \
    curl \
    wget \
    git \
    nginx \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw

# 3. Installation de Docker
log_info "🐳 Installation de Docker..."
# Supprimer les anciennes versions
apt remove docker docker-engine docker.io containerd runc -y || true

# Ajouter la clé GPG officielle de Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Ajouter le repository Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installer Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Démarrer Docker
systemctl start docker
systemctl enable docker

# Ajouter l'utilisateur au groupe docker
usermod -aG docker $USER

log_success "Docker installé et configuré"

# 4. Installation de Node.js 18 (pour le build frontend)
log_info "📋 Installation de Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Installation de Yarn
npm install -g yarn
log_success "Node.js et Yarn installés"

# 5. Clone du repository
log_info "📥 Clone du repository..."
if [ -d "$APP_DIR" ]; then
    log_warning "Le répertoire $APP_DIR existe déjà, suppression..."
    rm -rf "$APP_DIR"
fi

git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"

# 6. Création des fichiers Docker
log_info "🐳 Création de la configuration Docker..."

# Dockerfile pour le backend
cat > "$APP_DIR/backend/Dockerfile" << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copie et installation des dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY . .

# Exposition du port
EXPOSE 8001

# Commande de démarrage
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001"]
EOF

# docker-compose.yml
cat > "$APP_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  mongodb:
    image: mongo:6.0
    container_name: vote-secret-mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_DATABASE: vote_secret_production
    volumes:
      - mongodb_data:/data/db
    ports:
      - "127.0.0.1:27017:27017"
    networks:
      - vote-secret-network

  backend:
    build: ./backend
    container_name: vote-secret-backend
    restart: unless-stopped
    depends_on:
      - mongodb
    environment:
      - MONGO_URL=mongodb://mongodb:27017
      - DB_NAME=vote_secret_production
    ports:
      - "127.0.0.1:8001:8001"
    networks:
      - vote-secret-network

volumes:
  mongodb_data:

networks:
  vote-secret-network:
    driver: bridge
EOF

# 7. Configuration du backend
log_info "⚙️ Configuration du Backend..."
cat > "$APP_DIR/backend/.env" << EOF
MONGO_URL=mongodb://mongodb:27017
DB_NAME=vote_secret_production
LOG_LEVEL=INFO
CORS_ORIGINS=https://$DOMAIN
EOF

# 8. Build et configuration du frontend
log_info "🎨 Configuration et build du Frontend..."
cd "$APP_DIR/frontend"

# Configuration des variables d'environnement frontend
cat > .env << EOF
REACT_APP_BACKEND_URL=https://$DOMAIN
WDS_SOCKET_PORT=443
GENERATE_SOURCEMAP=false
EOF

# Installation des dépendances et build
yarn install
yarn build
log_success "Frontend buildé"

# 9. Configuration Nginx
log_info "🌐 Configuration de Nginx..."
cd "$APP_DIR"

cat > /etc/nginx/sites-available/vote-secret << 'EOF'
server {
    listen 80;
    server_name vote.super-csn.ca;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name vote.super-csn.ca;

    # Certificats SSL
    ssl_certificate /etc/letsencrypt/live/vote.super-csn.ca/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vote.super-csn.ca/privkey.pem;
    
    # Configuration SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Headers de sécurité
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;

    # Logs
    access_log /var/log/nginx/vote-secret.access.log;
    error_log /var/log/nginx/vote-secret.error.log;

    # Frontend
    location / {
        root /var/www/vote-secret/frontend/build;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support
    location /ws {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
EOF

# Activation du site
ln -sf /etc/nginx/sites-available/vote-secret /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t

# 10. Installation SSL avec Certbot
log_info "🔐 Installation des certificats SSL..."
apt install -y certbot python3-certbot-nginx

# Génération des certificats
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@super-csn.ca --redirect

# Auto-renouvellement
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# 11. Configuration du firewall
log_info "🔥 Configuration du firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# 12. Démarrage des services Docker
log_info "🚀 Démarrage des services avec Docker..."
cd "$APP_DIR"

# Build et démarrage des conteneurs
docker compose up -d --build

# Attendre que les services démarrent
sleep 10

# 13. Démarrage de Nginx
systemctl restart nginx
systemctl enable nginx

# 14. Création des scripts de gestion
log_info "📝 Création des scripts de gestion..."

# Script de gestion Docker
cat > "$APP_DIR/manage-docker.sh" << 'EOF'
#!/bin/bash

APP_DIR="/var/www/vote-secret"
cd "$APP_DIR"

case "$1" in
    start)
        echo "🚀 Démarrage de Vote Secret..."
        docker compose up -d
        sudo systemctl start nginx
        ;;
    stop)
        echo "🛑 Arrêt de Vote Secret..."
        docker compose down
        ;;
    restart)
        echo "🔄 Redémarrage de Vote Secret..."
        docker compose restart
        sudo systemctl restart nginx
        ;;
    status)
        echo "📊 Statut des services:"
        docker compose ps
        echo "--- Nginx ---"
        sudo systemctl status nginx --no-pager -l
        ;;
    logs)
        echo "📋 Logs:"
        docker compose logs -f
        ;;
    update)
        echo "🔄 Mise à jour..."
        git pull origin main
        cd frontend
        yarn install && yarn build
        cd ..
        docker compose up -d --build
        echo "✅ Mise à jour terminée"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
EOF

chmod +x "$APP_DIR/manage-docker.sh"

# 15. Vérification finale
log_info "🔍 Vérification du déploiement..."

# Vérifier les conteneurs
if docker compose ps | grep -q "Up"; then
    log_success "✅ Conteneurs Docker: ACTIFS"
else
    log_error "❌ Problème avec les conteneurs Docker"
    docker compose logs
fi

# Vérifier Nginx
if systemctl is-active --quiet nginx; then
    log_success "✅ Nginx: ACTIF"
else
    log_error "❌ Nginx: INACTIF"
fi

# Test de l'API
sleep 5
if curl -f -s "https://$DOMAIN/api/" > /dev/null; then
    log_success "✅ API: ACCESSIBLE"
else
    log_warning "⚠️ API: En cours de démarrage..."
fi

# 16. Messages finaux
echo ""
echo "========================================"
log_success "🎉 DÉPLOIEMENT DOCKER TERMINÉ!"
echo "========================================"
echo ""
log_info "📱 Application: https://$DOMAIN"
log_info "🐳 Gestion Docker: $APP_DIR/manage-docker.sh"
echo ""
log_info "📋 Commandes Docker utiles:"
echo "   • Statut: $APP_DIR/manage-docker.sh status"
echo "   • Logs: $APP_DIR/manage-docker.sh logs"
echo "   • Redémarrage: $APP_DIR/manage-docker.sh restart"
echo "   • Mise à jour: $APP_DIR/manage-docker.sh update"
echo ""
log_info "🔧 Commandes Docker natives:"
echo "   • docker compose ps (dans $APP_DIR)"
echo "   • docker compose logs -f"
echo "   • docker compose restart backend"
echo ""
log_success "✅ Vote Secret avec Docker est opérationnel!"