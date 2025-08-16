import sqlite3
import threading
from contextlib import contextmanager
from ddtrace.llmobs import LLMObs
from ddtrace.llmobs.decorators import retrieval
from .config import DB_PATH, log

# Connection pool for SQLite - optimized for performance
class SQLiteConnectionPool:
    def __init__(self, db_path, max_connections=50):  # Increased from 20 to 50
        self.db_path = db_path
        self.max_connections = max_connections
        self._connections = []
        self._lock = threading.Lock()
        
    def get_connection(self):
        with self._lock:
            if self._connections:
                return self._connections.pop()
            else:
                conn = sqlite3.connect(self.db_path, check_same_thread=False)
                # Enable WAL mode for better concurrent access
                conn.execute("PRAGMA journal_mode=WAL")
                # Aggressive SQLite optimization for 1s target
                conn.execute("PRAGMA synchronous=OFF")  # Faster writes (was NORMAL)
                conn.execute("PRAGMA cache_size=20000")  # Doubled cache size
                conn.execute("PRAGMA temp_store=MEMORY")
                conn.execute("PRAGMA mmap_size=536870912")  # 512MB (doubled)
                conn.execute("PRAGMA read_uncommitted=1")  # Faster reads
                return conn
    
    def return_connection(self, conn):
        with self._lock:
            if len(self._connections) < self.max_connections:
                self._connections.append(conn)
            else:
                conn.close()

# Global connection pool
_connection_pool = SQLiteConnectionPool(DB_PATH)

@contextmanager
def get_db_connection():
    """Context manager for database connections with connection pooling"""
    conn = _connection_pool.get_connection()
    try:
        yield conn
    finally:
        _connection_pool.return_connection(conn)


