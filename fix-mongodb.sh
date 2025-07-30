#!/bin/bash

# Fix MongoDB libssl1.1 dependency issue on Ubuntu 22.04+
# Utilise ce script si tu rencontres l'erreur libssl1.1 pendant l'installation

set -e

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

log_info "🔧 Fix MongoDB libssl1.1 pour Ubuntu 22.04+"

# 1. Détecter la version d'Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
UBUNTU_CODENAME=$(lsb_release -cs)

log_info "Système détecté: Ubuntu $UBUNTU_VERSION ($UBUNTU_CODENAME)"

# 2. Nettoyer les installations MongoDB échouées
log_info "🧹 Nettoyage des installations MongoDB échouées..."
apt remove --purge mongodb-org* -y || true
apt autoremove -y || true
rm -f /etc/apt/sources.list.d/mongodb-org-*.list || true

# 3. Installation de libssl1.1 pour Ubuntu 22.04+
if (( $(echo "$UBUNTU_VERSION >= 22.04" | bc -l) )); then
    log_info "📦 Installation de libssl1.1 pour Ubuntu 22.04+..."
    
    cd /tmp
    
    # Téléchargement et installation de libssl1.1
    if [ ! -f "libssl1.1_1.1.1f-1ubuntu2.19_amd64.deb" ]; then
        wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.19_amd64.deb
    fi
    
    dpkg -i libssl1.1_1.1.1f-1ubuntu2.19_amd64.deb
    log_success "✅ libssl1.1 installé"
    
    # 4. Installation de MongoDB 6.0 (compatible)
    log_info "🍃 Installation de MongoDB 6.0..."
    
    # Ajout de la clé GPG
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
    
    # Ajout du repository (utiliser focal pour compatibilité)
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    
    # Mise à jour et installation
    apt update
    
    # Installation avec versions spécifiques
    apt install -y \
        mongodb-org=6.0.3 \
        mongodb-org-database=6.0.3 \
        mongodb-org-server=6.0.3 \
        mongodb-org-mongos=6.0.3 \
        mongodb-org-shell=6.0.3 \
        mongodb-org-tools=6.0.3
    
    # Verrouiller les versions pour éviter les mises à jour automatiques
    echo "mongodb-org hold" | dpkg --set-selections
    echo "mongodb-org-database hold" | dpkg --set-selections
    echo "mongodb-org-server hold" | dpkg --set-selections
    echo "mongodb-org-mongos hold" | dpkg --set-selections
    echo "mongodb-org-shell hold" | dpkg --set-selections
    echo "mongodb-org-tools hold" | dpkg --set-selections
    
    log_success "✅ MongoDB 6.0 installé avec compatibilité libssl1.1"
    
else
    log_info "Ubuntu < 22.04 détecté - Installation MongoDB 5.0 classique"
    
    # Installation pour Ubuntu 20.04 et antérieures
    wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $UBUNTU_CODENAME/mongodb-org/5.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-5.0.list
    apt update
    apt install -y mongodb-org
    
    log_success "✅ MongoDB 5.0 installé"
fi

# 5. Configuration et démarrage de MongoDB
log_info "⚙️ Configuration de MongoDB..."

# Créer le répertoire des données si nécessaire
mkdir -p /var/lib/mongodb
chown mongodb:mongodb /var/lib/mongodb

# Démarrer et activer MongoDB
systemctl daemon-reload
systemctl start mongod
systemctl enable mongod

# Attendre que MongoDB démarre
sleep 5

# 6. Vérification de l'installation
log_info "🔍 Vérification de l'installation..."

if systemctl is-active --quiet mongod; then
    log_success "✅ MongoDB: ACTIF"
    
    # Test de connexion
    if mongo --eval "db.runCommand('ping')" >/dev/null 2>&1; then
        log_success "✅ Connexion MongoDB: OK"
        
        # Afficher la version
        mongo_version=$(mongod --version | head -n1)
        log_success "✅ Version: $mongo_version"
        
    else
        log_warning "⚠️ MongoDB démarré mais connexion difficile - peut nécessiter quelques secondes"
    fi
    
else
    log_error "❌ MongoDB: PROBLÈME DE DÉMARRAGE"
    log_info "📋 Logs récents:"
    journalctl -u mongod --no-pager -l -n 10
    exit 1
fi

# 7. Configuration de sécurité basique
log_info "🔐 Configuration de sécurité basique..."

mongo --eval "
use admin;
db.createUser({
  user: 'admin',
  pwd: 'vote_secret_admin_2025',
  roles: [{role: 'userAdminAnyDatabase', db: 'admin'}]
});
" >/dev/null 2>&1 || log_warning "⚠️ Utilisateur admin déjà existant ou erreur de création"

# 8. Messages finaux
echo ""
log_success "🎉 MongoDB installé et configuré avec succès!"
echo ""
log_info "📋 Informations importantes:"
echo "   • Service: systemctl status mongod"
echo "   • Logs: journalctl -u mongod -f"
echo "   • Connexion: mongo"
echo "   • Base de données pour Vote Secret: vote_secret_production"
echo ""
log_info "🔧 Vous pouvez maintenant relancer le script de déploiement principal:"
echo "   sudo ./deploy.sh"
echo ""