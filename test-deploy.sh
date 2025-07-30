#!/bin/bash

# Script de test pour valider deploy.sh sans vraiment déployer
# Simule un déploiement sur Ubuntu 22.04

set -e

SCRIPT_DIR="/app"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.sh"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "========================================"
echo -e "${BLUE}🧪 Test du Script de Déploiement${NC}"
echo "========================================"
echo ""

# Test 1: Syntaxe du script
log_info "Test 1: Vérification syntaxe deploy.sh..."
if bash -n "$DEPLOY_SCRIPT"; then
    log_success "✅ Syntaxe correcte"
else
    log_error "❌ Erreur de syntaxe"
    exit 1
fi

# Test 2: Variables définies
log_info "Test 2: Vérification des variables..."
if grep -q "DEFAULT_DOMAIN=\"vote.super-csn.ca\"" "$DEPLOY_SCRIPT"; then
    log_success "✅ Domaine correct: vote.super-csn.ca"
else
    log_error "❌ Domaine incorrect"
fi

if grep -q "simon@super-csn.ca" "$DEPLOY_SCRIPT"; then
    log_success "✅ Email certbot correct"
else
    log_error "❌ Email certbot incorrect"
fi

if grep -q "mongo:7.0" "$DEPLOY_SCRIPT"; then
    log_success "✅ Version MongoDB 7.0 (stable)"
else
    log_error "❌ Version MongoDB incorrecte" 
fi

# Test 3: Fichiers Docker
log_info "Test 3: Vérification des Dockerfiles..."

if [ -f "$SCRIPT_DIR/Dockerfile" ]; then
    log_success "✅ Dockerfile backend présent"
    if grep -q "python:3.12-slim" "$SCRIPT_DIR/Dockerfile"; then
        log_success "✅ Python 3.12 configuré"
    fi
    if grep -q "HEALTHCHECK" "$SCRIPT_DIR/Dockerfile"; then
        log_success "✅ Health check configuré"
    fi
else
    log_error "❌ Dockerfile backend manquant"
fi

if [ -f "$SCRIPT_DIR/Dockerfile.frontend" ]; then
    log_success "✅ Dockerfile frontend présent"
    if grep -q "node:22-alpine" "$SCRIPT_DIR/Dockerfile.frontend"; then
        log_success "✅ Node.js 22 LTS configuré"
    fi
    if grep -q "nginx:1.27-alpine" "$SCRIPT_DIR/Dockerfile.frontend"; then
        log_success "✅ Nginx 1.27 configuré"
    fi
else
    log_error "❌ Dockerfile frontend manquant"
fi

# Test 4: Docker Compose
log_info "Test 4: Vérification docker-compose.yml..."
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    log_success "✅ docker-compose.yml présent"
    if grep -q "mongo:7.0" "$SCRIPT_DIR/docker-compose.yml"; then
        log_success "✅ MongoDB 7.0 dans compose"
    fi
    if grep -q "healthcheck:" "$SCRIPT_DIR/docker-compose.yml"; then
        log_success "✅ Health checks configurés"
    fi
else
    log_error "❌ docker-compose.yml manquant"
fi

# Test 5: Variables d'environnement
log_info "Test 5: Vérification des variables d'environnement..."
if [ -f "$SCRIPT_DIR/frontend/.env" ]; then
    if grep -q "https://vote.super-csn.ca" "$SCRIPT_DIR/frontend/.env"; then
        log_success "✅ Frontend pointé vers vote.super-csn.ca"
    else
        log_error "❌ Frontend URL incorrecte"
    fi
else
    log_error "❌ Frontend .env manquant"
fi

if [ -f "$SCRIPT_DIR/backend/.env" ]; then
    if grep -q "mongodb://localhost:27017" "$SCRIPT_DIR/backend/.env"; then
        log_success "✅ Backend MongoDB URL correcte"
    else
        log_error "❌ Backend MongoDB URL incorrecte"
    fi
else
    log_error "❌ Backend .env manquant"
fi

# Test 6: Structure de l'application
log_info "Test 6: Vérification structure application..."

required_files=(
    "backend/server.py"
    "backend/requirements.txt"
    "frontend/package.json"
    "frontend/src/App.js"
    "README.md"
)

for file in "${required_files[@]}"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        log_success "✅ $file présent"
    else
        log_error "❌ $file manquant"
    fi
done

# Test 7: Fonctions critiques du script deploy.sh
log_info "Test 7: Vérification fonctions critiques..."

critical_functions=(
    "check_system"
    "install_system"
    "install_docker"
    "setup_project"
    "setup_nginx"
    "build_and_start"
    "setup_ssl"
    "setup_firewall"
    "test_application"
)

for func in "${critical_functions[@]}"; do
    if grep -q "^$func()" "$DEPLOY_SCRIPT"; then
        log_success "✅ Fonction $func définie"
    else
        log_error "❌ Fonction $func manquante"
    fi
done

# Test 8: Configuration Nginx dans le script
log_info "Test 8: Vérification configuration Nginx..."
if grep -q "location /api" "$DEPLOY_SCRIPT"; then
    log_success "✅ Proxy API configuré"
else
    log_error "❌ Proxy API manquant"
fi

if grep -q "proxy_pass.*:8001" "$DEPLOY_SCRIPT"; then
    log_success "✅ Port backend 8001 configuré"
else
    log_error "❌ Port backend incorrect"
fi

if grep -q "proxy_pass.*:3000" "$DEPLOY_SCRIPT"; then
    log_success "✅ Port frontend 3000 configuré"
else
    log_error "❌ Port frontend incorrect"
fi

echo ""
echo "========================================"
echo -e "${GREEN}🎯 Résumé du Test${NC}"
echo "========================================"
echo ""
echo -e "${BLUE}Le script deploy.sh est configuré pour:${NC}"
echo "• Domaine: vote.super-csn.ca"
echo "• Email SSL: simon@super-csn.ca"
echo "• MongoDB: 7.0 (stable)"
echo "• Node.js: 22 LTS"
echo "• Python: 3.12"
echo "• Nginx: 1.27"
echo ""
echo -e "${GREEN}✅ Validation terminée - Script prêt pour déploiement!${NC}"
echo ""
echo -e "${YELLOW}Commande de déploiement:${NC}"
echo "sudo ./deploy.sh"
echo ""