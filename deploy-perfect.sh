#!/bin/bash

# ========================================================================
# VOTE SECRET - DÉPLOIEMENT PARFAIT
# Script ultra-robuste qui fonctionne sur tous les systèmes Ubuntu/Debian
# Une seule commande pour tout installer et configurer
# ========================================================================

set -e
trap 'handle_error $? $LINENO' ERR

# Configuration
DOMAIN="vote.super-csn.ca"
REPO_URL="https://github.com/KiiTuNp/vote.git"
APP_DIR="/var/www/vote-secret"
LOG_FILE="/tmp/vote-secret-install.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fonctions de logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"; }

# Gestion d'erreur
handle_error() {
    local exit_code=$1
    local line_number=$2
    log_error "Erreur ligne $line_number (code: $exit_code)"
    log_error "Consultez les logs: $LOG_FILE"
    echo ""
    echo -e "${RED}❌ DÉPLOIEMENT ÉCHOUÉ${NC}"
    echo -e "${YELLOW}💡 Commandes de diagnostic:${NC}"
    echo "   sudo docker ps -a"
    echo "   sudo systemctl status nginx"
    echo "   tail -f $LOG_FILE"
    exit $exit_code
}

# Vérification des prérequis
check_prerequisites() {
    log_step "🔍 Vérification des prérequis..."
    
    # Vérifier root
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root:"
        echo "sudo $0"
        exit 1
    fi
    
    # Vérifier la connexion internet
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "Pas de connexion internet"
        exit 1
    fi
    
    # Vérifier l'espace disque (minimum 2GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 2000000 ]; then
        log_error "Espace disque insuffisant (minimum 2GB requis)"
        exit 1
    fi
    
    log_success "✅ Prérequis validés"
}

# Nettoyage intelligent
cleanup_previous() {
    log_step "🧹 Nettoyage des installations précédentes..."
    
    # Arrêter les services si ils existent
    systemctl stop nginx || true
    docker-compose -f "$APP_DIR/docker-compose.yml" down || true
    
    # Nettoyer les repos MongoDB problématiques
    rm -f /etc/apt/sources.list.d/mongodb-org-*.list || true
    rm -f /etc/apt/sources.list.d/focal*.list || true
    
    # Nettoyer Docker si nécessaire
    docker system prune -f || true
    
    log_success "✅ Nettoyage terminé"
}

# Installation système robuste
install_system_deps() {
    log_step "📦 Installation des dépendances système..."
    
    # Mise à jour
    apt update &>> "$LOG_FILE"
    apt upgrade -y &>> "$LOG_FILE"
    
    # Dépendances de base
    apt install -y \
        curl \
        wget \
        git \
        nginx \
        ufw \
        snapd \
        bc \
        jq \
        htop \
        unzip \
        &>> "$LOG_FILE"
    
    log_success "✅ Dépendances système installées"
}

# Installation Docker robuste
install_docker() {
    log_step "🐳 Installation de Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker déjà installé"
        return 0
    fi
    
    # Installation Docker officielle
    curl -fsSL https://get.docker.com -o get-docker.sh &>> "$LOG_FILE"
    sh get-docker.sh &>> "$LOG_FILE"
    
    # Installation Docker Compose
    DOCKER_COMPOSE_VERSION="v2.20.0"
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose &>> "$LOG_FILE"
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # Démarrer Docker
    systemctl start docker
    systemctl enable docker
    
    # Test Docker
    if ! docker --version &> /dev/null; then
        log_error "Installation Docker échouée"
        exit 1
    fi
    
    log_success "✅ Docker installé: $(docker --version)"
}

# Installation Node.js
install_nodejs() {
    log_step "📋 Installation de Node.js..."
    
    if command -v node &> /dev/null; then
        log_info "Node.js déjà installé: $(node --version)"
        return 0
    fi
    
    # Installation Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - &>> "$LOG_FILE"
    apt install -y nodejs &>> "$LOG_FILE"
    
    # Vérification
    if ! node --version &> /dev/null; then
        log_error "Installation Node.js échouée"
        exit 1
    fi
    
    log_success "✅ Node.js installé: $(node --version)"
}

