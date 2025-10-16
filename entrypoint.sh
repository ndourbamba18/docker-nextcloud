#!/bin/bash
set -e

echo "🚀 Démarrage de Nextcloud sur OpenShift..."

# Récupération de l'UID de l'utilisateur courant (pour OpenShift)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)
CURRENT_USER=$(whoami)

echo "🔧 Utilisateur: $CURRENT_UID($CURRENT_USER), Groupe: $CURRENT_GID"

# Création des répertoires nécessaires
echo "📁 Création des répertoires..."
mkdir -p /var/www/html/data /var/www/html/config /var/www/html/apps2
mkdir -p /var/log/apache2 /var/run/apache2 /var/www/sessions /tmp/apache2

# Configuration CRITIQUE des permissions pour OpenShift
echo "🔐 Configuration des permissions pour OpenShift..."

# Donner la propriété à l'utilisateur courant (UID arbitraire d'OpenShift)
chown -R $CURRENT_UID:0 /var/www/html /var/www/sessions /var/log/apache2 /var/run/apache2 /tmp/apache2

# Permissions complètes pour l'utilisateur et le groupe
chmod -R 775 /var/www/html /var/www/sessions
chmod -R 777 /var/log/apache2 /var/run/apache2 /tmp/apache2

# Permissions spécifiques pour les dossiers critiques de Nextcloud
chmod 777 /var/www/html/data /var/www/html/config /var/www/html/apps2
chmod 777 /var/www/html

# Vérification des permissions
echo "📋 Vérification des permissions:"
ls -la /var/www/html/
echo "---"
ls -la /var/www/html/config/

# Configuration de PHP pour utiliser notre dossier sessions personnalisé
echo "⚙️ Configuration PHP..."
if [ -f "/etc/php/8.3/cli/php.ini" ]; then
    sed -i 's|^;session.save_path = "/tmp"|session.save_path = "/var/www/sessions"|' /etc/php/8.3/cli/php.ini
    echo "session.save_path = /var/www/sessions" >> /etc/php/8.3/cli/php.ini
fi

if [ -f "/etc/php/8.3/apache2/php.ini" ]; then
    sed -i 's|^;session.save_path = "/tmp"|session.save_path = "/var/www/sessions"|' /etc/php/8.3/apache2/php.ini
    echo "session.save_path = /var/www/sessions" >> /etc/php/8.3/apache2/php.ini
fi

# Test d'écriture critique
echo "🧪 Test d'écriture dans /var/www/html/config..."
if touch /var/www/html/config/test_write.txt 2>/dev/null; then
    echo "✅ Test d'écriture réussi dans /var/www/html/config"
    rm -f /var/www/html/config/test_write.txt
else
    echo "❌ Échec du test d'écriture dans /var/www/html/config"
    # Tentative de correction d'urgence
    chmod 777 /var/www/html/config
fi

# Vérification si c'est une première installation
if [ ! -f /var/www/html/config/config.php ]; then
    echo "⚠️  Nextcloud n'est pas configuré. Création de la structure initiale..."
    
    # Créer le fichier .ocdata pour indiquer que Nextcloud est installé
    touch /var/www/html/config/.ocdata
    chmod 666 /var/www/html/config/.ocdata
    
    # Créer un config.php vide avec les bonnes permissions
    touch /var/www/html/config/config.php
    chmod 666 /var/www/html/config/config.php
    
    echo "📝 Fichiers de configuration créés avec permissions 666"
fi

# Vérification finale des capacités d'écriture
echo "🔍 Vérification finale des permissions:"
ls -la /var/www/html/config/

# Démarrer Apache en tant qu'utilisateur arbitraire
echo "✅ Démarrage d'Apache avec l'utilisateur $CURRENT_UID..."
exec "$@"
