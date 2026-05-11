import psycopg2
import os
from dotenv import load_dotenv

# Load credentials
load_dotenv()

# Database connection details
DB_NAME = "postgres"
DB_USER = "postgres"
DB_HOST = "db.jlrzzrhxqvpzrltolkbf.supabase.co"
DB_PORT = "5432"
DB_PASS = os.getenv("DB_PASSWORD", "YOUR_DATABASE_PASSWORD_HERE")

SQL_COMMANDS = """
-- 1. Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Add the embedding column to medical_records
ALTER TABLE medical_records 
ADD COLUMN IF NOT EXISTS embedding vector(768);

-- 3. Create a matching function for semantic search
CREATE OR REPLACE FUNCTION match_medical_records (
  query_embedding vector(768),
  match_threshold float,
  match_count int,
  p_family_id uuid
)
RETURNS TABLE (
  id uuid,
  family_id uuid,
  type text,
  extracted_text text,
  metadata jsonb,
  record_date date,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    medical_records.id,
    medical_records.family_id,
    medical_records.type,
    medical_records.extracted_text,
    medical_records.metadata,
    medical_records.record_date,
    1 - (medical_records.embedding <=> query_embedding) AS similarity
  FROM medical_records
  WHERE medical_records.family_id = p_family_id
    AND 1 - (medical_records.embedding <=> query_embedding) > match_threshold
  ORDER BY medical_records.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
"""

def run_migration():
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME, user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT
        )
        cur = conn.cursor()
        print("Connected to Supabase DB. Running RAG migration...")
        cur.execute(SQL_COMMANDS)
        conn.commit()
        print("✅ Migration successful! pgvector and semantic search are ready.")
        cur.close()
        conn.close()
    except Exception as e:
        print(f"❌ Error: {e}")
        print("\nTIP: If you don't want to use this script, simply copy the SQL inside it and paste it into the Supabase SQL Editor dashboard.")

if __name__ == "__main__":
    run_migration()
