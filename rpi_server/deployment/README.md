# Raspberry Pi deployment guide

Target hardware: Raspberry Pi 4B (4 GB or more), Raspberry Pi OS 64-bit
(Bookworm), Python 3.11+, MySQL 8.0, MongoDB 7.0 and Nginx.

This guide installs MySQL 8.0 from Oracle's ARM64 generic tarball because the
Oracle MySQL APT repository does not publish a `bookworm` ARM64 package.
`apt install mysql-server` on Debian Bookworm installs MariaDB, which is not the
database required by this project.

## 1. Prepare the operating system

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-venv python3-pip nginx git curl gnupg \
    libaio1 libnuma1
```

Keep the Pi on a static DHCP lease or give it a fixed LAN address. All examples
below use `192.168.1.42`; replace it with the address of your Pi.

## 2. Install MySQL 8.0 on ARM64

```bash
cd /tmp
curl -fLO https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.46-linux-glibc2.28-aarch64.tar.xz
sudo mkdir -p /opt/mysql
sudo tar -xJf mysql-8.0.46-linux-glibc2.28-aarch64.tar.xz \
    -C /opt/mysql --strip-components=1
```

Create the service account and directories:

```bash
sudo getent group mysql >/dev/null || sudo groupadd --system mysql
sudo getent passwd mysql >/dev/null || \
    sudo useradd --system --gid mysql --home-dir /nonexistent \
    --shell /usr/sbin/nologin mysql
sudo mkdir -p /var/lib/mysql /var/lib/mysql-files /var/log/mysql /var/run/mysqld
sudo chown -R mysql:mysql /var/lib/mysql /var/lib/mysql-files \
    /var/log/mysql /var/run/mysqld
```

Create `/etc/my.cnf`:

```ini
[mysqld]
user=mysql
basedir=/opt/mysql
datadir=/var/lib/mysql
socket=/var/run/mysqld/mysqld.sock
pid-file=/var/run/mysqld/mysqld.pid
bind-address=127.0.0.1
mysqlx=0
secure-file-priv=/var/lib/mysql-files
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
default-time-zone='+00:00'
log-error=/var/log/mysql/error.log

[client]
socket=/var/run/mysqld/mysqld.sock
```

Initialize the data directory. The temporary root password is written to
`/var/log/mysql/error.log`:

```bash
sudo /opt/mysql/bin/mysqld --initialize --user=mysql \
    --basedir=/opt/mysql --datadir=/var/lib/mysql \
    --log-error=/var/log/mysql/error.log
sudo grep 'temporary password' /var/log/mysql/error.log
```

Create `/etc/systemd/system/mysql.service`:

```ini
[Unit]
Description=MySQL 8.0 Community Server
After=network.target
Documentation=https://dev.mysql.com/doc/refman/8.0/en/

[Service]
Type=notify
User=mysql
Group=mysql
ExecStart=/opt/mysql/bin/mysqld --defaults-file=/etc/my.cnf
RuntimeDirectory=mysqld
RuntimeDirectoryMode=755
LimitNOFILE=65535
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Start MySQL and replace the temporary root password:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mysql
sudo mysql -uroot -p --socket=/var/run/mysqld/mysqld.sock
```

At the MySQL prompt:

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'replace-with-a-strong-root-password';
CREATE DATABASE voice_ledger
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'voice_ledger'@'localhost'
  IDENTIFIED WITH mysql_native_password BY 'replace-with-a-strong-app-password';
GRANT ALL PRIVILEGES ON voice_ledger.* TO 'voice_ledger'@'localhost';
FLUSH PRIVILEGES;
```

Verify that reboot persistence and localhost-only binding are active:

```bash
sudo systemctl is-enabled mysql
sudo ss -ltnp | grep 3306
```

`3306` must listen on `127.0.0.1`, not `0.0.0.0`.

## 3. Install MongoDB 7.0 on ARM64

```bash
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

echo "deb [arch=arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] \
https://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt update
sudo apt install -y mongodb-org
sudo systemctl enable --now mongod
mongod --version
```

