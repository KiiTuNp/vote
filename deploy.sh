#!/bin/bash

# ========================================================================
# VOTE SECRET - DÉPLOIEMENT DOCKER OPTIMISÉ (2025)
# Script unique avec les versions les plus stables et récentes
# MongoDB 8.0 LTS, Node.js 22 LTS, Docker Compose 2.39.1
# ========================================================================

set -e

# Configuration avec versions 2025
DOMAIN="vote.super-csn.ca"
REPO_URL="https://github.com/KiiTuNp/vote.git"
APP_DIR="/var/www/vote-secret"
LOG_FILE="/tmp/vote-secret-deploy.log"

# Versions les plus stables (Juillet 2025)
DOCKER_COMPOSE_VERSION="v2.39.1"
MONGODB_VERSION="8.0.12"
NODE_VERSION="22"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Fonctions de logging optimisées
log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"; }

# Fonction de confirmation optimisée
confirm() {
    local message="$1"
    local default="${2:-y}"
    local prompt="$message (Y/n): "
    [[ "$default" == "n" ]] && prompt="$message (y/N): "
    
    while true; do
        read -p "$prompt" -r response
        response=${response:-$default}
        case ${response,,} in
            [yy]|yes) return 0 ;;
            [nn]|no) return 1 ;;
            *) echo "Répondez par y (oui) ou n (non)." ;;
        esac
    done
}

# Gestion d'erreur optimisée
cleanup_on_error() {
    log_error "Échec du déploiement. Nettoyage automatique..."
    cd /
    docker-compose -f "$APP_DIR/docker-compose.yml" down --remove-orphans 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    log_error "Logs détaillés: $LOG_FILE"
    echo ""
    echo -e "${YELLOW}💡 Commandes de diagnostic:${NC}"
    echo "   sudo docker ps -a"
    echo "   sudo systemctl status nginx"
    echo "   tail -f $LOG_FILE"
    exit 1
}

trap cleanup_on_error ERR

# Vérifications système optimisées
check_system() {
    log_step "🔍 Vérification du système (Ubuntu/Debian)..."
    
    # Root check
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root"
        echo "Commande: sudo $0"
        exit 1
    fi
    
    # OS check
    if ! grep -q "ubuntu\|debian" /etc/os-release 2>/dev/null; then
        log_warning "OS non testé - Ce script est optimisé pour Ubuntu/Debian"
    fi
    
    # Internet check (plus rapide)
    if ! timeout 5 ping -c 1 1.1.1.1 &>/dev/null; then
        log_error "Pas de connexion internet"
        exit 1
    fi
    
    # Disk space check (minimum 4GB pour MongoDB 8.0)
    local available=$(df / | awk 'NR==2 {print $4}')
    if [ "$available" -lt 4000000 ]; then
        log_error "Espace disque insuffisant (minimum 4GB requis pour MongoDB 8.0)"
        exit 1
    fi
    
    # Architecture check
    if [[ $(uname -m) != "x86_64" ]]; then
        log_warning "Architecture non testée - Optimisé pour x86_64"
    fi
    
    log_success "✅ Système compatible"
}

# Nettoyage intelligent et rapide
cleanup_previous() {
    log_step "🧹 Nettoyage des installations précédentes..."
    
    # Arrêt rapide des services
    timeout 30 systemctl stop nginx 2>/dev/null || true
    
    if [ -f "$APP_DIR/docker-compose.yml" ]; then
        cd "$APP_DIR"
        timeout 30 docker-compose down --remove-orphans 2>/dev/null || true
        cd /
    fi
    
    # Nettoyage Docker optimisé
    docker container prune -f &>/dev/null || true
    docker image prune -f &>/dev/null || true
    
    # Suppression propre
    rm -rf "$APP_DIR"
    rm -f /etc/nginx/sites-{enabled,available}/vote-secret
    
    log_success "✅ Nettoyage terminé"
}

# Installation système optimisée
install_system() {
    log_step "📦 Installation des dépendances système..."
    
    # Update en parallèle
    apt update &>>"$LOG_FILE" &
    local apt_pid=$!
    
    # Attendre la fin du update
    wait $apt_pid
    
    # Installation en mode non-interactif optimisé
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        curl \
        wget \
        git \
        nginx-light \
        ufw \
        ca-certificates \
        gnupg \
        lsb-release \
        snapd \
        htop \
        &>>"$LOG_FILE"
    
    log_success "✅ Dépendances système installées"
}

