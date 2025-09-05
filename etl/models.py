from sqlalchemy import Table, Column, BigInteger, Integer, String, DateTime, MetaData, ForeignKey, Text
from sqlalchemy.dialects.postgresql import insert
metadata = MetaData(schema=None)

teams = Table(
    "teams", metadata,
    Column("id", BigInteger, primary_key=True),
    Column("name", String(200), nullable=False),
    Column("short_name", String(50)),
    Column("crest_url", Text),
)

players = Table(
    "players", metadata,
    Column("id", BigInteger, primary_key=True),
    Column("team_id", BigInteger, ForeignKey("teams.id", ondelete="CASCADE"), index=True),
    Column("name", String(200), nullable=False),
    Column("position", String(50)),
)

matches = Table(
    "matches", metadata,
    Column("id", BigInteger, primary_key=True),
    Column("season", Integer, index=True),
    Column("round", String(50)),
    Column("date_utc", DateTime(timezone=True), index=True),
    Column("home_id", BigInteger, ForeignKey("teams.id", ondelete="SET NULL"), index=True),
    Column("away_id", BigInteger, ForeignKey("teams.id", ondelete="SET NULL"), index=True),
    Column("goals_home", Integer),
    Column("goals_away", Integer),
    Column("status", String(10), index=True),
)

events = Table(
    "events", metadata,
    Column("match_id", BigInteger, ForeignKey("matches.id", ondelete="CASCADE"), primary_key=True),
    Column("minute", Integer, primary_key=True),
    Column("type", String(50), primary_key=True),
    Column("player_id", BigInteger, nullable=True),
    Column("team_id", BigInteger, ForeignKey("teams.id", ondelete="SET NULL")),
)

def upsert(conn, table, rows, key_cols):
    """Idempotent UPSERT pour PostgreSQL via ON CONFLICT."""
    if not rows:
        return 0
    stmt = insert(table).values(rows)
    update_cols = {c.name: stmt.excluded[c.name] for c in table.columns if c.name not in key_cols}
    stmt = stmt.on_conflict_do_update(index_elements=[table.c[k] for k in key_cols], set_=update_cols)
    res = conn.execute(stmt)
    return res.rowcount or 0
