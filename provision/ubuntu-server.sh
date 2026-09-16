#!/usr/bin/env bash
# provision/ubuntu-server.sh
#
# Provisions the "ubuntu-server" target: installs services, creates realistic
# vulnerabilities, and plants the SRV_* flags. Flag values come from the
# generated, git-ignored provision/flags.env (synced at /vagrant/provision/).
#
# This runs as root under Vagrant. It is written to be re-runnable.
set -uo pipefail

log() { echo "[provision:ubuntu-server] $*"; }

# ---------------------------------------------------------------------------
# Load planted flag values (FLAG_SRV_*). Fall back to obvious placeholders so a
# missing flags.env never aborts the build (the scoreboard just won't match).
# ---------------------------------------------------------------------------
FLAGS_ENV="/vagrant/provision/flags.env"
if [ -f "$FLAGS_ENV" ]; then
  # shellcheck disable=SC1090
  source "$FLAGS_ENV"
  log "loaded flags.env"
else
  log "WARNING: $FLAGS_ENV not found — run 'python generate.py' on the host. Using placeholders."
fi

# plant <FLAG_ID> <path> [mode] [owner]  — write the flag value to a file.
plant() {
  local id="$1" path="$2" mode="${3:-644}" owner="${4:-root:root}"
  local var="FLAG_${id}"
  local val="${!var:-}"
  [ -z "$val" ] && val="FLAG{missing_${id}}"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$val" > "$path"
  chmod "$mode" "$path"
  chown "$owner" "$path"
  log "planted $id -> $path"
}

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Packages (best-effort; needs build-time NAT which Vagrant provides by default)
# ---------------------------------------------------------------------------
log "installing packages..."
apt-get update -y >/dev/null 2>&1
apt-get install -y apache2 openssh-server gcc libcap2-bin zip nfs-kernel-server \
                   mysql-server curl netcat-openbsd git >/dev/null 2>&1 || \
  log "WARNING: some packages failed to install (continuing)"

# ===========================================================================
# BASIC (info disclosure / recon)
# ===========================================================================

# SRV_B01 — world-readable file under the web root
plant SRV_B01 /var/www/html/backup/flag.txt 644 www-data:www-data
cat > /var/www/html/robots.txt <<'EOF'
User-agent: *
Disallow: /backup/
EOF

# SRV_B02 — default SSH creds for 'deploy'; flag in home
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
echo 'deploy:deploy' | chpasswd
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true
plant SRV_B02 /home/deploy/flag.txt 644 deploy:deploy

# SRV_B03 — MOTD banner leak
plant SRV_B03 /etc/motd 644 root:root

# SRV_B04 — world-readable creds backup under /opt
plant SRV_B04 /opt/backup/creds.txt 644 root:root

# SRV_B05 — custom TCP banner service on 8081 (systemd + netcat loop)
plant SRV_B05 /opt/bannerd/banner.txt 644 root:root
cat > /opt/bannerd/bannerd.sh <<'EOF'
#!/usr/bin/env bash
# tiny banner service: prints the banner file to any TCP client on 8081
while true; do
  cat /opt/bannerd/banner.txt | nc -l -p 8081 -q 1 >/dev/null 2>&1 || sleep 1
done
EOF
chmod 755 /opt/bannerd/bannerd.sh
cat > /etc/systemd/system/bannerd.service <<'EOF'
[Unit]
Description=CTF banner service (intentionally leaks a version banner)
After=network.target
[Service]
ExecStart=/opt/bannerd/bannerd.sh
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable --now bannerd.service >/dev/null 2>&1 || true

# SRV_B06 — flag in deploy's shell history
plant SRV_B06 /tmp/_srv_b06 644 root:root
{
  echo "ls -la"
  echo "cat /etc/hostname"
  echo "echo $(cat /tmp/_srv_b06)   # oops, pasted a secret"
  echo "history -c"
} > /home/deploy/.bash_history
chown deploy:deploy /home/deploy/.bash_history
chmod 644 /home/deploy/.bash_history
rm -f /tmp/_srv_b06

# SRV_B07 — exposed .git directory under the web root with a committed secret
mkdir -p /var/www/html/.git
plant SRV_B07 /var/www/html/.git/FLAG 644 www-data:www-data
# make it look like a real repo so `git` tooling / browsing finds it
(cd /var/www/html/.git && echo "ref: refs/heads/master" > HEAD 2>/dev/null || true)

# SRV_B08 — flag in a cron comment (world-readable)
SRV_B08_VAL="${FLAG_SRV_B08:-}"; [ -z "$SRV_B08_VAL" ] && SRV_B08_VAL="FLAG{missing_SRV_B08}"
cat > /etc/cron.d/backup-job <<EOF
# Nightly backup job
# NOTE(dev): temporary token for the backup API: ${SRV_B08_VAL}
0 3 * * * root /usr/local/bin/nightly-backup.sh
EOF
chmod 644 /etc/cron.d/backup-job

