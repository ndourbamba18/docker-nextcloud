#!/bin/bash
set -e

echo "🚀 Démarrage de Nextcloud sur OpenShift..."

# Récupération de l'UID de l'utilisateur courant (pour OpenShift)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

echo "🔧 Utilisateur: $CURRENT_UID, Groupe: $CURRENT_GID"

# Création des répertoires nécessaires
mkdir -p /var/www/html/data /var/www/html/config /var/www/html/apps2
mkdir -p /var/log/apache2 /var/run/apache2 /var/www/sessions

# Configuration des permissions pour OpenShift
echo "📁 Configuration des permissions..."
chgrp -R 0 /var/www/html /var/log/apache2 /var/run/apache2 /var/www/sessions
chmod -R g=u /var/www/html /var/log/apache2 /var/run/apache2 /var/www/sessions
chmod -R 775 /var/www/html/data /var/www/html/config /var/www/html/apps2 /var/www/sessions
chmod 777 /var/log/apache2 /var/run/apache2

# Configuration de PHP pour utiliser notre dossier sessions personnalisé
if [ -f "/etc/php/8.3/cli/php.ini" ]; then
    sed -i 's|^;session.save_path = "/tmp"|session.save_path = "/var/www/sessions"|' /etc/php/8.3/cli/php.ini
fi

if [ -f "/etc/php/8.3/apache2/php.ini" ]; then
    sed -i 's|^;session.save_path = "/tmp"|session.save_path = "/var/www/sessions"|' /etc/php/8.3/apache2/php.ini
fi

# Vérification si c'est une première installation
if [ ! -f /var/www/html/config/config.php ]; then
    echo "⚠️  Nextcloud n'est pas configuré. Une installation manuelle sera nécessaire."
    echo "📝 Le fichier config.php sera créé lors de la première configuration via l'interface web."
    
    # S'assurer que le dossier config est accessible en écriture
    touch /var/www/html/config/.ocdata
    chmod 775 /var/www/html/config/.ocdata
fi

# Vérification de la capacité d'écriture
if [ -w "/var/www/html/config" ]; then
    echo "✅ Le dossier config est accessible en écriture"
else
    echo "❌ ATTENTION: Le dossier config n'est pas accessible en écriture"
    ls -la /var/www/html/
fi

# Démarrage d'Apache
echo "✅ Configuration terminée, démarrage d'Apache..."
exec "$@"