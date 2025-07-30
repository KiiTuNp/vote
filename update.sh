#!/bin/bash

# Vote Secret - Script de mise à jour rapide
# Utilise ce script pour mettre à jour l'application sans refaire tout le déploiement

set -e

APP_DIR="/var/www/vote-secret"
DOMAIN="vote.super-csn.ca"

# Couleurs
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

log_info "🔄 Mise à jour de Vote Secret..."

# 1. Arrêter l'application
log_info "🛑 Arrêt des services..."
supervisorctl stop vote-secret:*

# 2. Sauvegarde de sécurité
log_info "💾 Sauvegarde de sécurité..."
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p /backup/vote-secret
mongodump --db vote_secret_production --out "/backup/vote-secret/pre_update_$DATE" --quiet

# 3. Mise à jour du code
log_info "📥 Récupération des dernières modifications..."
cd "$APP_DIR"
git stash --quiet || true  # Sauvegarder les changements locaux éventuels
git pull origin main

# 4. Mise à jour du backend
log_info "🐍 Mise à jour du Backend..."
cd "$APP_DIR/backend"
source venv/bin/activate
pip install -r requirements.txt --quiet
deactivate

# 5. Mise à jour du frontend
log_info "🎨 Mise à jour du Frontend..."
cd "$APP_DIR/frontend"
yarn install --silent
yarn build --silent

# 6. Mise à jour des permissions
log_info "🔐 Mise à jour des permissions..."
chown -R www-data:www-data "$APP_DIR"

# 7. Redémarrage des services
log_info "🚀 Redémarrage des services..."
supervisorctl start vote-secret:*
systemctl reload nginx

# 8. Vérification
log_info "🔍 Vérification du déploiement..."
sleep 5

if supervisorctl status vote-secret-backend | grep -q RUNNING; then
    log_success "✅ Backend: ACTIF"
else
    log_error "❌ Backend: PROBLÈME DÉTECTÉ"
    log_info "📋 Logs du backend:"
    tail -n 20 /var/log/supervisor/vote-secret-backend.err.log
    exit 1
fi

if curl -f -s "https://$DOMAIN/api/" > /dev/null; then
    log_success "✅ API: ACCESSIBLE"
else
    log_warning "⚠️ API: Vérifiez les logs si nécessaire"
fi

log_success "🎉 Mise à jour terminée avec succès!"
log_info "📱 Application disponible sur: https://$DOMAIN"