# ===========================================================================
# MEDIUM (privilege escalation / service misconfig)
# ===========================================================================

# SRV_M01 — sudo NOPASSWD on 'find' (GTFOBins root shell) -> root flag
plant SRV_M01 /root/flag_sudo.txt 600 root:root
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/find' > /etc/sudoers.d/deploy-find
chmod 440 /etc/sudoers.d/deploy-find

# SRV_M02 — custom SUID-root binary that calls `service` via relative PATH
cat > /opt/status.c <<'EOF'
#include <stdlib.h>
int main(void){ setuid(0); setgid(0); system("id > /dev/null; service --status-all"); return 0; }
EOF
gcc /opt/status.c -o /usr/local/bin/status 2>/dev/null && {
  chown root:root /usr/local/bin/status
  chmod 4755 /usr/local/bin/status
} || log "WARNING: could not compile SRV_M02 SUID binary"
plant SRV_M02 /root/flag_suid.txt 600 root:root

# SRV_M03 — world-writable script run by root cron every minute
plant SRV_M03 /root/flag_cron.txt 600 root:root
cat > /opt/maintenance.sh <<'EOF'
#!/usr/bin/env bash
# maintenance task (runs as root via cron)
:
EOF
chmod 777 /opt/maintenance.sh   # intentionally world-writable
echo '* * * * * root /opt/maintenance.sh' > /etc/cron.d/maintenance
chmod 644 /etc/cron.d/maintenance

# SRV_M04 — weak zip password protecting a flag
SRV_M04_VAL="${FLAG_SRV_M04:-}"; [ -z "$SRV_M04_VAL" ] && SRV_M04_VAL="FLAG{missing_SRV_M04}"
echo "$SRV_M04_VAL" > /opt/backup/_secret_plain.txt
chmod 600 /opt/backup/_secret_plain.txt   # the plaintext copy is root-only
(cd /opt/backup && zip -P sunshine secret.zip _secret_plain.txt >/dev/null 2>&1) || \
  log "WARNING: could not create SRV_M04 zip"
chmod 644 /opt/backup/secret.zip 2>/dev/null || true

# SRV_M05 — capability cap_dac_read_search on a copy of an interpreter/tool
plant SRV_M05 /root/flag_cap.txt 600 root:root
cp /usr/bin/tar /usr/local/bin/rtar 2>/dev/null && \
  setcap cap_dac_read_search+ep /usr/local/bin/rtar 2>/dev/null || \
  log "WARNING: could not set SRV_M05 capability"

# SRV_M06 — NFS export with no_root_squash
plant SRV_M06 /srv/nfs/share/flag.txt 644 root:root
echo '/srv/nfs/share 192.168.56.0/24(rw,sync,no_root_squash,no_subtree_check)' > /etc/exports
exportfs -ra >/dev/null 2>&1 || true
systemctl restart nfs-kernel-server >/dev/null 2>&1 || true

# SRV_M07 — MySQL root with empty password + flag in a 'secrets' DB
SRV_M07_VAL="${FLAG_SRV_M07:-}"; [ -z "$SRV_M07_VAL" ] && SRV_M07_VAL="FLAG{missing_SRV_M07}"
mkdir -p /opt/dbseed
cat > /opt/dbseed/mysql_flag.sql <<EOF
CREATE DATABASE IF NOT EXISTS secrets;
USE secrets;
CREATE TABLE IF NOT EXISTS flags (name VARCHAR(64), value VARCHAR(128));
DELETE FROM flags;
INSERT INTO flags VALUES ('server', '${SRV_M07_VAL}');
EOF
systemctl start mysql >/dev/null 2>&1 || true
# force root to use empty-password auth (lab-only, intentionally insecure)
mysql -u root <<'SQL' 2>/dev/null || log "WARNING: could not seed MySQL (SRV_M07)"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';
FLUSH PRIVILEGES;
SQL
mysql -u root < /opt/dbseed/mysql_flag.sql 2>/dev/null || true

# SRV_M08 — sudo rule that keeps PATH, script calls `cat` unqualified
plant SRV_M08 /root/flag_env.txt 600 root:root
cat > /usr/local/bin/readlog <<'EOF'
#!/usr/bin/env bash
cat /var/log/app.log 2>/dev/null   # relative 'cat' — hijackable via PATH
EOF
chmod 755 /usr/local/bin/readlog
cat > /etc/sudoers.d/deploy-readlog <<'EOF'
Defaults!/usr/local/bin/readlog env_keep += "PATH"
deploy ALL=(root) NOPASSWD: /usr/local/bin/readlog
EOF
chmod 440 /etc/sudoers.d/deploy-readlog

