import '../configs/configs.dart';
import '../services/inventory/inventory_services.dart';
import '../services/cashier/cashier_services.dart';
import '../services/auth/unified_auth_service.dart';

// components
import '../components/toastmsg.dart';
import '../components/buttonswithsound.dart';

// page sections
import '../page_sections/cashier_page/index.dart' as responsive;

import 'package:intl/intl.dart';

class CashierPage extends StatefulWidget {
  final ValueNotifier<int> reloadNotifier;
  const CashierPage({super.key, required this.reloadNotifier});

  @override
  CashierPageState createState() => CashierPageState();
}

class CashierPageState extends State<CashierPage> {
  // init variable
  bool firstLoad = true;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  // cashier variable
  int currentOrderId = 1; // Order ID tracking variable
  String selectedCategory = "";
  String employeeID = "RZ0000";
  String employeeName = "RZ";
  bool checkPrintReceipt =
      globalAppConfig["cashier"]["bluetooth_printer"]["enabled"];
  bool checkCashDrawer = globalAppConfig["cashier"]["cash_drawer"]["enabled"];
  List<String> categories = [];
  List<Map<String, dynamic>> productsStream = [];
  List<Map<String, dynamic>> cart = [];
  Map<String, dynamic> receiptData = {};
  Map<int, dynamic> outOfStockItems = {};

  void resetAuthentication() {
    setState(() {
      _isAuthenticated = false;
    });
  }

