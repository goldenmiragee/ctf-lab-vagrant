#!/usr/bin/env bash
# provision/ubuntu-client.sh
#
# Provisions the "ubuntu-client" workstation: local users, misconfigurations,
# and privilege-escalation paths. Plants the CLI_* flags plus the SRV_H06 pivot
# flag (reached from ubuntu-server via reused credentials).
#
# Runs as root under Vagrant; written to be re-runnable.
set -uo pipefail

log() { echo "[provision:ubuntu-client] $*"; }

FLAGS_ENV="/vagrant/provision/flags.env"
if [ -f "$FLAGS_ENV" ]; then
  # shellcheck disable=SC1090
  source "$FLAGS_ENV"; log "loaded flags.env"
else
  log "WARNING: $FLAGS_ENV not found — run 'python generate.py' on the host. Using placeholders."
fi

plant() {
  local id="$1" path="$2" mode="${3:-644}" owner="${4:-root:root}"
  local var="FLAG_${id}"; local val="${!var:-FLAG{missing_${id}}}"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$val" > "$path"; chmod "$mode" "$path"; chown "$owner" "$path"
  log "planted $id -> $path"
}
val_of() { local var="FLAG_$1"; echo "${!var:-FLAG{missing_$1}}"; }

export DEBIAN_FRONTEND=noninteractive
log "installing packages..."
apt-get update -y >/dev/null 2>&1
apt-get install -y openssh-server gcc libimage-exiftool-perl imagemagick openssl \
                   cron sudo >/dev/null 2>&1 || log "WARNING: some packages failed"

# --- users -----------------------------------------------------------------
id alice >/dev/null 2>&1 || useradd -m -s /bin/bash alice
echo 'alice:password123' | chpasswd
id bob >/dev/null 2>&1 || useradd -m -s /bin/bash bob
echo 'bob:sunshine2021' | chpasswd
id svc >/dev/null 2>&1 || useradd -m -s /bin/bash svc
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true

# ===========================================================================
# BASIC
# ===========================================================================

# CLI_B01 — plaintext desktop note
plant CLI_B01 /home/alice/Desktop/notes.txt 644 alice:alice

# CLI_B02 — weak password; flag in home
plant CLI_B02 /home/alice/flag.txt 644 alice:alice

# CLI_B03 — flag hidden in EXIF Comment of a JPEG
mkdir -p /home/alice/Pictures
if convert -size 48x48 xc:skyblue /home/alice/Pictures/vacation.jpg 2>/dev/null && \
   exiftool -overwrite_original -Comment="$(val_of CLI_B03)" /home/alice/Pictures/vacation.jpg >/dev/null 2>&1; then
  log "embedded CLI_B03 into EXIF"
else
  # fallback: keep the flag discoverable if imagemagick/exiftool unavailable
  plant CLI_B03 /home/alice/Pictures/vacation_comment.txt 644 alice:alice
  log "WARNING: EXIF embed failed for CLI_B03, used fallback file"
fi
chown -R alice:alice /home/alice/Pictures

# CLI_B04 — base64-encoded flag inside a config dotfile
mkdir -p /home/alice/.config/app
B64="$(printf '%s' "$(val_of CLI_B04)" | base64 -w0)"
cat > /home/alice/.config/app/settings.conf <<EOF
[app]
theme = dark
# legacy backup key (base64):
backup_key = ${B64}
EOF
chown -R alice:alice /home/alice/.config

# CLI_B05 — whitespace/zero-width stego in a seemingly empty file
python3 - "$(val_of CLI_B05)" <<'PY'
import sys
flag = sys.argv[1]
# encode each char's bits as space(0)/tab(1), prefixed by a blank-looking line
bits = ''.join(format(ord(c), '08b') for c in flag)
hidden = ''.join(' ' if b == '0' else '\t' for b in bits)
with open('/tmp/empty.txt', 'w') as f:
    f.write('\n' + hidden + '\n')
PY
chmod 644 /tmp/empty.txt

# CLI_B06 — "browser saved" plaintext credentials
mkdir -p /home/alice/creds
cat > /home/alice/creds/logins.txt <<EOF
site,username,password
http://intranet.local,alice,$(val_of CLI_B06)
EOF
chown -R alice:alice /home/alice/creds

