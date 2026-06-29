from app.config.settings import settings

broker_url = None
result_backend = None
conf = type('conf', (), {'broker_url': 'disabled'})()
