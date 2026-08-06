#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Tests for oracle_meta_export -- all Oracle interactions are mocked."""

import configparser
import os
import subprocess
import tempfile
import textwrap
import unittest
from unittest import mock

# Ensure the parent package is importable
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import oracle_meta_export as ome


class TestSafeFilename(unittest.TestCase):
    def test_normal_name(self):
        self.assertEqual(ome.safe_filename("MY_PROC"), "MY_PROC")

    def test_special_characters(self):
        self.assertEqual(ome.safe_filename('a<b>c:d"e'), "a_b_c_d_e")

    def test_empty_string(self):
        self.assertEqual(ome.safe_filename(""), "")


class TestLoadConfig(unittest.TestCase):
    def _write_config(self, tmp, content):
        path = os.path.join(tmp, "config.ini")
        with open(path, "w") as f:
            f.write(textwrap.dedent(content))
        return path

    def test_basic_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_config(tmp, """\
                [database]
                host = 10.0.0.1
                port = 1522
                service_name = testdb
                user = scott
                password = tiger

                [export]
                output_dir = /tmp/out
                object_types = PROCEDURE,TRIGGER

                [git]
                auto_commit = false
                commit_prefix = [test]
            """)
            cfg = ome.load_config(path)
            self.assertEqual(cfg["host"], "10.0.0.1")
            self.assertEqual(cfg["port"], 1522)
            self.assertEqual(cfg["service_name"], "testdb")
            self.assertEqual(cfg["user"], "scott")
            self.assertEqual(cfg["password"], "tiger")
            self.assertEqual(cfg["output_dir"], "/tmp/out")
            self.assertEqual(cfg["object_types"], ["PROCEDURE", "TRIGGER"])
            self.assertFalse(cfg["auto_commit"])
            self.assertEqual(cfg["commit_prefix"], "[test]")

    def test_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write_config(tmp, """\
                [database]
                [export]
                [git]
            """)
            cfg = ome.load_config(path)
            self.assertEqual(cfg["host"], "127.0.0.1")
            self.assertEqual(cfg["port"], 1521)
            self.assertEqual(cfg["object_types"], ome.DEFAULT_OBJECT_TYPES)
            self.assertTrue(cfg["auto_commit"])


class TestWriteMetadataFile(unittest.TestCase):
    def test_creates_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            rel = ome.write_metadata_file(
                tmp, "SCOTT", "PROCEDURE", "MY_PROC",
                "CREATE OR REPLACE PROCEDURE my_proc AS BEGIN NULL; END;",
            )
            self.assertEqual(rel, os.path.join("SCOTT", "procedures", "MY_PROC.sql"))
            full = os.path.join(tmp, rel)
            self.assertTrue(os.path.isfile(full))
            with open(full) as f:
                self.assertIn("my_proc", f.read())

    def test_unknown_type_uses_lowercase(self):
        with tempfile.TemporaryDirectory() as tmp:
            rel = ome.write_metadata_file(
                tmp, "HR", "JAVA_SOURCE", "MyClass", "class MyClass {}"
            )
            self.assertIn("java_source", rel)


