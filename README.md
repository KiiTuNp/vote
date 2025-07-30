# Vote Secret - Système de Vote Anonyme pour Assemblées

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Status](https://img.shields.io/badge/status-production--ready-green.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## 📋 Description

**Vote Secret** est une application web complète permettant de tenir des votes secrets en assemblée. L'application offre une interface organisateur pour créer des réunions, approuver des participants et créer des sondages, ainsi qu'une interface participant pour voter de manière anonyme.

### 🎯 Fonctionnalités Principales

#### Côté Organisateur
- ✅ Création de réunions avec codes uniques
- ✅ Approbation/rejet des participants en temps réel
- ✅ Création de sondages avec options multiples
- ✅ Minuteur optionnel sur les sondages
- ✅ Lancement et fermeture manuelle des sondages
- ✅ Visualisation des résultats en temps réel
- ✅ Génération de rapport PDF final
- ✅ Suppression automatique des données après rapport

#### Côté Participant
- ✅ Rejoindre une réunion avec nom + code
- ✅ Système d'attente d'approbation
- ✅ Vote anonyme sur sondages actifs
- ✅ Affichage des résultats après vote uniquement
- ✅ Mises à jour automatiques

#### Sécurité & Anonymat
- ✅ **Votes 100% anonymes** - Aucun lien entre participant et vote
- ✅ **Protection des données** - Suppression complète après rapport PDF
- ✅ **Validation des entrées** - Sécurisation côté backend
- ✅ **Gestion d'erreurs** - Messages appropriés pour les utilisateurs

## 🏗️ Architecture Technique

### Stack Technologique
- **Frontend:** React 18 + Tailwind CSS + Shadcn/UI
- **Backend:** FastAPI (Python) + Motor (MongoDB Async)
- **Base de données:** MongoDB
- **PDF Generation:** ReportLab
- **Time réel:** Polling automatique (3 secondes)

### Structure des Données
```
Meetings: {id, title, organizer_name, meeting_code, status, created_at}
Participants: {id, name, meeting_id, approval_status, joined_at}
Polls: {id, meeting_id, question, options[], status, timer_duration, created_at}
Votes: {id, poll_id, selected_option} // PAS de user_id pour anonymat
```

## 🚀 Installation et Déploiement

### Prérequis
- **Node.js** 18+ et Yarn
- **Python** 3.9+
- **MongoDB** 5.0+
- **System dependencies:** reportlab, motor, fastapi

### 1. Clonage du Projet
```bash
git clone <repository-url>
cd vote-secret
```

### 2. Configuration Backend

#### Installation des dépendances
```bash
cd backend
pip install -r requirements.txt
```

#### Variables d'environnement (`backend/.env`)
```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=vote_secret_db
```

#### Structure requirements.txt
```
fastapi==0.110.1
uvicorn==0.25.0
motor==3.3.1
python-dotenv>=1.0.1
pymongo==4.5.0
pydantic>=2.6.4
reportlab>=4.0.0
python-multipart>=0.0.9
```

### 3. Configuration Frontend

#### Installation des dépendances
```bash
cd frontend
yarn install
```

#### Variables d'environnement (`frontend/.env`)
```env
REACT_APP_BACKEND_URL=https://votre-domaine.com
WDS_SOCKET_PORT=443
```

### 4. Configuration MongoDB

#### Base de données locale
```bash
# Installation MongoDB (Ubuntu/Debian)
sudo apt update
sudo apt install -y mongodb

# Démarrage du service
sudo systemctl start mongodb
sudo systemctl enable mongodb
```

#### Collections créées automatiquement
- `meetings`
- `participants` 
- `polls`
- `votes`

### 5. Déploiement Production

#### Option A: Déploiement Docker (Recommandé)

**Dockerfile Backend**
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8001

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8001"]
```

**Dockerfile Frontend**
```dockerfile
FROM node:18-alpine

WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn install

COPY . .
RUN yarn build

FROM nginx:alpine
COPY --from=0 /app/build /usr/share/nginx/html
EXPOSE 3000
```

**docker-compose.yml**
```yaml
version: '3.8'
services:
  mongodb:
    image: mongo:5.0
    restart: always
    environment:
      MONGO_INITDB_DATABASE: vote_secret_db
    volumes:
      - mongodb_data:/data/db
    ports:
      - "27017:27017"

  backend:
    build: ./backend
    restart: always
    depends_on:
      - mongodb
    environment:
      - MONGO_URL=mongodb://mongodb:27017
      - DB_NAME=vote_secret_db
    ports:
      - "8001:8001"

  frontend:
    build: ./frontend
    restart: always
    depends_on:
      - backend
    environment:
      - REACT_APP_BACKEND_URL=https://votre-domaine.com
    ports:
      - "3000:3000"

volumes:
  mongodb_data:
```

#### Option B: Déploiement Superviseur (serveur Linux)

**Configuration Superviseur (`/etc/supervisor/conf.d/vote-secret.conf`)**
```ini
[program:vote-secret-backend]
command=/usr/bin/python3 -m uvicorn server:app --host 0.0.0.0 --port 8001
directory=/app/backend
user=www-data
autostart=true
autorestart=true
stderr_logfile=/var/log/vote-secret-backend.err.log
stdout_logfile=/var/log/vote-secret-backend.out.log

[program:vote-secret-frontend]
command=/usr/bin/yarn start
directory=/app/frontend
user=www-data
autostart=true
autorestart=true
stderr_logfile=/var/log/vote-secret-frontend.err.log
stdout_logfile=/var/log/vote-secret-frontend.out.log
environment=PORT=3000
```

#### Option C: Déploiement Cloud (Heroku, DigitalOcean, AWS)

**Configuration Nginx (Reverse Proxy)**
```nginx
server {
    listen 80;
    server_name votre-domaine.com;

    # Frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # WebSocket support (si nécessaire)
    location /ws {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 6. Configuration HTTPS (Production)

#### Certificats SSL avec Certbot
```bash
# Installation Certbot
sudo apt install certbot python3-certbot-nginx

# Génération certificat
sudo certbot --nginx -d votre-domaine.com

# Auto-renouvellement
sudo crontab -e
# Ajouter: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 🔧 Configuration Avancée

### Variables d'Environnement Complètes

#### Backend (.env)
```env
# Base de données
MONGO_URL=mongodb://localhost:27017
DB_NAME=vote_secret_db

# Sécurité (optionnel)
SECRET_KEY=your-secret-key-here
CORS_ORIGINS=https://votre-domaine.com

# Logging
LOG_LEVEL=INFO
```

#### Frontend (.env)
```env
# URL Backend (OBLIGATOIRE)
REACT_APP_BACKEND_URL=https://votre-domaine.com

# Configuration WebSocket
WDS_SOCKET_PORT=443

# Build Configuration
GENERATE_SOURCEMAP=false
```

### Sécurité Production

#### 1. Configuration CORS
```python
# backend/server.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://votre-domaine.com"],  # Spécifier le domaine
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)
```

#### 2. Rate Limiting (Recommandé)
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/api/meetings")
@limiter.limit("5/minute")  # 5 créations par minute max
async def create_meeting(request: Request, meeting_data: MeetingCreate):
    # ...
```

#### 3. Monitoring MongoDB
```javascript
// Indexes recommandés
db.meetings.createIndex({ "meeting_code": 1 }, { unique: true })
db.participants.createIndex({ "meeting_id": 1 })
db.polls.createIndex({ "meeting_id": 1 })
db.votes.createIndex({ "poll_id": 1 })
```

## 📚 Guide d'Utilisation

### 1. Flux Organisateur
```
1. Accéder à l'application
2. Cliquer "Créer une réunion"
3. Remplir titre et nom organisateur
4. Noter le code de réunion généré (ex: F231EC4C)
5. Partager le code avec les participants
6. Approuver les participants dans l'onglet "Participants"
7. Créer des sondages dans "Créer un sondage"
8. Lancer les sondages manuellement
9. Voir les résultats en temps réel
10. Télécharger le rapport PDF final (supprime les données)
```

### 2. Flux Participant
```
1. Accéder à l'application
2. Cliquer "Rejoindre une réunion"
3. Saisir nom et code de réunion
4. Attendre l'approbation de l'organisateur
5. Voter sur les sondages actifs
6. Voir les résultats après avoir voté
```

## 🔌 Documentation API

### Endpoints Principaux

#### Meetings
```http
POST /api/meetings
GET /api/meetings/{meeting_code}
GET /api/meetings/{meeting_id}/organizer
GET /api/meetings/{meeting_id}/report
```

#### Participants
```http
POST /api/participants/join
POST /api/participants/{participant_id}/approve
GET /api/participants/{participant_id}/status
```

#### Polls & Votes
```http
POST /api/meetings/{meeting_id}/polls
POST /api/polls/{poll_id}/start
POST /api/polls/{poll_id}/close
POST /api/votes
GET /api/polls/{poll_id}/results
```

### Exemples d'Utilisation

#### Créer une réunion
```bash
curl -X POST "https://votre-domaine.com/api/meetings" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Assemblée Générale 2025",
    "organizer_name": "Jean Dupont"
  }'
```

#### Rejoindre une réunion
```bash
curl -X POST "https://votre-domaine.com/api/participants/join" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Marie Martin",
    "meeting_code": "F231EC4C"
  }'
```

## 🐛 Dépannage

### Problèmes Courants

#### 1. Backend ne démarre pas
```bash
# Vérifier les logs
tail -f /var/log/supervisor/backend.*.log

# Vérifier les dépendances
pip list | grep fastapi
pip list | grep motor
```

#### 2. Frontend ne se connecte pas au backend
```bash
# Vérifier la variable d'environnement
echo $REACT_APP_BACKEND_URL

# Vérifier la connectivité
curl https://votre-domaine.com/api/
```

#### 3. MongoDB inaccessible
```bash
# Vérifier le service
sudo systemctl status mongodb

# Tester la connexion
mongo --eval "db.runCommand('ping')"
```

#### 4. Génération PDF échoue
```bash
# Vérifier ReportLab
python -c "from reportlab.pdfgen import canvas; print('OK')"

# Vérifier les permissions fichier temporaire
ls -la /tmp/
```

### Logs Utiles

#### Monitoring Backend
```bash
# Logs en temps réel
tail -f /var/log/supervisor/backend.out.log

# Erreurs spécifiques
grep -i error /var/log/supervisor/backend.err.log
```

#### Monitoring Frontend
```bash
# Logs React
tail -f /var/log/supervisor/frontend.out.log

# Erreurs de build
yarn build --verbose
```

## 📊 Monitoring et Maintenance

### Métriques Importantes
- Nombre de réunions créées par jour
- Nombre de participants par réunion
- Temps moyen de génération PDF
- Taux d'erreur API

### Sauvegarde MongoDB
```bash
# Sauvegarde quotidienne
mongodump --db vote_secret_db --out /backup/$(date +%Y%m%d)

# Restauration
mongorestore --db vote_secret_db --drop /backup/20250730/vote_secret_db/
```

### Nettoyage Automatique
```python
# Script de nettoyage des réunions anciennes (optionnel)
# À exécuter via cron si besoin de nettoyage automatique
from datetime import datetime, timedelta
from motor.motor_asyncio import AsyncIOMotorClient

async def cleanup_old_meetings():
    # Supprimer les réunions de plus de 30 jours
    cutoff_date = datetime.utcnow() - timedelta(days=30)
    await db.meetings.delete_many({"created_at": {"$lt": cutoff_date}})
```

## 🔐 Sécurité et Conformité

### Protection des Données
- ✅ **Anonymat garanti** - Aucun lien entre participant et vote
- ✅ **Suppression automatique** - Données effacées après rapport
- ✅ **Chiffrement HTTPS** - Communications sécurisées
- ✅ **Validation des entrées** - Protection contre injections

### Conformité RGPD
- Les données personnelles (noms participants) sont supprimées automatiquement
- Pas de cookies de tracking
- Pas de stockage long terme des données personnelles
- Rapport PDF comme seule trace légale des votes

## 📞 Support et Contribution

### Structure du Projet
```
/app/
├── backend/                 # API FastAPI
│   ├── server.py           # Application principale
│   ├── requirements.txt    # Dépendances Python
│   └── .env               # Variables d'environnement
├── frontend/               # Interface React
│   ├── src/
│   │   ├── App.js         # Application principale
│   │   ├── App.css        # Styles
│   │   └── components/ui/ # Composants Shadcn
│   ├── package.json       # Dépendances Node
│   └── .env              # Variables d'environnement
└── README.md             # Documentation
```

### Commandes de Développement
```bash
# Backend (développement)
cd backend && uvicorn server:app --reload --host 0.0.0.0 --port 8001

# Frontend (développement)  
cd frontend && yarn start

# Tests
python backend_test.py

# Build production
cd frontend && yarn build
```

### Licence
MIT License - Voir le fichier LICENSE pour plus de détails.

---

**Vote Secret v1.0.0** - Système de vote anonyme professionnel pour assemblées  
Développé avec ❤️ en France 🇫🇷