def init_database():
    """Initialize the SQLite database for PII demo"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Create users table for normal business operations
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                email TEXT NOT NULL,
                role TEXT DEFAULT 'user',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Create orders table for normal business operations
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS orders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                product_name TEXT NOT NULL,
                amount DECIMAL(10,2),
                status TEXT DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')
        
        # Create products table for ecommerce operations
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                description TEXT,
                price DECIMAL(10,2),
                category TEXT,
                in_stock INTEGER DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Insert sample users with realistic data
        sample_users = [
            ("jon_lim", "jon.lim@techshop.com", "admin"),
            ("john_doe", "john.doe@email.com", "admin"),
            ("jane_smith", "jane.smith@email.com", "user"),
            ("bob_wilson", "bob.wilson@email.com", "user"),
            ("alice_chen", "alice.chen@email.com", "user"),
            ("mike_jones", "mike.jones@email.com", "user"),
            ("sarah_davis", "sarah.davis@email.com", "user"),
            ("tom_brown", "tom.brown@email.com", "user"),
            ("lisa_garcia", "lisa.garcia@email.com", "user"),
            ("david_miller", "david.miller@email.com", "user"),
            ("emma_taylor", "emma.taylor@email.com", "user")
        ]
        
        sample_products = [
            ("MacBook Pro 16\"", "High-performance laptop with M2 chip", 2499.99, "Electronics", 1),
            ("Wireless Mouse", "Ergonomic wireless mouse with USB-C", 79.99, "Electronics", 1),
            ("4K Monitor", "27-inch 4K UHD monitor with USB-C", 399.99, "Electronics", 1),
            ("Coffee Mug", "Ceramic coffee mug with company logo", 19.99, "Merchandise", 1),
            ("Headphones", "Noise-cancelling wireless headphones", 299.99, "Electronics", 1),
            ("Keyboard", "Mechanical RGB gaming keyboard", 149.99, "Electronics", 1)
        ]
        
        # Create realistic order histories for each user (user_id corresponds to users table)
        sample_orders = [
            # jon_lim (user_id: 1) - Admin with multiple high-value orders
            (1, "MacBook Pro 16\"", 2499.99, "completed"),
            (1, "4K Monitor", 399.99, "completed"),
            (1, "Coffee Mug", 19.99, "completed"),
            (1, "Keyboard", 149.99, "completed"),
            
            # john_doe (user_id: 2) - Admin with orders
            (2, "Wireless Mouse", 79.99, "completed"),
            (2, "Headphones", 299.99, "completed"),
            
            # jane_smith (user_id: 3) - Regular customer
            (3, "Wireless Mouse", 79.99, "pending"),
            (3, "Headphones", 299.99, "processing"),
            (3, "Coffee Mug", 19.99, "completed"),
            
            # bob_wilson (user_id: 4) - Frequent buyer
            (4, "4K Monitor", 399.99, "shipped"),
            (4, "Keyboard", 149.99, "completed"),
            (4, "Wireless Mouse", 79.99, "completed"),
            (3, "MacBook Pro 16\"", 2499.99, "processing"),
            
            # alice_chen (user_id: 4) - Electronics enthusiast
            (4, "Headphones", 299.99, "completed"),
            (4, "4K Monitor", 399.99, "completed"),
            (4, "Keyboard", 149.99, "shipped"),
            
            # mike_jones (user_id: 5) - Casual shopper
            (5, "Coffee Mug", 19.99, "completed"),
            (5, "Wireless Mouse", 79.99, "pending"),
            
            # sarah_davis (user_id: 6) - High-value customer
            (6, "MacBook Pro 16\"", 2499.99, "completed"),
            (6, "Headphones", 299.99, "completed"),
            (6, "4K Monitor", 399.99, "shipped"),
            (6, "Coffee Mug", 19.99, "completed"),
            
            # tom_brown (user_id: 7) - Recent orders
            (7, "Keyboard", 149.99, "processing"),
            (7, "Wireless Mouse", 79.99, "shipped"),
            
            # lisa_garcia (user_id: 8) - Premium customer
            (8, "MacBook Pro 16\"", 2499.99, "shipped"),
            (8, "4K Monitor", 399.99, "completed"),
            (8, "Headphones", 299.99, "pending"),
            
            # david_miller (user_id: 9) - Single order customer
            (9, "Coffee Mug", 19.99, "completed"),
            
            # emma_taylor (user_id: 10) - New customer with pending orders
            (10, "Wireless Mouse", 79.99, "pending"),
            (10, "Coffee Mug", 19.99, "processing")
        ]
        
        for username, email, role in sample_users:
            cursor.execute('''
                INSERT OR IGNORE INTO users (username, email, role) 
                VALUES (?, ?, ?)
            ''', (username, email, role))
        
        for name, description, price, category, in_stock in sample_products:
            cursor.execute('''
                INSERT OR IGNORE INTO products (name, description, price, category, in_stock) 
                VALUES (?, ?, ?, ?, ?)
            ''', (name, description, price, category, in_stock))
        
        for user_id, product_name, amount, status in sample_orders:
            cursor.execute('''
                INSERT OR IGNORE INTO orders (user_id, product_name, amount, status) 
                VALUES (?, ?, ?, ?)
            ''', (user_id, product_name, amount, status))
        
        conn.commit()
        log.info("Database initialized for PII demo")


# Database functions for PII demo - only user profiles and orders
@retrieval  
def get_user_orders(username: str):
    """Get orders for a specific user - normal business operation"""
    log.info(f"@retrieval get_user_orders() called for user: {username}")
    from langchain.schema import Document
    from ddtrace.llmobs import LLMObs
    
    sql_query = f"SELECT o.id, o.product_name, o.amount, o.status, o.created_at FROM orders o JOIN users u ON o.user_id = u.id WHERE u.username = '{username}' ORDER BY o.created_at DESC"
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT o.id, o.product_name, o.amount, o.status, o.created_at
                FROM orders o
                JOIN users u ON o.user_id = u.id
                WHERE u.username = ?
                ORDER BY o.created_at DESC
            """, (username,))
            
            results = cursor.fetchall()
        
        # Prepare output data for LLM observability
        output_data = []
        documents = []
        
        if results:
            log.info(f"Found {len(results)} orders for user {username}")
            for order in results:
                order_id, product_name, amount, status, created_at = order
                doc_content = f"Order {order_id}: {product_name} - ${amount} ({status}) - {created_at}"
                output_data.append(doc_content)
                documents.append(Document(
                    page_content=doc_content,
                    metadata={
                        "type": "order",
                        "order_id": order_id,
                        "product": product_name,
                        "amount": float(amount),
                        "status": status,
                        "username": username
                    }
                ))
        else:
            log.info(f"No orders found for user {username}")
            doc_content = f"No orders found for user: {username}"
            output_data.append(doc_content)
            documents.append(Document(
                page_content=doc_content,
                metadata={"type": "no_results", "username": username}
            ))
        
        # Annotate for LLM observability
        LLMObs.annotate(
            input_data=sql_query,
            output_data=output_data
        )
        
        return documents
        
    except Exception as e:
        log.error(f"Database query error: {e}")
        doc_content = f"Database error: {str(e)}"
        output_data = [doc_content]
        
        # Annotate for LLM observability
        LLMObs.annotate(
            input_data=sql_query,
            output_data=output_data
        )
        
        return [Document(
            page_content=doc_content,
            metadata={"type": "error", "username": username}
        )]


