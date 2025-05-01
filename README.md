# Kiosk System

## Idea And Flow

## Server
1. Firestore as server and database
2. local server + ngrok

## Kiosk Inventory Management Flow

### **1. Inventory Structure**
The kiosk sells two types of items:
1. **Frozen** - Received directly from the factory
2. **Goreng (Fried)** - Made from frozen stock at the kiosk

#### **Frozen Inventory**
- Factory delivers frozen stock in packs.
- Some products come in multiple package sizes (e.g., Popia: 8 pcs, 50 pcs).
- Stored in the `frozen_inventory` table.

#### **Goreng Inventory**
- Created when employees take frozen stock for frying.
- Deducts from the `frozen_inventory` table.
- Stored in the `kiosk_product` table.

---

### **2. Database Tables**

### **Kiosk Product Table (`kiosk_product`)**
Tracks both frozen and goreng inventory.

| Column            | Type    | Description                                     |
|------------------|--------|-------------------------------------------------|
| id               | INTEGER | Unique ID                                       |
| frozen_id        | INTEGER | Links to `frozen_inventory` for stock tracking |
| product_name     | TEXT    | Name of the item                                |
| shortform | TEXT | Shortform of the product name |
| picture | BLOB | Pictures Blob |
| category         | TEXT    | Category (POPIA, KUEH, etc.)                    |
| price           | REAL    | Selling price                                   |
| total_stocks      | INTEGER | Number of items available                       |
| total_pieces     | INTEGER | Number of pieces per item (for tracking)       |
| total_pieces_used | INTEGER | Pieces used when converting to Goreng          |
| exist | INTEGER | Bool check for exist or not |

**Goreng products will be linked to `frozen_inventory` through `frozen_id` to deduct stock.**

### **Set Product Table (`set_product`)**
Stores information about predefined sets.

| Column   | Type    | Description            |
|---------|--------|------------------------|
| id      | INTEGER | Unique ID              |
| name | TEXT   | Name of the set        |
| price   | REAL    | Selling price          |
| set_items | TEXT | Parameter for items chooser |
| max_quantity | INTEGER | Max quantity items for this set |
| exist | INTEGER | Bool to check set exist or not |

---

## **3. Inventory Management Flow**
### **Receiving Frozen Stock**
1. Factory delivers frozen items to the kiosk.
2. Employee logs the received stock in `kiosk_product`.

### **Converting Package to Piece for (GORENG)**
1. Employee opens a frozen package to use for frying.
2. System creates an entry in `kiosk_product` under total_pieces_used.
3. Kiosk Employee will need to manualy set for total_pieces_used based on how many package employee open. automatically will substract from total_stocks

### **Selling Goreng Items**
1. Customer orders an item or set.
2. If the order contains a mixable set:
   - System prompts cashier to choose items from the allowed mix.
3. Stock is deducted from `kiosk_product`.

### **Handling Sets**
1. When selling a set:
   - Fixed items are directly deducted.
   - Mixable items require selection.
2. Each selected item’s stock is adjusted accordingly.
3. Example String we can use in set_items:
    - String format is like this `PIECE/PACKAGE,kiosk_product.id/kiosk_product.category _QTY,...`
    - `PIECE`: Set is sells in piece, `PACKAGE`: Set is sells in package. Should be set one time in early string
    - Use kiosk_product.category to include all items in that category. If category string contain space, change with #
    1. "1 Corndog + 3 POPIA Mix" -> `"PIECE,15 _1,POPIA#F50 _3"`
    2. "4 POPIA Mix" -> `PIECE,POPIA#F50 _4`
    3. "Corndog Goreng" -> `PIECE,15 PIECE` _means current existed product will be sold in piece_




4. if total quantity set in string not tally with max_quantity, it will be invalid
5. lastly create one function(param: setString, setMaxQty) to get this kind of data for example `setString = "PIECE,15 _1,POPIA#F50 _3"`:
   ```
   {
      "type": "total_pieces_used" //if PIECE change to "total_pieces_used", if PACKAGE change to "total_stocks", 
      "details": [{
         "ids": [15],
         "max_qty": 1
      },
      {
         "ids": [1,2,3,4,..] // all id related to kiosk_product.category (change # to blank space) and find
         "max_qty": 3
      }],
      "total_max_qty": 4 // this is the total of max_qty in details, should tally with "setMaxQty" parameters inside function
   }
   ```

6. For this kiosk, They also will sell a fried(goreng) product from a frozen(`kiosk_product`) database, but for now i dont know how to take fried product from this database (*right now i have created `total_pieces_used` for goreng used*)
   - For now, im thinking to set goreng product in `SET` 

---

## **4. Coupon System**

### **Discount Table (`discount_info`)**
Manages all coupons and discounts for the kiosk.

