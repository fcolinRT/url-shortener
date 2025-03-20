#!/bin/bash
# setup.sh - Setup script for URL shortener

# Exit on error
set -e

echo "========================================"
echo "URL Shortener Setup Script"
echo "========================================"

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "Error: This script must be run as root" 1>&2
   exit 1
fi

# Update system
echo "Updating system packages..."
apt update && apt upgrade -y

# Install dependencies
echo "Installing dependencies..."
apt install -y python3 python3-pip python3-venv nginx supervisor

# Install MongoDB
echo "Installing MongoDB..."
apt install -y gnupg
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
apt update
apt install -y mongodb-org
systemctl start mongod
systemctl enable mongod

# Create app directory
echo "Setting up application directory..."
mkdir -p /var/www/url-shortener
cd /var/www/url-shortener

# Ask for GitHub username
echo "Enter your GitHub username:"
read -r github_username

# Clone the repository
echo "Cloning repository..."
git clone "https://github.com/$github_username/url-shortener.git" .

# Set up Python virtual environment
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p logs backups

# Set up environment file
echo "Setting up environment file..."
cp .env.template .env
echo "Please edit the .env file with your configuration"
echo "Press any key to continue..."
read -n 1

# Set up Supervisor
echo "Setting up Supervisor..."
cat > /etc/supervisor/conf.d/url-shortener.conf <<EOF
[program:url-shortener]
directory=/var/www/url-shortener
command=/var/www/url-shortener/venv/bin/gunicorn -w 4 -b 127.0.0.1:5000 app:app
user=www-data
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stderr_logfile=/var/www/url-shortener/logs/supervisor.err.log
stdout_logfile=/var/www/url-shortener/logs/supervisor.out.log
EOF

# Set up Nginx
echo "Setting up Nginx..."
echo "Enter your domain name (e.g., example.com):"
read -r domain_name

cat > /etc/nginx/sites-available/url-shortener <<EOF
server {
    listen 80;
    server_name $domain_name www.$domain_name;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/url-shortener /etc/nginx/sites-enabled/

# Test Nginx configuration
nginx -t

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/url-shortener

# Restart services
echo "Restarting services..."
supervisorctl reread
supervisorctl update
supervisorctl start url-shortener
systemctl reload nginx

# Set up SSL with Let's Encrypt
echo "Would you like to set up SSL with Let's Encrypt? (y/n)"
read -r setup_ssl

if [ "$setup_ssl" = "y" ]; then
    echo "Installing Certbot..."
    apt install -y certbot python3-certbot-nginx
    
    echo "Setting up SSL for $domain_name..."
    certbot --nginx -d "$domain_name" -d "www.$domain_name"
    
    echo "SSL setup complete!"
fi

# Set up backup script
echo "Setting up backup script..."
cat > /var/www/url-shortener/scripts/backup.sh <<EOF
#!/bin/bash
TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/www/url-shortener/backups"
mkdir -p \$BACKUP_DIR
mongodump --db url_shortener --out \$BACKUP_DIR/\$TIMESTAMP
find \$BACKUP_DIR -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null
EOF

chmod +x /var/www/url-shortener/scripts/backup.sh

# Set up cron job for backup
echo "Setting up daily backup via cron..."
(crontab -l 2>/dev/null; echo "0 2 * * * /var/www/url-shortener/scripts/backup.sh > /var/www/url-shortener/logs/backup.log 2>&1") | crontab -

echo "========================================"
echo "Setup complete!"
echo "========================================"
echo "Your URL shortener is now running at: http://$domain_name"
if [ "$setup_ssl" = "y" ]; then
    echo "Secure access: https://$domain_name"
fi
echo "========================================"
echo "Next steps:"
echo "1. Test your URL shortener by visiting your domain"
echo "2. Monitor logs in /var/www/url-shortener/logs"
echo "3. Update application: cd /var/www/url-shortener && git pull"
echo "4. Restart after updates: supervisorctl restart url-shortener"
echo "========================================"