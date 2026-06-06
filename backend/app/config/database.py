from supabase import create_client, Client
from app.config.settings import settings
from typing import Optional

_supabase_client: Optional[Client] = None
_supabase_service: Optional[Client] = None


def get_supabase() -> Client:
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = create_client(
            settings.supabase_url,
            settings.supabase_anon_key
        )
    return _supabase_client


def get_supabase_service() -> Client:
    global _supabase_service
    if _supabase_service is None:
        _supabase_service = create_client(
            settings.supabase_url,
            settings.supabase_service_key
        )
    return _supabase_service


supabase = get_supabase()