  // Add this method to reload product data
  Future<void> _loadInitData() async {
    try {
      setState(
        () => _isLoading = true,
      ); // Optional: add a loading state variable

      if (firstLoad) {
        CASHIER_LOGS =
            await LoggingService(logName: "cashier_logs").initialize();
      }

      int getLatestId = await getLatestTransactionId() + 1;

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
        currentOrderId = getLatestId;
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
    resetAuthentication();
    _loadInitData();
    firstLoad = false;
    widget.reloadNotifier.addListener(() async {
      await _reloadAll();
    });
    // CASHIER_LOGS.info('CashierPage initialized');
  }

  @override
  void dispose() {
    widget.reloadNotifier.removeListener(() async {
      await _reloadAll();
    });
    super.dispose();
  }

  Future<void> _reloadAll() async {
    await _loadInitData();
    setState(() {
      cart.clear();
      outOfStockItems.clear();
      receiptData.clear();
      // Reset other variables if needed
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      // Check if the product already exists in the cart
      int existingIndex = cart.indexWhere(
        (item) => item["name"] == product["name"],
      );
      AudioManager().playSound(soundPath: 'assets/sounds/click.mp3');
      if (existingIndex >= 0) {
        if (cart[existingIndex].containsKey("set")) {
          // If the product is a set, need to process again
          for (int i = 0; i < product["set"].length; i++) {
            bool checkItemNotExist = true;
            for (int k = 0; k < cart[existingIndex]["set"].length; k++) {
              if (cart[existingIndex]["set"][k]["id"] ==
                  product["set"][i]["id"]) {
                _increaseQuantity(cart[existingIndex]["set"][i]);
                checkItemNotExist = false;
                break;
              }
            }
            if (checkItemNotExist) {
              cart[existingIndex]["set"].add(product["set"][i]);
            }
          }
        }
        _increaseQuantity(cart[existingIndex]);
      } else {
        // New product, add to cart with quantity 1
        Map<String, dynamic> newItem = {...product, "quantity": 1};
        newItem = processItem(newItem);
        newItem["selected"] = false;
        cart.add(newItem);
      }
    });
  }

  void _removeFromCart(int index) {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return responsive.ResponsiveSetSelectionDialog(
          setDetail: setDetail,
          setType: setType,
          outOfStockItems: outOfStockItems,
          increaseQuantity: _increaseQuantity,
          onAddToCart: _addToCart,
        );
      },
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
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent:
            MediaQuery.of(context).size.width < 600
                ? 150.0
                : 180.0, // Adaptive card size
        childAspectRatio: 1.1, // Slightly adjusted for better proportions
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
                _addToCart(product);
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
                      child:
                          product['image'] is Uint8List &&
                                  (product['image'] as Uint8List).isNotEmpty
                              ? Image.memory(
                                product['image'],
                                fit: BoxFit.cover,
                              )
                              : Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey,
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
                          "${product['name']}",
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

  void _selectAll() {
    setState(() {
      for (var item in cart) {
        item["selected"] = true;
      }
    });
  }

  bool _increaseQuantity(Map<String, dynamic> item) {
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

  Future<bool> _processTransaction({
    String? paymentMethod,
    Map<String, dynamic>? transactionData,
  }) async {
    try {
      Map<String, dynamic> processTransactionData = {
        'processed_set': {},
        'id': currentOrderId,
        "employeeName": employeeName,
        "employeeID": employeeID,
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
          Map<String, dynamic> inventoryTransaction = {};
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

          processedCart.forEach((id, value) {
            inventoryTransaction[id] = {
              'total_stocks': value['total_stocks'] ?? 0,
              'total_pieces_used': value['total_pieces_used'] ?? 0,
            };
          });

          processTransactionData['inventoryTransaction'] = inventoryTransaction;
          processTransactionData['processed_set'] = processedCart;
          processTransactionData['receiptList'] = receiptList;
          processTransactionData['datetime'] = DateFormat(
            'yyyy-MM-dd HH:mm:ss',
          ).format(DateTime.now());
          processTransactionData['timestamp_int'] = getDateTimeNow(
            timestamp: true,
          );
          processTransactionData['receiptData'] = {...receiptData};
        }
      });

      bool checkStockUpdate = await inventory.adjustProductQuantities(
        bulkData: processTransactionData['processed_set'],
      );

      bool checkRecordTransaction = await recordTransaction(
        employeeId: employeeID,
        processTransactionData: processTransactionData,
      );

      bool checkAllTransaction = checkRecordTransaction && checkStockUpdate;

      // CASHIER_LOGS.debug(
      //   'raw transactionData: \n${CASHIER_LOGS.map2str(removeImageKey(transactionData!))}',
      // );
      // CASHIER_LOGS.debug(
      //   'Processing transaction: \n${CASHIER_LOGS.map2str(removeImageKey(processTransactionData))}',
      // );

      if (checkAllTransaction) {
        // Launch receipt processing in the backgroundb
        if (checkPrintReceipt) {
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
                  setState(() {
                    checkPrintReceipt = false;
                  });
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

                checkPrintReceipt = false;
              }
            }
          });
        }

        if (paymentMethod == 'cash' && checkCashDrawer) {
          await checkAndOpenCashDrawer(context);
        }

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
      productsStream = loadedProducts;
    });

    await _reloadAll();
    // Show success message
    showToastMessage(
      context,
      LOCALIZATION.localize("cashier_page.payment_successful"),
      ToastLevel.success,
      position: ToastPosition.topRight,
    );

    // Reload product data
    await AudioManager().playSound(
      soundPath: 'assets/sounds/transaction_done.mp3',
    );
  }

  void _showCouponDialog(BuildContext context) {
    String couponCode = ''; // TODO: Use this for coupon validation
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
                // TODO: Validate the coupon code and apply discount
                // For now, we'll just close the dialog and ignore the coupon code
                print('Coupon code entered: $couponCode'); // Use the variable
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
    receiptData['checkPrint'] = checkPrintReceipt;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return responsive.ResponsiveCheckoutDialog(
          context: context,
          totalAmount: totalAmount,
          cart: cart,
          receiptData: receiptData,
          onShowCashPaymentDialog: _showCashPaymentDialog,
          onSetReceiptData: (key, value) {
            setState(() {
              receiptData[key] = value;
            });
          },
        );
      },
    );
  }

  void _showCashPaymentDialog(BuildContext context, double totalAmount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return responsive.ResponsiveCashPaymentDialog(
          totalAmount: totalAmount,
          onProcessPayment: (
            dialogContext,
            paymentMethod,
            cashGiven,
            changeAmount,
          ) async {
            final transactionData = {
              'total': totalAmount,
              'payment_method': paymentMethod,
              'cash_given': cashGiven,
              'cart': cart,
            };
            receiptData["changeAmount"] = changeAmount;
            receiptData["enteredAmount"] = cashGiven;

            bool checkTransaction = await _processTransaction(
              paymentMethod: paymentMethod,
              transactionData: transactionData,
            );

            if (checkTransaction) {
              Navigator.of(dialogContext).pop(true);
              _processSuccessfulTransaction();
            } else {
              // Error handling is already done in _processTransaction
              Navigator.of(dialogContext).pop(false);
            }
          },
        );
      },
    );
  }

  // [NEW:260725] [Employee Selection and Login Screen] - Now using UnifiedAuthService
  Widget _buildEmployeeAuthScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withOpacity(0.1),
              primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await UnifiedAuthService.showEmployeeAuth(
                context,
                authenticator:
                    (employee, password) =>
                        empAuth(employee, password, LOGS: CASHIER_LOGS),
                employees: EMPQUERY.employees,
                logs: CASHIER_LOGS,
              );

              if (result != null && result.success) {
                setState(() {
                  _isAuthenticated = true;
                  employeeID = result.employeeID!;
                  employeeName = result.employeeName!;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              LOCALIZATION.localize("cashier_page.select_account"),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildEmployeeAuthScreen();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: responsive.ResponsiveCashierLayout(
          categoryTabs: _buildCategoryTabs(),
          productGrid: _buildProductGrid(),
          orderSummary: responsive.ResponsiveOrderSummary(
            cart: cart,
            currentOrderId: currentOrderId,
            outOfStockItems: outOfStockItems,
            toggleSelection: (index) {
              setState(() {
                cart[index]["selected"] = !(cart[index]["selected"] ?? false);
              });
            },
            removeFromCart: (index) {
              setState(() {
                _removeFromCart(index);
              });
            },
            increaseQuantity: (item) {
              setState(() {
                _increaseQuantity(item);
              });
            },
            selectAll: () {
              setState(() {
                _selectAll();
              });
            },
            showCouponDialog: _showCouponDialog,
            showCheckoutDialog: _showCheckoutDialog,
            setReceiptData: (key, value) {
              setState(() {
                receiptData[key] = value;
              });
            },
          ),
        ),
      ),
    );
  }
}
