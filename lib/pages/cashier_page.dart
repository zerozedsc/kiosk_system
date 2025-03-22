import '../configs/configs.dart';
import '../services/inventory/inventory_services.dart';
import '../services/cashier/cashier_services.dart';

// components
import '../components/toastmsg.dart';
import '../components/numpad.dart';
import '../components/image.dart';
import '../components/buttonswithsound.dart';

import 'package:intl/intl.dart';

class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  _CashierPageState createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  // init variable
  bool firstLoad = true;
  bool _isLoading = false;

  // cashier variable
  int currentOrderId = 1; // Order ID tracking variable
  String selectedCategory = "";
  List<String> categories = [];
  List<Map<String, dynamic>> productsStream = [];
  List<Map<String, dynamic>> cart = [];
  Map<String, dynamic> receiptData = {};
  Map<int, dynamic> outOfStockItems = {};

  // Add this method to reload product data
  Future<void> _loadProductsData() async {
    try {
      setState(
        () => _isLoading = true,
      ); // Optional: add a loading state variable

      if (firstLoad) {
        CASHIER_LOGS =
            await LoggingService(logName: "cashier_logs").initialize();
      }

      currentOrderId = await getLatestTransactionId() + 1;

      List<Map<String, dynamic>> loadedProducts =
          await inventory.getAllProductsAndSets();

      // Extract unique categories from productsStream
      Set<String> uniqueCategories = {};
      for (var product in loadedProducts) {
        if (product["categories"] != null) {
          for (var category in product["categories"]) {
            uniqueCategories.add(category);
            continue;
          }
        }

        if (product.containsKey("set") && product["set"] != null) {
          uniqueCategories.add("SET");
          break;
        }
      }

      setState(() {
        productsStream = loadedProducts;
        categories = uniqueCategories.toList();
        // Keep the current category if it exists in the updated categories
        if (!categories.contains(selectedCategory) && categories.isNotEmpty) {
          selectedCategory = categories[0];
        }
        _isLoading = false; // Optional: if you added a loading state
      });

      CASHIER_LOGS.info('Products reloaded: ${productsStream.length} items');
    } catch (e) {
      CASHIER_LOGS.error('Error reloading products', e, StackTrace.current);
      showToastMessage(
        context,
        '${LOCALIZATION.localize("cashier_page.error_loading_products")}\n\n$e',
        ToastLevel.error,
        position: ToastPosition.topRight,
      );

      setState(
        () => _isLoading = false,
      ); // Optional: if you added a loading state
    }
  }

  // init function
  @override
  void initState() {
    super.initState();
    _loadProductsData();
    firstLoad = false;
  }

  void addToCart(Map<String, dynamic> product) {
    setState(() {
      // Check if the product already exists in the cart
      int existingIndex = cart.indexWhere(
        (item) => item["name"] == product["name"],
      );
      AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
      if (existingIndex >= 0) {
        // Product already exists, increase quantity
        increaseQuantity(cart[existingIndex]);
      } else {
        // New product, add to cart with quantity 1
        Map<String, dynamic> newItem = {...product, "quantity": 1};
        newItem = processItem(newItem);
        cart.add(newItem);
      }
    });
  }

  void removeFromCart(int index) {
    setState(() {
      cart.removeAt(index);
    });
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children:
              categories.map((category) {
                bool isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await AudioManager().playSound(
                            soundPath: 'assets/sounds/click.mp3',
                          );
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? primaryColor : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : Colors.grey.shade800,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  void _showDialogForSet(Map<String, dynamic> setDetail, String setType) {
    // Extract set details and initialize selection tracking

    List<Map<String, dynamic>> setDetails = List<Map<String, dynamic>>.from(
      setDetail['details'] ?? [],
    );
    Map<int, int> selectedQuantities =
        {}; // Map to track product ID -> quantity selected
    int totalSelectedQuantity = 0;
    int totalMaxQuantity = setDetail['total_max_qty'] ?? 0;
    String setType = setDetail['set'];

    // Get group names from inventory.setCatalog
    List<String> groupNames = [];
    if (inventory.setCatalog != null &&
        inventory.setCatalog!.containsKey(setDetail['id'])) {
      String? groupNamesStr =
          inventory.setCatalog![setDetail['id']]!['group_names'];
      if (groupNamesStr != null && groupNamesStr.isNotEmpty) {
        groupNames = groupNamesStr.split(',');
      }
    }

    // Find matching products for each set item based on the IDs in details
    List<List<Map<String, dynamic>>> setOptionsGroups = [];

    for (var detail in setDetails) {
      List<int> ids = List<int>.from(detail['ids'] ?? []);
      int maxQty = detail['max_qty'] ?? 0;

      List<Map<String, dynamic>> matchingProducts = [];
      for (int id in ids) {
        if (inventory.productCatalog!.containsKey(id)) {
          Map<String, dynamic> itemWithQuantity = {
            'id': id,
            ...inventory.productCatalog![id]!,
            'quantity': 0,
          };
          matchingProducts.add(itemWithQuantity);
        }
      }

      // Auto-set quantity for groups with only one product
      if (matchingProducts.length == 1 && maxQty > 0) {
        int id = matchingProducts[0]['id'];
        selectedQuantities[id] = maxQty;
        matchingProducts[0]['quantity'] = maxQty;
        totalSelectedQuantity += maxQty;
      }

      setOptionsGroups.add(matchingProducts);
    }

    final List<int> outOfStockId = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                setDetail['name'] ??
                    LOCALIZATION.localize("cashier_page.set_selection"),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Set description and price
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  setDetail['name'] ?? "",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${LOCALIZATION.localize("cashier_page.select_items")} ($totalSelectedQuantity/$totalMaxQuantity)",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "${globalAppConfig["userPreferences"]["currency"]}${setDetail['price']?.toStringAsFixed(2) ?? '0.00'}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Progress indicator
                    LinearProgressIndicator(
                      value:
                          totalMaxQuantity > 0
                              ? totalSelectedQuantity / totalMaxQuantity
                              : 0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        totalSelectedQuantity == totalMaxQuantity
                            ? Colors.green
                            : primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product selection groups
                    Expanded(
                      child: ListView.builder(
                        itemCount: setOptionsGroups.length,
                        itemBuilder: (context, groupIndex) {
                          final products = setOptionsGroups[groupIndex];
                          final maxQtyForGroup =
                              setDetails[groupIndex]['max_qty'] ?? 0;

                          // Get group name from the list or use default
                          String groupName =
                              groupIndex < groupNames.length
                                  ? groupNames[groupIndex].trim()
                                  : "${LOCALIZATION.localize("cashier_page.group")} ${groupIndex + 1}";

                          // Calculate current selected quantity for this group
                          int groupSelectedQty = 0;
                          for (var product in products) {
                            int id = product['id'] ?? 0;
                            groupSelectedQty += product['quantity'] as int ?? 0;
                          }

                          // Check if this is a single-product group that should be auto-selected
                          bool isSingleItemGroup = products.length == 1;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Group header with name and quantity info
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      groupName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            groupSelectedQty >= maxQtyForGroup
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.grey.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "$groupSelectedQty/$maxQtyForGroup ${LOCALIZATION.localize("main_word.items")}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              groupSelectedQty >= maxQtyForGroup
                                                  ? Colors.green
                                                  : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Product cards in a horizontal scrollable view
                              SizedBox(
                                height: 140,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final item = products[index];
                                    final int id = item['id'] ?? 0;
                                    final int currentQty =
                                        item['quantity'] ?? 0;
                                    final bool isOutOfStock =
                                        ((item[setType] ?? 0) <= 0) ||
                                        (outOfStockItems.containsKey(id) &&
                                            outOfStockItems[id].containsKey(
                                              setType,
                                            ));
                                    final bool reachedGroupMax =
                                        groupSelectedQty >= maxQtyForGroup;

                                    return Container(
                                      width: 120,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              currentQty > 0
                                                  ? primaryColor
                                                  : Colors.grey.shade300,
                                          width: currentQty > 0 ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        color:
                                            isOutOfStock
                                                ? Colors.grey.shade200
                                                : Colors.white,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // Product image
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(7),
                                                  ),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  ColorFiltered(
                                                    colorFilter:
                                                        isOutOfStock
                                                            ? const ColorFilter.matrix(
                                                              [
                                                                0.2126,
                                                                0.7152,
                                                                0.0722,
                                                                0,
                                                                0,
                                                                0.2126,
                                                                0.7152,
                                                                0.0722,
                                                                0,
                                                                0,
                                                                0.2126,
                                                                0.7152,
                                                                0.0722,
                                                                0,
                                                                0,
                                                                0,
                                                                0,
                                                                0,
                                                                1,
                                                                0,
                                                              ],
                                                            )
                                                            : const ColorFilter.mode(
                                                              Colors
                                                                  .transparent,
                                                              BlendMode.srcOver,
                                                            ),
                                                    child: CardImage(
                                                      imageSource:
                                                          item['image'],
                                                      fit: BoxFit.cover,
                                                      backgroundColor:
                                                          Colors.grey[300],
                                                      placeholderWidget:
                                                          const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                              size: 30,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  if (isOutOfStock)
                                                    Container(
                                                      color: Colors.black
                                                          .withOpacity(0.5),
                                                      child: Center(
                                                        child: Text(
                                                          LOCALIZATION.localize(
                                                            "cashier_page.no_stock",
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Product name and quantity controls
                                          Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  item['shortform'] ??
                                                      item['name'],
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 4),

                                                // Hide quantity controls for single-item groups
                                                // or display larger controls for multi-item groups
                                                if (!isSingleItemGroup)
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      // Decrease button - enlarged
                                                      InkWell(
                                                        onTap: () async {
                                                          await AudioManager()
                                                              .playSound(
                                                                soundPath:
                                                                    'assets/sounds/click.mp3',
                                                              );
                                                          if (currentQty > 0) {
                                                            setState(() {
                                                              item['quantity'] =
                                                                  currentQty -
                                                                  1;
                                                              if (outOfStockItems
                                                                      .containsKey(
                                                                        item["id"],
                                                                      ) &&
                                                                  outOfStockItems[item["id"]]
                                                                      ?.containsKey(
                                                                        item["type"],
                                                                      )) {
                                                                outOfStockItems[item["id"]]
                                                                    .remove(
                                                                      item["type"],
                                                                    );
                                                              }
                                                              selectedQuantities[id] =
                                                                  item['quantity'];
                                                              totalSelectedQuantity--;
                                                            });
                                                          }
                                                        },

                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6, // Increased from 2
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                currentQty > 0
                                                                    ? primaryColor
                                                                    : Colors
                                                                        .grey
                                                                        .shade300,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6, // Increased from 4
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            Icons.remove,
                                                            size:
                                                                18, // Increased from 14
                                                            color:
                                                                currentQty > 0
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .grey
                                                                        .shade600,
                                                          ),
                                                        ),
                                                      ),

                                                      // Quantity display
                                                      Container(
                                                        margin: const EdgeInsets.symmetric(
                                                          horizontal:
                                                              10, // Increased from 8
                                                        ),
                                                        child: Text(
                                                          "$currentQty",
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize:
                                                                16, // Increased from 14
                                                          ),
                                                        ),
                                                      ),

                                                      // Increase button - enlarged
                                                      InkWell(
                                                        onTap: () async {
                                                          await AudioManager()
                                                              .playSound(
                                                                soundPath:
                                                                    'assets/sounds/click.mp3',
                                                              );
                                                          if (!isOutOfStock &&
                                                              !reachedGroupMax &&
                                                              totalSelectedQuantity <
                                                                  totalMaxQuantity) {
                                                            // Use a modified version of increaseQuantity
                                                            // since we're dealing with items not yet in cart
                                                            setState(() {
                                                              if (!item
                                                                  .containsKey(
                                                                    "type",
                                                                  )) {
                                                                item['type'] =
                                                                    setType;
                                                              }
                                                              final _quantityBefore =
                                                                  item['quantity'] ??
                                                                  0;
                                                              if (increaseQuantity(
                                                                item,
                                                              )) {
                                                                outOfStockId.add(
                                                                  item['id'],
                                                                );
                                                              }
                                                              if (item['quantity'] !=
                                                                  _quantityBefore) {
                                                                totalSelectedQuantity++;
                                                              }
                                                              selectedQuantities[id] =
                                                                  item['quantity'];
                                                            });
                                                          }
                                                        },

                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                6, // Increased from 2
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                (!isOutOfStock &&
                                                                        !reachedGroupMax &&
                                                                        totalSelectedQuantity <
                                                                            totalMaxQuantity)
                                                                    ? primaryColor
                                                                    : Colors
                                                                        .grey
                                                                        .shade300,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6, // Increased from 4
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            Icons.add,
                                                            size:
                                                                18, // Increased from 14
                                                            color:
                                                                (!isOutOfStock &&
                                                                        !reachedGroupMax &&
                                                                        totalSelectedQuantity <
                                                                            totalMaxQuantity)
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .grey
                                                                        .shade600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                else if (currentQty > 0)
                                                  // For single items, just show the auto-selected quantity
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 4,
                                                          horizontal: 10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      "$currentQty",
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(height: 24),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButtonWithSound(
                  onPressed: () {
                    for (var id in outOfStockId) {
                      if (outOfStockItems.containsKey(id)) {
                        outOfStockItems.remove(id);
                      }
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(LOCALIZATION.localize("main_word.cancel")),
                ),
                ElevatedButtonWithSound(
                  onPressed:
                      totalSelectedQuantity == totalMaxQuantity
                          ? () {
                            // Create a copy of the set product with selected items
                            Map<String, dynamic> setProductToAdd = {
                              ...setDetail,
                            };

                            // Build the list of selected items with quantities
                            List<Map<String, dynamic>> selectedItems = [];
                            for (int i = 0; i < setOptionsGroups.length; i++) {
                              for (var item in setOptionsGroups[i]) {
                                int qty = item['quantity'] ?? 0;

                                if (qty > 0) {
                                  selectedItems.add({
                                    'id': item['id'],
                                    'name': item['name'],
                                    'quantity': qty,
                                    'type': setType,
                                  });
                                }
                              }
                            }

                            // Add selected items to the set product
                            setProductToAdd['set'] = selectedItems;
                            setProductToAdd['type'] = setType;

                            // Add the set to cart
                            addToCart(setProductToAdd);
                            Navigator.of(context).pop();
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(LOCALIZATION.localize("main_word.add")),
                ),
              ],
            );
          },
        );
      },
      barrierDismissible: false,
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter productsStream based on selected category
    List<Map<String, dynamic>> filteredProducts =
        productsStream.where((product) {
          if (selectedCategory == "SET") {
            return product.containsKey("set") && product["set"] != null;
          }
          return (product["categories"] != null &&
              product["categories"].contains(selectedCategory));
        }).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns
        childAspectRatio: 1.2, // Smaller card
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final bool isOutOfStock =
            ((product['total_stocks'] ?? 0) <= 0 ||
                (outOfStockItems.containsKey(product['id']) &&
                    outOfStockItems[product['id']].containsKey(
                      'total_stocks',
                    ))) &&
            selectedCategory != "SET";

        return GestureDetector(
          onTap: () async {
            if (!isOutOfStock) {
              if (selectedCategory == "SET" && !product.containsKey("piece")) {
                _showDialogForSet(product, product['set']);
              } else {
                addToCart(product);
              }
            } else {
              showToastMessage(
                context,
                LOCALIZATION.localize("cashier_page.no_stock"),
                ToastLevel.error,
                position: ToastPosition.topRight,
              );
            }
          },

          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Product Image
                  Positioned.fill(
                    child: ColorFiltered(
                      colorFilter:
                          isOutOfStock
                              ? ColorFilter.matrix([
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]) // Grayscale filter for out of stock items
                              : const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.srcOver,
                              ),
                      child: CardImage(
                        imageSource: product['image'],
                        fit: BoxFit.cover,
                        backgroundColor: Colors.grey[300],
                        placeholderWidget: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // No Stock Ribbon
                  if (isOutOfStock)
                    Positioned(
                      top: 20,
                      right: -30,
                      child: Transform.rotate(
                        angle: 45 * 3.14159 / 180, // 45 degrees in radians
                        child: Container(
                          width: 120,
                          height: 25,
                          color: Colors.red,
                          child: Center(
                            child: Text(
                              LOCALIZATION.localize("cashier_page.no_stock"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Gradient Overlay (for better text readability)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating Text (Product Name + Price)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          product['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${globalAppConfig["userPreferences"]["currency"]} ${product['price']}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void selectAll() {
    setState(() {
      for (var item in cart) {
        item["selected"] = true;
      }
    });
  }

  void toggleAll() {
    setState(() {
      for (var item in cart) {
        item["selected"] = !item["selected"];
      }
    });
  }

  // BUG: This function is not working as expected
  // Sometimes it turn exception for SET in _buildOrderSummary on !cart[index]["selected"]
  void toggleSelection(int index) {
    CASHIER_LOGS.debug('Toggle Check: ${CASHIER_LOGS.list2str(cart)}');
    setState(() {
      cart[index]["selected"] = !cart[index]["selected"];
    });
  }

  bool increaseQuantity(Map<String, dynamic> item) {
    int newQty = (item["quantity"] ?? 1) + 1;

    if (newQty > inventory.productCatalog![item["id"]]![item['type']]) {
      setState(() {
        if (!outOfStockItems.containsKey(item["id"])) {
          outOfStockItems[item["id"]] = {item['type']: true};
        } else {
          outOfStockItems[item["id"]][item['type']] = true;
        }
      });

      showToastMessage(
        context,
        LOCALIZATION.localize("cashier_page.not_enough_stock"),
        ToastLevel.error,
        position: ToastPosition.topRight,
      );
      return false;
    }

    setState(() {
      item["quantity"] = newQty;
    });

    if (newQty + 1 > inventory.productCatalog![item["id"]]![item['type']]) {
      if (!outOfStockItems.containsKey(item["id"])) {
        outOfStockItems[item["id"]] = {item['type']: true};
      } else {
        outOfStockItems[item["id"]][item['type']] = true;
      }
      return false;
    }

    return true;
  }

  Future<bool> processTransaction({
    String? paymentMethod,
    Map<String, dynamic>? transactionData,
  }) async {
    try {
      Map<String, dynamic> processTransactionData = {
        'processed_set': {},
        'id': currentOrderId,
      };

      transactionData?.forEach((key, value) {
        if (key == 'payment_method')
          processTransactionData['paymentMethod'] = "$value";
        if (key == 'total')
          processTransactionData['totalAmount'] = double.parse("$value");
        if (key == 'cart') {
          List<Map<String, dynamic>> cartItems =
              value as List<Map<String, dynamic>>;
          Map<String, dynamic> processedCart = {};
          List<Map<String, dynamic>> receiptList = [];
          String id;
          for (var item in cartItems) {
            if (item.containsKey('set')) {
              for (var setItem in item['set']) {
                id = "${setItem['id']}";
                if (!processedCart.containsKey(id)) {
                  processedCart[id] = {
                    'name': "${setItem['name']}",
                    'price_per_stock':
                        setItem['price'] != null
                            ? double.parse("${setItem['price']}")
                            : double.parse(
                              "${inventory.productCatalog![setItem['id']]!['price']}",
                            ),
                    'total_stocks': 0,
                    'total_pieces_used': 0,
                  };
                }

                processedCart[id][setItem['type']] =
                    processedCart[id][setItem['type']] +
                    (setItem['quantity'] as int);
              }
            } else {
              id = "${item['id']}";
              if (!item.containsKey('set') && !processedCart.containsKey(id)) {
                processedCart[id] = {
                  'name': "${item['name']}",
                  'price_per_stock': double.parse("${item['price']}"),
                  'total_stocks': 0,
                  'total_pieces_used': 0,
                };
              }

              processedCart[id][item['type']] += (item['quantity'] as int);
            }
            Map<String, dynamic> receipt = {
              'name': "${item['name']}",
              'quantity': item['quantity'] as int,
              'total_price': item['price'] * (item['quantity'] as int) * 1.0,
            };
            receiptList.add(receipt);
          }

          processTransactionData['processed_set'] = processedCart;
          processTransactionData['receiptList'] = receiptList;
          processTransactionData['datetime'] = DateFormat(
            'yyyy-MM-dd HH:mm:ss',
          ).format(DateTime.now());
          processTransactionData['timestamp_int'] =
              DateTime.now().millisecondsSinceEpoch;
          processTransactionData['receiptData'] = {...receiptData};
        }
      });

      bool checkStockUpdate = await inventory.adjustProductQuantities(
        bulkData: processTransactionData['processed_set'],
      );

      bool checkRecordTransaction = await recordTransaction(
        timestamp: processTransactionData['timestamp_int'],
        receiptList: "${processTransactionData['receiptList']}",
        paymentMethod: processTransactionData['paymentMethod'],
        totalAmount: processTransactionData['totalAmount'],
      );

      bool checkAllTransaction = checkRecordTransaction && checkStockUpdate;

      // CASHIER_LOGS.debug(
      //   'raw transactionData: \n${CASHIER_LOGS.map2str(transactionData!)}',
      // );
      // CASHIER_LOGS.debug(
      //   'Processing transaction: \n${CASHIER_LOGS.map2str(processTransactionData)}',
      // );

      if (checkAllTransaction) {
        // Launch receipt processing in the backgroundb 
        Future.microtask(() async {
          try {
            // First check and request permissions with timeout
            final hasPermissions =
                await PermissionManager.requestBluetoothPermissionsWithTimeout(
                  context,
                  timeout: const Duration(seconds: 15),
                );

            if (!hasPermissions) {
              showToastMessage(
                context,
                'Bluetooth permissions are required to use the printer',
                ToastLevel.warning,
              );
              return;
            }

            // Store the current printer
            final currentPrinterCopy = btPrinter?.selectedPrinter;

            final printResult = await processReceipt(
              context: context, // This will be used in the main isolate
              currentPrinter: currentPrinterCopy,
              receiptData: processTransactionData,
            );

            if (printResult != true) {
              // Show toast on the main thread
              if (context.mounted) {
                showToastMessage(
                  context,
                  'Failed to print receipt',
                  ToastLevel.warning,
                  position: ToastPosition.topRight,
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              showToastMessage(
                context,
                'Error printing receipt: ${e.toString()}',
                ToastLevel.warning,
                position: ToastPosition.topRight,
              );
            }
          }
        });

        return true;
      }
      return false;
    } catch (e) {
      CASHIER_LOGS.error('Error processing transaction', e, StackTrace.current);
      showToastMessage(
        context,
        '${LOCALIZATION.localize("cashier_page.payment_failed")}\n\n$e',
        ToastLevel.error,
        position: ToastPosition.topRight,
      );
      return false;
    }
  }

  void _processSuccessfulTransaction() async {
    List<Map<String, dynamic>> loadedProducts =
        await inventory.getAllProductsAndSets();

    setState(() {
      cart.clear();
      outOfStockItems.clear();
      receiptData.clear();
      currentOrderId++;
      productsStream = loadedProducts;
    });

    // Show success message
    showToastMessage(
      context,
      LOCALIZATION.localize("cashier_page.payment_successful"),
      ToastLevel.success,
      position: ToastPosition.topRight,
    );

    // Reload product data
    await _loadProductsData();
    await AudioManager().playSound(
      soundPath: 'assets/sounds/transaction_done.mp3',
    );
  }

  void _showCouponDialog(BuildContext context) {
    String couponCode = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(LOCALIZATION.localize("cashier_page.enter_coupon_code")),
          content: TextField(
            onChanged: (value) {
              couponCode = value;
            },
            decoration: InputDecoration(
              hintText: LOCALIZATION.localize(
                "cashier_page.coupon_placeholder",
              ),
              prefixIcon: const Icon(Icons.discount),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: <Widget>[
            TextButtonWithSound(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(LOCALIZATION.localize("main_word.cancel")),
            ),
            ElevatedButtonWithSound(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () {
                // Here you would validate the coupon code and apply discount
                // For now, we'll just close the dialog
                Navigator.of(context).pop();

                // Show toast message instead of SnackBar
                showToastMessage(
                  context,
                  LOCALIZATION.localize("cashier_page.coupon_applied"),
                  ToastLevel.info,
                  position: ToastPosition.topRight,
                );
              },
              child: Text(LOCALIZATION.localize("main_word.apply")),
            ),
          ],
        );
      },
    );
  }

  void _showCheckoutDialog(BuildContext context, double totalAmount) {
    CASHIER_LOGS.console('Showing checkout dialog');
    bool printReceipt = true;
    String selectedPaymentMethod = 'cash';

    // Calculate necessary values for display
    double subtotal = cart.fold(
      0.0,
      (sum, item) => sum + ((item['price'] ?? 0.0) * (item['quantity'] ?? 1)),
    );
    double discountAmount =
        0.0; // Replace with actual discount calculation if needed
    double taxRate =
        (globalAppConfig["cashier"]["tax"] as num?)?.toDouble() ?? 0.0;
    double taxAmount = subtotal * taxRate;
    receiptData['checkPrint'] = printReceipt;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                // Added SingleChildScrollView to prevent overflow
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  padding: const EdgeInsets.all(
                    20,
                  ), // Reduced padding from 24 to 20
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            LOCALIZATION.localize(
                              "cashier_page.checkout_confirmation",
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            padding: EdgeInsets.zero, // Reduce button padding
                            constraints:
                                const BoxConstraints(), // Minimize constraints
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 20), // Reduced height from 24 to 20
                      // Order summary
                      Text(
                        LOCALIZATION.localize("cashier_page.order_items"),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8), // Reduced height from 12 to 8
                      // Order items list
                      Container(
                        constraints: BoxConstraints(
                          // Set a fixed height to show approximately 4 items
                          maxHeight: 150, // Reduced from 160 to 150
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: false,
                          itemCount: cart.length,
                          itemBuilder: (context, index) {
                            final item = cart[index];
                            final quantity = item['quantity'] ?? 1;
                            final price = item['price'] ?? 0.0;
                            final itemTotal = price * quantity;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6, // Reduced from 8 to 6
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "$quantity x",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item['name'] ?? "")),
                                  Text(
                                    "${globalAppConfig["userPreferences"]["currency"]}${itemTotal.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16), // Reduced from 20 to 16
                      // Total amount with tax and discount details
                      Container(
                        padding: const EdgeInsets.all(
                          10,
                        ), // Reduced from 12 to 10
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  LOCALIZATION.localize("main_word.total"),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${globalAppConfig["userPreferences"]["currency"]}${totalAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            // Small divider
                            Divider(
                              height: 10,
                              thickness: 0.5,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            // Tax and discount details in smaller font
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${LOCALIZATION.localize("cashier_page.tax")}: ${globalAppConfig["userPreferences"]["currency"]}${taxAmount.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  "${LOCALIZATION.localize("cashier_page.discount")}: ${globalAppConfig["userPreferences"]["currency"]}${discountAmount.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        discountAmount > 0
                                            ? Colors.orange
                                            : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16), // Reduced from 24 to 16
                      // Payment method selection
                      Text(
                        LOCALIZATION.localize(
                          "cashier_page.select_payment_method",
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8), // Reduced from 12 to 8
                      // Payment method options
                      Wrap(
                        spacing: 8, // Reduced from 10 to 8
                        runSpacing: 8, // Reduced from 10 to 8
                        children: [
                          if (globalAppConfig["cashier"]["payment_methods"]["cash"])
                            _buildPaymentMethodButton(
                              icon: Icons.money,
                              label: LOCALIZATION.localize(
                                "cashier_page.payment_cash",
                              ),
                              value: 'cash',
                              selectedValue: selectedPaymentMethod,
                              onSelected: (value) {
                                setState(() => selectedPaymentMethod = value);
                              },
                            ),
                          if (globalAppConfig["cashier"]["payment_methods"]["credit"])
                            _buildPaymentMethodButton(
                              icon: Icons.credit_card,
                              label: LOCALIZATION.localize(
                                "cashier_page.payment_credit",
                              ),
                              value: 'credit',
                              selectedValue: selectedPaymentMethod,
                              onSelected: (value) {
                                setState(() => selectedPaymentMethod = value);
                              },
                            ),
                          if (globalAppConfig["cashier"]["payment_methods"]["debit"])
                            _buildPaymentMethodButton(
                              icon: Icons.payment,
                              label: LOCALIZATION.localize(
                                "cashier_page.payment_debit",
                              ),
                              value: 'debit',
                              selectedValue: selectedPaymentMethod,
                              onSelected: (value) {
                                setState(() => selectedPaymentMethod = value);
                              },
                            ),
                          if (globalAppConfig["cashier"]["payment_methods"]["qr"])
                            _buildPaymentMethodButton(
                              icon: Icons.qr_code,
                              label: LOCALIZATION.localize(
                                "cashier_page.payment_qr",
                              ),
                              value: 'qr',
                              selectedValue: selectedPaymentMethod,
                              onSelected: (value) {
                                setState(() => selectedPaymentMethod = value);
                              },
                            ),
                          if (globalAppConfig["cashier"]["payment_methods"]["apple"])
                            _buildPaymentMethodButton(
                              icon: Icons.apple,
                              label: LOCALIZATION.localize(
                                "cashier_page.payment_apple",
                              ),
                              value: 'apple',
                              selectedValue: selectedPaymentMethod,
                              onSelected: (value) {
                                setState(() => selectedPaymentMethod = value);
                              },
                            ),
                        ],
                      ),

                      const SizedBox(height: 16), // Reduced from 24 to 16
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ), // Reduced from 20 to 16
                              minimumSize: const Size(
                                0,
                                36,
                              ), // Set minimum height
                            ),
                            child: Text(
                              LOCALIZATION.localize("main_word.cancel"),
                            ),
                          ),
                          const SizedBox(width: 8), // Reduced from 12 to 8
                          Row(
                            children: [
                              // Print receipt toggle
                              Row(
                                children: [
                                  Text(
                                    LOCALIZATION.localize(
                                      "cashier_page.print_receipt",
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                    ), // Reduced from 14 to 13
                                  ),
                                  const SizedBox(
                                    width: 4,
                                  ), // Reduced from 8 to 4
                                  Transform.scale(
                                    scale: 0.8, // Scale down the switch
                                    child: Switch(
                                      value: printReceipt,
                                      activeColor: primaryColor,
                                      onChanged: (value) {
                                        setState(() {
                                          printReceipt = value;
                                          receiptData['checkPrint'] = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 8), // Reduced from 12 to 8
                              // Confirm payment button
                              ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.check,
                                  size: 16,
                                ), // Smaller icon
                                label: Text(
                                  LOCALIZATION.localize(
                                    "cashier_page.confirm_payment",
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                  ), // Smaller text
                                ),
                                onPressed: () {
                                  // Close the checkout dialog first
                                  Navigator.of(context).pop();

                                  // Based on the selected payment method, show the appropriate dialog
                                  if (selectedPaymentMethod == 'cash') {
                                    // Show the cash payment dialog for cash payments
                                    _showCashPaymentDialog(
                                      context,
                                      totalAmount,
                                    );
                                  } else {
                                    // For other payment methods, just complete the transaction
                                    setState(() {
                                      cart.clear();
                                      currentOrderId++;
                                    });

                                    showToastMessage(
                                      context,
                                      LOCALIZATION.localize(
                                        "cashier_page.payment_successful",
                                      ),
                                      ToastLevel.success,
                                      position: ToastPosition.topRight,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16, // Reduced padding
                                  ),
                                  minimumSize: const Size(
                                    0,
                                    36,
                                  ), // Set minimum height
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCashPaymentDialog(BuildContext context, double totalAmount) {
    String enteredAmount = '';
    bool showError = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate change amount if valid
            double? changeAmount;
            if (enteredAmount.isNotEmpty) {
              try {
                double cashGiven = double.parse(enteredAmount);
                if (cashGiven >= totalAmount) {
                  changeAmount = cashGiven - totalAmount;
                }
              } catch (e) {
                // Handle parsing error
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.4,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header
                    Text(
                      LOCALIZATION.localize("cashier_page.payment_cash"),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Amount display
                    Text(
                      "${LOCALIZATION.localize("cashier_page.total")}: ${globalAppConfig["userPreferences"]["currency"]}${totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount entry field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: showError ? Colors.red : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "${globalAppConfig["userPreferences"]["currency"]}",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              enteredAmount.isEmpty ? "0.00" : enteredAmount,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Error message if applicable
                    if (showError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          LOCALIZATION.localize(
                            "cashier_page.amount_too_small",
                          ),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Change amount display
                    if (changeAmount != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              LOCALIZATION.localize("cashier_page.reminder"),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "${globalAppConfig["userPreferences"]["currency"]}${changeAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Numpad
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: NumPad(
                        initialValue: enteredAmount,
                        onValueChanged: (value) {
                          setState(() {
                            enteredAmount = value;
                            showError = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop(false); // Cancel
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            LOCALIZATION.localize("main_word.cancel"),
                          ),
                        ),

                        OutlinedButton(
                          onPressed: () {
                            // Go back to the checkout dialog
                            Navigator.of(
                              context,
                            ).pop(); // Close the cash payment dialog
                            _showCheckoutDialog(
                              context,
                              totalAmount,
                            ); // Reopen the checkout dialog
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(LOCALIZATION.localize("main_word.back")),
                        ),

                        ElevatedButtonWithSound(
                          onPressed: () async {
                            // Validate and process payment
                            try {
                              double cashGiven = double.parse(enteredAmount);
                              final transactionData = {
                                'total': totalAmount,
                                'payment_method': 'cash',
                                'cash_given': cashGiven,
                                'cart': cart,
                              };
                              receiptData["changeAmount"] = changeAmount;
                              receiptData["enteredAmount"] = double.parse(
                                enteredAmount,
                              );
                              bool checkTransaction = await processTransaction(
                                paymentMethod: 'cash',
                                transactionData: transactionData,
                              );
                              if (cashGiven >= totalAmount &&
                                  checkTransaction) {
                                Navigator.of(context).pop(true);
                              } else {
                                setState(() {
                                  showError = true;
                                });
                              }
                            } catch (e) {
                              setState(() {
                                showError = true;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                          ),
                          child: Text(LOCALIZATION.localize("main_word.enter")),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((result) {
      // Handle the dialog result
      if (result == true) {
        _processSuccessfulTransaction();
      }
    });
  }

  Widget _buildPaymentMethodButton({
    required IconData icon,
    required String label,
    required String value,
    required String selectedValue,
    required Function(String) onSelected,
  }) {
    final isSelected = value == selectedValue;

    return InkWell(
      onTap: () async {
        await AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
        onSelected(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    // Calculate total
    double totalPrice = cart.fold(
      0.0,
      (sum, item) => sum + ((item['price'] ?? 0.0) * (item['quantity'] ?? 1)),
    );
    double discountAmount = 0.0;
    double taxRate =
        (globalAppConfig["cashier"]["tax"] as num?)?.toDouble() ?? 0.0;
    double taxAmount = totalPrice * taxRate;
    double finalTotal = totalPrice + taxAmount - discountAmount;
    int totalItems = cart.length;
    // Format order ID to 6 digits with leading zeros
    String formattedOrderId = NumberFormat(
      globalAppConfig["cashier"]["formattedOrderId"],
    ).format(currentOrderId);

    final List<int> outOfStockId = [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section with Order ID (made thinner)
          Container(
            padding: const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              5,
            ), // Reduced vertical padding
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(25),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side: Order summary title and ID
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LOCALIZATION.localize("cashier_page.order_summary"),
                      style: const TextStyle(
                        fontSize: 15, // Slightly smaller
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "#$formattedOrderId",
                      style: TextStyle(
                        fontSize: 11, // Smaller font size
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Right side: Items count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, // Smaller
                    vertical: 2, // Smaller
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$totalItems ${LOCALIZATION.localize("main_word.items")}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11, // Smaller font
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Order items list
          Expanded(
            child:
                cart.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            LOCALIZATION.localize("cashier_page.cart_empty"),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        final quantity = item['quantity'] ?? 1;
                        final price = item['price'] ?? 0.0;
                        final setItems =
                            item['set'] as List<Map<String, dynamic>>?;

                        // Determine if the item is pcs or pack based on the conditions
                        String unitType;
                        if (setItems != null ||
                            item["type"] == "total_pieces_used") {
                          unitType = "(pcs)";
                        } else {
                          unitType = "(pack)"; // Default fallback
                        }

                        return Dismissible(
                          key: Key("cart-item-$index"),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => removeFromCart(index),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  item["selected"] == true
                                      ? primaryColor.withAlpha(20)
                                      : null,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: ListTile(
                                leading: Checkbox(
                                  activeColor: primaryColor,
                                  value: item["selected"] ?? false,
                                  onChanged: (_) => toggleSelection(index),
                                  visualDensity: VisualDensity.compact,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["name"] ?? "",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.visible,
                                    ),
                                    Text(
                                      "${globalAppConfig["userPreferences"]["currency"]}${price.toStringAsFixed(2)} $unitType",
                                      style: TextStyle(
                                        fontSize: 12, // Increased from 10
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (setItems != null && setItems.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children:
                                              setItems
                                                  .map(
                                                    (setItem) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 8,
                                                          ),
                                                      child: Text(
                                                        "• ${setItem['name']} x${setItem['quantity']}",
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color:
                                                              Colors.grey[600],
                                                          height: 1.2,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                                // Quantity controls
                                trailing:
                                    setItems == null
                                        ? Container(
                                          height:
                                              32, // Increased from 30 for better touch area
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Decrease button with increased padding
                                              InkWell(
                                                onTap: () {
                                                  AudioManager().playSound(
                                                    soundPath:
                                                        'assets/sounds/click.mp3',
                                                  );
                                                  if (quantity > 1) {
                                                    setState(() {
                                                      item["quantity"] =
                                                          quantity - 1;
                                                      // CASHIER_LOGS.debug("item: \n${CASHIER_LOGS.map2str(item)} \n outOfStockId: \n${CASHIER_LOGS.map2str(outOfStockItems)}");
                                                      if (outOfStockItems
                                                              .containsKey(
                                                                item["id"],
                                                              ) &&
                                                          outOfStockItems[item["id"]]
                                                              ?.containsKey(
                                                                item["type"],
                                                              )) {
                                                        outOfStockItems[item["id"]]
                                                            .remove(
                                                              item["type"],
                                                            );
                                                      }
                                                    });
                                                  } else {
                                                    removeFromCart(index);
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6, // Increased from 3 for better touch area
                                                  ),
                                                  child: Icon(
                                                    Icons.remove,
                                                    size:
                                                        14, // Slightly larger icon
                                                    color:
                                                        primaryColor, // Added primaryColor for better visibility
                                                  ),
                                                ),
                                              ),
                                              // Quantity indicator with black text
                                              SizedBox(
                                                width:
                                                    24, // Increased from 18 for better visibility
                                                child: Center(
                                                  child: Text(
                                                    "$quantity",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          12, // Slightly larger text
                                                      color:
                                                          Colors
                                                              .black, // Changed to black for better visibility
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Increase button with increased padding
                                              InkWell(
                                                onTap: () {
                                                  AudioManager().playSound(
                                                    soundPath:
                                                        'assets/sounds/click.mp3',
                                                  );
                                                  if (increaseQuantity(item)) {
                                                    outOfStockId.add(
                                                      item['id'],
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6, // Increased from 3 for better touch area
                                                  ),
                                                  child: Icon(
                                                    Icons.add,
                                                    size:
                                                        14, // Slightly larger icon
                                                    color:
                                                        primaryColor, // Added primaryColor for better visibility
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                horizontalTitleGap: 2,
                                dense: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // Action bar bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                // Selection and discount actions
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.select_all, size: 14),
                      onPressed: selectAll,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 32), // Smaller height
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      label: Text(
                        LOCALIZATION.localize("main_word.select_all"),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 6),

                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.discount, size: 14),
                        onPressed: () {
                          _showCouponDialog(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 32), // Smaller height
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        label: Text(
                          LOCALIZATION.localize(
                            "cashier_page.coupon_placeholder",
                          ),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Cost breakdown
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LOCALIZATION.localize("cashier_page.subtotal"),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          "${globalAppConfig["userPreferences"]["currency"]}${totalPrice.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${LOCALIZATION.localize("cashier_page.tax")} (${(taxRate * 100).toStringAsFixed(0)}%)",
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          "${globalAppConfig["userPreferences"]["currency"]}${taxAmount.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LOCALIZATION.localize("cashier_page.discount"),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          "-${globalAppConfig["userPreferences"]["currency"]}${discountAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12, thickness: 0.8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LOCALIZATION.localize("main_word.total"),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "${globalAppConfig["userPreferences"]["currency"]}${finalTotal.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Pay button
                ElevatedButtonWithSound.icon(
                  onPressed:
                      cart.isEmpty
                          ? null
                          : () {
                            receiptData = {
                              "items": totalItems,
                              "tax": taxAmount,
                              "discountAmount": discountAmount,
                            };
                            _showCheckoutDialog(context, finalTotal);
                          },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(
                      double.infinity,
                      44,
                    ), // Made smaller
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text(
                    LOCALIZATION.localize("cashier_page.checkout"),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildCategoryTabs(),
                  Expanded(child: _buildProductGrid()),
                ],
              ),
            ),
            Expanded(flex: 1, child: _buildOrderSummary()),
          ],
        ),
      ),
    );
  }
}