| Column       | Type    | Description                                       |
|-------------|---------|---------------------------------------------------|
| id          | INTEGER | Unique ID                                         |
| code        | TEXT    | Unique coupon code                                |
| cut_price   | NUMERIC | Fixed amount discount (e.g., $5 off)              |
| cut_percent | NUMERIC | Percentage discount (e.g., 10% off)               |
| product_id  | TEXT    | Specific product IDs this discount applies to     |
| set_id      | TEXT    | Specific set IDs this discount applies to         |
| condition   | TEXT    | Additional conditions (e.g., "min_purchase:50")   |
| usage_count | INTEGER | Count cell for condition total_distribute         |
| exist       | INTEGER | Boolean to check if coupon is active              |

### **Coupon Types**
1. **Amount-based coupons** - Uses `cut_price` (e.g., $5 off total bill)
2. **Percentage-based coupons** - Uses `cut_percent` (e.g., 10% off)
3. **Product-specific coupons** - Uses `product_id` to target specific items
4. **Set-specific coupons** - Uses `set_id` to target specific sets
5. **Conditional coupons** - Uses `condition` field for additional rules

### **Implementing the Coupon System**
1. **Coupon Entry**:
   - Cashier enters the coupon code during checkout
   - System validates the code against `discount_info` table

2. **Coupon Validation**:
   - Check if coupon exists and is active (`exist` = 1)
   - Verify all conditions are met (minimum purchase, etc.)
   - Ensure coupon is applicable to items in cart

3. **Discount Application**:
   - For product-specific coupons: Apply only to matching items
   - For set-specific coupons: Apply only to matching sets
   - For general coupons: Apply to entire purchase

4. **Condition Format**:
   The `condition` field uses a comma-separated key:value format for multiple conditions:
   ```
   min_purchase:50,max_use:1,start_date:2023-05-01,end_date:2023-05-30,time_range:17:00-19:00
   ```
   
   Available conditions:
   - `min_specific_item_purchase:X` - Minimum specicic item need to purchase (based on id either set or product)
   - `min_total_item_purchase:X` - Minimum total item need to purchase
   - `need_to_buy_all_item:0,1` - Need to buy all item listed (1=true, 0=false)
   - `can_buy_either_one:0,1` - Can buy either one in list (1=true, 0=false)
   - `min_price_purchase:X` - Minimum purchase amount (in currency)
   - `max_use:X` - Maximum times this coupon can be used overall
   - `max_use_per_customer:X` - Maximum uses per customer
   - `total_distribute:X` - Coupon total distribute
   - `start_date:YYYY-MM-DD` - Coupon valid from date
   - `end_date:YYYY-MM-DD` - Coupon expires after date
   - `days:1,2,3,4,5` - Valid only on specific days (1=Monday, 7=Sunday)
   - `time_range:HH:MM-HH:MM` - Valid only during specified hours
   - `membership_level:X` - Required membership tier (1=Basic, 2=Premium)
   - `online_generate:0,1` - Need to get pad number or generated number when entering coupon code

5. **Example Scenarios**:
   - 10% off any purchase: Set `cut_percent` to 10
   - $5 off when spending $50+: Set `cut_price` to 5, `condition` to "min_purchase:50"
   - Buy 1 Get 1 Free for Corndog: Implement through `product_id` + logic
   - 15% off any set: Set `cut_percent` to 15, populate `set_id` field

--

## **Example Scenarios**
### **Scenario 1: Selling 1 Corndog + 3 POPIA Mix (Set)**
1. Cashier selects "1 Corndog + 3 POPIA Mix".
2. System loads set details:
   - 1 Corndog (fixed item)
   - 3 POPIA (cashier selects mix from available options).
3. System deducts:
   - 1 Corndog from `kiosk_product`.
   - 3 pieces of selected POPIA from `kiosk_product`.

### **Scenario 2: Employee Opens a Pack of 50 Popia for Goreng**
1. Employee marks **1 pack (50 pcs) as opened**.
2. System creates a Goreng entry in `kiosk_product` with 50 pcs available.
3. `total_stock` in `kiosk_product` reduces by 1 pack.

---



## **Flow for Employee Auth**
1. Kiosk Employee should use setup account
2. Only Kiosk Manager can add Kiosk Employee
3. Kiosk Employee information will be saved locally and cloud (firestore)
4. For Kiosk System Auth
    1. Log in into tablet(Kiosk System), username and password for specific Kiosk will be save in local and cloud
        - If Kiosk Employee or Kiosk Manager want to log in into pos system, the auth will only be done in local (encrypting or not?) using Kiosk Account
        - If Kiosk Employee or Main Company want to adjust password for certain Kiosk Account, it can be done in another app/server and in local side will be update. The update function will always be done before app opened for the first time in that day
    2. After log in into tablet(Kiosk System), each of Kiosk Employee should log in again as attendance system
    3. When kiosk is closing, Kiosk Employees should log out and last employee should log out from Kiosk System and Off the Tablet

