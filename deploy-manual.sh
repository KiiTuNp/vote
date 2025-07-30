#!/bin/bash

# ========================================================================
# VOTE SECRET - DÉPLOIEMENT MANUEL SANS DOCKER (Ubuntu 22.04)
# Guide étape par étape pour un déploiement fiable et simple
# Domain: vote.super-csn.ca - Email: simon@super-csn.ca
# ========================================================================

set -e

# Configuration
DOMAIN="vote.super-csn.ca"
EMAIL="simon@super-csn.ca"
APP_DIR="/var/www/vote-secret"
LOG_FILE="/tmp/vote-manual-deploy.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"; }

# Gestion d'erreur
cleanup_on_error() {
    log_error "Échec du déploiement. Arrêt des services..."
    systemctl stop vote-backend 2>/dev/null || true
    systemctl stop vote-frontend 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    systemctl stop mongod 2>/dev/null || true
    log_error "Logs détaillés: $LOG_FILE"
    exit 1
}

trap cleanup_on_error ERR

echo ""
echo "========================================"
echo -e "${PURPLE}🚀 Vote Secret - Déploiement Manuel${NC}"
echo -e "${PURPLE}   Sans Docker - Ubuntu 22.04${NC}"
echo -e "${PURPLE}   Domaine: $DOMAIN${NC}"
echo "========================================"
echo ""

# Initialisation du log
echo "=== Vote Secret Manual Deployment ===" > "$LOG_FILE"
echo "Date: $(date)" >> "$LOG_FILE"
echo "====================================" >> "$LOG_FILE"

# Vérifications système
log_step "🔍 Vérification du système..."

if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    echo "Commande: sudo $0"
    exit 1
fi

if ! grep -q "ubuntu" /etc/os-release 2>/dev/null; then
    log_warning "OS non testé - Ce script est optimisé pour Ubuntu 22.04"
fi

if ! timeout 5 ping -c 1 1.1.1.1 &>/dev/null; then
    log_error "Pas de connexion internet"
    exit 1
fi

local available=$(df / | awk 'NR==2 {print $4}')
if [ "$available" -lt 2000000 ]; then
    log_error "Espace disque insuffisant (minimum 2GB requis)"
    exit 1
fi

log_success "✅ Système compatible"

# ÉTAPE 1: Mise à jour système et installation dépendances de base
log_step "📦 ÉTAPE 1: Installation des dépendances système..."

apt update &>>"$LOG_FILE"
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    curl \
    wget \
    git \
    nginx \
    ufw \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    supervisor \
    &>>"$LOG_FILE"

log_success "✅ Dépendances système installées"

# ÉTAPE 2: Installation Python 3.12
log_step "🐍 ÉTAPE 2: Installation Python 3.12..."

add-apt-repository ppa:deadsnakes/ppa -y &>>"$LOG_FILE"
apt update &>>"$LOG_FILE"
apt install -y python3.12 python3.12-venv python3.12-dev python3-pip &>>"$LOG_FILE"

# Créer un lien symbolique pour python3.12
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 &>>"$LOG_FILE"

python3 --version &>>"$LOG_FILE"
log_success "✅ Python 3.12 installé: $(python3 --version)"

# ÉTAPE 3: Installation Node.js 22 LTS
log_step "🟢 ÉTAPE 3: Installation Node.js 22 LTS..."

curl -fsSL https://deb.nodesource.com/setup_22.x | bash - &>>"$LOG_FILE"
apt install -y nodejs &>>"$LOG_FILE"

# Installation Yarn
npm install -g yarn &>>"$LOG_FILE"

node_version=$(node --version)
npm_version=$(npm --version)
yarn_version=$(yarn --version)

log_success "✅ Node.js installé: $node_version"
log_success "✅ NPM installé: $npm_version"
log_success "✅ Yarn installé: $yarn_version"

# ÉTAPE 4: Installation MongoDB 7.0
log_step "🍃 ÉTAPE 4: Installation MongoDB 7.0..."

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor &>>"$LOG_FILE"

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list &>>"$LOG_FILE"

apt update &>>"$LOG_FILE"
apt install -y mongodb-org &>>"$LOG_FILE"

# Démarrer et activer MongoDB
systemctl start mongod
systemctl enable mongod

# Vérifier MongoDB
if systemctl is-active --quiet mongod; then
    log_success "✅ MongoDB 7.0 installé et démarré"
else
    log_error "❌ Erreur démarrage MongoDB"
    exit 1
fi

# ÉTAPE 5: Clonage et configuration du projet
log_step "📥 ÉTAPE 5: Configuration du projet..."

rm -rf "$APP_DIR"
git clone https://github.com/KiiTuNp/vote.git "$APP_DIR" &>>"$LOG_FILE"
cd "$APP_DIR"