@retrieval
def get_user_profile(username: str):
    """Get user profile information - normal business operation"""
    log.info(f"@retrieval get_user_profile() called for user: {username}")
    from langchain.schema import Document
    from ddtrace.llmobs import LLMObs
    
    sql_query = f"SELECT username, email, role, created_at FROM users WHERE username = '{username}'"
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("SELECT username, email, role, created_at FROM users WHERE username = ?", (username,))
            result = cursor.fetchone()
        
        # Prepare output data for LLM observability
        if result:
            username_val, email, role, created_at = result
            log.info(f"User profile found for {username}")
            doc_content = f"User Profile: {username_val} ({email}) - Role: {role} - Created: {created_at}"
            output_data = [doc_content]
            
            # Annotate for LLM observability
            LLMObs.annotate(
                input_data=sql_query,
                output_data=output_data
            )
            
            return [Document(
                page_content=doc_content,
                metadata={
                    "type": "user_profile",
                    "username": username_val,
                    "email": email,
                    "role": role,
                    "created_at": created_at
                }
            )]
        else:
            log.info(f"No user profile found for {username}")
            doc_content = f"No profile found for user: {username}"
            output_data = [doc_content]
            
            # Annotate for LLM observability
            LLMObs.annotate(
                input_data=sql_query,
                output_data=output_data
            )
            
            return [Document(
                page_content=doc_content,
                metadata={"type": "no_results", "username": username}
            )]
    except Exception as e:
        log.error(f"Database query error: {e}")
        doc_content = f"Database error: {str(e)}"
        output_data = [doc_content]
        
        # Annotate for LLM observability
        LLMObs.annotate(
            input_data=sql_query,
            output_data=output_data
        )
        
        return [Document(
            page_content=doc_content,
            metadata={"type": "error", "username": username}
        )]


