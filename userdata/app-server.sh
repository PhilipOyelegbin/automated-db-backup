#!/bin/bash

set -e

# --------------------------------------------------------------
# Define Variables
# --------------------------------------------------------------
USERNAME="sysadmin"
PASSWORD="P@ssw0rd123!"

# --------------------------------------------------------------
# Ensure PasswordAuthentication is set to yes in sshd_config
# --------------------------------------------------------------
echo ">>> Updating sshd_config to allow password authentication..."
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

echo ">>> Restarting SSH service..."
if command -v systemctl >/dev/null; then
    systemctl restart sshd
else
    service ssh restart
fi

# --------------------------------------------------------------
# Ensure the user exists
# --------------------------------------------------------------
if id "$USERNAME" &>/dev/null; then
    echo ">>> User $USERNAME already exists."
else
    echo ">>> Creating user $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
fi

echo ">>> Setting password for $${var.username}..."
echo "$USERNAME:$PASSWORD" | chpasswd

echo ">>> Adding $USERNAME to sudo group..."
usermod -aG sudo "$USERNAME"

# --------------------------------------------------------------
# Installing and setting up MongoDB
# --------------------------------------------------------------
echo ">>> Updating package lists..."
apt update && apt upgrade -y
apt install gnupg curl unzip cron -y

echo ">>> Installing MongoDB..."
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
echo "deb [signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
apt update
apt install -y mongodb-org

# --------------------------------------------------------------
# Configure And Restart MongoDB
# --------------------------------------------------------------
echo ">>> Configuring MongoDB to bind to all IP addresses..."
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

echo ">>> Starting MongoDB service..."
systemctl enable mongod
systemctl restart mongod

# --------------------------------------------------------------
# Create MongoDB admin user
# --------------------------------------------------------------
echo ">>> Creating MongoDB admin user..."
mongosh <<-'EOF'
    use araya_db
    db.createUser({user: "admin", pwd: "ar@yA01.", roles: [{ role: "root", db: "admin" }]})
EOF

# --------------------------------------------------------------
# Create Database Seed Script
# --------------------------------------------------------------
echo ">>> Creating database seed script..."
tee /tmp/seed_database.sh > /dev/null <<-'EOF'
    #!/bin/bash

    # --------------------------------------------------------------
    # Execute the mongosh command
    # --------------------------------------------------------------
    echo ">>> Seeding the MongoDB database..."
    mongosh <<-'EOF'
        use araya_db  
        db.users.drop(); 
        db.users.insertMany([
            { name: "Alice", age: 30, status: "active" },
            { name: "Bob", age: 25, status: "inactive" },
            { name: "Charlie", age: 35, status: "active" },
            { name: "Mary", age: 35, status: "active" },
            { name: "John", age: 43, status: "inactive" }
        ])
    EOF

    echo ">>> ✅ Database seeding script executed."
EOF

chmod 740 /tmp/seed_database.sh

echo ">>> Running database seed script..."
bash /tmp/seed_database.sh

# --------------------------------------------------------------
# Create Database Backup and Upload Script
# --------------------------------------------------------------
echo ">>> Creating database backup and upload script"
tee /usr/local/bin/dbbackup_and_upload.sh > /dev/null <<-'EOF'
    #!/bin/bash

    # --------------------------------------------------------------
    # Define variables
    # --------------------------------------------------------------
    MONGO_HOST="localhost"          # MongoDB Host
    MONGO_PORT="27017"              # MongoDB Port
    MONGO_DB="araya_db"   # MongoDB Database Name
    R2_BUCKET_NAME="db-backups"
    R2_ACCOUNT_ID="your_r2_account_id"
    R2_ACCESS_KEY="your_r2_access_key"
    R2_SECRET_KEY="your_r2_secret_key"
    R2_REGION="auto"  # R2 region, typically "auto" is fine.
    BACKUP_DIR="/tmp/mongodb_backup"
    BACKUP_FILE="${BACKUP_DIR}/${MONGO_DB}_$(date +'%Y%m%d%H%M%S').tar.gz"

    # --------------------------------------------------------------
    # MongoDB dump command
    # --------------------------------------------------------------
    echo ">>> Backing up MongoDB database..."
    mkdir -p $BACKUP_DIR

    mongodump --host $MONGO_HOST --port $MONGO_PORT --db $MONGO_DB --out $BACKUP_DIR

    if [ $? -ne 0 ]; then
        echo ">>> MongoDB backup failed!"
        exit 1
    fi

    # --------------------------------------------------------------
    # Compress the backup into a tarball
    # --------------------------------------------------------------
    echo ">>> Compressing backup into tarball..."
    tar -czvf $BACKUP_FILE -C $BACKUP_DIR $MONGO_DB

    if [ $? -ne 0 ]; then
        echo ">>> Compression failed!"
        exit 1
    fi

    # --------------------------------------------------------------
    # Upload to Cloudflare R2 using AWS CLI
    # --------------------------------------------------------------
    echo ">>> Uploading backup to Cloudflare R2..."

    export AWS_ACCESS_KEY_ID=$R2_ACCESS_KEY
    export AWS_SECRET_ACCESS_KEY=$R2_SECRET_KEY
    export AWS_DEFAULT_REGION=$R2_REGION
    export AWS_S3_ENDPOINT_URL="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

    aws s3 cp $BACKUP_FILE s3://$R2_BUCKET_NAME/ --endpoint-url $AWS_S3_ENDPOINT_URL

    if [ $? -ne 0 ]; then
        echo ">>> Upload to Cloudflare R2 failed!"
        exit 1
    fi

    # --------------------------------------------------------------
    # Clean up
    # --------------------------------------------------------------
    echo ">>> Cleaning up backup files..."
    rm -rf $BACKUP_DIR

    echo ">>> ✅ Backup completed and uploaded successfully!"
