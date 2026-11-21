# Deployment Quick Reference

Full Raspberry Pi checklist:
[`../../rpi_server/deployment/README.md`](../../rpi_server/deployment/README.md).

## Steps

1. Install Raspberry Pi OS 64-bit, Python 3.11+, Nginx, and MySQL 8.0 from the
   ARM64 generic tarball (Debian Bookworm APT provides MariaDB, not MySQL).
2. Apply `rpi_server/deployment/mysql-pi-2gb.cnf` for a 2 GB board, then create
   the `voice_ledger` database/user and a dedicated OS service account.
3. Copy `rpi_server/`, create `.venv`, and install
   `requirements-dev.txt` (or `requirements.txt` in production).
4. Configure `.env` with MySQL, a strong `JWT_SECRET_KEY`, optional
   `ADMIN_EMAIL`/`ADMIN_PASSWORD`, and `BACKUP_DIR`.
5. Run `alembic upgrade head` and `python -m app.scripts.seed_demo`.
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
alembic upgrade head          # includes 0003_supporting_tables
python -m app.scripts.seed_demo
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
pytest -q            # 66 passed, 2 gated integration tests skipped
python -m compileall -q app tests alembic
# Requires live MySQL and a migrated test database.
# Set TEST_DATABASE_URL when it is not 127.0.0.1:3306.
RUN_INTEGRATION=1 pytest -m integration
```

```bash
cd mobile_app
flutter analyze
flutter test
```

Back up MySQL with the admin `CREATE_BACKUP` action or a scheduled
`mysqldump --single-transaction`. The dump includes the four supporting tables;
a lost audit or FX row never changes a balance. Legacy MongoDB exports can be
loaded with `python -m app.scripts.import_legacy_supporting_export`.