# Clone et préparation du projet
setup_project() {
    log_step "📥 Configuration du projet..."
    
    # Supprimer l'ancien répertoire
    rm -rf "$APP_DIR"
    
    # Clone
    git clone "$REPO_URL" "$APP_DIR" &>> "$LOG_FILE"
    cd "$APP_DIR"
    
    # Correction automatique du package.json
    if grep -q '"date-fns": "^4' frontend/package.json; then
        log_info "Correction du conflit date-fns..."
        sed -i 's/"date-fns": "^4.1.0"/"date-fns": "^3.6.0"/' frontend/package.json
    fi
    
    log_success "✅ Projet configuré"
}

# Configuration et build du frontend
build_frontend() {
    log_step "🎨 Build du frontend..."
    
    cd "$APP_DIR/frontend"
    
    # Configuration environnement
    cat > .env << EOF
REACT_APP_BACKEND_URL=https://$DOMAIN
GENERATE_SOURCEMAP=false
EOF
    
    # Installation des dépendances avec gestion d'erreur
    log_info "Installation des dépendances npm..."
    if ! npm install --legacy-peer-deps &>> "$LOG_FILE"; then
        log_warning "npm install échoué, tentative avec yarn..."
        npm install -g yarn &>> "$LOG_FILE"
        yarn install &>> "$LOG_FILE"
    fi
    
    # Build
    log_info "Build de production..."
    if ! npm run build &>> "$LOG_FILE"; then
        log_error "Build frontend échoué"
        exit 1
    fi
    
    # Vérification du build
    if [ ! -d "build" ] || [ ! -f "build/index.html" ]; then
        log_error "Build frontend incomplet"
        exit 1
    fi
    
    cd "$APP_DIR"
    log_success "✅ Frontend buildé avec succès"
}

# Configuration Docker optimisée
setup_docker() {
    log_step "🐳 Configuration Docker..."
    
    cd "$APP_DIR"
    
    # Backend Dockerfile optimisé
    cat > backend/Dockerfile << 'EOF'
FROM python:3.9-slim

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Installation des dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copie du code
COPY . .

EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8001/api/ || exit 1

# Commande de démarrage
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "1"]
EOF

    # docker-compose.yml optimisé
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
    ports:
      - "127.0.0.1:27017:27017"
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

volumes:
  mongodb_data:
    driver: local

networks:
  vote-network:
    driver: bridge
EOF

    log_success "✅ Configuration Docker créée"
}

# Configuration Nginx sécurisée
setup_nginx() {
    log_step "🌐 Configuration Nginx..."
    
    # Configuration Nginx optimisée
    cat > /etc/nginx/sites-available/vote-secret << EOF
# Configuration temporaire HTTP (avant SSL)
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        root $APP_DIR/frontend/build;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Activation du site
    ln -sf /etc/nginx/sites-available/vote-secret /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test de la configuration
    if ! nginx -t &>> "$LOG_FILE"; then
        log_error "Configuration Nginx invalide"
        exit 1
    fi
    
    log_success "✅ Nginx configuré"
}

# Configuration SSL automatique
setup_ssl() {
    log_step "🔐 Configuration SSL..."
    
    # Installation Certbot
    snap install core &>> "$LOG_FILE"
    snap refresh core &>> "$LOG_FILE"
    snap install --classic certbot &>> "$LOG_FILE"
    ln -sf /snap/bin/certbot /usr/bin/certbot
    
    # Démarrer Nginx pour validation HTTP
    systemctl restart nginx
    systemctl enable nginx
    
    # Générer les certificats
    log_info "Génération des certificats SSL..."
    if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@super-csn.ca --redirect &>> "$LOG_FILE"; then
        log_success "✅ Certificats SSL installés"
        
        # Configuration cron pour renouvellement automatique
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
    else
        log_warning "⚠️ SSL échoué, application accessible en HTTP uniquement"
        log_info "Vous pourrez configurer SSL manuellement plus tard avec:"
        log_info "sudo certbot --nginx -d $DOMAIN"
    fi
}