# CLI_B07 — world-readable hidden file at filesystem root
plant CLI_B07 /.hidden_flag 644 root:root

# CLI_B08 — flag leaked into a log + the systemd journal
plant CLI_B08 /var/log/ctf-seed.log 644 root:root
logger -t ctf "seed marker: $(val_of CLI_B08)" 2>/dev/null || true

# ===========================================================================
# MEDIUM
# ===========================================================================

# CLI_M01 — sudo to an editor (GTFOBins shell escape) -> root flag
plant CLI_M01 /root/flag_editor.txt 600 root:root
echo 'alice ALL=(root) NOPASSWD: /usr/bin/vim' > /etc/sudoers.d/alice-vim
chmod 440 /etc/sudoers.d/alice-vim

# CLI_M02 — group-writable root script run via root cron
plant CLI_M02 /root/flag_group.txt 600 root:root
groupadd -f devs
usermod -aG devs alice
cat > /usr/local/bin/collect-metrics.sh <<'EOF'
#!/usr/bin/env bash
:
EOF
chown root:devs /usr/local/bin/collect-metrics.sh
chmod 775 /usr/local/bin/collect-metrics.sh   # group-writable by 'devs'
echo '* * * * * root /usr/local/bin/collect-metrics.sh' > /etc/cron.d/metrics
chmod 644 /etc/cron.d/metrics

# CLI_M03 — bob's private key readable by others -> ssh to bob
plant CLI_M03 /home/bob/flag.txt 640 bob:bob
mkdir -p /home/bob/.ssh
sudo -u bob ssh-keygen -t rsa -b 2048 -N '' -f /home/bob/.ssh/id_rsa >/dev/null 2>&1 || \
  ssh-keygen -t rsa -b 2048 -N '' -f /home/bob/.ssh/id_rsa >/dev/null 2>&1
cat /home/bob/.ssh/id_rsa.pub >> /home/bob/.ssh/authorized_keys 2>/dev/null || true
chown -R bob:bob /home/bob/.ssh
chmod 700 /home/bob/.ssh
chmod 644 /home/bob/.ssh/authorized_keys 2>/dev/null || true
chmod 644 /home/bob/.ssh/id_rsa            # intentionally world-readable private key

# CLI_M04 — bob's user cron runs a script alice can write
plant CLI_M04 /home/bob/.secret/flag_cron.txt 600 bob:bob
cat > /home/bob/run-sync.sh <<'EOF'
#!/usr/bin/env bash
:
EOF
chown alice:alice /home/bob/run-sync.sh   # bob runs it, but alice owns/can edit it
chmod 755 /home/bob/run-sync.sh
echo '* * * * * /home/bob/run-sync.sh' | crontab -u bob - 2>/dev/null || true

# CLI_M05 — readable /etc/shadow backup with bob's crackable hash
# (answer is bob's PASSWORD 'sunshine2021', recovered by cracking the hash)
BOB_HASH="$(openssl passwd -6 sunshine2021 2>/dev/null || echo '!')"
cat > /var/backups/shadow.bak <<EOF
root:*:19000:0:99999:7:::
bob:${BOB_HASH}:19000:0:99999:7:::
EOF
chmod 644 /var/backups/shadow.bak   # backups should be root-only; here they aren't

# CLI_M06 — polkit rule allowing a privileged action -> root flag
plant CLI_M06 /root/flag_polkit.txt 600 root:root
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-ctf.rules <<'EOF'
// Lab misconfiguration: grant members of 'devs' broad privileged actions.
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("devs")) { return polkit.Result.YES; }
});
EOF
chmod 644 /etc/polkit-1/rules.d/49-ctf.rules

# CLI_M07 — writable dir in root's cron PATH; script calls a command unqualified
plant CLI_M07 /root/flag_pathcron.txt 600 root:root
mkdir -p /usr/local/games
chmod 777 /usr/local/games   # writable dir that sits in root's PATH
cat > /etc/cron.d/rootpath <<'EOF'
PATH=/usr/local/games:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
* * * * * root backup >/dev/null 2>&1
EOF
chmod 644 /etc/cron.d/rootpath

# ===========================================================================
# HARD
# ===========================================================================

