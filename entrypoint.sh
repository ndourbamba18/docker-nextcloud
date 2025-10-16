#!/bin/bash
set -e

echo "🚀 Lancement de Nextcloud..."

# UID/GID dynamiques (OpenShift)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)
echo "🔧 UID=$CURRENT_UID, GID=$CURRENT_GID"

# Répertoires requis
mkdir -p /var/www/html/data /var/www/html/config /var/www/html/apps2
mkdir -p /var/www/sessions /var/log/apache2 /var/run/apache2

# Permissions globales (pour UID dynamique)
echo "📁 Application des permissions..."
chgrp -R 0 /var/www/html /var/www /var/log/apache2 /var/run/apache2 /var/www/sessions
chmod -R g=u /var/www/html /var/www /var/log/apache2 /var/run/apache2 /var/www/sessions
chmod -R 775 /var/www/html /var/www/sessions
chmod 777 /var/log/apache2 /var/run/apache2

# Vérification du dossier config
if [ ! -f /var/www/html/config/config.php ]; then
    echo "⚠️  Fichier config.php introuvable — première installation."
    touch /var/www/html/config/.ocdata
    chmod 775 /var/www/html/config /var/www/html/config/.ocdata
else
    echo "✅ Fichier config.php détecté."
fi

# Vérifier si le dossier est bien accessible
if [ -w "/var/www/html/config" ]; then
    echo "✅ Le dossier /var/www/html/config est accessible en écriture."
else
    echo "❌ Le dossier /var/www/html/config n'est PAS accessible !"
    ls -ld /var/www/html/config
fi

echo "✅ Démarrage d'Apache..."
exec "$@"