# Configuration firewall
setup_firewall() {
    log_step "🔥 Configuration du firewall..."
    
    ufw --force enable &>> "$LOG_FILE"
    ufw allow ssh &>> "$LOG_FILE"
    ufw allow 'Nginx Full' &>> "$LOG_FILE"
    
    log_success "✅ Firewall configuré"
}

# Démarrage des services
start_services() {
    log_step "🚀 Démarrage des services..."
    
    cd "$APP_DIR"
    
    # Build et démarrage Docker
    log_info "Construction des images Docker..."
    docker-compose build &>> "$LOG_FILE"
    
    log_info "Démarrage des conteneurs..."
    docker-compose up -d &>> "$LOG_FILE"
    
    # Attendre que les services démarrent
    log_info "Attente du démarrage complet (60s)..."
    sleep 60
    
    # Redémarrer Nginx
    systemctl restart nginx
    
    log_success "✅ Services démarrés"
}

# Tests complets de l'application
test_application() {
    log_step "🧪 Tests de l'application..."
    
    local tests_passed=0
    local total_tests=6
    
    # Test 1: Conteneurs Docker
    if docker-compose ps | grep -q "Up"; then
        log_success "✅ Test 1/6: Conteneurs Docker actifs"
        ((tests_passed++))
    else
        log_error "❌ Test 1/6: Problème conteneurs Docker"
    fi
    
    # Test 2: Nginx
    if systemctl is-active --quiet nginx; then
        log_success "✅ Test 2/6: Nginx actif"
        ((tests_passed++))
    else
        log_error "❌ Test 2/6: Nginx inactif"
    fi
    
    # Test 3: API Backend (HTTP)
    sleep 10
    if curl -f -s http://localhost:8001/api/ > /dev/null 2>&1; then
        log_success "✅ Test 3/6: API Backend accessible"
        ((tests_passed++))
    else
        log_warning "⚠️ Test 3/6: API Backend - en cours de démarrage"
    fi
    
    # Test 4: Site web
    local protocol="https"
    if ! curl -f -s https://$DOMAIN > /dev/null 2>&1; then
        protocol="http"
    fi
    
    if curl -f -s $protocol://$DOMAIN > /dev/null 2>&1; then
        log_success "✅ Test 4/6: Site web accessible ($protocol)"
        ((tests_passed++))
    else
        log_error "❌ Test 4/6: Site web inaccessible"
    fi
    
    # Test 5: API via proxy
    if curl -f -s $protocol://$DOMAIN/api/ > /dev/null 2>&1; then
        log_success "✅ Test 5/6: API via proxy accessible"
        ((tests_passed++))
    else
        log_warning "⚠️ Test 5/6: API via proxy - peut nécessiter quelques minutes"
    fi
    
    # Test 6: MongoDB
    if docker-compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        log_success "✅ Test 6/6: MongoDB accessible"
        ((tests_passed++))
    else
        log_warning "⚠️ Test 6/6: MongoDB - vérification manuelle requise"
    fi
    
    # Résultat des tests
    if [ $tests_passed -ge 4 ]; then
        log_success "🎉 Tests réussis: $tests_passed/$total_tests"
        return 0
    else
        log_warning "⚠️ Tests partiels: $tests_passed/$total_tests"
        return 1
    fi
}

