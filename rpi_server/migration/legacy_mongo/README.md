# Legacy document-store data → MySQL (optional, one-off)

Only needed if the old deployment already holds voice commands, audit logs,
application events or cached rates you want to keep. New installs skip this.
Nothing here runs as part of the application.

## 1. Export (on the old host, or any machine that can reach the old database)

Use the `mongoexport` tool from the MongoDB Database Tools. The old database
name was `voice_ledger_analytics` (the old `MONGODB_DATABASE`).

```bash
mkdir -p ~/legacy_export && cd ~/legacy_export
for c in voice_commands audit_logs application_events exchange_rates; do
  mongoexport --uri="mongodb://127.0.0.1:27017/voice_ledger_analytics" \
    --collection="$c" --out="$c.jsonl"
done
```

Keep the old MongoDB data directory/backup until step 3 is verified.

## 2. Create the MySQL tables, then dry-run

```bash
cd /opt/voice-ledger/rpi_server
sudo -u voiceledger .venv/bin/alembic upgrade head
sudo -u voiceledger .venv/bin/python migration/legacy_mongo/import_legacy_export.py \
    --dir ~/legacy_export --dry-run
```

## 3. Import and verify

```bash
sudo -u voiceledger .venv/bin/python migration/legacy_mongo/import_legacy_export.py \
    --dir ~/legacy_export
mysql -u voice_ledger -p voice_ledger -e \
  "SELECT 'VOICE_COMMAND', COUNT(*) FROM VOICE_COMMAND
   UNION ALL SELECT 'AUDIT_LOG', COUNT(*) FROM AUDIT_LOG
   UNION ALL SELECT 'APPLICATION_EVENT', COUNT(*) FROM APPLICATION_EVENT
   UNION ALL SELECT 'EXCHANGE_RATE_CACHE', COUNT(*) FROM EXCHANGE_RATE_CACHE;"
```

Compare with `wc -l ~/legacy_export/*.jsonl`. The script's report accounts for
every line (imported, already present, unlinked or rejected). The import is
safe to re-run. Rejected voice commands (their user no longer exists) are saved
to `rejected_voice_commands.jsonl` rather than discarded.

Exchange-rate rows are only a cache; expired ones are harmless and are removed
by the admin `PRUNE_RATE_CACHE` action.

## 4. Retire the old service

After verification: `sudo systemctl disable --now mongod`, then
`sudo apt purge mongodb-org*` and delete `/var/lib/mongodb` once you no longer
need the backup. This frees roughly 300–500 MB of RAM on a 2 GB Pi.
