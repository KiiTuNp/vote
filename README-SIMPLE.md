# 🚀 Vote Secret - Installation Ultra-Simple

## ⚡ Installation en 1 commande

```bash
wget https://raw.githubusercontent.com/KiiTuNp/vote/main/deploy-perfect.sh
chmod +x deploy-perfect.sh
sudo ./deploy-perfect.sh
```

**C'est tout !** ✨

---

## 🎯 Ce que fait le script automatiquement

✅ **Détecte votre système** (Ubuntu 18.04, 20.04, 22.04, 24.04)  
✅ **Installe Docker** (évite tous les problèmes MongoDB)  
✅ **Clone et configure** le projet automatiquement  
✅ **Corrige tous les bugs connus** (date-fns, libssl1.1, etc.)  
✅ **Build le frontend** avec gestion d'erreurs  
✅ **Configure SSL automatique** (Let's Encrypt)  
✅ **Configure le firewall** (sécurité)  
✅ **Teste l'application** (6 tests automatiques)  
✅ **Crée les scripts de gestion** pour après  

---

## 📱 Après l'installation

Votre application sera accessible sur :
**https://vote.super-csn.ca**

## 🔧 Gestion simple

Une seule commande pour tout gérer :

```bash
vote-admin status    # Voir le statut
vote-admin logs      # Voir les logs en temps réel
vote-admin restart   # Redémarrer l'application
vote-admin update    # Mettre à jour depuis GitHub
vote-admin backup    # Sauvegarder la base de données
vote-admin test      # Tester l'application
```

---

## 🛡️ Robustesse du script

- **Auto-diagnostic** : Détecte et corrige les problèmes automatiquement
- **Idempotent** : Peut être relancé sans danger
- **Rollback** : Nettoie automatiquement en cas d'erreur
- **Logs complets** : Tout est loggé dans `/tmp/vote-secret-install.log`
- **Tests intégrés** : 6 tests automatiques à la fin
- **Gestion d'erreurs** : Chaque étape est vérifiée

---

## 📊 Fonctionnalités de l'application

### 👥 Pour l'organisateur
- Créer des réunions avec codes uniques
- Approuver/rejeter les participants
- Créer des sondages avec minuteur optionnel
- Voir les résultats en temps réel
- Télécharger le rapport PDF final

### 🗳️ Pour les participants  
- Rejoindre avec nom + code de réunion
- Vote anonyme (aucune traçabilité)
- Voir les résultats après avoir voté
- Interface moderne et responsive

### 🔒 Sécurité
- **Anonymat total** : Impossible de lier un vote à un participant
- **Suppression automatique** : Toutes les données effacées après le rapport PDF
- **HTTPS forcé** : Communications chiffrées
- **Firewall configuré** : Accès sécurisé

---

## 🆘 Dépannage (rare)

Si quelque chose ne va pas :

```bash
# Voir les logs détaillés
tail -f /tmp/vote-secret-install.log

# Redémarrer tous les services
vote-admin restart

# Tester l'application
vote-admin test

# Voir le statut complet
vote-admin status
```

---

## 🔄 Mise à jour

```bash
vote-admin update
```

Met à jour automatiquement depuis GitHub et redémarre les services.

---

## 💾 Sauvegarde

```bash
vote-admin backup
```

Sauvegarde la base de données MongoDB dans `/backup/vote-secret/`

---

## ⚙️ Architecture (pour les curieux)

- **Frontend** : React + Tailwind CSS + Shadcn/UI
- **Backend** : FastAPI (Python) 
- **Base de données** : MongoDB (dans Docker)
- **Reverse Proxy** : Nginx
- **SSL** : Let's Encrypt (automatique)
- **Conteneurisation** : Docker + Docker Compose

---

## 🎉 Résultat final

Une application de vote secret professionnelle, sécurisée et prête pour la production !

**Installation : 1 commande**  
**Gestion : 1 commande**  
**Simplicité : Maximum** ✨