Confirm `/etc/mongod.conf` contains:

```yaml
net:
  port: 27017
  bindIp: 127.0.0.1
```

MongoDB is supporting storage only. It can be rebuilt with `init_mongo`; never
use it as the source of truth for money.

## 4. Install the API

```bash
sudo useradd --system --create-home --shell /usr/sbin/nologin voiceledger
sudo mkdir -p /opt/voice-ledger
sudo git clone <repository-url> /opt/voice-ledger
sudo chown -R voiceledger:voiceledger /opt/voice-ledger
sudo mkdir -p /var/backups/voice_ledger
sudo chown voiceledger:voiceledger /var/backups/voice_ledger

cd /opt/voice-ledger/rpi_server
sudo -u voiceledger python3 -m venv .venv
sudo -u voiceledger .venv/bin/pip install --upgrade pip
sudo -u voiceledger .venv/bin/pip install -r requirements.txt
sudo -u voiceledger cp .env.example .env
sudo -u voiceledger nano .env
```

Set at least:

```dotenv
ENVIRONMENT=production
DEBUG=false
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=voice_ledger
MYSQL_PASSWORD=replace-with-a-strong-app-password
MYSQL_DATABASE=voice_ledger
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DATABASE=voice_ledger_analytics
JWT_SECRET_KEY=replace-with-a-64-byte-random-secret
BACKUP_DIR=/var/backups/voice_ledger
```

Generate a JWT secret without printing it twice:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(64))"
```

Initialize both databases. Use the Alembic path or the reference SQL path, not
both, on the same database:

```bash
sudo -u voiceledger .venv/bin/alembic upgrade head
sudo -u voiceledger .venv/bin/python -m app.scripts.init_mongo
```

Optional demo data:

```bash
sudo -u voiceledger .venv/bin/python -m app.scripts.seed_demo
```

Demo accounts created by the Python seed:

- Admin: `admin@voiceledger.local` / `Admin@12345`
- Normal user: `demo@voiceledger.local` / `Demo@12345`

The SQL seed in `sql/seed/001_seed.sql` uses the same demo accounts. Do not run
both seeds against a fresh database because the IDs and emails overlap.

## 5. Start the API with systemd

```bash
cd /opt/voice-ledger/rpi_server
sudo cp deployment/voice-ledger-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now voice-ledger-api
sudo systemctl status voice-ledger-api
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/health/ready
```

Logs:

```bash
journalctl -u voice-ledger-api -f
```

The unit starts only after MySQL and MongoDB. If either database is unavailable,
`/health/ready` returns `503` and the app cannot serve financial data.

## 6. Nginx and HTTPS

```bash
sudo cp deployment/nginx.conf /etc/nginx/sites-available/voice-ledger
sudo ln -sf /etc/nginx/sites-available/voice-ledger \
    /etc/nginx/sites-enabled/voice-ledger
sudo rm -f /etc/nginx/sites-enabled/default
sudo nano /etc/nginx/sites-available/voice-ledger
sudo nginx -t
sudo systemctl reload nginx
```

Change `ledger.example.com` to the DNS name whose certificate the Android
device trusts. Obtain a certificate with Certbot:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d ledger.example.com
sudo certbot renew --dry-run
```

The supplied Nginx file uses the Bookworm-compatible `listen 443 ssl http2`
syntax. Do not copy a newer `http2 on;` directive onto Nginx 1.22.

### HTTPS on a private LAN

The Android release build sets `android:usesCleartextTraffic="false"`, so plain
HTTP and self-signed certificates are rejected. Use one of these options:

1. Give the Pi a real DNS name with a publicly trusted certificate and point
   that name to the Pi's LAN address with local DNS or router DNS.
2. Use a local certificate authority and install the CA on the phone. A user
   CA is not automatically trusted by release apps; only do this if the app has
   deliberately been configured to trust that CA.
3. For an isolated teaching/demo network only, build a debug APK, which permits
   cleartext traffic, and expose port 80 without the HTTPS redirect. This is a
   documented demo compromise, not the production configuration.

