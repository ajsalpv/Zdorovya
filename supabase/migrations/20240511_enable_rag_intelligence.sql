-- MIGRATION: Enable RAG Intelligence Layer
-- DATE: 2024-05-11

-- 1. Enable the pgvector extension to support AI embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Add the embedding column to the medical_records table
-- This stores the "semantic meaning" of every report
ALTER TABLE medical_records 
ADD COLUMN IF NOT EXISTS embedding vector(768);

-- 3. Create the Semantic Search Function
-- This allows the AI to find reports based on context (e.g., searching for "heart" finds ECGs)
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

-- 4. Create an index for faster AI retrieval (optional but recommended for performance)
CREATE INDEX IF NOT EXISTS medical_records_embedding_idx 
ON medical_records 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
