import sqlite3
import os

'''
frozen_inventory:
CREATE TABLE "frozen_inventory" (
	"id"	INTEGER NOT NULL UNIQUE,
	"product_name"	TEXT NOT NULL,
	"category"	TEXT NOT NULL,
	"total_pieces"	INTEGER NOT NULL,
	"total_stocks"	INTEGER NOT NULL,
	"exists"	INTEGER NOT NULL,
	PRIMARY KEY("id" AUTOINCREMENT)
);
'''

'''
kiosk_product:
CREATE TABLE "kiosk_product" (
	"id"	INTEGER NOT NULL UNIQUE,
	"frozen_id"	INTEGER NOT NULL,
	"product_name"	TEXT NOT NULL,
	"picture"	BLOB,
	"category"	TEXT NOT NULL,
	"price"	NUMERIC NOT NULL,
	"total_stocks"	INTEGER NOT NULL,
	"total_pieces"	INTEGER NOT NULL,
	"total_pieces_used"	INTEGER,
	"exist"	INTEGER NOT NULL,
	PRIMARY KEY("id" AUTOINCREMENT),
	FOREIGN KEY("exist") REFERENCES "frozen_inventory"("exists") ON DELETE CASCADE,
	FOREIGN KEY("frozen_id") REFERENCES "frozen_inventory"("id") ON DELETE CASCADE
);
'''

'''
set_product
CREATE TABLE "set_product" (
	"id"	INTEGER NOT NULL UNIQUE,
	"name"	TEXT NOT NULL,
	"price"	REAL NOT NULL,
	"set_items"	TEXT NOT NULL,
	"exist"	INTEGER NOT NULL,
	PRIMARY KEY("id" AUTOINCREMENT)
);
'''
class Database:
    def __init__(self, db_path='kiosk.db'):
        """Initialize database connection"""
        self.db_path = db_path
        self.conn = self._create_connection()
        
    def _create_connection(self):
        """Create a database connection"""
        try:
            conn = sqlite3.connect(self.db_path)
            return conn
        except sqlite3.Error as e:
            print(f"Database connection error: {e}")
            return None
    
    def close(self):
        """Close the database connection"""
        if self.conn:
            self.conn.close()
    
    def insert_product(self, product_name, category, total_pieces, total_stocks, price:float=0, picture=None):
        """
        Insert data into both frozen_inventory and kiosk_product tables
        
        Args:
            product_name (str): Name of the product
            category (str): Product category
            total_pieces (int): Total pieces
            total_stocks (int): Total stocks
            price (float): Product price (for kiosk_product)
            picture (bytes, optional): Product image as BLOB
            
        Returns:
            tuple: (frozen_id, kiosk_id) or (None, None) if insertion failed
        """
        if not self.conn:
            return None, None
        
        cursor = self.conn.cursor()
        
        try:
            # Begin transaction
            self.conn.execute("BEGIN TRANSACTION")
            
            # Insert into frozen_inventory
            frozen_sql = """
            INSERT INTO frozen_inventory (product_name, category, total_pieces, total_stocks, exist)
            VALUES (?, ?, ?, ?, 1)
            """
            cursor.execute(frozen_sql, (product_name, category, total_pieces, total_stocks))
            frozen_id = cursor.lastrowid
            
            # Insert into kiosk_product
            kiosk_sql = """
            INSERT INTO kiosk_product 
            (frozen_id, product_name, picture, category, price, total_stocks, total_pieces, total_pieces_used, exist)
            VALUES (?, ?, ?, ?, ?, ?, ?, 0, 1)
            """
            cursor.execute(kiosk_sql, 
                         (frozen_id, product_name, picture, category, price, total_stocks, total_pieces))
            kiosk_id = cursor.lastrowid
            
            # Commit transaction
            self.conn.commit()
            return frozen_id, kiosk_id
            
        except sqlite3.Error as e:
            # Rollback in case of error
            self.conn.rollback()
            print(f"Database insertion error: {e}")
            return None, None
   
   
    
    def update_product(self, frozen_id, product_name=None, category=None, 
                      total_pieces=None, total_stocks=None, price=None, picture=None):
        """
        Update product data in both tables
        
        Args:
            frozen_id (int): ID of the frozen inventory item
            product_name, category, total_pieces, total_stocks, price, picture: Fields to update
            
        Returns:
            bool: Success status
        """
        if not self.conn:
            return False
            
        cursor = self.conn.cursor()
        try:
            self.conn.execute("BEGIN TRANSACTION")
            
            # Update frozen_inventory table
            update_parts = []
            params = []
            
            if product_name is not None:
                update_parts.append("product_name = ?")
                params.append(product_name)
            if category is not None:
                update_parts.append("category = ?")
                params.append(category)
            if total_pieces is not None:
                update_parts.append("total_pieces = ?")
                params.append(total_pieces)
            if total_stocks is not None:
                update_parts.append("total_stocks = ?")
                params.append(total_stocks)
                
            if update_parts:
                frozen_sql = f"UPDATE frozen_inventory SET {', '.join(update_parts)} WHERE id = ?"
                params.append(frozen_id)
                cursor.execute(frozen_sql, params)
            
            # Update kiosk_product table
            update_parts = []
            params = []
            
            if product_name is not None:
                update_parts.append("product_name = ?")
                params.append(product_name)
            if category is not None:
                update_parts.append("category = ?")
                params.append(category)
            if total_pieces is not None:
                update_parts.append("total_pieces = ?")
                params.append(total_pieces)
            if total_stocks is not None:
                update_parts.append("total_stocks = ?")
                params.append(total_stocks)
            if price is not None:
                update_parts.append("price = ?")
                params.append(price)
            if picture is not None:
                update_parts.append("picture = ?")
                params.append(picture)
                
            if update_parts:
                kiosk_sql = f"UPDATE kiosk_product SET {', '.join(update_parts)} WHERE frozen_id = ?"
                params.append(frozen_id)
                cursor.execute(kiosk_sql, params)
            
            self.conn.commit()
            return True
            
        except sqlite3.Error as e:
            self.conn.rollback()
            print(f"Database update error: {e}")
            return False


def run():
    # Initialize database
    db = Database(db_path=r"D:\Coding\Big Project\Mobile App\kiosk_system\assets\db\app.db")
    
    # Check if file exists
    if not db.conn:
        print("Database connection failed.")
        return
    
    # Path to the product text file
    product_file_path = r"D:\Coding\Big Project\Mobile App\kiosk_system\test-script\python\product.txt"
    
    if not os.path.exists(product_file_path):
        print(f"Product file not found: {product_file_path}")
        return
    
    with open(product_file_path, 'r') as file:
            for line in file:
                # Skip empty lines
                if not line.strip():
                    continue
                
                # Parse product data (name, category, pieces, stocks, price)
                parts = line.strip().split(',')
                if len(parts) >= 5:
                    product_name = parts[0]
                    category = parts[1]
                    total_pieces = int(parts[2])
                    total_stocks = int(parts[3])
                    price = float(parts[4])
                    
                    # Insert product into database
                    frozen_id, kiosk_id = db.insert_product(
                        product_name, category, total_pieces, total_stocks, price
                    )
                    print(f"Added: {product_name} - IDs: {frozen_id}, {kiosk_id}")
                else:
                    print(f"Invalid product format: {line.strip()}")
        
    print("All products have been imported.")

    
    # Close database connection
    db.close()
    

if __name__ == "__main__":
    run()