log_success "✅ Projet cloné dans $APP_DIR"

# ÉTAPE 6: Configuration Backend
log_step "⚙️ ÉTAPE 6: Configuration Backend Python..."

cd "$APP_DIR/backend"

# Créer environnement virtuel Python
python3 -m venv venv &>>"$LOG_FILE"
source venv/bin/activate

# Installer dépendances Python
pip install --upgrade pip &>>"$LOG_FILE"
pip install -r requirements.txt &>>"$LOG_FILE"

# Configuration .env backend
cat > .env << EOF
MONGO_URL=mongodb://localhost:27017
DB_NAME=vote_secret_production
CORS_ORIGINS=https://$DOMAIN,http://$DOMAIN
EOF

log_success "✅ Backend Python configuré"

# ÉTAPE 7: Configuration Frontend
log_step "⚙️ ÉTAPE 7: Configuration Frontend React..."

cd "$APP_DIR/frontend"

# Configuration .env frontend
cat > .env << EOF
REACT_APP_BACKEND_URL=https://$DOMAIN
GENERATE_SOURCEMAP=false
EOF

# Installation dépendances Node.js avec gestion des erreurs
log_info "Installation des dépendances frontend..."
if yarn install --frozen-lockfile &>>"$LOG_FILE"; then
    log_success "✅ Dépendances installées avec Yarn"
elif npm install --legacy-peer-deps &>>"$LOG_FILE"; then
    log_success "✅ Dépendances installées avec NPM"
else
    log_error "❌ Erreur installation dépendances frontend"
    exit 1
fi

# Build du frontend
log_info "Build du frontend React..."
if yarn build &>>"$LOG_FILE"; then
    log_success "✅ Frontend buildé avec Yarn"
elif npm run build &>>"$LOG_FILE"; then
    log_success "✅ Frontend buildé avec NPM"
else
    log_error "❌ Erreur build frontend"
    exit 1
fi

if [ ! -d "build" ] || [ ! -f "build/index.html" ]; then
    log_error "❌ Build frontend invalide"
    exit 1
fi

log_success "✅ Frontend React configuré et buildé"

# ÉTAPE 8: Configuration des services systemd
log_step "🔧 ÉTAPE 8: Configuration des services systemd..."

# Service Backend
cat > /etc/systemd/system/vote-backend.service << EOF
[Unit]
Description=Vote Secret Backend
After=network.target mongod.service
Requires=mongod.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR/backend
Environment=PATH=$APP_DIR/backend/venv/bin
ExecStart=$APP_DIR/backend/venv/bin/uvicorn server:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Service Frontend (utilisation de serve pour servir les fichiers statiques)
npm install -g serve &>>"$LOG_FILE"

cat > /etc/systemd/system/vote-frontend.service << EOF
[Unit]
Description=Vote Secret Frontend
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR/frontend
ExecStart=/usr/bin/serve -s build -l 3000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Permissions
chown -R www-data:www-data "$APP_DIR"
chmod +x "$APP_DIR/backend/venv/bin/uvicorn"

# Recharger systemd
systemctl daemon-reload

log_success "✅ Services systemd configurés"

# ÉTAPE 9: Configuration Nginx
log_step "🌐 ÉTAPE 9: Configuration Nginx..."

