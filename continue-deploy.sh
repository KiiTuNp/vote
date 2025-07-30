#!/bin/bash

# Fix rapide pour le problème npm date-fns
# Exécute ce script depuis le répertoire où tu étais

set -e

DOMAIN="vote.super-csn.ca"
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

echo "🔧 Fix rapide pour le problème npm date-fns"

# 1. Aller dans le répertoire du projet
cd "$APP_DIR"

# 2. Corriger le package.json
log_info "📝 Correction du package.json..."
cd frontend

# Fixer la version de date-fns pour compatibility avec react-day-picker
sed -i 's/"date-fns": "^4.1.0"/"date-fns": "^3.6.0"/' package.json

log_success "✅ package.json corrigé"

# 3. Réinstaller les dépendances avec --legacy-peer-deps
log_info "📦 Réinstallation des dépendances..."
rm -rf node_modules package-lock.json

# Utiliser npm avec --legacy-peer-deps pour forcer la résolution
npm install --legacy-peer-deps

log_success "✅ Dépendances installées"

# 4. Build du frontend
log_info "🏗️ Build du frontend..."
npm run build

log_success "✅ Frontend buildé avec succès"
cd ..

# 5. Continuer avec la configuration Docker
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

# 6. Installation SSL avec Certbot
log_info "🔐 Installation des certificats SSL..."
apt install -y snapd
snap install core; snap refresh core
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

# Génération des certificats
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@super-csn.ca --redirect

# 7. Configuration du firewall
log_info "🔥 Configuration du firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# 8. Démarrage des services Docker
log_info "🚀 Démarrage des services Docker..."

# Démarrage des conteneurs
docker-compose up -d --build

# Attendre que les services démarrent
log_info "⏳ Attente du démarrage des services..."
sleep 30

# 9. Démarrage de Nginx
systemctl restart nginx
systemctl enable nginx

# 10. Script de gestion simple
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
        cd frontend && npm install --legacy-peer-deps && npm run build && cd ..
        docker-compose up -d --build
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        ;;
esac
EOF

chmod +x manage.sh

# 11. Vérifications finales
log_info "🔍 Vérifications finales..."

# Vérifier Docker
if docker-compose ps | grep -q "Up"; then
    log_success "✅ Conteneurs Docker: ACTIFS"
else
    log_warning "⚠️ Conteneurs en cours de démarrage..."
    docker-compose logs
fi

# Vérifier Nginx
if systemctl is-active --quiet nginx; then
    log_success "✅ Nginx: ACTIF"
else
    log_warning "⚠️ Nginx: Redémarrage..."
    systemctl restart nginx
fi

# Test API (avec délai)
sleep 10
if curl -f -s "https://$DOMAIN/api/" > /dev/null; then
    log_success "✅ API: ACCESSIBLE"
else
    log_warning "⚠️ API: Attendre quelques minutes pour le démarrage complet"
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
echo ""
log_info "🔍 Si l'API n'est pas encore accessible, attendre 2-3 minutes"
echo "     Les conteneurs Docker peuvent prendre du temps à démarrer"