# 🚨 Fix MongoDB Ubuntu 22.04+ - Vote Secret

## Problème rencontré

Si vous voyez cette erreur :
```
mongodb-org-server : Depends: libssl1.1 (>= 1.1.1) but it is not installable
--2025-07-30 19:44:47--  http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.19_amd64.deb
HTTP request sent, awaiting response... 404 Not Found
```

## 🔥 SOLUTION IMMÉDIATE - Docker (Recommandée)

**Cette solution évite COMPLÈTEMENT le problème :**

```bash
# Une seule commande pour tout installer
wget https://raw.githubusercontent.com/KiiTuNp/vote/main/deploy-simple.sh
chmod +x deploy-simple.sh
sudo ./deploy-simple.sh
```

✅ **Avantages du déploiement Docker :**
- Évite tous les problèmes de dépendances
- Fonctionne sur Ubuntu 18.04, 20.04, 22.04, 24.04
- Installation ultra-simple
- Isolation complète des services
- Mise à jour facile

## 🛠️ Solutions alternatives (si vous ne voulez pas Docker)

### Solution 1 : Script corrigé avec fallbacks multiples
```bash
# Le script corrigé essaie plusieurs sources pour libssl1.1
wget https://raw.githubusercontent.com/KiiTuNp/vote/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### Solution 2 : Fix MongoDB manuel
```bash
# Fix spécialisé MongoDB
wget https://raw.githubusercontent.com/KiiTuNp/vote/main/fix-mongodb.sh  
chmod +x fix-mongodb.sh
sudo ./fix-mongodb.sh

# Puis déploiement normal
sudo ./deploy.sh
```

### Solution 3 : Installation manuelle libssl1.1

Si toutes les solutions automatiques échouent :

```bash
# Méthode 1: Repos Ubuntu 20.04
echo "deb http://archive.ubuntu.com/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/focal.list
sudo apt update
sudo apt install libssl1.1
sudo rm /etc/apt/sources.list.d/focal.list
sudo apt update

# Méthode 2: Installation forcée
cd /tmp
wget http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.20_amd64.deb
sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2.20_amd64.deb

# Méthode 3: Si les deux précédentes échouent
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ubuntu-toolchain-r/test
sudo apt update
sudo apt install libssl1.1
```

## 🐳 Pourquoi Docker est la meilleure solution ?

### Problème avec Ubuntu 22.04+ :
- Ubuntu 22.04+ utilise `libssl3` par défaut
- MongoDB 5.0/6.0 a été compilé avec `libssl1.1`
- `libssl1.1` n'est plus dans les repos officiels Ubuntu 22.04+
- Les liens vers les archives changent régulièrement

### Solution Docker :
- MongoDB s'exécute dans un conteneur avec ses propres dépendances
- Pas de conflit avec le système hôte
- Isolation complète
- Même version de MongoDB sur tous les systèmes
- Mise à jour simplifiée

## 📋 Après le déploiement Docker

Votre application sera accessible sur : **https://vote.super-csn.ca**

### Commandes de gestion :
```bash
cd /var/www/vote-secret

# Voir le statut
./manage.sh status

# Voir les logs
./manage.sh logs

# Redémarrer
./manage.sh restart

# Mettre à jour
./manage.sh update

# Arrêter
./manage.sh stop

# Démarrer
./manage.sh start
```

### Commandes Docker directes :
```bash
cd /var/www/vote-secret

# Voir les conteneurs
docker-compose ps

# Logs en temps réel
docker-compose logs -f

# Redémarrer un service
docker-compose restart backend

# Reconstruire
docker-compose up -d --build
```

## 🔧 Dépannage

### Si l'API n'est pas accessible :
```bash
# Vérifier les conteneurs
docker-compose ps

# Voir les logs du backend
docker-compose logs backend

# Redémarrer le backend
docker-compose restart backend
```

### Si le site ne charge pas :
```bash
# Vérifier Nginx
sudo systemctl status nginx

# Vérifier les certificats SSL
sudo certbot certificates

# Redémarrer Nginx
sudo systemctl restart nginx
```

### Si MongoDB ne démarre pas :
```bash
# Logs MongoDB
docker-compose logs mongodb

# Redémarrer MongoDB
docker-compose restart mongodb

# Vérifier l'espace disque
df -h
```

## 🎯 Test de l'installation

Après le déploiement, testez :

1. **Site web** : https://vote.super-csn.ca
2. **API** : https://vote.super-csn.ca/api/
3. **Créer une réunion** : Interface organisateur
4. **Rejoindre** : Interface participant

## 💡 Notes importantes

- Le déploiement Docker inclut automatiquement les certificats SSL
- Le firewall est configuré automatiquement
- Les sauvegardes MongoDB sont dans le volume Docker `mongodb_data`
- Les logs sont accessibles via `docker-compose logs`

## 🆘 Support

Si le déploiement Docker échoue également :

1. **Vérifiez les prérequis** :
   ```bash
   docker --version
   docker-compose --version
   ```

2. **Espaces disque** :
   ```bash
   df -h
   ```

3. **Logs système** :
   ```bash
   sudo journalctl -f
   ```

4. **Nettoyage et nouvelle tentative** :
   ```bash
   sudo docker system prune -a
   sudo ./deploy-simple.sh
   ```

---

**🎉 Le déploiement Docker fonctionne sur tous les systèmes Ubuntu/Debian et évite complètement les problèmes de dépendances !**