cat > /etc/nginx/sites-available/vote-secret << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Logs
    access_log /var/log/nginx/vote-access.log;
    error_log /var/log/nginx/vote-error.log;
    
    # Frontend (React build)
    location / {
        root $APP_DIR/frontend/build;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # Cache pour les assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 60s;
    }
    
    # WebSocket support
    location /ws {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Activer le site
ln -sf /etc/nginx/sites-available/vote-secret /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx
nginx -t &>>"$LOG_FILE"

log_success "✅ Nginx configuré"

# ÉTAPE 10: Démarrage des services
log_step "🚀 ÉTAPE 10: Démarrage des services..."

# Démarrer et activer les services
systemctl enable vote-backend
systemctl enable vote-frontend
systemctl enable nginx

systemctl start vote-backend
systemctl start vote-frontend  
systemctl start nginx

# Attendre que les services démarrent
sleep 10

# Vérifier les services
services_ok=0
if systemctl is-active --quiet mongod; then
    log_success "✅ MongoDB actif"
    ((services_ok++))
else
    log_error "❌ MongoDB inactif"
fi

if systemctl is-active --quiet vote-backend; then
    log_success "✅ Backend actif"
    ((services_ok++))
else
    log_error "❌ Backend inactif"
    journalctl -u vote-backend --no-pager -l >> "$LOG_FILE"
fi

if systemctl is-active --quiet vote-frontend; then
    log_success "✅ Frontend actif" 
    ((services_ok++))
else
    log_error "❌ Frontend inactif"
    journalctl -u vote-frontend --no-pager -l >> "$LOG_FILE"
fi

if systemctl is-active --quiet nginx; then
    log_success "✅ Nginx actif"
    ((services_ok++))
else
    log_error "❌ Nginx inactif"
    journalctl -u nginx --no-pager -l >> "$LOG_FILE"
fi

if [ $services_ok -lt 4 ]; then
    log_error "❌ Certains services ne démarrent pas"
    log_error "Consultez les logs: $LOG_FILE"
    exit 1
fi

log_success "✅ Tous les services sont actifs"

# ÉTAPE 11: Configuration SSL avec Let's Encrypt
log_step "🔐 ÉTAPE 11: Configuration SSL automatique..."

# Installation Certbot
snap install core &>>"$LOG_FILE"
snap refresh core &>>"$LOG_FILE" 
snap install --classic certbot &>>"$LOG_FILE"
ln -sf /snap/bin/certbot /usr/bin/certbot

# Génération certificat SSL
log_info "Génération du certificat SSL pour $DOMAIN..."
if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect &>>"$LOG_FILE"; then
    log_success "✅ SSL configuré avec succès"
    
    # Auto-renouvellement
    cat > /etc/cron.d/certbot-renew << 'EOF'
0 12 * * * root /usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"
EOF
    log_success "✅ Renouvellement automatique configuré"
else
    log_warning "⚠️ SSL échoué - Application accessible en HTTP"
fi

# ÉTAPE 12: Configuration Firewall
log_step "🔥 ÉTAPE 12: Configuration du firewall..."

ufw --force reset &>>"$LOG_FILE"
ufw default deny incoming &>>"$LOG_FILE"
ufw default allow outgoing &>>"$LOG_FILE"

ufw allow ssh &>>"$LOG_FILE"
ufw allow 'Nginx Full' &>>"$LOG_FILE"
ufw limit ssh &>>"$LOG_FILE"

ufw --force enable &>>"$LOG_FILE"

log_success "✅ Firewall configuré"

# ÉTAPE 13: Tests finaux
log_step "🧪 ÉTAPE 13: Tests de validation..."

sleep 5

tests_passed=0
total_tests=5

# Test 1: MongoDB
if timeout 10 mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
    log_success "✅ Test 1/5: MongoDB répond"
    ((tests_passed++))
else
    log_error "❌ Test 1/5: MongoDB ne répond pas"
fi

# Test 2: Backend API
if timeout 10 curl -f -s http://localhost:8001/api/ &>/dev/null; then
    log_success "✅ Test 2/5: Backend API répond"
    ((tests_passed++))
else
    log_error "❌ Test 2/5: Backend API ne répond pas"
fi

# Test 3: Frontend local
if timeout 10 curl -f -s http://localhost/ &>/dev/null; then
    log_success "✅ Test 3/5: Frontend local répond"
    ((tests_passed++))
else
    log_error "❌ Test 3/5: Frontend local ne répond pas"
fi

# Test 4: Nginx
if systemctl is-active --quiet nginx; then
    log_success "✅ Test 4/5: Nginx actif"
    ((tests_passed++))
else
    log_error "❌ Test 4/5: Nginx inactif"
fi

# Test 5: Site web complet
protocol="https"
if ! timeout 10 curl -f -s https://$DOMAIN &>/dev/null; then
    protocol="http"
fi

if timeout 10 curl -f -s $protocol://$DOMAIN &>/dev/null; then
    log_success "✅ Test 5/5: Site accessible ($protocol://$DOMAIN)"
    ((tests_passed++))
else
    log_warning "⚠️ Test 5/5: Vérifiez que le DNS pointe vers ce serveur"
fi

# ÉTAPE 14: Création script de gestion
log_step "📝 ÉTAPE 14: Création des outils de gestion..."

cat > "$APP_DIR/vote-admin" << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "🚀 Démarrage de Vote Secret..."
        systemctl start mongod vote-backend vote-frontend nginx
        echo "✅ Services démarrés"
        ;;
    stop)
        echo "🛑 Arrêt de Vote Secret..."
        systemctl stop vote-backend vote-frontend nginx
        echo "✅ Services arrêtés"
        ;;
    restart)
        echo "🔄 Redémarrage de Vote Secret..."
        systemctl restart mongod vote-backend vote-frontend nginx
        echo "✅ Services redémarrés"
        ;;
    status)
        echo "📊 Statut de Vote Secret:"
        echo ""
        echo "=== MongoDB ==="
        systemctl status mongod --no-pager -l | head -5
        echo ""
        echo "=== Backend ==="
        systemctl status vote-backend --no-pager -l | head -5
        echo ""
        echo "=== Frontend ==="
        systemctl status vote-frontend --no-pager -l | head -5  
        echo ""
        echo "=== Nginx ==="
        systemctl status nginx --no-pager -l | head -5
        ;;
    logs)
        case "$2" in
            backend)
                echo "📋 Logs Backend:"
                journalctl -u vote-backend -f
                ;;
            frontend)
                echo "📋 Logs Frontend:"
                journalctl -u vote-frontend -f
                ;;
            nginx)
                echo "📋 Logs Nginx:"
                tail -f /var/log/nginx/vote-*.log
                ;;
            *)
                echo "📋 Logs disponibles:"
                echo "  vote-admin logs backend"
                echo "  vote-admin logs frontend" 
                echo "  vote-admin logs nginx"
                ;;
        esac
        ;;
    update)
        echo "🔄 Mise à jour depuis GitHub..."
        cd /var/www/vote-secret
        git pull origin main
        
        # Backend
        cd backend
        source venv/bin/activate
        pip install -r requirements.txt
        
        # Frontend
        cd ../frontend
        yarn install && yarn build
        
        # Redémarrage
        systemctl restart vote-backend vote-frontend nginx
        echo "✅ Mise à jour terminée"
        ;;
    test)
        echo "🧪 Test de l'application:"
        echo -n "MongoDB: "
        systemctl is-active mongod
        echo -n "Backend: "
        curl -I http://localhost:8001/api/ 2>/dev/null | head -1 || echo "❌ Erreur"
        echo -n "Frontend: "
        curl -I http://localhost/ 2>/dev/null | head -1 || echo "❌ Erreur"
        echo -n "Site web: "
        curl -I https://vote.super-csn.ca/ 2>/dev/null | head -1 || curl -I http://vote.super-csn.ca/ 2>/dev/null | head -1 || echo "❌ Erreur"
        ;;
    backup)
        echo "💾 Sauvegarde de la base de données..."
        BACKUP_DIR="/backup/vote-secret/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        mongodump --db vote_secret_production --out "$BACKUP_DIR"
        echo "✅ Sauvegarde créée: $BACKUP_DIR"
        ;;
    *)
        echo "Vote Secret - Gestion de l'application"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|update|test|backup}"
        echo ""
        echo "Commandes:"
        echo "  start    - Démarrer l'application"
        echo "  stop     - Arrêter l'application"
        echo "  restart  - Redémarrer l'application"
        echo "  status   - Voir le statut des services"
        echo "  logs     - Voir les logs (backend|frontend|nginx)"
        echo "  update   - Mettre à jour depuis GitHub"
        echo "  test     - Tester l'accès à l'application"
        echo "  backup   - Sauvegarder la base de données"
        ;;
