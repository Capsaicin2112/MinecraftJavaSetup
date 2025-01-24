#!/bin/bash

# 0) Save the hostname of the server to a variable
hostname=$(hostname)
echo "Hostname: $hostname"

# Define variables to be passed to the backup script
backup_dir="/root/backups"
sftp_password="{FILL IN}"
sftp_user="{FILL IN}"
sftp_host="{FILL IN}"
sftp_path="/{FILL IN}/$hostname"

# 1) Install required packages
apt update && apt install -y curl screen zip sshpass

# 2) Create /root/backups folder if it doesn't exist
if [ ! -d "$backup_dir" ]; then
  mkdir -p "$backup_dir"
  echo "Backup directory created: $backup_dir"
else
  echo "Backup directory already exists: $backup_dir"
fi

# 3) Create the run_backup.sh script
backup_script="/root/run_backup.sh"
cat << EOF > "$backup_script"
#!/bin/bash

# Variables passed from the parent script
backup_dir="$backup_dir"
hostname="$hostname"
sftp_password="$sftp_password"
sftp_user="$sftp_user"
sftp_host="$sftp_host"
sftp_path="$sftp_path"

# Create a tarball of the "world" directory
backupfilename="\$backup_dir/\$(date +%Y.%m.%d.%H.%M.%S).tar.gz"
tar -pzvcf "\$backupfilename" world

# Transfer backup to SFTP site
sshpass -p "\$sftp_password" sftp \$sftp_user@\$sftp_host:\$sftp_path <<< \$'put '\$backupfilename''

# Keep only the latest 3 backup files
ls -tp "\$backup_dir" | grep -v '/\$' | tail -n +4 | xargs -I {} rm -- "\$backup_dir/{}"
EOF

chmod 744 "$backup_script"
echo "Backup script created: $backup_script"

# 4) Update crontab to run the backup script at 4am every day
cron_job="0 4 * * * $backup_script"
(crontab -l 2>/dev/null; echo "$cron_job") | crontab -
echo "Crontab updated to run backup script at 4am daily."

# 5) Check for a *server*.jar file in the current directory
filetorun=$(ls *server*.jar 2>/dev/null | head -n 1)
if [ -n "$filetorun" ]; then
  echo "Server jar file found: $filetorun"
else
  echo "No server jar file found in the current directory."
  exit 1
fi

# 6) Create the screen_minecraft.sh script
screen_script="/root/screen_minecraft.sh"
cat << EOF > "$screen_script"
#!/bin/bash

# Run the Minecraft server in a screen session
screen -dmS minecraft java -Xms1G -Xmx2G -jar $filetorun nogui
EOF

chmod 744 "$screen_script"
echo "Minecraft screen script created: $screen_script"

# Summary
echo "Setup completed successfully."