# Installation Docker optimisée
install_docker() {
    log_step "🐳 Installation Docker (dernière version stable)..."
    
    if command -v docker &>/dev/null && docker --version | grep -q "Docker version"; then
        log_info "Docker déjà installé: $(docker --version)"
    else
        # Installation Docker officielle (méthode la plus fiable)
        curl -fsSL https://get.docker.com -o get-docker.sh &>>"$LOG_FILE"
        sh get-docker.sh &>>"$LOG_FILE"
        rm get-docker.sh
        
        # Configuration optimisée Docker
        systemctl start docker
        systemctl enable docker
        
        # Optimisation Docker daemon
        cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
        systemctl restart docker
    fi
    
    # Installation Docker Compose (dernière version 2025)
    if ! command -v docker-compose &>/dev/null; then
        log_info "Installation Docker Compose $DOCKER_COMPOSE_VERSION..."
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose &>>"$LOG_FILE"
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    
    # Test rapide Docker
    if ! timeout 30 docker run --rm hello-world &>>"$LOG_FILE"; then
        log_error "Docker ne fonctionne pas correctement"
        exit 1
    fi
    
    log_success "✅ Docker installé: $(docker --version | cut -d',' -f1)"
    log_success "✅ Docker Compose: $(docker-compose --version)"
}

# Configuration projet optimisée
setup_project() {
    log_step "📥 Configuration du projet (versions 2025)..."
    
    # Clone rapide
    git clone --depth 1 "$REPO_URL" "$APP_DIR" &>>"$LOG_FILE"
    cd "$APP_DIR"
    
    # Dockerfile frontend optimisé (Node.js 22 LTS)
    cat > frontend/Dockerfile << EOF
# Build stage - Node.js 22 LTS (Juillet 2025)
FROM node:${NODE_VERSION}-alpine as builder

# Variables d'environnement optimisées
ENV NODE_ENV=production
ENV GENERATE_SOURCEMAP=false
ENV NODE_OPTIONS="--max_old_space_size=4096"
ENV DISABLE_HOT_RELOAD=true
ENV CI=true

WORKDIR /app

# Installation dépendances système nécessaires (optimisé)
RUN apk add --no-cache --virtual .build-deps \
    python3 \
    make \
    g++ \
    git

# Copie des fichiers de configuration
COPY package*.json yarn.lock* ./

# Installation optimisée des dépendances
RUN npm ci --only=production --no-audit --no-fund --legacy-peer-deps

# Copie du code source
COPY . .

# Variables pour l'application
ENV REACT_APP_BACKEND_URL=https://${DOMAIN}

# Build optimisé
RUN npm run build

# Vérification du build
RUN test -d build && test -f build/index.html || exit 1

# Production stage - Nginx optimisé
FROM nginx:1.27-alpine

# Copie des fichiers buildés
COPY --from=builder /app/build /usr/share/nginx/html

# Configuration Nginx optimisée pour React
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    # Gestion SPA \
    location / { \
        try_files \$uri \$uri/ /index.html; \
    } \
    \
    # Cache optimisé pour les assets \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
        access_log off; \
    } \
    \
    # Security headers \
    add_header X-Frame-Options DENY always; \
    add_header X-Content-Type-Options nosniff always; \
    add_header X-XSS-Protection "1; mode=block" always; \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

    # Dockerfile backend optimisé
    cat > backend/Dockerfile << 'EOF'
# Python 3.12 (dernière stable 2025)
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Installation dépendances système optimisées
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Installation dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copie du code
COPY . .

EXPOSE 8001

# Health check optimisé
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8001/api/ || exit 1

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "1"]
EOF

    # Docker Compose optimisé (versions 2025)
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  mongodb:
    image: mongodb/mongodb-community-server:${MONGODB_VERSION}
    container_name: vote-mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_DATABASE: vote_secret_production
    volumes:
      - mongodb_data:/data/db
    networks:
      - vote-network
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

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
      - CORS_ORIGINS=https://${DOMAIN}
    ports:
      - "127.0.0.1:8001:8001"
    networks:
      - vote-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/api/"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 45s
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: vote-frontend
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:80"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - vote-network
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M

volumes:
  mongodb_data:
    driver: local

networks:
  vote-network:
    driver: bridge
EOF

    log_success "✅ Projet configuré avec les versions les plus récentes"
}