# CLI_H01 — unprivileged user namespaces enabled (privesc primitive present).
# ponytail: simplified — we set the condition + plant the flag rather than ship a
# full kernel exploit. Upgrade path: pair with a known vulnerable setuid helper.
plant CLI_H01 /root/.hidden/flag_userns.txt 600 root:root
sysctl -w kernel.unprivileged_userns_clone=1 >/dev/null 2>&1 || true
echo 'kernel.unprivileged_userns_clone=1' > /etc/sysctl.d/99-userns.conf

# CLI_H02 — real TOCTOU: setuid helper checks then opens a predictable temp path
plant CLI_H02 /root/.hidden/flag_race.txt 600 root:root
cat > /opt/toctou.c <<'EOF'
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
/* Vulnerable: access()-then-open() on a predictable path (classic TOCTOU). */
int main(void){
    const char *p = "/tmp/toctou_input";
    if (access(p, R_OK) == 0) {          /* time-of-check */
        sleep(1);                        /* race window */
        setuid(0); setgid(0);
        char cmd[256];
        snprintf(cmd, sizeof cmd, "cat %s", p);  /* time-of-use */
        system(cmd);
    }
    return 0;
}
EOF
gcc /opt/toctou.c -o /usr/local/bin/toctou 2>/dev/null && {
  chown root:root /usr/local/bin/toctou; chmod 4755 /usr/local/bin/toctou;
} || log "WARNING: could not compile CLI_H02 helper"

# CLI_H03 — real format-string bug in a setuid binary that holds the flag in memory
plant CLI_H03 /root/.hidden/flag_fmt.txt 600 root:root
cat > /opt/fmt.c <<'EOF'
#include <stdio.h>
#include <string.h>
#include <unistd.h>
/* Vulnerable: user input passed straight to printf as the format string.
   The root-only flag is read into a stack buffer, leakable via %s/%p. */
int main(int argc, char **argv){
    char flag[128] = {0};
    FILE *f = fopen("/root/.hidden/flag_fmt.txt", "r");
    if (f){ fgets(flag, sizeof flag, f); fclose(f); }
    if (argc > 1){ printf(argv[1]); printf("\n"); }
    return 0;
}
EOF
gcc -fno-stack-protector /opt/fmt.c -o /usr/local/bin/fmtinfo 2>/dev/null && {
  chown root:root /usr/local/bin/fmtinfo; chmod 4755 /usr/local/bin/fmtinfo;
} || log "WARNING: could not compile CLI_H03 helper"

# CLI_H04 — sudo token / permissive ptrace (privesc primitive present).
# ponytail: simplified — we relax ptrace_scope and plant the flag; a full session-
# token hijack requires an active sudo session to steal. Upgrade path: scripted victim.
plant CLI_H04 /root/.hidden/flag_token.txt 600 root:root
sysctl -w kernel.yama.ptrace_scope=0 >/dev/null 2>&1 || true
echo 'kernel.yama.ptrace_scope=0' > /etc/sysctl.d/99-ptrace.conf

# CLI_H05 — flag split into 3 XOR shares; recombining them yields the flag
python3 - "$(val_of CLI_H05)" <<'PY'
import os, sys
flag = sys.argv[1].encode()
os.makedirs('/opt/parts', exist_ok=True)
a = os.urandom(len(flag))
b = os.urandom(len(flag))
c = bytes(f ^ x ^ y for f, x, y in zip(flag, a, b))   # a ^ b ^ c == flag
open('/opt/parts/a.bin','wb').write(a)
open('/opt/parts/b.bin','wb').write(b)
open('/opt/parts/c.bin','wb').write(c)
# root-only solution copy for grading
open('/opt/parts/_solution.txt','w').write(sys.argv[1] + "\n")
PY
chmod 644 /opt/parts/a.bin /opt/parts/b.bin /opt/parts/c.bin 2>/dev/null || true
chmod 600 /opt/parts/_solution.txt 2>/dev/null || true

# ---------------------------------------------------------------------------
# SRV_H06 — pivot target: 'svc' flag reachable from ubuntu-server's reused key
# ---------------------------------------------------------------------------
plant SRV_H06 /home/svc/flag_pivot.txt 640 svc:svc

log "provisioning complete."
