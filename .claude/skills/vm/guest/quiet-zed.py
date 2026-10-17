"""Seed Zed's announcement state after its first launch, with Zed stopped.

Zed 1.24.2: crates/auto_update_ui/src/auto_update_ui.rs and crates/db/src/kvp.rs.
There is no general announcement setting; auto_update=false prevents later updates.
"""
import sqlite3
import sys
import time
from contextlib import closing
from pathlib import Path


def ready(database):
    # Zed creates its database and kv_store table on its first launch.
    try:
        with closing(sqlite3.connect(database.as_uri() + '?mode=ro', uri=True)) as db:
            return db.execute("SELECT 1 FROM sqlite_master WHERE name = 'kv_store'").fetchone() is not None
    except sqlite3.OperationalError:
        return False


def quiet(database):
    # mode=rw refuses a missing database; let Zed own its schema and migrations.
    with closing(sqlite3.connect(database.as_uri() + '?mode=rw', uri=True)) as db, db:
        db.execute("INSERT OR REPLACE INTO kv_store (key, value) VALUES (?, ?)",
                   ('delta_announcement_dismissed', '1'))
        db.execute("DELETE FROM kv_store WHERE key = ?",
                   ('auto-updater-should-show-updated-notification',))


def wait(database, seconds):
    deadline = time.monotonic() + seconds
    while not ready(database):
        if time.monotonic() >= deadline:
            sys.exit(f'quiet-zed: Zed created no kv_store in {database} within {seconds} s')
        time.sleep(1)


if __name__ == '__main__':
    database = Path.home() / 'Library/Application Support/Zed/db/0-stable/db.sqlite'
    args = sys.argv[1:]
    if not args:
        quiet(database)
    elif len(args) == 2 and args[0] == '--wait':
        wait(database, int(args[1]))
    else:
        sys.exit('usage: quiet-zed.py [--wait <seconds>]')