EOF

chmod 740 /usr/local/bin/dbbackup_and_upload.sh

# --------------------------------------------------------------
# Setup cronjob to run dbbackup_and_upload.sh every 30 minutes
# --------------------------------------------------------------
echo ">>> Setting up cronjob for database backup and upload..."
(crontab -l 2>/dev/null; echo "*/30 * * * * bash /usr/local/bin/dbbackup_and_upload.sh >> /var/log/dbbackup_and_upload.log 2>&1") | crontab - && echo "Cronjob set up successfully."


# --------------------------------------------------------------
# Install AWS CLI for uploading to Cloudflare R2
# --------------------------------------------------------------
echo ">>> Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# --------------------------------------------------------------
# Create Restore Script
# --------------------------------------------------------------
echo ">>> Creating database restore script"
tee /usr/local/bin/restore_latest_backup.sh > /dev/null <<-'EOF'
    #!/bin/bash

    # --------------------------------------------------------------
    # Define Variables
    # --------------------------------------------------------------
    MONGO_HOST="localhost"
    MONGO_PORT="27017"
    MONGO_DB="araya_db"     # Database to restore
    R2_BUCKET="db-backups"
    R2_ACCOUNT_ID="YOUR_ACCOUNT_ID"  # Replace with your R2 account ID
    R2_ACCESS_KEY="your_r2_access_key"
    R2_SECRET_KEY="your_r2_secret_key"
    R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
    DOWNLOAD_DIR="/tmp/mongodb_restore"
    BACKUP_FOLDER_NAME=$(basename "$LATEST_BACKUP" .tar.gz)
    BACKUP_PATH="$DOWNLOAD_DIR/$BACKUP_FOLDER_NAME"
    
    mkdir -p "$DOWNLOAD_DIR"

    # --------------------------------------------------------------
    # Set AWS CLI environment variables
    # --------------------------------------------------------------
    export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY"
    export AWS_DEFAULT_REGION="auto"

    # --------------------------------------------------------------
    # Find the latest backup
    # --------------------------------------------------------------
    echo ">>> Finding the latest backup in R2 bucket $R2_BUCKET..."
    LATEST_BACKUP=$(aws s3 ls "s3://$R2_BUCKET/" --endpoint-url "$R2_ENDPOINT" | sort | tail -n 1 | awk '{print $4}')

    if [ -z "$LATEST_BACKUP" ]; then
        echo ">>> No backups found in R2 bucket!"
        exit 1
    fi

    echo ">>> Latest backup found: $LATEST_BACKUP"

    # --------------------------------------------------------------
    # Download the backup
    # --------------------------------------------------------------
    echo ">>> Downloading backup..."
    aws s3 cp "s3://$R2_BUCKET/$LATEST_BACKUP" "$DOWNLOAD_DIR/$LATEST_BACKUP" --endpoint-url "$R2_ENDPOINT"

    if [ $? -ne 0 ]; then
        echo ">>> Download failed!"
        exit 1
    fi

    # --------------------------------------------------------------
    # Extract the backup
    # --------------------------------------------------------------
    echo ">>> Extracting backup..."
    tar -xzvf "$DOWNLOAD_DIR/$LATEST_BACKUP" -C "$DOWNLOAD_DIR"

    if [ $? -ne 0 ]; then
        echo ">>> Extraction failed!"
        exit 1
    fi

    # --------------------------------------------------------------
    # Restore to MongoDB
    # --------------------------------------------------------------
    echo ">>> Restoring backup to MongoDB database '$MONGO_DB'..."
    mongorestore --host "$MONGO_HOST" --port "$MONGO_PORT" --db "$MONGO_DB" --drop "$BACKUP_PATH/$MONGO_DB"

    if [ $? -ne 0 ]; then
        echo ">>> MongoDB restore failed!"
        exit 1
    fi

    # --------------------------------------------------------------
    # Cleanup
    # --------------------------------------------------------------
    echo ">>> Cleaning up temporary files..."
    rm -rf "$DOWNLOAD_DIR"

    echo ">>> ✅ Restore completed successfully!"
EOF

chmod 740 /usr/local/bin/restore_latest_backup.sh

echo ">>> ✅ MongoDB installation and setup complete."