Never expose MySQL `3306`, MongoDB `27017` or Uvicorn `8000` outside the Pi.

## 7. Firewall

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80,443/tcp
sudo ufw enable
sudo ufw status
```

Only SSH and HTTPS are public. MySQL, MongoDB and Uvicorn remain bound to
loopback.

## 8. Build and install the Android application

Build on the development machine, not on the Pi:

```bash
cd mobile_app
flutter pub get
flutter analyze
flutter test
flutter build apk --release \
  --dart-define=API_BASE_URL=https://ledger.example.com/api/v1
```

The output is:

```text
mobile_app/build/app/outputs/flutter-apk/app-release.apk
```

Install it with ADB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

For a physical phone, enable USB debugging, connect it, and accept the RSA
fingerprint prompt. Grant microphone permission on first launch.

### Release signing

`android/key.properties` is ignored by Git. If it is absent, the build falls
back to debug signing so `flutter run --release` still works for local testing.
For a distributable APK, copy `android/key.properties.example` to
`android/key.properties`, generate a private keystore, and fill in the values:

```bash
keytool -genkeypair -v \
  -keystore /secure/path/voiceledger-release.jks \
  -storepass '<store-password>' \
  -keypass '<key-password>' \
  -alias voiceledger \
  -keyalg RSA -keysize 2048 -validity 3650 \
  -dname "CN=Voice Ledger, OU=DBMS, O=Voice Ledger, L=India, C=IN"
```

Use forward slashes in `storeFile` on Windows, for example
`C:/keys/voiceledger-release.jks`. Never commit the keystore or
`key.properties`.

The repository currently builds a demo-signed APK with a local evaluation key.
Replace it with a private keystore before publishing.

## 9. Verification

From the Pi:

```bash
curl -s https://ledger.example.com/health
curl -s https://ledger.example.com/health/ready
curl -s https://ledger.example.com/docs -o /dev/null -w '%{http_code}\n'
curl -s -X POST https://ledger.example.com/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@voiceledger.local","password":"Demo@12345"}'
```

Run the live integration suite from the repository root:

```bash
cd rpi_server
RUN_INTEGRATION=1 \
TEST_DATABASE_URL='mysql+pymysql://test:test@127.0.0.1:3306/voice_ledger_test?charset=utf8mb4' \
MONGODB_URI='mongodb://127.0.0.1:27017' \
pytest -q
```

Run the end-to-end Pi smoke test after the API and demo data are ready:

```bash
cd /opt/voice-ledger
BASE_URL=https://ledger.example.com/api/v1 \
bash integrations/pi_smoke_test.sh
```

The smoke script checks health, login, dashboard, all ledger command types,
idempotent replay, rejection auditing and admin actions.

Finally open the Android app, sign in as the demo user, record one income, one
expense and one lending entry, and confirm the dashboard balance and calendar
change.

## 10. Backups and maintenance

```bash
sudo -u voiceledger mkdir -p /var/backups/voice_ledger
sudo -u voiceledger sh -c "MYSQL_PWD='<app-password>' mysqldump \
  --host 127.0.0.1 --user voice_ledger --single-transaction --quick \
  --routines --triggers --no-tablespaces voice_ledger | \
  gzip > /var/backups/voice_ledger/voice_ledger_\$(date +%F).sql.gz"
```

- Copy backups off the Pi.
- Apply schema changes with `alembic upgrade head` or the admin
  `RUN_MIGRATIONS` action.
- MongoDB is not authoritative; recreate indexes and collections with
  `python -m app.scripts.init_mongo` after a rebuild.
- Rotate `JWT_SECRET_KEY` only during a planned sign-out of all clients.
- Do not upgrade the app user to MySQL `root`.

## 11. Known deployment limitations

- MySQL is installed from the generic ARM64 tarball because Oracle does not
  publish a Bookworm ARM64 APT package.
- A trusted TLS certificate is required for the release Android build.
- The supplied APK is signed with an evaluation key, not a Play Store key.
- A real Raspberry Pi, physical Android device and microphone have not been
  available for hardware acceptance testing in this environment.
