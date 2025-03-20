#!/bin/bash
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/www/url-shortener/backups"
mkdir -p $BACKUP_DIR
mongodump --db url_shortener --out $BACKUP_DIR/$TIMESTAMP
find $BACKUP_DIR -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null