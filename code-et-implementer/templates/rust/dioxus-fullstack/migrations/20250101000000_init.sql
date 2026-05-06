-- Portable schema for SQLite + Postgres. Forward-only.
CREATE TABLE IF NOT EXISTS users (
    id    TEXT PRIMARY KEY NOT NULL,
    email TEXT NOT NULL UNIQUE
);
