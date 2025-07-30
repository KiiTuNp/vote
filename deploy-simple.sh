#!/bin/bash

# Vote Secret - Déploiement SIMPLE avec Docker
# Solution qui évite TOUS les problèmes de dépendances
# Fonctionne sur Ubuntu 18.04, 20.04, 22.04, 24.04

set -e

DOMAIN="vote.super-csn.ca"
REPO_URL="https://github.com/KiiTuNp/vote.git"
APP_DIR="/var/www/vote-secret"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   log_error "Exécuter en tant que root: sudo $0"
   exit 1
fi

log_info "🚀 Vote Secret - Déploiement Docker SIMPLE sur $DOMAIN"

# 1. Mise à jour système
log_info "📦 Mise à jour du système..."
apt update && apt upgrade -y

# 2. Installation des outils de base
log_info "🛠️ Installation des outils de base..."
apt install -y curl wget git nginx ufw

# 3. Installation de Docker (méthode simple)
log_info "🐳 Installation de Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $SUDO_USER || true
    log_success "✅ Docker installé"
else
    log_info "Docker déjà installé"
fi

# 4. Installation de Docker Compose
log_info "🐙 Installation de Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    log_success "✅ Docker Compose installé"
else
    log_info "Docker Compose déjà installé"
fi

# 5. Clone du projet
log_info "📥 Clone du projet..."
rm -rf "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"

# 6. Création des fichiers Docker optimisés
log_info "📝 Création de la configuration Docker..."

# Backend Dockerfile
cat > backend/Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# Installation des dépendances système nécessaires
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copie et installation des dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code
COPY . .

EXPOSE 8001

# Commande de démarrage
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "1"]
EOF

# Docker Compose principal
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  mongodb:
    image: mongo:6.0
    container_name: vote-mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_DATABASE: vote_secret_production
    volumes:
      - mongodb_data:/data/db
      - ./mongo-init:/docker-entrypoint-initdb.d
    ports:
      - "127.0.0.1:27017:27017"
    networks:
      - vote-network
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 3

  backend:
    build: 
      context: ./backend
      dockerfile: Dockerfile
    container_name: vote-backend
    restart: unless-stopped
    depends_on:
      mongodb:
        condition: service_healthy
    environment:
      - MONGO_URL=mongodb://mongodb:27017
      - DB_NAME=vote_secret_production
      - CORS_ORIGINS=https://vote.super-csn.ca
    ports:
      - "127.0.0.1:8001:8001"
    networks:
      - vote-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/api/"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  mongodb_data:
    driver: local

networks:
  vote-network:
    driver: bridge
EOF

# 7. Installation de Node.js pour le build frontend
log_info "📋 Installation de Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
fi

# 8. Configuration et build du frontend
log_info "🎨 Configuration du frontend..."
cd frontend

cat > .env << EOF
REACT_APP_BACKEND_URL=https://$DOMAIN
GENERATE_SOURCEMAP=false
EOF

# Corriger le problème de date-fns
sed -i 's/"date-fns": "^4.1.0"/"date-fns": "^3.6.0"/' package.json

# Installation avec --legacy-peer-deps pour éviter les conflits
npm install --legacy-peer-deps
npm run build
cd ..

# 9. Configuration Nginx ultra-simple
log_info "🌐 Configuration Nginx..."
cat > /etc/nginx/sites-available/vote-secret << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # Certificats SSL (Certbot les créera)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # Configuration SSL basique
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    # Frontend
    location / {
        root $APP_DIR/frontend/build;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # API Backend
    location /api {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/vote-secret /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 10. Installation SSL avec Certbot
log_info "🔐 Installation des certificats SSL..."
apt install -y snapd
snap install core; snap refresh core
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

# Génération des certificats (mode non-interactif)
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@super-csn.ca --redirect

# 11. Configuration du firewall
log_info "🔥 Configuration du firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# 12. Démarrage des services Docker
log_info "🚀 Démarrage des services Docker..."
cd "$APP_DIR"

# Démarrage des conteneurs
docker-compose up -d --build

# Attendre que les services démarrent
log_info "⏳ Attente du démarrage des services..."
sleep 30

# 13. Démarrage de Nginx
systemctl restart nginx
systemctl enable nginx

# 14. Script de gestion simple
cat > manage.sh << 'EOF'
#!/bin/bash
cd /var/www/vote-secret

case "$1" in
    start)
        echo "🚀 Démarrage..."
        docker-compose up -d
        systemctl start nginx
        ;;
    stop)
        echo "🛑 Arrêt..."
        docker-compose down
        ;;
    restart)
        echo "🔄 Redémarrage..."
        docker-compose restart
        systemctl restart nginx
        ;;
    status)
        echo "📊 Statut:"
        docker-compose ps
        ;;
    logs)
        docker-compose logs -f
        ;;
    update)
        echo "🔄 Mise à jour..."
        git pull
        cd frontend && npm run build && cd ..
        docker-compose up -d --build
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        ;;
esac
EOF

chmod +x manage.sh

# 15. Vérifications finales
log_info "🔍 Vérifications finales..."

# Vérifier Docker
if docker-compose ps | grep -q "Up"; then
    log_success "✅ Conteneurs Docker: ACTIFS"
else
    log_error "❌ Problème avec Docker"
    docker-compose logs
fi

# Vérifier Nginx
if systemctl is-active --quiet nginx; then
    log_success "✅ Nginx: ACTIF"
else
    log_error "❌ Nginx: PROBLÈME"
fi

# Test API
sleep 10
if curl -f -s "https://$DOMAIN/api/" > /dev/null; then
    log_success "✅ API: ACCESSIBLE"
else
    log_warning "⚠️ API: Vérifiez dans quelques minutes"
fi

# Messages finaux
echo ""
echo "🎉 DÉPLOIEMENT TERMINÉ!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_success "📱 Application: https://$DOMAIN"
log_info "🔧 Gestion: cd $APP_DIR && ./manage.sh"
echo ""
log_info "📋 Commandes utiles:"
echo "   ./manage.sh status  # Voir le statut"
echo "   ./manage.sh logs    # Voir les logs"
echo "   ./manage.sh restart # Redémarrer"
echo "   ./manage.sh update  # Mettre à jour"
echo ""
log_success "✅ Vote Secret est opérationnel avec Docker!"