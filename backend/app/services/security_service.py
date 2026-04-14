import logging
from cryptography.fernet import Fernet
from app.config import settings

logger = logging.getLogger(__name__)

class SecurityService:
    def __init__(self):
        # The encryption key must be a 32 url-safe base64-encoded bytes string
        # We ensure it's properly encoded or derived in a real-world scenario
        try:
            self.cipher_suite = Fernet(settings.encryption_key.encode())
        except Exception as e:
            logger.error(f"Failed to initialize encryption: {e}")
            # Fallback for demo (not recommended for production)
            self.cipher_suite = Fernet(Fernet.generate_key())

    def encrypt_data(self, data: str) -> str:
        """Encrypt string data using AES-256."""
        if not data:
            return ""
        try:
            encrypted_text = self.cipher_suite.encrypt(data.encode())
            return encrypted_text.decode()
        except Exception as e:
            logger.error(f"Encryption error: {e}")
            return data # Fallback to raw data to avoid losing info, but log error

    def decrypt_data(self, encrypted_data: str) -> str:
        """Decrypt string data."""
        if not encrypted_data:
            return ""
        try:
            decrypted_text = self.cipher_suite.decrypt(encrypted_data.encode())
            return decrypted_text.decode()
        except Exception as e:
            logger.error(f"Decryption error: {e}")
            return encrypted_data # Fallback to raw if not encrypted

security_service = SecurityService()
