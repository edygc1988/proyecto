"""
Microservicio 2: Consumidor de Items
Consume los endpoints del Microservicio 1 para obtener y crear items
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import requests
import os
import logging
from datetime import datetime
from functools import wraps
import time

# Configuración de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuración del Microservicio 1 desde variables de entorno
MICROSERVICE_1_URL = os.getenv('MICROSERVICE_1_URL', 'http://localhost:5000')
MICROSERVICE_1_HOST = os.getenv('MICROSERVICE_1_HOST', 'microservice-1')
MICROSERVICE_1_PORT = os.getenv('MICROSERVICE_1_PORT', '5000')

# Construir URL base del Microservicio 1
if not MICROSERVICE_1_URL.startswith('http'):
    MICROSERVICE_1_URL = f"http://{MICROSERVICE_1_HOST}:{MICROSERVICE_1_PORT}"

# Timeout para requests
REQUEST_TIMEOUT = 10
MAX_RETRIES = 3

def retry_decorator(max_retries=MAX_RETRIES, timeout=1):
    """Decorador para reintentar requests en caso de fallo"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except (requests.ConnectionError, requests.Timeout) as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        logger.warning(f"Intento {attempt + 1}/{max_retries} falló, reintentando en {timeout}s...")
                        time.sleep(timeout)
                    else:
                        logger.error(f"Todos los intentos fallaron: {e}")
            raise last_exception
        return wrapper
    return decorator

