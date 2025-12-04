# Automated DB Backups

**Instruction**: Setup a scheduled workflow to backup a Database every 30 minutes

**Project Goals**: The goal of this project is to setup a scheduled workflow to backup a Database every 30 minutes and upload the backup to **Cloudflare R2** which has a free tier for storage.

---

## Requirements

The pre-requisite for this project is to have a server setup and a database ready to backup.

- Setup a server on Digital Ocean or any other provider
- Run a MongoDB instance on the server
- Seed some data to the database

Once you have a server and a database ready, you can proceed to the next step.

**Scheduled Backups**

You can do this bit either by setting up a cron job on the server or alternatively setup a scheduled workflow in Github Actions that runs every 30 minutes and execute the backup from there. Database should be backedup up into a tarball and uploaded to Clouodflare R2.

Hint: You can use the `mongodump` to dump the database and then use `aws cli` to upload the file to R2.

**Stretch Goal**

Write a script to download the latest backup from R2 and restore the database.

> Database backups are essential to ensure that you can restore your data in case of a disaster. This project will give you hands on experience on how to setup a scheduled workflow to backup a database and how to restore it from a backup.

---

## Project Deliverables

1. **Project Setup**

   - Clone the repo to your local machine

   ```bash
   git clone https://github.com/PhilipOyelegbin/automated-db-backups

   cd automated-db-backups
   ```

2. **Server Orchestration And Configuration**

   - Generate a SSH key which will be needed to access the servers using the command `ssh-keygen -t rsa -b 4096 -f id_rsa -N ""`.
   - Run the commands below to provision the infrastructure.

   ```bash
   terraform init

   terraform apply
   ```

3. **Data Update**

   - SSH into the app server via the bastion host and update the variales in the scripts `dbbackup_and_upload.sh` and `restore_latest_backup.sh` to the right data.

4. **Check Seeded Data**

   - Using a database client, check if seeded data exist on the daabase using the details user: `admin`, password: `ar@yA01.` and database: `araya_db` to login.

5. **Database Backup and Recovery**

   - Wait for 30 minutes for the first backup to take place. Check your R2 storage on cludlfare for the uploaded backup
   - Add a new data to the database before the next 30 minutes and wait for the second uplaoaded backup.
   - Delete some data from the database using the database client and run the restoration script sing the command `sudo bash /usr/local/bin/restore_latest_backup.sh` to restore the latest backup
   - Refresh your database client to confirm the lost data has been restored.

---

## Tools and Technologies

- **Operating Systems**: Amazon Linux 2023, Debian 13
- **Database**: MongoDB
- **Backup Tools**: tar
- **Security Tools**: SSH, Security Group
- **Version Control**: Git (for documenting and tracking configuration changes)

---

## Success Criteria

- All servers are configured, optimized, and secured.
- Demonstrated troubleshooting and resolution of at least three system issues.
- Successful recovery from a simulated disaster using database backup files.
- Clear and comprehensive documentation of the entire process.

---

## Conclusion