class TestGitHelpers(unittest.TestCase):
    def test_git_init_creates_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = os.path.join(tmp, "repo")
            created = ome.git_init(repo)
            self.assertTrue(created)
            self.assertTrue(os.path.isdir(os.path.join(repo, ".git")))

    def test_git_init_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = os.path.join(tmp, "repo")
            ome.git_init(repo)
            created = ome.git_init(repo)
            self.assertFalse(created)

    def test_git_add_and_commit(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = os.path.join(tmp, "repo")
            ome.git_init(repo)
            # Create a file
            with open(os.path.join(repo, "test.txt"), "w") as f:
                f.write("hello")
            committed = ome.git_add_and_commit(repo, "first commit")
            self.assertTrue(committed)
            # No new changes
            committed = ome.git_add_and_commit(repo, "no changes")
            self.assertFalse(committed)

    def test_git_has_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = os.path.join(tmp, "repo")
            ome.git_init(repo)
            self.assertFalse(ome.git_has_changes(repo))
            with open(os.path.join(repo, "a.txt"), "w") as f:
                f.write("data")
            self.assertTrue(ome.git_has_changes(repo))


class TestExportMetadata(unittest.TestCase):
    """Integration-style test with mocked Oracle connection."""

    @staticmethod
    def _mock_cursor():
        """Return a mock cursor that simulates Oracle queries."""
        cursor = mock.MagicMock()

        def execute_side_effect(sql, **kwargs):
            if "SELECT USER FROM DUAL" in sql:
                cursor.fetchone.return_value = ("SCOTT",)
            elif "ALL_OBJECTS" in sql:
                otype = kwargs.get("otype", "")
                if otype == "PROCEDURE":
                    cursor.fetchall.return_value = [("MY_PROC",)]
                else:
                    cursor.fetchall.return_value = []
            elif "DBMS_METADATA" in sql:
                cursor.fetchone.return_value = (
                    "CREATE OR REPLACE PROCEDURE my_proc AS BEGIN NULL; END;",
                )

        cursor.execute = mock.MagicMock(side_effect=execute_side_effect)
        return cursor

    @mock.patch("oracle_meta_export.get_connection")
    def test_export_and_commit(self, mock_get_conn):
        cursor = self._mock_cursor()
        conn = mock.MagicMock()
        conn.cursor.return_value = cursor
        mock_get_conn.return_value = conn

        with tempfile.TemporaryDirectory() as tmp:
            output = os.path.join(tmp, "repo")
            config = {
                "host": "127.0.0.1",
                "port": 1521,
                "service_name": "orcl",
                "user": "scott",
                "password": "tiger",
                "output_dir": output,
                "object_types": ["PROCEDURE"],
                "schemas": [],
                "encoding": "utf-8",
                "auto_commit": True,
                "commit_prefix": "[test]",
            }
            result = ome.export_metadata(config)
            self.assertEqual(result["exported"], 1)
            self.assertTrue(result["committed"])

            # Verify file was created
            proc_file = os.path.join(output, "SCOTT", "procedures", "MY_PROC.sql")
            self.assertTrue(os.path.isfile(proc_file))

            # Verify git commit was made
            rc, log = ome._run_git(["log", "--oneline"], output)
            self.assertEqual(rc, 0)
            self.assertIn("[test]", log)

    @mock.patch("oracle_meta_export.get_connection")
    def test_no_commit_when_disabled(self, mock_get_conn):
        cursor = self._mock_cursor()
        conn = mock.MagicMock()
        conn.cursor.return_value = cursor
        mock_get_conn.return_value = conn

        with tempfile.TemporaryDirectory() as tmp:
            output = os.path.join(tmp, "repo")
            config = {
                "host": "127.0.0.1",
                "port": 1521,
                "service_name": "orcl",
                "user": "scott",
                "password": "tiger",
                "output_dir": output,
                "object_types": ["PROCEDURE"],
                "schemas": [],
                "encoding": "utf-8",
                "auto_commit": False,
                "commit_prefix": "[test]",
            }
            result = ome.export_metadata(config)
            self.assertEqual(result["exported"], 1)
            self.assertFalse(result["committed"])

    @mock.patch("oracle_meta_export.get_connection")
    def test_second_run_detects_changes(self, mock_get_conn):
        """Simulate two runs: first creates, second modifies content."""
        cursor = self._mock_cursor()
        conn = mock.MagicMock()
        conn.cursor.return_value = cursor
        mock_get_conn.return_value = conn

        with tempfile.TemporaryDirectory() as tmp:
            output = os.path.join(tmp, "repo")
            config = {
                "host": "127.0.0.1",
                "port": 1521,
                "service_name": "orcl",
                "user": "scott",
                "password": "tiger",
                "output_dir": output,
                "object_types": ["PROCEDURE"],
                "schemas": [],
                "encoding": "utf-8",
                "auto_commit": True,
                "commit_prefix": "[test]",
            }
            # First run
            ome.export_metadata(config)

            # Modify mock to return different content
            def execute_v2(sql, **kwargs):
                if "SELECT USER FROM DUAL" in sql:
                    cursor.fetchone.return_value = ("SCOTT",)
                elif "ALL_OBJECTS" in sql:
                    otype = kwargs.get("otype", "")
                    if otype == "PROCEDURE":
                        cursor.fetchall.return_value = [("MY_PROC",)]
                    else:
                        cursor.fetchall.return_value = []
                elif "DBMS_METADATA" in sql:
                    cursor.fetchone.return_value = (
                        "CREATE OR REPLACE PROCEDURE my_proc AS BEGIN "
                        "DBMS_OUTPUT.PUT_LINE('v2'); END;",
                    )

            cursor.execute = mock.MagicMock(side_effect=execute_v2)

            # Second run
            result = ome.export_metadata(config)
            self.assertTrue(result["committed"])

            # Two commits should exist
            rc, log = ome._run_git(["log", "--oneline"], output)
            self.assertEqual(rc, 0)
            lines = [l for l in log.splitlines() if l.strip()]
            self.assertEqual(len(lines), 2)


class TestMainCLI(unittest.TestCase):
    def test_missing_config(self):
        with self.assertRaises(SystemExit) as ctx:
            ome.main(["--config", "/nonexistent/config.ini"])
        self.assertEqual(ctx.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