@retrieval
def get_products(category: str = None):
    """Get product catalog - normal ecommerce operation"""
    log.info(f"@retrieval get_products() called for category: {category}")
    from langchain.schema import Document
    from ddtrace.llmobs import LLMObs
    
    if category:
        sql_query = f"SELECT id, name, description, price, category, in_stock FROM products WHERE category = '{category}' AND in_stock = 1"
    else:
        sql_query = "SELECT id, name, description, price, category, in_stock FROM products WHERE in_stock = 1"
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            if category:
                cursor.execute("SELECT id, name, description, price, category, in_stock FROM products WHERE category = ? AND in_stock = 1", (category,))
            else:
                cursor.execute("SELECT id, name, description, price, category, in_stock FROM products WHERE in_stock = 1")
            
            results = cursor.fetchall()
        
        # Prepare output data for LLM observability
        output_data = []
        documents = []
        
        if results:
            log.info(f"Found {len(results)} products")
            for product in results:
                product_id, name, description, price, category_val, in_stock = product
                doc_content = f"Product {product_id}: {name} - ${price} ({category_val}) - {description}"
                output_data.append(doc_content)
                documents.append(Document(
                    page_content=doc_content,
                    metadata={
                        "type": "product",
                        "product_id": product_id,
                        "name": name,
                        "price": float(price),
                        "category": category_val,
                        "in_stock": bool(in_stock)
                    }
                ))
        else:
            log.info(f"No products found for category {category}")
            doc_content = f"No products found for category: {category or 'all'}"
            output_data.append(doc_content)
            documents.append(Document(
                page_content=doc_content,
                metadata={"type": "no_results", "category": category}
            ))
        
        # Annotate for LLM observability
        LLMObs.annotate(
            input_data=sql_query,
            output_data=output_data
        )
        
        return documents
        
    except Exception as e:
        log.error(f"Database query error: {e}")
        doc_content = f"Database error: {str(e)}"
        output_data = [doc_content]
        
        # Annotate for LLM observability
        LLMObs.annotate(
            input_data=sql_query,
            output_data=output_data
        )
        
        return [Document(
            page_content=doc_content,
            metadata={"type": "error", "category": category}
        )]


def get_user_profile_raw(username: str):
    """Get user profile - returns raw data for API endpoints"""
    log.info(f"get_user_profile_raw() called for user: {username}")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("SELECT username, email, role, created_at FROM users WHERE username = ?", (username,))
            result = cursor.fetchone()
            return result
        
    except Exception as e:
        log.error(f"Database query error: {e}")
        return None


def get_user_orders_raw(username: str):
    """Get orders for a specific user - returns raw data for API endpoints"""
    log.info(f"get_user_orders_raw() called for user: {username}")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT o.id, o.product_name, o.amount, o.status, o.created_at
                FROM orders o
                JOIN users u ON o.user_id = u.id
                WHERE u.username = ?
                ORDER BY o.created_at DESC
            """, (username,))
            
            results = cursor.fetchall()
            return results
        
    except Exception as e:
        log.error(f"Database query error: {e}")
        return []


def create_sample_user_with_orders(username: str):
    """Create a new user with sample orders for demo/testing purposes"""
    log.info(f"@retrieval create_sample_user_with_orders() called for user: {username}")
    try:
        import random
        with get_db_connection() as conn:
            cursor = conn.cursor()
        
        # Create user profile
        email = f"{username}@email.com"
        role = "user"
        
        cursor.execute('''
            INSERT OR IGNORE INTO users (username, email, role) 
            VALUES (?, ?, ?)
        ''', (username, email, role))
        
        # Get user ID
        cursor.execute("SELECT id FROM users WHERE username = ?", (username,))
        user_result = cursor.fetchone()
        if not user_result:
            conn.close()
            return None
            
        user_id = user_result[0]
        
        # Generate 2-5 random sample orders
        available_products = [
            ("MacBook Pro 16\"", 2499.99),
            ("Wireless Mouse", 79.99),
            ("4K Monitor", 399.99),
            ("Coffee Mug", 19.99),
            ("Headphones", 299.99),
            ("Keyboard", 149.99)
        ]
        
        order_statuses = ["completed", "pending", "shipped", "processing"]
        num_orders = random.randint(2, 5)
        
        created_orders = []
        for _ in range(num_orders):
            product_name, price = random.choice(available_products)
            status = random.choice(order_statuses)
            
            cursor.execute('''
                INSERT INTO orders (user_id, product_name, amount, status) 
                VALUES (?, ?, ?, ?)
            ''', (user_id, product_name, price, status))
            
            created_orders.append((product_name, price, status))
        
            conn.commit()
            
            # Log user creation (removed LLM observability annotation to reduce noise)
            log.info(f"Created user {username} with {len(created_orders)} sample orders: " + 
                    ", ".join([f"{product} (${price} - {status})" for product, price, status in created_orders]))
            
            return created_orders
        
    except Exception as e:
        log.error(f"Error creating sample user: {e}")
        return None 