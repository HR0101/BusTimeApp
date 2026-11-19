#!/bin/sh
# Run as root on the Ubuntu 24.04 Lightsail host, after verifying ubuntu SSH access.
set -eu
test "$(id -u)" -eq 0
command -v unattended-upgrade >/dev/null
install -d -m 755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/00-bustime.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
LoginGraceTime 30
EOF
chmod 644 /etc/ssh/sshd_config.d/00-bustime.conf
/usr/sbin/sshd -t
systemctl reload ssh
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
chmod 644 /etc/apt/apt.conf.d/20auto-upgrades
systemctl enable --now unattended-upgrades
echo 'SSH hardening and automatic security updates enabled.'
