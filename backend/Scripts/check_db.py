import sys
import os
sys.path.append(os.getcwd())

from app.database import engine
from sqlalchemy import inspect

inspector = inspect(engine)
tables = inspector.get_table_names()
print(f"Tables: {tables}")

for table in tables:
    columns = [c['name'] for c in inspector.get_columns(table)]
    print(f"Table {table}: {columns}")
