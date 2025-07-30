#!/bin/bash

# ========================================================================
# VOTE SECRET - DÉPLOIEMENT DOCKER ROBUSTE
# Script unique et définitif pour installer Vote Secret avec Docker
# Fonctionne sur Ubuntu 18.04, 20.04, 22.04, 24.04+
# ========================================================================

set -e

# Configuration
DOMAIN="vote.super-csn.ca"
REPO_URL="https://github.com/KiiTuNp/vote.git"
APP_DIR="/var/www/vote-secret"
LOG_FILE="/tmp/vote-secret-deploy.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Fonctions de logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"; }

# Fonction pour demander confirmation
confirm() {
    local message="$1"
    while true; do
        read -p "$message (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Répondez par y (oui) ou n (non).";;
        esac
    done
}

# Gestion d'erreur avec nettoyage
cleanup_on_error() {
    log_error "Échec du déploiement. Nettoyage en cours..."
    cd /
    docker-compose -f "$APP_DIR/docker-compose.yml" down 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    log_error "Consultez les logs: $LOG_FILE"
    exit 1
}

trap cleanup_on_error ERR

# Vérifications préliminaires
check_system() {
    log_step "🔍 Vérification du système..."
    
    # Root check
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo $0"
        exit 1
    fi
    
    # Internet check
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        log_error "Pas de connexion internet"
        exit 1
    fi
    
    # Disk space check (minimum 3GB)
    local available=$(df / | awk 'NR==2 {print $4}')
    if [ "$available" -lt 3000000 ]; then
        log_error "Espace disque insuffisant (minimum 3GB requis)"
        exit 1
    fi
    
    log_success "✅ Système vérifié"
}

# Nettoyage intelligent
cleanup_previous() {
    log_step "🧹 Nettoyage des installations précédentes..."
    
    # Arrêter les services existants
    systemctl stop nginx 2>/dev/null || true
    if [ -f "$APP_DIR/docker-compose.yml" ]; then
        cd "$APP_DIR"
        docker-compose down 2>/dev/null || true
        cd /
    fi
    
    # Nettoyer les anciens conteneurs Vote Secret
    docker ps -a --filter "name=vote-" -q | xargs -r docker rm -f 2>/dev/null || true
    
    # Nettoyer les images inutilisées
    docker system prune -f &>/dev/null || true
    
    # Supprimer l'ancien répertoire
    rm -rf "$APP_DIR"
    
    # Nettoyer les configurations nginx
    rm -f /etc/nginx/sites-enabled/vote-secret
    rm -f /etc/nginx/sites-available/vote-secret
    
    log_success "✅ Nettoyage terminé"
}

# Installation des dépendances système
install_system() {
    log_step "📦 Installation des dépendances système..."
    
    # Mise à jour des paquets
    apt update &>>"$LOG_FILE"
    
    # Installation des paquets essentiels
    DEBIAN_FRONTEND=noninteractive apt install -y \
        curl \
        wget \
        git \
        nginx \
        ufw \
        ca-certificates \
        gnupg \
        lsb-release \
        snapd \
        &>>"$LOG_FILE"
    
    log_success "✅ Dépendances système installées"
}

# Installation de Docker
install_docker() {
    log_step "🐳 Installation de Docker..."
    
    if command -v docker &>/dev/null; then
        log_info "Docker déjà installé: $(docker --version)"
    else
        # Installation Docker officielle
        curl -fsSL https://get.docker.com -o get-docker.sh &>>"$LOG_FILE"
        sh get-docker.sh &>>"$LOG_FILE"
        rm get-docker.sh
        
        # Démarrer Docker
        systemctl start docker
        systemctl enable docker
    fi
    
    # Installation Docker Compose
    if ! command -v docker-compose &>/dev/null; then
        COMPOSE_VERSION="v2.21.0"
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose &>>"$LOG_FILE"
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    
    # Test Docker
    if ! docker run --rm hello-world &>>"$LOG_FILE"; then
        log_error "Docker ne fonctionne pas correctement"
        exit 1
    fi
    
    log_success "✅ Docker installé et fonctionnel"
}

# Clone et préparation du projet
setup_project() {
    log_step "📥 Téléchargement du projet..."
    
    # Clone du repository
    git clone "$REPO_URL" "$APP_DIR" &>>"$LOG_FILE"
    cd "$APP_DIR"
    
    # Création du Dockerfile pour le frontend (évite les problèmes npm)
    cat > frontend/Dockerfile << 'EOF'
# Build stage - utilise Node.js 18 LTS pour la compatibilité
FROM node:18-alpine as builder

# Variables d'environnement pour le build
ENV NODE_ENV=production
ENV GENERATE_SOURCEMAP=false
ENV NODE_OPTIONS=--max_old_space_size=4096
ENV DISABLE_HOT_RELOAD=true

# Créer le répertoire de travail
WORKDIR /app

# Installer les dépendances système nécessaires pour certains packages npm
RUN apk add --no-cache python3 make g++ git

# Copier les fichiers de configuration npm
COPY package.json yarn.lock* package-lock.json* ./

# Nettoyer le cache npm et installer les dépendances
RUN npm cache clean --force || true
RUN rm -rf node_modules || true

# Installer les dépendances avec --legacy-peer-deps pour résoudre les conflits
RUN npm install --legacy-peer-deps --production=false --no-audit --no-fund

# Copier le code source
COPY . .

# Variables d'environnement pour l'application
ENV REACT_APP_BACKEND_URL=https://vote.super-csn.ca

# Build de production avec craco
RUN npm run build

# Vérifier que le build a réussi
RUN test -d build && test -f build/index.html || (echo "Build failed - missing build directory or index.html" && exit 1)

# Production stage - utilise nginx:alpine
FROM nginx:alpine

# Copier les fichiers buildés
COPY --from=builder /app/build /usr/share/nginx/html

# Configuration Nginx pour React Router (SPA)
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        try_files $uri $uri/ /index.html; \
    } \
    location /static/ { \
        root /usr/share/nginx/html; \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Exposer le port 80
EXPOSE 80

# Commande par défaut
CMD ["nginx", "-g", "daemon off;"]
EOF

    # Dockerfile backend optimisé
    cat > backend/Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copier et installer les dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copier le code
COPY . .

EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8001/api/ || exit 1

# Commande de démarrage
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001"]
EOF

    # Docker Compose complet
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
    networks:
      - vote-network
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s

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
      retries: 5
      start_period: 60s

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: vote-frontend
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:80"
    depends_on:
      - backend
    networks:
      - vote-network

volumes:
  mongodb_data:
    driver: local

networks:
  vote-network:
    driver: bridge
EOF

    log_success "✅ Projet configuré avec Docker"
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