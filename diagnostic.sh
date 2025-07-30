#!/bin/bash

# Vote Secret - Script de monitoring et diagnostic
# Utilise ce script pour vérifier l'état de l'application

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

echo "=============================================="
echo "🔍 DIAGNOSTIC VOTE SECRET"
echo "=============================================="
echo ""

# 1. Vérification des services système
log_info "📊 Vérification des services système..."
echo ""

# MongoDB
if systemctl is-active --quiet mongod; then
    log_success "✅ MongoDB: ACTIF"
    mongo_version=$(mongod --version | head -n1)
    echo "   Version: $mongo_version"
else
    log_error "❌ MongoDB: INACTIF"
    echo "   Commande pour démarrer: sudo systemctl start mongod"
fi

# Nginx
if systemctl is-active --quiet nginx; then
    log_success "✅ Nginx: ACTIF"
    nginx_version=$(nginx -v 2>&1)
    echo "   $nginx_version"
else
    log_error "❌ Nginx: INACTIF"
    echo "   Commande pour démarrer: sudo systemctl start nginx"
fi

# Supervisor
if systemctl is-active --quiet supervisor; then
    log_success "✅ Supervisor: ACTIF"
else
    log_error "❌ Supervisor: INACTIF"
    echo "   Commande pour démarrer: sudo systemctl start supervisor"
fi

echo ""

# 2. Vérification de l'application
log_info "🚀 Vérification de l'application Vote Secret..."
echo ""

# Backend
backend_status=$(supervisorctl status vote-secret-backend 2>/dev/null || echo "NOT_FOUND")
if echo "$backend_status" | grep -q "RUNNING"; then
    log_success "✅ Backend: ACTIF"
    echo "   $backend_status"
else
    log_error "❌ Backend: PROBLÈME"
    echo "   Status: $backend_status"
    echo "   Logs récents:"
    tail -n 5 /var/log/supervisor/vote-secret-backend.err.log 2>/dev/null || echo "   Aucun log d'erreur trouvé"
fi

echo ""

# 3. Tests de connectivité
log_info "🌐 Tests de connectivité..."
echo ""

# Test HTTPS du site
if curl -f -s "https://$DOMAIN" > /dev/null; then
    log_success "✅ Site web: ACCESSIBLE"
else
    log_error "❌ Site web: INACCESSIBLE"
fi

# Test API
if curl -f -s "https://$DOMAIN/api/" > /dev/null; then
    log_success "✅ API: ACCESSIBLE"
    api_response=$(curl -s "https://$DOMAIN/api/" | head -c 100)
    echo "   Réponse: $api_response"
else
    log_error "❌ API: INACCESSIBLE"
fi

echo ""

# 4. Vérification des certificats SSL
log_info "🔐 Vérification des certificats SSL..."
echo ""

cert_info=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ $? -eq 0 ]; then
    log_success "✅ Certificat SSL: VALIDE"
    echo "   $cert_info"
else
    log_error "❌ Certificat SSL: PROBLÈME"
fi

echo ""

# 5. Vérification de l'espace disque
log_info "💽 Vérification de l'espace disque..."
echo ""

disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
if [ "$disk_usage" -lt 80 ]; then
    log_success "✅ Espace disque: OK ($disk_usage% utilisé)"
else
    log_warning "⚠️ Espace disque: ATTENTION ($disk_usage% utilisé)"
fi

echo ""

# 6. Vérification de la mémoire
log_info "🧠 Vérification de la mémoire..."
echo ""

mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$mem_usage" -lt 80 ]; then
    log_success "✅ Mémoire: OK ($mem_usage% utilisée)"
else
    log_warning "⚠️ Mémoire: ATTENTION ($mem_usage% utilisée)"
fi

echo ""

# 7. Vérification des logs récents
log_info "📋 Logs récents (dernières 5 lignes)..."
echo ""

echo "🔹 Backend (stdout):"
tail -n 5 /var/log/supervisor/vote-secret-backend.out.log 2>/dev/null || echo "   Aucun log trouvé"

echo ""
echo "🔹 Backend (stderr):"
tail -n 5 /var/log/supervisor/vote-secret-backend.err.log 2>/dev/null || echo "   Aucun log d'erreur"

echo ""
echo "🔹 Nginx access:"
tail -n 3 /var/log/nginx/vote-secret.access.log 2>/dev/null || echo "   Aucun log d'accès trouvé"

echo ""
echo "🔹 Nginx error:"
tail -n 3 /var/log/nginx/vote-secret.error.log 2>/dev/null || echo "   Aucun log d'erreur nginx"

echo ""

# 8. Statistiques de base de données
log_info "🍃 Statistiques MongoDB..."
echo ""

if systemctl is-active --quiet mongod; then
    db_stats=$(mongo vote_secret_production --quiet --eval "
        print('Collections:');
        db.getCollectionNames().forEach(function(collection) {
            var count = db[collection].count();
            print('  ' + collection + ': ' + count + ' documents');
        });
    " 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$db_stats"
    else
        log_warning "⚠️ Impossible de récupérer les statistiques de la base"
    fi
else
    log_error "❌ MongoDB non disponible pour les statistiques"
fi

echo ""

# 9. Recommandations
log_info "💡 Recommandations et commandes utiles..."
echo ""

echo "🔧 Gestion des services:"
echo "   • Redémarrer l'app: sudo $APP_DIR/manage.sh restart"
echo "   • Voir les logs: sudo $APP_DIR/manage.sh logs"
echo "   • Mettre à jour: sudo $APP_DIR/update.sh"
echo ""

echo "🔍 Diagnostic avancé:"
echo "   • Logs backend complets: sudo tail -f /var/log/supervisor/vote-secret-backend.out.log"
echo "   • Logs nginx: sudo tail -f /var/log/nginx/vote-secret.access.log"
echo "   • Statut détaillé: sudo supervisorctl status"
echo ""

echo "💾 Sauvegarde:"
echo "   • Sauvegarde manuelle: sudo $APP_DIR/backup.sh"
echo "   • Emplacement des sauvegardes: /backup/vote-secret/"
echo ""

echo "=============================================="
log_info "🏁 Diagnostic terminé"
echo "=============================================="