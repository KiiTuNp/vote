# Vote Secret - Système de Vote Anonyme

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Status](https://img.shields.io/badge/status-production--ready-green.svg)

## 🚀 Installation Ultra-Simple pour Ubuntu 22.04

### Une seule commande pour tout installer :

```bash
wget https://raw.githubusercontent.com/KiiTuNp/vote/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

**Le script est entièrement automatisé** - il configurera automatiquement le domaine vote.super-csn.ca et l'email simon@super-csn.ca pour SSL.

---

## 📋 Ce que fait le script automatiquement

✅ **Vérifie votre système** (Ubuntu 18.04, 20.04, 22.04, 24.04+)  
✅ **Nettoie** les installations précédentes  
✅ **Installe Docker** (évite tous les problèmes de dépendances)  
✅ **Clone et configure** le projet depuis GitHub  
✅ **Build avec Docker** (évite les problèmes npm/Node.js)  
✅ **Configure Nginx** (reverse proxy)  
✅ **Configure SSL** (Let's Encrypt - optionnel)  
✅ **Configure le firewall** (sécurité)  
✅ **Teste l'application** (5 tests automatiques)  
✅ **Crée les outils de gestion** pour après  

---

## 🎯 Résultat final

Après le script, votre application sera accessible sur :
**https://vote.super-csn.ca**

---

## 🛠️ Gestion après installation

Le script crée automatiquement l'outil `vote-admin` :

```bash
vote-admin status    # Voir le statut des services
vote-admin logs      # Voir les logs en temps réel
vote-admin restart   # Redémarrer l'application
vote-admin update    # Mettre à jour depuis GitHub
vote-admin test      # Tester l'application
vote-admin backup    # Sauvegarder la base de données
vote-admin start     # Démarrer l'application
vote-admin stop      # Arrêter l'application
```

---

## 📱 Fonctionnalités de l'application

### 👥 Pour l'organisateur
- **Créer des réunions** avec codes uniques
- **Approuver/rejeter** les participants
- **Créer des sondages** avec minuteur optionnel
- **Voir les résultats** en temps réel
- **Télécharger le rapport PDF** final

### 🗳️ Pour les participants  
- **Rejoindre** avec nom + code de réunion
- **Vote anonyme** (aucune traçabilité possible)
- **Voir les résultats** après avoir voté
- Interface moderne et responsive

### 🔒 Sécurité et anonymat
- **Anonymat total** : Impossible de lier un vote à un participant
- **Suppression automatique** : Toutes les données effacées après le rapport PDF
- **HTTPS forcé** : Communications chiffrées
- **Firewall configuré** : Accès sécurisé

---

## 🔧 Architecture technique

- **Frontend** : React + Tailwind CSS + Shadcn/UI (dans Docker)
- **Backend** : FastAPI (Python) (dans Docker)
- **Base de données** : MongoDB (dans Docker)
- **Reverse Proxy** : Nginx
- **SSL** : Let's Encrypt (automatique)
- **Conteneurisation** : Docker + Docker Compose

---

## 📊 Étapes détaillées du déploiement

### 1. Préparation
- Vérification système (root, internet, espace disque)
- Nettoyage des installations précédentes
- Installation des dépendances système

### 2. Installation Docker
- Installation automatique de Docker
- Installation de Docker Compose
- Test de fonctionnement

### 3. Configuration du projet
- Clone depuis GitHub
- Création des Dockerfiles optimisés
- Configuration des variables d'environnement

### 4. Configuration Nginx
- Configuration du reverse proxy
- Préparation pour SSL
- Test de la configuration

### 5. Build et démarrage
- Construction des images Docker
- Démarrage des conteneurs
- Vérification des services

### 6. Configuration SSL (optionnel)
- Installation de Certbot
- Génération des certificats
- Configuration du renouvellement automatique

### 7. Sécurité
- Configuration du firewall UFW
- Ouverture des ports nécessaires

### 8. Tests finaux
- Test des conteneurs Docker
- Test du site web
- Test de l'API
- Validation complète

---

## 🆘 Dépannage

### Si le déploiement échoue :

1. **Consultez les logs** :
```bash
tail -f /tmp/vote-secret-deploy.log
```

2. **Vérifiez les services** :
```bash
vote-admin status
```

3. **Redémarrez si nécessaire** :
```bash
vote-admin restart
```

### Problèmes courants :

- **Pas assez d'espace disque** : Minimum 3GB requis
- **Problème DNS** : Vérifiez que le domaine pointe vers votre serveur
- **Port 80/443 occupé** : Le script nettoie automatiquement

---

## 🔄 Mise à jour

Pour mettre à jour l'application :

```bash
vote-admin update
```

Cette commande :
- Récupère les dernières modifications depuis GitHub
- Reconstruit les images Docker
- Redémarre les services

---

## 💾 Sauvegarde

Pour sauvegarder la base de données :

```bash
vote-admin backup
```

Les sauvegardes sont stockées dans `/backup/vote-secret/`

---

## 🧪 Test de l'installation

Pour tester que tout fonctionne :

```bash
vote-admin test
```

---

## 📁 Structure des fichiers

Après installation :

```
/var/www/vote-secret/          # Application
├── backend/                   # API FastAPI
├── frontend/                  # Interface React
├── docker-compose.yml         # Configuration Docker
├── vote-admin                 # Script de gestion
└── ...

/tmp/vote-secret-deploy.log    # Logs d'installation
/usr/local/bin/vote-admin      # Commande globale
```

---

## ⚡ Points forts du script

- **Robuste** : Gère toutes les erreurs connues
- **Idempotent** : Peut être relancé sans problème
- **Interactif** : Demande confirmation pour SSL
- **Complet** : De l'installation aux tests
- **Loggé** : Tout est tracé pour le debug
- **Testé** : Validation automatique du résultat

---

## 🎉 Support

- **Logs complets** : `/tmp/vote-secret-deploy.log`
- **Commandes de diagnostic** : `vote-admin status`
- **Tests intégrés** : `vote-admin test`

**Une seule installation, une application complète !** ✨