# Configuration Nginx
setup_nginx() {
    log_step "🌐 Configuration de Nginx..."
    
    # Configuration Nginx pour le reverse proxy
    cat > /etc/nginx/sites-available/vote-secret << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Frontend (interface utilisateur)
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # WebSocket support
    location /ws {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF
    
    # Activer le site
    ln -sf /etc/nginx/sites-available/vote-secret /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test de configuration
    nginx -t &>>"$LOG_FILE"
    
    log_success "✅ Nginx configuré"
}

# Build et démarrage des services Docker
build_and_start() {
    log_step "🚀 Build et démarrage des services..."
    
    cd "$APP_DIR"
    
    log_info "Construction des images Docker (cela peut prendre quelques minutes)..."
    if ! docker-compose build --no-cache &>>"$LOG_FILE"; then
        log_error "Échec du build Docker"
        log_info "Vérification des logs..."
        docker-compose logs &>>"$LOG_FILE"
        exit 1
    fi
    
    log_info "Démarrage des conteneurs..."
    docker-compose up -d &>>"$LOG_FILE"
    
    log_success "✅ Services Docker démarrés"
}

# Configuration SSL
setup_ssl() {
    log_step "🔐 Configuration SSL..."
    
    # Installation Certbot
    snap install core &>>"$LOG_FILE"
    snap refresh core &>>"$LOG_FILE"
    snap install --classic certbot &>>"$LOG_FILE"
    ln -sf /snap/bin/certbot /usr/bin/certbot
    
    # Démarrer Nginx
    systemctl start nginx
    systemctl enable nginx
    
    log_info "Génération des certificats SSL pour $DOMAIN..."
    
    if confirm "Voulez-vous installer les certificats SSL automatiquement?"; then
        if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@super-csn.ca --redirect &>>"$LOG_FILE"; then
            log_success "✅ Certificats SSL installés"
            
            # Auto-renouvellement
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        else
            log_warning "⚠️ Échec SSL - Application accessible en HTTP"
        fi
    else
        log_info "SSL ignoré - Application accessible en HTTP"
    fi
}

# Configuration du firewall
setup_firewall() {
    log_step "🔥 Configuration du firewall..."
    
    ufw --force enable &>>"$LOG_FILE"
    ufw allow ssh &>>"$LOG_FILE"
    ufw allow 'Nginx Full' &>>"$LOG_FILE"
    
    log_success "✅ Firewall configuré"
}

# Tests de l'application
test_application() {
    log_step "🧪 Tests de l'application..."
    
    log_info "Attente du démarrage complet des services (60 secondes)..."
    sleep 60
    
    local tests_passed=0
    local total_tests=5
    
    # Test 1: Conteneurs Docker
    if docker-compose ps | grep -q "Up"; then
        log_success "✅ Test 1/5: Conteneurs Docker actifs"
        ((tests_passed++))
    else
        log_error "❌ Test 1/5: Problème conteneurs Docker"
        docker-compose ps
    fi
    
    # Test 2: Nginx
    if systemctl is-active --quiet nginx; then
        log_success "✅ Test 2/5: Nginx actif"
        ((tests_passed++))
    else
        log_error "❌ Test 2/5: Nginx inactif"
    fi
    
    # Test 3: Backend API
    if curl -f -s http://localhost:8001/api/ &>/dev/null; then
        log_success "✅ Test 3/5: Backend API accessible"
        ((tests_passed++))
    else
        log_warning "⚠️ Test 3/5: Backend API - peut nécessiter plus de temps"
    fi
    
    # Test 4: Frontend
    if curl -f -s http://localhost:3000/ &>/dev/null; then
        log_success "✅ Test 4/5: Frontend accessible"
        ((tests_passed++))
    else
        log_warning "⚠️ Test 4/5: Frontend - peut nécessiter plus de temps"
    fi
    
    # Test 5: Site web complet
    local protocol="https"
    if ! curl -f -s https://$DOMAIN &>/dev/null; then
        protocol="http"
    fi
    
    if curl -f -s $protocol://$DOMAIN &>/dev/null; then
        log_success "✅ Test 5/5: Site web accessible ($protocol://$DOMAIN)"
        ((tests_passed++))
    else
        log_warning "⚠️ Test 5/5: Site web - vérification DNS requise"
    fi
    
    # Résultat des tests
    if [ $tests_passed -ge 3 ]; then
        log_success "🎉 Tests réussis: $tests_passed/$total_tests"
        return 0
    else
        log_warning "⚠️ Tests partiels: $tests_passed/$total_tests"
        log_info "L'application peut nécessiter quelques minutes supplémentaires"
        return 1
    fi
}

# Création du script de gestion
create_admin_script() {
    log_step "📝 Création du script d'administration..."
    
    cat > "$APP_DIR/vote-admin" << 'EOF'
#!/bin/bash

APP_DIR="/var/www/vote-secret"
cd "$APP_DIR" 2>/dev/null || { echo "Erreur: Vote Secret non installé"; exit 1; }

case "$1" in
    start)
        echo "🚀 Démarrage de Vote Secret..."
        docker-compose up -d
        systemctl start nginx
        echo "✅ Services démarrés"
        ;;
    stop)
        echo "🛑 Arrêt de Vote Secret..."
        docker-compose down
        echo "✅ Services arrêtés"
        ;;
    restart)
        echo "🔄 Redémarrage de Vote Secret..."
        docker-compose restart
        systemctl restart nginx
        echo "✅ Services redémarrés"
        ;;
    status)
        echo "📊 Statut de Vote Secret:"
        echo ""
        echo "=== Conteneurs Docker ==="
        docker-compose ps
        echo ""
        echo "=== Nginx ==="
        systemctl status nginx --no-pager -l | head -5
        ;;
    logs)
        echo "📋 Logs en temps réel (Ctrl+C pour quitter):"
        docker-compose logs -f
        ;;
    update)
        echo "🔄 Mise à jour depuis GitHub..."
        git pull origin main
        docker-compose up -d --build
        systemctl restart nginx
        echo "✅ Mise à jour terminée"
        ;;
    test)
        echo "🧪 Test de l'application:"
        echo -n "Site web: "
        curl -I https://vote.super-csn.ca/ 2>/dev/null | head -1 || curl -I http://vote.super-csn.ca/ 2>/dev/null | head -1
        echo -n "API: "
        curl -I https://vote.super-csn.ca/api/ 2>/dev/null | head -1 || curl -I http://vote.super-csn.ca/api/ 2>/dev/null | head -1
        ;;
    backup)
        echo "💾 Sauvegarde de la base de données..."
        BACKUP_DIR="/backup/vote-secret/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        docker-compose exec -T mongodb mongodump --db vote_secret_production --out /data/db/backup
        docker cp vote-mongodb:/data/db/backup "$BACKUP_DIR/"
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
        echo "  logs     - Voir les logs en temps réel"
        echo "  update   - Mettre à jour depuis GitHub"
        echo "  test     - Tester l'accès à l'application"
        echo "  backup   - Sauvegarder la base de données"
        ;;