@retry_decorator()
def call_microservice_1(endpoint, method='GET', data=None):
    """
    Realiza llamadas al Microservicio 1 con reintentos automáticos
    """
    url = f"{MICROSERVICE_1_URL}{endpoint}"
    logger.info(f"Llamando a {method} {url}")
    
    try:
        if method == 'GET':
            response = requests.get(url, timeout=REQUEST_TIMEOUT)
        elif method == 'POST':
            response = requests.post(url, json=data, timeout=REQUEST_TIMEOUT)
        elif method == 'PUT':
            response = requests.put(url, json=data, timeout=REQUEST_TIMEOUT)
        elif method == 'DELETE':
            response = requests.delete(url, timeout=REQUEST_TIMEOUT)
        
        response.raise_for_status()
        return response.json()
    
    except requests.exceptions.RequestException as e:
        logger.error(f"Error llamando a {url}: {e}")
        raise

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de health check"""
    return jsonify({
        'status': 'healthy',
        'service': 'microservice-2',
        'timestamp': datetime.now().isoformat()
    }), 200

@app.route('/status', methods=['GET'])
def service_status():
    """Verifica el estado de ambos servicios"""
    status = {
        'service': 'microservice-2',
        'timestamp': datetime.now().isoformat(),
        'microservice-1': 'unknown'
    }
    
    try:
        response = call_microservice_1('/health')
        status['microservice-1'] = 'healthy'
    except Exception as e:
        logger.error(f"Microservice-1 no está disponible: {e}")
        status['microservice-1'] = 'unhealthy'
    
    return jsonify(status), 200

@app.route('/items', methods=['GET'])
def get_items():
    """
    Obtiene todos los items del Microservicio 1
    GET /items
    """
    try:
        logger.info("Obteniendo items del Microservicio 1")
        result = call_microservice_1('/items', method='GET')
        
        return jsonify({
            'status': 'success',
            'service': 'microservice-2',
            'source': 'microservice-1',
            'data': result.get('data', []),
            'count': result.get('count', 0)
        }), 200
    
    except requests.exceptions.ConnectionError as e:
        logger.error(f"No se puede conectar al Microservicio 1: {e}")
        return jsonify({
            'status': 'error',
            'message': 'El Microservicio 1 no está disponible',
            'details': str(e)
        }), 503
    
    except Exception as e:
        logger.error(f"Error obteniendo items: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/items/<int:item_id>', methods=['GET'])
def get_item(item_id):
    """
    Obtiene un item específico del Microservicio 1
    GET /items/{id}
    """
    try:
        logger.info(f"Obteniendo item {item_id} del Microservicio 1")
        result = call_microservice_1(f'/items/{item_id}', method='GET')
        
        return jsonify({
            'status': 'success',
            'service': 'microservice-2',
            'source': 'microservice-1',
            'data': result.get('data')
        }), 200
    
    except requests.exceptions.ConnectionError as e:
        logger.error(f"No se puede conectar al Microservicio 1: {e}")
        return jsonify({
            'status': 'error',
            'message': 'El Microservicio 1 no está disponible',
            'details': str(e)
        }), 503
    
    except Exception as e:
        logger.error(f"Error obteniendo item: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/items', methods=['POST'])
def create_item():
    """
    Crea un nuevo item en el Microservicio 1
    POST /items
    Body: { "name": "...", "description": "..." }
    """
    try:
        data = request.get_json()
        
        if not data or 'name' not in data:
            return jsonify({
                'status': 'error',
                'message': 'El campo "name" es requerido'
            }), 400
        
        logger.info(f"Creando item: {data.get('name')}")
        result = call_microservice_1('/items', method='POST', data=data)
        
        return jsonify({
            'status': 'success',
            'service': 'microservice-2',
            'source': 'microservice-1',
            'message': 'Item creado exitosamente',
            'data': result.get('data')
        }), 201
    
    except requests.exceptions.ConnectionError as e:
        logger.error(f"No se puede conectar al Microservicio 1: {e}")
        return jsonify({
            'status': 'error',
            'message': 'El Microservicio 1 no está disponible',
            'details': str(e)
        }), 503
    
    except Exception as e:
        logger.error(f"Error creando item: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/items/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    """
    Actualiza un item en el Microservicio 1
    PUT /items/{id}
    """
    try:
        data = request.get_json()
        
        logger.info(f"Actualizando item {item_id}")
        result = call_microservice_1(f'/items/{item_id}', method='PUT', data=data)
        
        return jsonify({
            'status': 'success',
            'service': 'microservice-2',
            'source': 'microservice-1',
            'message': 'Item actualizado exitosamente',
            'data': result.get('data')
        }), 200
    
    except requests.exceptions.ConnectionError as e:
        logger.error(f"No se puede conectar al Microservicio 1: {e}")
        return jsonify({
            'status': 'error',
            'message': 'El Microservicio 1 no está disponible',
            'details': str(e)
        }), 503
    
    except Exception as e:
        logger.error(f"Error actualizando item: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/items/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    """
    Elimina un item en el Microservicio 1
    DELETE /items/{id}
    """
    try:
        logger.info(f"Eliminando item {item_id}")
        result = call_microservice_1(f'/items/{item_id}', method='DELETE')
        
        return jsonify({
            'status': 'success',
            'service': 'microservice-2',
            'source': 'microservice-1',
            'message': 'Item eliminado exitosamente'
        }), 200
    
    except requests.exceptions.ConnectionError as e:
        logger.error(f"No se puede conectar al Microservicio 1: {e}")
        return jsonify({
            'status': 'error',
            'message': 'El Microservicio 1 no está disponible',
            'details': str(e)
        }), 503
    
    except Exception as e:
        logger.error(f"Error eliminando item: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/proxy/info', methods=['GET'])
def proxy_info():
    """Información sobre la configuración de proxy"""
    return jsonify({
        'service': 'microservice-2',
        'microservice_1_url': MICROSERVICE_1_URL,
        'microservice_1_host': MICROSERVICE_1_HOST,
        'microservice_1_port': MICROSERVICE_1_PORT,
        'request_timeout': REQUEST_TIMEOUT,
        'max_retries': MAX_RETRIES
    }), 200

@app.errorhandler(404)
def not_found(error):
    """Manejador para rutas no encontradas"""
    return jsonify({
        'status': 'error',
        'message': 'Ruta no encontrada'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Manejador para errores internos del servidor"""
    return jsonify({
        'status': 'error',
        'message': 'Error interno del servidor'
    }), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    logger.info(f"Iniciando Microservicio 2 en puerto {port}")
    logger.info(f"Conectando a Microservicio 1 en: {MICROSERVICE_1_URL}")
    app.run(host='0.0.0.0', port=port, debug=os.getenv('FLASK_ENV') == 'development')
