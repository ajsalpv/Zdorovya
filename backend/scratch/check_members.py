import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

supabase_url = os.environ.get("SUPABASE_URL")
supabase_key = os.environ.get("SUPABASE_ANON_KEY")

supabase: Client = create_client(supabase_url, supabase_key)

try:
    res = supabase.table("family_members").select("*").execute()
    print(res.data)
except Exception as e:
    print(f"Error: {e}")