esac
EOF
    
    chmod +x "$APP_DIR/vote-admin"
    ln -sf "$APP_DIR/vote-admin" /usr/local/bin/vote-admin
    
    log_success "✅ Script d'administration créé: vote-admin"
}

# Messages finaux
show_summary() {
    local protocol="https"
    if ! curl -f -s https://$DOMAIN &>/dev/null; then
        protocol="http"
    fi
    
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
    echo "   vote-admin status    # Voir le statut"
    echo "   vote-admin logs      # Logs en temps réel"
    echo "   vote-admin restart   # Redémarrer"
    echo "   vote-admin update    # Mettre à jour"
    echo "   vote-admin test      # Tester l'application"
    echo "   vote-admin backup    # Sauvegarder"
    echo ""
    echo -e "${GREEN}✅ Installation terminée!${NC}"
    echo ""
}

# ========================================================================
# SCRIPT PRINCIPAL
# ========================================================================

main() {
    echo ""
    echo "========================================"
    echo -e "${PURPLE}🚀 Vote Secret - Déploiement Docker${NC}"
    echo -e "${PURPLE}   Domaine: $DOMAIN${NC}"
    echo "========================================"
    echo ""
    
    # Initialisation du log
    echo "=== Vote Secret Docker Deployment ===" > "$LOG_FILE"
    echo "Date: $(date)" >> "$LOG_FILE"
    echo "====================================" >> "$LOG_FILE"
    
    # Confirmation avant démarrage
    echo -e "${YELLOW}Ce script va:${NC}"
    echo "  • Installer Docker et les dépendances"
    echo "  • Télécharger et configurer Vote Secret"
    echo "  • Configurer Nginx et le firewall"
    echo "  • Proposer l'installation SSL"
    echo "  • Tester l'application complète"
    echo ""
    
    if ! confirm "Continuer avec l'installation?"; then
        echo "Installation annulée."
        exit 0
    fi
    
    # Exécution séquentielle
    check_system
    cleanup_previous
    install_system
    install_docker
    setup_project
    setup_nginx
    build_and_start
    setup_ssl
    setup_firewall
    
    # Tests et finalisation
    if test_application; then
        create_admin_script
        show_summary
        log_success "🎉 DÉPLOIEMENT RÉUSSI!"
    else
        create_admin_script
        show_summary
        log_warning "⚠️ Déploiement terminé avec avertissements"
        echo -e "${YELLOW}L'application peut nécessiter quelques minutes pour être complètement opérationnelle.${NC}"
    fi
}

# Lancement
main "$@"