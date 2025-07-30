# Instructions de déploiement Vote Secret sur VPS

## 🚀 Déploiement automatique

### 1. Préparation du serveur

Connectez-vous à votre VPS en SSH :
```bash
ssh root@votre-serveur
```

### 2. Téléchargement et exécution du script de déploiement

```bash
# Télécharger le script de déploiement
wget https://raw.githubusercontent.com/KiiTuNp/vote/main/deploy.sh

# Rendre le script exécutable
chmod +x deploy.sh

# Exécuter le déploiement (en tant que root)
sudo ./deploy.sh
```

Le script va automatiquement :
- ✅ Installer toutes les dépendances (Node.js, Python, MongoDB, Nginx)
- ✅ Cloner votre repository
- ✅ Configurer l'environnement
- ✅ Installer les certificats SSL
- ✅ Configurer le reverse proxy Nginx
- ✅ Démarrer tous les services

### 3. Vérification du déploiement

Après le déploiement, votre application sera accessible sur :
**https://vote.super-csn.ca**

## 🔧 Scripts de gestion

### Scripts disponibles après déploiement :

1. **Gestion des services** : `/var/www/vote-secret/manage.sh`
```bash
sudo /var/www/vote-secret/manage.sh status    # Voir le statut
sudo /var/www/vote-secret/manage.sh restart   # Redémarrer
sudo /var/www/vote-secret/manage.sh logs      # Voir les logs
sudo /var/www/vote-secret/manage.sh update    # Mettre à jour
```

2. **Mise à jour rapide** : `/var/www/vote-secret/update.sh` (ou `update.sh` dans le repo)
```bash
# Utiliser le script local après déploiement
sudo /var/www/vote-secret/update.sh

# Ou télécharger la dernière version
wget https://raw.githubusercontent.com/KiiTuNp/vote/main/update.sh
sudo ./update.sh
```

3. **Diagnostic** : `/var/www/vote-secret/diagnostic.sh` (ou `diagnostic.sh` dans le repo)
```bash
# Utiliser le script local
sudo /var/www/vote-secret/diagnostic.sh

# Ou télécharger pour diagnostic
wget https://raw.githubusercontent.com/KiiTuNp/vote/main/diagnostic.sh
sudo ./diagnostic.sh
```

4. **Sauvegarde** : `/var/www/vote-secret/backup.sh`
```bash
sudo /var/www/vote-secret/backup.sh
```

## 📋 Commandes utiles post-déploiement

### Gestion des services
```bash
# Statut général
sudo supervisorctl status

# Redémarrer le backend
sudo supervisorctl restart vote-secret-backend

# Redémarrer Nginx
sudo systemctl restart nginx

# Statut MongoDB
sudo systemctl status mongod
```

### Logs
```bash
# Logs du backend
sudo tail -f /var/log/supervisor/vote-secret-backend.out.log

# Logs Nginx
sudo tail -f /var/log/nginx/vote-secret.access.log
sudo tail -f /var/log/nginx/vote-secret.error.log

# Logs système
sudo journalctl -f -u nginx
sudo journalctl -f -u mongod
```

### Certificats SSL
```bash
# Renouveler manuellement
sudo certbot renew

# Vérifier l'expiration
sudo certbot certificates

# Test de renouvellement
sudo certbot renew --dry-run
```

## 🛠️ Dépannage

### Si l'application ne démarre pas :

1. **Vérifier les services** :
```bash
sudo /var/www/vote-secret/diagnostic.sh
```

2. **Vérifier les logs d'erreur** :
```bash
sudo tail -f /var/log/supervisor/vote-secret-backend.err.log
```

3. **Redémarrer tous les services** :
```bash
sudo /var/www/vote-secret/manage.sh restart
```

### Si SSL ne fonctionne pas :

1. **Régénérer les certificats** :
```bash
sudo certbot --nginx -d vote.super-csn.ca --force-renewal
```

2. **Vérifier la configuration Nginx** :
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Si l'API n'est pas accessible :

1. **Vérifier que le backend tourne** :
```bash
sudo supervisorctl status vote-secret-backend
```

2. **Tester l'API localement** :
```bash
curl http://localhost:8001/api/
```

3. **Vérifier la configuration Nginx** :
```bash
curl -I https://vote.super-csn.ca/api/
```

## 🔄 Mise à jour de l'application

Pour mettre à jour l'application après des modifications dans le code :

```bash
# Option 1: Script de mise à jour automatique
sudo /var/www/vote-secret/update.sh

# Option 2: Mise à jour manuelle
cd /var/www/vote-secret
sudo git pull origin main
cd frontend && sudo -u www-data yarn build
sudo supervisorctl restart vote-secret-backend
```

## 📊 Monitoring

- **Application** : https://vote.super-csn.ca
- **API Health** : https://vote.super-csn.ca/api/
- **Logs Backend** : `/var/log/supervisor/vote-secret-backend.out.log`
- **Logs Nginx** : `/var/log/nginx/vote-secret.access.log`

## 🗂️ Structure des fichiers sur le serveur

```
/var/www/vote-secret/          # Application principale
├── backend/                   # API FastAPI
├── frontend/build/           # Build React de production
├── manage.sh                 # Script de gestion
├── backup.sh                 # Script de sauvegarde
└── diagnostic.sh            # Script de diagnostic

/etc/nginx/sites-available/   # Configuration Nginx
├── vote-secret              # Config du site

/etc/supervisor/conf.d/       # Configuration Supervisor
├── vote-secret.conf         # Config des services

/var/log/                     # Logs
├── supervisor/vote-secret-*  # Logs de l'application
└── nginx/vote-secret.*      # Logs web
```

## ⚠️ Sécurité

Le script configure automatiquement :
- ✅ Firewall UFW avec ports SSH et HTTPS
- ✅ Certificats SSL automatiques avec Let's Encrypt
- ✅ Headers de sécurité Nginx
- ✅ Configuration SSL sécurisée
- ✅ Limitation des tailles d'upload
- ✅ Logs de sécurité

## 📞 Support

En cas de problème :
1. Exécuter le diagnostic : `sudo /var/www/vote-secret/diagnostic.sh`
2. Consulter les logs récents
3. Vérifier la configuration avec les commandes de dépannage ci-dessus