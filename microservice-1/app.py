"""
Microservicio 1: CRUD de Items
Proporciona endpoints para crear y obtener items almacenados en PostgreSQL
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import os
import logging
from datetime import datetime

# Configuración de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuración de base de datos desde variables de entorno
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'microservices_db')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'postgres')

def get_db_connection():
    """Crea una conexión a la base de datos PostgreSQL"""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except psycopg2.OperationalError as e:
        logger.error(f"Error conectando a la base de datos: {e}")
        raise

def init_db():
    """Inicializa la base de datos creando la tabla si no existe"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Crear tabla items
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        logger.info("Base de datos inicializada correctamente")
    except Exception as e:
        logger.error(f"Error inicializando la base de datos: {e}")
        raise

@app.before_request
def before_request():
    """Hook que se ejecuta antes de cada request"""
    pass

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de health check"""
    return jsonify({
        'status': 'healthy',
        'service': 'microservice-1',
        'timestamp': datetime.now().isoformat()
    }), 200

@app.route('/items', methods=['GET'])
def get_items():
    """
    Obtiene todos los items de la base de datos
    GET /items
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("SELECT id, name, description, created_at FROM items ORDER BY created_at DESC")
        items = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        logger.info(f"Se obtuvieron {len(items)} items")
        return jsonify({
            'status': 'success',
            'data': items,
            'count': len(items)
        }), 200
        
    except Exception as e:
        logger.error(f"Error obteniendo items: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/items/<int:item_id>', methods=['GET'])
def get_item(item_id):
    """
    Obtiene un item específico por ID
    GET /items/{id}
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("SELECT id, name, description, created_at FROM items WHERE id = %s", (item_id,))
        item = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if item is None:
            return jsonify({
                'status': 'error',
                'message': f'Item con ID {item_id} no encontrado'
            }), 404
        
        logger.info(f"Item obtenido: {item_id}")
        return jsonify({
            'status': 'success',
            'data': item
        }), 200
        
    except Exception as e:
        logger.error(f"Error obteniendo item: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/items', methods=['POST'])
def create_item():
    """
    Crea un nuevo item en la base de datos
    POST /items
    Requerido: name (string)
    Opcional: description (string)
    """
    try:
        data = request.get_json()
        
        # Validación
        if not data or 'name' not in data:
            return jsonify({
                'status': 'error',
                'message': 'El campo "name" es requerido'
            }), 400
        
        name = data.get('name')
        description = data.get('description', '')
        
        if not name or not isinstance(name, str):
            return jsonify({
                'status': 'error',
                'message': 'El campo "name" debe ser una cadena no vacía'
            }), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            "INSERT INTO items (name, description) VALUES (%s, %s) RETURNING id, name, description, created_at",
            (name, description)
        )
        
        new_item = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Item creado: {new_item[0]} - {name}")
        return jsonify({
            'status': 'success',
            'message': 'Item creado exitosamente',
            'data': {
                'id': new_item[0],
                'name': new_item[1],
                'description': new_item[2],
                'created_at': new_item[3].isoformat() if new_item[3] else None
            }
        }), 201
        
    except Exception as e:
        logger.error(f"Error creando item: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/items/<int:item_id>', methods=['PUT'])
def update_item(item_id):
    """
    Actualiza un item existente
    PUT /items/{id}
    """
    try:
        data = request.get_json()
        
        if not data or ('name' not in data and 'description' not in data):
            return jsonify({
                'status': 'error',
                'message': 'Al menos un campo debe ser proporcionado'
            }), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Verificar que el item existe
        cursor.execute("SELECT id FROM items WHERE id = %s", (item_id,))
        if cursor.fetchone() is None:
            cursor.close()
            conn.close()
            return jsonify({
                'status': 'error',
                'message': f'Item con ID {item_id} no encontrado'
            }), 404
        
        # Actualizar campos proporcionados
        updates = []
        params = []
        
        if 'name' in data:
            updates.append("name = %s")
            params.append(data['name'])
        
        if 'description' in data:
            updates.append("description = %s")
            params.append(data['description'])
        
        params.append(item_id)
        
        query = f"UPDATE items SET {', '.join(updates)} WHERE id = %s RETURNING id, name, description, created_at"
        cursor.execute(query, params)
        updated_item = cursor.fetchone()
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Item actualizado: {item_id}")
        return jsonify({
            'status': 'success',
            'message': 'Item actualizado exitosamente',
            'data': {
                'id': updated_item[0],
                'name': updated_item[1],
                'description': updated_item[2],
                'created_at': updated_item[3].isoformat() if updated_item[3] else None
            }
        }), 200
        
    except Exception as e:
        logger.error(f"Error actualizando item: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/items/<int:item_id>', methods=['DELETE'])
def delete_item(item_id):
    """
    Elimina un item por ID
    DELETE /items/{id}
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM items WHERE id = %s RETURNING id", (item_id,))
        deleted = cursor.fetchone()
        
        conn.commit()
        cursor.close()
        conn.close()
        
        if deleted is None:
            return jsonify({
                'status': 'error',
                'message': f'Item con ID {item_id} no encontrado'
            }), 404
        
        logger.info(f"Item eliminado: {item_id}")
        return jsonify({
            'status': 'success',
            'message': 'Item eliminado exitosamente'
        }), 200
        
    except Exception as e:
        logger.error(f"Error eliminando item: {e}")
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

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
    # Inicializar la base de datos
    try:
        init_db()
    except Exception as e:
        logger.error(f"No se pudo inicializar la base de datos: {e}")
    
    # Ejecutar la aplicación
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=os.getenv('FLASK_ENV') == 'development')