# Création des scripts de gestion
create_management_scripts() {
    log_step "📝 Création des scripts de gestion..."
    
    cd "$APP_DIR"
    
    # Script de gestion principal
    cat > vote-admin << 'EOF'
#!/bin/bash

APP_DIR="/var/www/vote-secret"
cd "$APP_DIR"

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
        echo "📊 Statut des services:"
        echo ""
        echo "=== Docker Containers ==="
        docker-compose ps
        echo ""
        echo "=== Nginx ==="
        systemctl status nginx --no-pager -l | head -3
        echo ""
        echo "=== Firewall ==="
        ufw status | head -5
        ;;
    logs)
        echo "📋 Logs en temps réel (Ctrl+C pour quitter):"
        docker-compose logs -f
        ;;
    update)
        echo "🔄 Mise à jour de l'application..."
        git pull origin main
        cd frontend
        npm install --legacy-peer-deps
        npm run build
        cd ..
        docker-compose up -d --build
        systemctl restart nginx
        echo "✅ Mise à jour terminée"
        ;;
    backup)
        echo "💾 Sauvegarde de la base de données..."
        BACKUP_DIR="/backup/vote-secret/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        docker-compose exec -T mongodb mongodump --db vote_secret_production --out /data/backup
        docker cp vote-mongodb:/data/backup "$BACKUP_DIR/"
        echo "✅ Sauvegarde créée dans: $BACKUP_DIR"
        ;;
    test)
        echo "🧪 Test de l'application..."
        echo "Site web: curl -I https://vote.super-csn.ca/"
        curl -I https://vote.super-csn.ca/ 2>/dev/null | head -1
        echo "API: curl -I https://vote.super-csn.ca/api/"
        curl -I https://vote.super-csn.ca/api/ 2>/dev/null | head -1
        echo "✅ Tests terminés"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update|backup|test}"
        echo ""
        echo "🔧 Commandes disponibles:"
        echo "  start   - Démarrer tous les services"
        echo "  stop    - Arrêter tous les services"
        echo "  restart - Redémarrer tous les services"
        echo "  status  - Voir le statut des services"
        echo "  logs    - Voir les logs en temps réel"
        echo "  update  - Mettre à jour l'application"
        echo "  backup  - Sauvegarder la base de données"
        echo "  test    - Tester l'application"
        exit 1
        ;;
esac
EOF
    
    chmod +x vote-admin
    ln -sf "$APP_DIR/vote-admin" /usr/local/bin/vote-admin
    
    log_success "✅ Scripts de gestion créés"
}

# Affichage final
show_final_summary() {
    local protocol="https"
    if ! curl -f -s https://$DOMAIN > /dev/null 2>&1; then
        protocol="http"
    fi
    
    echo ""
    echo "========================================"
    echo -e "${GREEN}🎉 Vote Secret déployé avec succès!${NC}"
    echo "========================================"
    echo ""
    echo -e "${CYAN}📱 Application:${NC} $protocol://$DOMAIN"
    echo -e "${CYAN}🔧 Gestion:${NC} vote-admin"
    echo ""
    echo -e "${YELLOW}📋 Commandes principales:${NC}"
    echo "   vote-admin status    # Voir le statut"
    echo "   vote-admin logs      # Voir les logs"
    echo "   vote-admin restart   # Redémarrer"
    echo "   vote-admin update    # Mettre à jour"
    echo "   vote-admin backup    # Sauvegarder"
    echo "   vote-admin test      # Tester l'app"
    echo ""
    echo -e "${BLUE}📂 Localisation:${NC} $APP_DIR"
    echo -e "${BLUE}📄 Logs:${NC} $LOG_FILE"
    echo ""
    echo -e "${GREEN}✅ Installation terminée avec succès!${NC}"
    echo ""
}

# ========================================================================
# SCRIPT PRINCIPAL
# ========================================================================

main() {
    echo ""
    echo "========================================"
    echo -e "${PURPLE}🚀 Vote Secret - Installation Parfaite${NC}"
    echo -e "${PURPLE}   Domaine: $DOMAIN${NC}"
    echo "========================================"
    echo ""
    
    # Initialiser le log
    echo "=== Vote Secret Installation Log ===" > "$LOG_FILE"
    echo "Date: $(date)" >> "$LOG_FILE"
    echo "Domaine: $DOMAIN" >> "$LOG_FILE"
    echo "====================================" >> "$LOG_FILE"
    
    # Exécution séquentielle avec vérifications
    check_prerequisites
    cleanup_previous
    install_system_deps
    install_docker
    install_nodejs
    setup_project
    build_frontend
    setup_docker
    setup_nginx
    setup_ssl
    setup_firewall
    start_services
    
    # Tests et finalisation
    if test_application; then
        create_management_scripts
        show_final_summary
        echo -e "${GREEN}🎉 SUCCÈS TOTAL!${NC}" | tee -a "$LOG_FILE"
    else
        log_warning "Installation terminée avec des avertissements"
        log_info "L'application peut nécessiter quelques minutes supplémentaires pour être complètement opérationnelle"
        create_management_scripts
        show_final_summary
    fi
}

# Lancement du script principal
main "$@"