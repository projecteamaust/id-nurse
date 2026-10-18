"""schema.sql (for PostgreSQL) must describe the same tables as app/models.py, and the seed must work."""

import tests  # noqa: F401  (test settings; must be the first import)
import re
import unittest

from sqlalchemy import select
from sqlalchemy.dialects import postgresql
from sqlalchemy.exc import IntegrityError
from sqlalchemy.schema import CreateTable

from app import db
from app.config import BACKEND_DIR
from app.models import Item, Patient, User
from tests.helpers import fresh_database


def _schema_sql() -> str:
    return (BACKEND_DIR / "schema.sql").read_text(encoding="utf-8")


def _tables_in_schema_sql() -> dict[str, set[str]]:
    """{table name: column names} from the CREATE TABLE blocks in schema.sql."""
    tables = {}
    for name, body in re.findall(r"CREATE TABLE (\w+) \((.*?)\n\);", _schema_sql(), re.S):
        columns = set()
        for line in body.splitlines():
            match = re.match(r" {4}(\w+)\s", line)  # column lines; longer indents continue a line
            if match and match.group(1) != "CONSTRAINT":
                columns.add(match.group(1))
        tables[name] = columns
    return tables


class SchemaTest(unittest.TestCase):
    def test_schema_sql_matches_models(self):
        from_models = {t.name: {c.name for c in t.columns} for t in db.Base.metadata.sorted_tables}
        self.assertEqual(_tables_in_schema_sql(), from_models)

    def test_schema_sql_has_the_model_indexes_and_constraints(self):
        sql = _schema_sql()
        for table in db.Base.metadata.sorted_tables:
            for index in table.indexes:
                self.assertIn(f"CREATE INDEX {index.name} ON {table.name}", sql)
            for constraint in table.constraints:
                # Only our named checks and unique keys; unnamed ones (PRIMARY KEY, REFERENCES) are inline.
                if isinstance(constraint.name, str) and constraint.name.endswith(("_check", "_key")):
                    self.assertIn(f"CONSTRAINT {constraint.name}", sql)

    def test_models_compile_for_postgresql(self):
        for table in db.Base.metadata.sorted_tables:
            ddl = str(CreateTable(table).compile(dialect=postgresql.dialect()))
            self.assertIn(f"CREATE TABLE {table.name}", ddl)


class SeedTest(unittest.TestCase):
    def setUp(self):
        fresh_database()

    def test_seed_data(self):
        with db.session_scope() as session:
            users = session.scalars(select(User).order_by(User.id)).all()
            self.assertEqual([(u.employee_id, u.role) for u in users], [("48216", "nurse"), ("31082", "supervisor")])
            self.assertIsNone(users[0].password_hash)
            self.assertTrue(users[1].password_hash.startswith("pbkdf2_sha256$200000$"))
            self.assertEqual(len(session.scalars(select(Patient)).all()), 2)
            items = session.scalars(select(Item).order_by(Item.slot_number)).all()
            self.assertEqual([i.slot_number for i in items], [1, 2, 3, 4, 5, 6])
            self.assertEqual([i.cabinet_location for i in items], ["A1", "A2", "A3", "B1", "B2", "B3"])
            self.assertEqual(len({i.category for i in items}), 3)

    def test_seed_twice_changes_nothing(self):
        from app.seed import seed

        with db.session_scope() as session:
            self.assertFalse(seed(session, "another-password"))

    def test_supervisor_must_have_a_password(self):
        with db.session_scope() as session:
            session.add(User(employee_id="99999", name="No Password", password_hash=None,
                             role="supervisor", ward="Ward 1"))
            with self.assertRaises(IntegrityError):
                session.commit()

    def test_stock_can_not_go_below_zero(self):
        with db.session_scope() as session:
            item = session.scalar(select(Item).where(Item.slot_number == 4))
            item.quantity = -1
            with self.assertRaises(IntegrityError):
                session.commit()


if __name__ == "__main__":
    unittest.main()
