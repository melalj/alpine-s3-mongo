# 🗄️ alpine-s3-mongo

A lightweight Alpine Linux Docker image for MongoDB backup and restore operations using AWS S3 with intelligent retention policies.

## ✨ Features

- **🔄 Automated Backups**: Create compressed MongoDB backups and upload to S3
- **📥 Flexible Restore**: Restore from latest backup or specific versions
- **🧹 Smart Retention**: Intelligent backup rotation (hourly/daily/weekly/monthly)
- **📋 Version Management**: List and browse all available backup versions
- **🐳 Lightweight**: Based on Alpine Linux for minimal image size
- **☁️ S3 Native**: Full AWS S3 integration with versioning support

## 🚀 Quick Start

1. **Create your environment file**:

```bash
cp .env.example .env
# Edit .env with your settings
```

2. **Run a backup**:

```bash
docker run -it --rm --env-file .env $(docker build -q .) bash /backup.sh
```

3. **List available versions**:

```bash
docker run -it --rm --env-file .env $(docker build -q .) bash /list-versions.sh
```

4. **Restore latest backup**:

```bash
docker run -it --rm --env-file .env $(docker build -q .) bash /restore.sh
```

## 📋 Scripts

| Script | Purpose | Description |
|--------|---------|-------------|
| `backup.sh` | 💾 Backup | Creates compressed MongoDB dump and uploads to S3 |
| `restore.sh` | 📥 Restore | Downloads and restores MongoDB from S3 backup |
| `thin.sh` | 🧹 Cleanup | Applies retention policy to remove old backups |
| `list-versions.sh` | 📋 Browse | Lists all available backup versions with timestamps |

## ⚙️ Environment Variables

### 🔐 AWS S3 Configuration

```bash
AWS_ACCESS_KEY_ID=AKIA...           # Your AWS access key
AWS_SECRET_ACCESS_KEY=wJa...        # Your AWS secret key  
AWS_DEFAULT_REGION=us-east-1        # AWS region for your S3 bucket
S3_BUCKET=my-mongo-backups          # S3 bucket name
```

### 💾 Backup Settings

```bash
BACKUP_ARCHIVE_NAME=myapp.gz        # Name for backup file
BACKUP_MONGODB_URI=mongodb://user:pass@host:27017  # MongoDB connection string
BACKUP_AUTH_DB_NAME=admin           # Authentication database
BACKUP_DB_NAME=myapp                # Database to backup
BACKUP_EXTRA_PARAMS=                # Additional mongodump parameters
BACKUP_EXTRA_FLAGS=--excludeCollection=logs  # Extra mongodump flags
```

### 📥 Restore Settings

```bash
RESTORE_ARCHIVE_NAME=myapp.gz       # Backup file to restore
RESTORE_MONGODB_URI=mongodb://user:pass@host:27017  # Target MongoDB
RESTORE_AUTH_DB_NAME=admin          # Authentication database
RESTORE_DB_NAME=myapp               # Target database name
RESTORE_EXTRA_PARAMS=               # Additional mongorestore parameters
RESTORE_EXTRA_FLAGS=--drop          # Extra mongorestore flags (e.g., --drop)
RESTORE_VERSION_ID=                 # Optional: specific S3 version ID
```

### 🧹 Retention Policy

```bash
THIN_ARCHIVE_NAME=myapp.gz          # Archive to apply retention policy to
KEEP_HOURLY_FOR_IN_HOURS=24         # Keep hourly backups for 24 hours
KEEP_DAILY_FOR_IN_DAYS=30           # Keep daily backups for 30 days  
KEEP_WEEKLY_FOR_IN_WEEKS=52         # Keep weekly backups for 52 weeks
KEEP_MONTHLY_FOR_IN_MONTHS=60       # Keep monthly backups for 60 months
```

## 🎯 Usage Examples

### Basic Backup & Restore

```bash
# Create a backup
docker run -it --rm --env-file .env $(docker build -q .) bash /backup.sh

# Restore the latest backup
docker run -it --rm --env-file .env $(docker build -q .) bash /restore.sh
```

### Version-Specific Restore

```bash
# 1. List all available versions
docker run -it --rm --env-file .env $(docker build -q .) bash /list-versions.sh

# 2. Copy the desired VersionId from the output
# 3. Restore specific version
RESTORE_VERSION_ID=your-version-id-here \
  docker run -it --rm --env-file .env $(docker build -q .) bash /restore.sh
```

### Automated Cleanup

```bash
# Apply retention policy (run after backups)
docker run -it --rm --env-file .env $(docker build -q .) bash /thin.sh
```

### Scheduled Backups

```bash
# Add to crontab for daily backups at 2 AM
0 2 * * * docker run --rm --env-file /path/to/.env $(docker build -q /path/to/repo) bash /backup.sh
```

## 🔧 Advanced Configuration

### Custom MongoDB Parameters

```bash
# Exclude specific collections
BACKUP_EXTRA_FLAGS="--excludeCollection=logs --excludeCollection=cache"

# Include only specific collections  
BACKUP_EXTRA_FLAGS="--collection=users --collection=orders"

# Custom authentication
BACKUP_EXTRA_PARAMS="--authenticationMechanism=SCRAM-SHA-256"
```

### S3 Bucket Versioning

⚠️ **Important**: Enable versioning on your S3 bucket for the `thin.sh` script to work properly:

```bash
aws s3api put-bucket-versioning \
  --bucket your-bucket-name \
  --versioning-configuration Status=Enabled
```

## 🐳 Docker Compose Example

```yaml
version: '3.8'
services:
  mongo-backup:
    build: .
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_DEFAULT_REGION=us-east-1
      - S3_BUCKET=my-mongo-backups
      - BACKUP_ARCHIVE_NAME=myapp.gz
      - BACKUP_MONGODB_URI=mongodb://mongo:27017
      - BACKUP_DB_NAME=myapp
    command: bash /backup.sh
    depends_on:
      - mongo
      
  mongo:
    image: mongo:7
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: password
```

## 🔍 Troubleshooting

### Common Issues

**Build fails**: Make sure you're using Alpine Edge for latest packages
**AWS authentication fails**: Verify your AWS credentials and region
**MongoDB connection fails**: Check your MongoDB URI and network connectivity
**S3 upload fails**: Ensure your AWS user has S3 write permissions

### Debug Mode

```bash
# Run with verbose output
docker run -it --rm --env-file .env $(docker build -q .) bash -x /backup.sh
```

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