esac
EOF

chmod +x "$APP_DIR/vote-admin"
ln -sf "$APP_DIR/vote-admin" /usr/local/bin/vote-admin

log_success "✅ Script d'administration créé: vote-admin"

# Messages finaux
echo ""
echo "========================================"
echo -e "${GREEN}🎉 Vote Secret déployé avec succès!${NC}"
echo "========================================"
echo ""
echo -e "${BLUE}📱 Application:${NC} $protocol://$DOMAIN"
echo -e "${BLUE}🔧 Administration:${NC} vote-admin"
echo -e "${BLUE}📂 Répertoire:${NC} $APP_DIR"
echo -e "${BLUE}📄 Logs:${NC} $LOG_FILE"
echo ""
echo -e "${YELLOW}🛠️ Commandes principales:${NC}"
echo "   vote-admin status      # Voir le statut"
echo "   vote-admin logs backend # Logs backend"
echo "   vote-admin restart     # Redémarrer"
echo "   vote-admin update      # Mettre à jour"
echo "   vote-admin test        # Tester l'application"
echo "   vote-admin backup      # Sauvegarder"
echo ""

if [ $tests_passed -ge 4 ]; then
    echo -e "${GREEN}🎉 SUCCÈS: $tests_passed/$total_tests tests réussis!${NC}"
    echo -e "${GREEN}✅ Application prête et fonctionnelle!${NC}"
else
    echo -e "${YELLOW}⚠️ ATTENTION: $tests_passed/$total_tests tests réussis${NC}"
    echo -e "${YELLOW}Consultez les logs pour plus de détails: $LOG_FILE${NC}"
fi

echo ""
echo -e "${BLUE}🌐 Votre application est accessible sur:${NC}"
echo -e "${GREEN}   $protocol://$DOMAIN${NC}"
echo ""
echo -e "${GREEN}✅ DÉPLOIEMENT TERMINÉ!${NC}"
echo ""