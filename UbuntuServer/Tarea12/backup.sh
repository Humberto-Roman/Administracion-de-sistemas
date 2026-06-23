#!/bin/sh
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/backups/mail_backup_$TIMESTAMP.tar.gz"
tar -czf "$BACKUP_FILE" -C /var/mail .
echo "Backup: $BACKUP_FILE"
find /backups -name "mail_backup_*.tar.gz" -mtime +7 -delete