# ===========================================================================
# HARD (chained / advanced privesc)
# ===========================================================================

# SRV_H01 — writable systemd unit editable by the 'deploy' group
plant SRV_H01 /root/.hidden/flag_chain.txt 600 root:root
cat > /etc/systemd/system/appworker.service <<'EOF'
[Unit]
Description=App worker (lab: unit file is group-writable — do not do this)
[Service]
ExecStart=/bin/true
[Install]
WantedBy=multi-user.target
EOF
chown root:deploy /etc/systemd/system/appworker.service
chmod 664 /etc/systemd/system/appworker.service   # group-writable
echo 'deploy ALL=(root) NOPASSWD: /bin/systemctl restart appworker, /bin/systemctl daemon-reload' \
  > /etc/sudoers.d/deploy-appworker
chmod 440 /etc/sudoers.d/deploy-appworker

# SRV_H02 — sudo preserves LD_PRELOAD
plant SRV_H02 /root/.hidden/flag_ldpreload.txt 600 root:root
cat > /etc/sudoers.d/deploy-ldpreload <<'EOF'
Defaults env_keep += "LD_PRELOAD"
deploy ALL=(root) NOPASSWD: /usr/bin/apt
EOF
chmod 440 /etc/sudoers.d/deploy-ldpreload

# SRV_H03 — deploy in the docker group (root-equivalent)
plant SRV_H03 /root/.hidden/flag_docker.txt 600 root:root
apt-get install -y docker.io >/dev/null 2>&1 || log "WARNING: docker.io install failed (SRV_H03)"
groupadd -f docker
usermod -aG docker deploy
systemctl enable --now docker >/dev/null 2>&1 || true

# SRV_H04 — leaked API token still valid against local admin API on :8082
SRV_H04_VAL="${FLAG_SRV_H04:-}"; [ -z "$SRV_H04_VAL" ] && SRV_H04_VAL="FLAG{missing_SRV_H04}"
mkdir -p /opt/adminapi
echo "$SRV_H04_VAL" > /opt/adminapi/token_flag.txt
chmod 600 /opt/adminapi/token_flag.txt
# the recoverable token (from .git) that the API accepts
ADMIN_TOKEN="s3cr3t-admin-token-9d0e"
echo "committed token: ${ADMIN_TOKEN}" >> /var/www/html/.git/FLAG
cat > /opt/adminapi/adminapi.py <<EOF
#!/usr/bin/env python3
import http.server, socketserver
TOKEN = "${ADMIN_TOKEN}"
FLAG = open("/opt/adminapi/token_flag.txt").read().strip()
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        auth = self.headers.get("Authorization", "")
        if self.path == "/flag" and auth == "Bearer " + TOKEN:
            self.send_response(200); self.end_headers(); self.wfile.write(FLAG.encode())
        else:
            self.send_response(403); self.end_headers(); self.wfile.write(b"forbidden")
    def log_message(self, *a): pass
socketserver.TCPServer(("0.0.0.0", 8082), H).serve_forever()
EOF
cat > /etc/systemd/system/adminapi.service <<'EOF'
[Unit]
Description=CTF admin API (accepts a leaked bearer token)
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/adminapi/adminapi.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable --now adminapi.service >/dev/null 2>&1 || true

# SRV_H05 — root cron uses tar with a wildcard in a writable dir
plant SRV_H05 /root/.hidden/flag_wildcard.txt 600 root:root
mkdir -p /opt/archive
chmod 777 /opt/archive
echo "seed" > /opt/archive/data.txt
cat > /usr/local/bin/archiver.sh <<'EOF'
#!/usr/bin/env bash
cd /opt/archive && tar czf /opt/archive_backup.tgz * 2>/dev/null
EOF
chmod 755 /usr/local/bin/archiver.sh
echo '*/2 * * * * root /usr/local/bin/archiver.sh' > /etc/cron.d/archiver
chmod 644 /etc/cron.d/archiver

# SRV_H06 — credential reuse: place a private key for deploy that unlocks 'svc'
# on ubuntu-client. The pivot flag itself is planted by ubuntu-client.sh.
mkdir -p /home/deploy/.ssh
cat > /home/deploy/.ssh/id_rsa <<'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
LAB-PLACEHOLDER-KEY-reused-across-hosts-do-not-use-in-production
-----END OPENSSH PRIVATE KEY-----
EOF
cat > /home/deploy/.ssh/config <<'EOF'
Host client
    HostName 192.168.56.31
    User svc
    IdentityFile ~/.ssh/id_rsa
EOF
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/id_rsa

log "provisioning complete."
