#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Oracle Metadata Export Tool

Extracts database metadata (stored procedures, triggers, packages, functions,
views, etc.) from Oracle 11.2.0.4+ and stores them as files in a local git
repository.  On the first run the repository is automatically initialized;
subsequent runs detect changes, additions and deletions and commit them so
that every modification is traceable through git history.
"""

import argparse
import configparser
import datetime
import logging
import os
import re
import subprocess
import sys

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Metadata type -> subdirectory mapping
# ---------------------------------------------------------------------------
TYPE_DIR_MAP = {
    "PROCEDURE": "procedures",
    "FUNCTION": "functions",
    "TRIGGER": "triggers",
    "PACKAGE": "packages",
    "PACKAGE_BODY": "package_bodies",
    "VIEW": "views",
    "TYPE": "types",
    "TYPE_BODY": "type_bodies",
    "SYNONYM": "synonyms",
    "SEQUENCE": "sequences",
    "TABLE": "tables",
}

DEFAULT_OBJECT_TYPES = ["PROCEDURE", "FUNCTION", "TRIGGER", "PACKAGE",
                        "PACKAGE_BODY", "VIEW"]


# ---------------------------------------------------------------------------
# Configuration helpers
# ---------------------------------------------------------------------------

def load_config(config_path):
    """Load settings from an INI configuration file and return a dict."""
    cfg = configparser.ConfigParser()
    cfg.read(config_path, encoding="utf-8")

    db = cfg["database"] if "database" in cfg else {}
    export = cfg["export"] if "export" in cfg else {}
    git_sec = cfg["git"] if "git" in cfg else {}

    raw_types = export.get("object_types", ",".join(DEFAULT_OBJECT_TYPES))
    object_types = [t.strip().upper() for t in raw_types.split(",") if t.strip()]

    raw_schemas = export.get("schemas", "")
    schemas = [s.strip().upper() for s in raw_schemas.split(",") if s.strip()]

    return {
        "host": db.get("host", "127.0.0.1"),
        "port": int(db.get("port", 1521)),
        "service_name": db.get("service_name", "orcl"),
        "user": db.get("user", ""),
        "password": db.get("password", ""),
        "output_dir": export.get("output_dir", "./oracle_metadata_repo"),
        "object_types": object_types,
        "schemas": schemas,
        "encoding": export.get("encoding", "utf-8"),
        "auto_commit": git_sec.get("auto_commit", "true").lower() == "true",
        "commit_prefix": git_sec.get("commit_prefix", "[oracle-meta]"),
    }


# ---------------------------------------------------------------------------
# Safe filename
# ---------------------------------------------------------------------------

_UNSAFE_RE = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def safe_filename(name):
    """Convert an Oracle object name to a safe filename."""
    return _UNSAFE_RE.sub("_", name)


# ---------------------------------------------------------------------------
# Oracle interaction
# ---------------------------------------------------------------------------

def get_connection(config):
    """Create and return an Oracle database connection using *oracledb*."""
    import oracledb  # imported here so tests can mock it

    dsn = oracledb.makedsn(config["host"], config["port"],
                           service_name=config["service_name"])
    return oracledb.connect(user=config["user"],
                            password=config["password"], dsn=dsn)


def fetch_object_names(cursor, schema, object_type):
    """Return a list of object names for the given *schema* and *object_type*.

    Uses ``ALL_OBJECTS`` so that the connected user can export objects from
    schemas they have access to.
    """
    sql = (
        "SELECT OBJECT_NAME FROM ALL_OBJECTS "
        "WHERE OWNER = :owner AND OBJECT_TYPE = :otype "
        "AND STATUS = 'VALID' "
        "ORDER BY OBJECT_NAME"
    )
    cursor.execute(sql, owner=schema, otype=object_type)
    return [row[0] for row in cursor.fetchall()]


def fetch_source(cursor, schema, object_name, object_type):
    """Return the DDL source for an object via ``DBMS_METADATA``."""
    cursor.execute(
        "SELECT DBMS_METADATA.GET_DDL(:otype, :oname, :owner) FROM DUAL",
        otype=object_type, oname=object_name, owner=schema,
    )
    row = cursor.fetchone()
    if row and row[0]:
        clob = row[0]
        return clob.read() if hasattr(clob, "read") else str(clob)
    return ""


def fetch_table_ddl(cursor, schema, table_name):
    """Return DDL for a table including column comments and indexes."""
    parts = []
    # Table DDL
    cursor.execute(
        "SELECT DBMS_METADATA.GET_DDL('TABLE', :tname, :owner) FROM DUAL",
        tname=table_name, owner=schema,
    )
    row = cursor.fetchone()
    if row and row[0]:
        clob = row[0]
        parts.append(clob.read() if hasattr(clob, "read") else str(clob))
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# File I/O
# ---------------------------------------------------------------------------

def write_metadata_file(output_dir, schema, object_type, object_name,
                        content, encoding="utf-8"):
    """Write *content* to ``<output_dir>/<schema>/<type_dir>/<name>.sql``.

    Returns the relative path (from *output_dir*) of the written file.
    """
    type_dir = TYPE_DIR_MAP.get(object_type, object_type.lower())
    dir_path = os.path.join(output_dir, schema, type_dir)
    os.makedirs(dir_path, exist_ok=True)

    filename = safe_filename(object_name) + ".sql"
    file_path = os.path.join(dir_path, filename)

    with open(file_path, "w", encoding=encoding) as fh:
        fh.write(content)

    return os.path.relpath(file_path, output_dir)


# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------

def _run_git(args, cwd):
    """Run a git command in *cwd* and return ``(returncode, stdout)``."""
    cmd = ["git"] + args
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    return result.returncode, result.stdout.strip()


def git_init(repo_dir):
    """Initialise a git repository in *repo_dir* if it does not exist yet.

    Returns ``True`` when a new repository was created.
    """
    os.makedirs(repo_dir, exist_ok=True)
    git_dir = os.path.join(repo_dir, ".git")
    if os.path.isdir(git_dir):
        return False

    rc, _ = _run_git(["init"], repo_dir)
    if rc != 0:
        raise RuntimeError("git init failed in " + repo_dir)

    # Set a default identity so commits work even in CI.
    _run_git(["config", "user.email", "oracle-meta-export@localhost"], repo_dir)
    _run_git(["config", "user.name", "Oracle Meta Export"], repo_dir)
    return True


def git_has_changes(repo_dir):
    """Return ``True`` if there are staged or unstaged changes."""
    rc, out = _run_git(["status", "--porcelain"], repo_dir)
    return bool(out)


def git_add_and_commit(repo_dir, message):
    """Stage all changes and commit with *message*.

    Returns ``True`` if a commit was created.
    """
    _run_git(["add", "-A"], repo_dir)
    if not git_has_changes(repo_dir):
        return False
    rc, _ = _run_git(["commit", "-m", message], repo_dir)
    return rc == 0


# ---------------------------------------------------------------------------
# Export orchestration
# ---------------------------------------------------------------------------

def export_metadata(config):
    """Main export routine: connect to Oracle, dump all requested objects,
    write files, and commit to git.

    Returns a dict with counters: ``{"exported": int, "committed": bool}``.
    """
    output_dir = os.path.abspath(config["output_dir"])
    encoding = config.get("encoding", "utf-8")
    auto_commit = config.get("auto_commit", True)
    commit_prefix = config.get("commit_prefix", "[oracle-meta]")

    # 1. Ensure git repo
    is_new = git_init(output_dir)
    logger.info("Git repo %s: %s", output_dir,
                "initialized" if is_new else "already exists")

    # 2. Connect to Oracle
    conn = get_connection(config)
    cursor = conn.cursor()

    # Determine schemas to export
    schemas = config.get("schemas", [])
    if not schemas:
        cursor.execute("SELECT USER FROM DUAL")
        schemas = [cursor.fetchone()[0]]

    exported = 0
    for schema in schemas:
        for object_type in config["object_types"]:
            logger.info("Exporting %s.%s ...", schema, object_type)
            names = fetch_object_names(cursor, schema, object_type)
            for name in names:
                try:
                    if object_type == "TABLE":
                        content = fetch_table_ddl(cursor, schema, name)
                    else:
                        content = fetch_source(cursor, schema, name,
                                               object_type)
                    if content:
                        rel = write_metadata_file(output_dir, schema,
                                                  object_type, name,
                                                  content, encoding)
                        logger.debug("  wrote %s", rel)
                        exported += 1
                except Exception:
                    logger.exception("Failed to export %s.%s.%s",
                                     schema, object_type, name)

    cursor.close()
    conn.close()

    # 3. Commit
    committed = False
    if auto_commit:
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        if is_new:
            msg = f"{commit_prefix} Initial metadata export at {now}"
        else:
            msg = f"{commit_prefix} Update metadata at {now}"
        committed = git_add_and_commit(output_dir, msg)
        if committed:
            logger.info("Committed changes: %s", msg)
        else:
            logger.info("No changes detected, nothing to commit.")

    return {"exported": exported, "committed": committed}


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Export Oracle database metadata and track with git.",
    )
    parser.add_argument(
        "-c", "--config", default="config.ini",
        help="Path to the configuration file (default: config.ini)",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true",
        help="Enable debug logging",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)-8s %(message)s",
    )

    if not os.path.isfile(args.config):
        logger.error("Config file not found: %s", args.config)
        sys.exit(1)

    config = load_config(args.config)
    result = export_metadata(config)
    logger.info("Export complete: %d objects, committed=%s",
                result["exported"], result["committed"])


if __name__ == "__main__":
    main()
