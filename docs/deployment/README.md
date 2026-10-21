# Deployment Quick Reference

Full Raspberry Pi checklist:
[`../../rpi_server/deployment/README.md`](../../rpi_server/deployment/README.md).

## Steps

1. Install Raspberry Pi OS 64-bit, Python 3.11+, Nginx, MySQL 8.0 from the
   ARM64 generic tarball (Debian Bookworm APT provides MariaDB, not MySQL), and
   MongoDB 7.0 from the official ARM64 repository.
2. Create the `voice_ledger` database/user and a dedicated OS service account.
3. Copy `rpi_server/`, create `.venv`, and install
   `requirements-dev.txt` (or `requirements.txt` in production).
4. Configure `.env` with MySQL, MongoDB, a strong `JWT_SECRET_KEY`, optional
   `ADMIN_EMAIL`/`ADMIN_PASSWORD`, and `BACKUP_DIR`.
5. Run `alembic upgrade head`, `python -m app.scripts.seed_demo` and
   `python -m app.scripts.init_mongo`.
6. Install `deployment/voice-ledger-api.service` and
   `deployment/nginx.conf`; obtain a TLS certificate.
7. Bind Uvicorn to `127.0.0.1:8000`; expose only ports 80/443.
8. Verify `/health`, `/health/ready` and the OpenAPI docs.
9. Build the Android APK with the trusted Pi HTTPS URL:
   `flutter build apk --release --dart-define=API_BASE_URL=https://<host>/api/v1`.
10. Run `integrations/pi_smoke_test.sh` and the DBMS demo queries.

## Database initialization

Normal application setup:

```bash
cd rpi_server
alembic upgrade head
python -m app.scripts.seed_demo
python -m app.scripts.init_mongo
```

Reference DBMS setup (fresh database only):

```bash
mysql -u root -p < rpi_server/sql/schema/001_schema.sql
mysql -u root -p voice_ledger < rpi_server/sql/schema/002_views.sql
mysql -u root -p voice_ledger < rpi_server/sql/seed/001_seed.sql
```

Use one path, not both, on the same database because the demo IDs/emails
overlap. The SQL seed provides the reference admin and richer demonstration
data.

## Verification

```bash
cd rpi_server
ruff check app tests alembic
pytest -q
python -m compileall -q app tests alembic
# Requires live MySQL + MongoDB and a migrated test database.
# Set TEST_DATABASE_URL when it is not 127.0.0.1:3306.
RUN_INTEGRATION=1 pytest -m integration
# Current result: 62 passed with live MySQL 8.0.46 + MongoDB 7.0.37.
```

```bash
cd mobile_app
flutter analyze
flutter test
```

Back up MySQL with the admin `CREATE_BACKUP` action or a scheduled
`mysqldump --single-transaction`. MongoDB is not authoritative and can be
rebuilt with `init_mongo`.
