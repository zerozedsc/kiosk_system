import '../../configs/configs.dart';
import '../../services/inventory/inventory_services.dart';

import '../../components/buttonswithsound.dart';
import '../../components/toastmsg.dart';

// --- Product Tab ---
class ProductInventoryTab extends StatefulWidget {
  final ValueNotifier<int> reloadNotifier;
  const ProductInventoryTab({super.key, required this.reloadNotifier});

  @override
  State<ProductInventoryTab> createState() => _ProductInventoryTabState();
}

class _ProductInventoryTabState extends State<ProductInventoryTab> {
  List<Map<String, dynamic>> inventoryItems = [];
  String searchQuery = '';
  int? selectedProductId;
  String? selectedCategory;
  String sortBy = 'Name';
  bool sortAsc = true;

  List<String> get categories {
    final set = <String>{};
    for (var item in inventoryItems) {
      if (item['categories'] != null) set.add(item['categories']);
    }
    return set.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    widget.reloadNotifier.addListener(() async {
      await _loadProducts();
    });
  }

  @override
  void dispose() {
    widget.reloadNotifier.removeListener(() async {
      await _loadProducts();
    });
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final productList =
        inventory.productCatalog?.entries
            .map((e) => {"id": e.key, ...e.value})
            .toList();
    setState(() {
      inventoryItems = productList ?? [];
    });
  }

  void _showBulkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            LOCALIZATION.localize("inventory_page.bulk_section_title") ??
                "Bulk",
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButtonWithSound.icon(
                icon: const Icon(Icons.add),
                label: Text(
                  LOCALIZATION.localize("inventory_page.bulk_add_items") ??
                      "Bulk Add",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showBulkActionDialog(context, "add");
                },
              ),
              const SizedBox(height: 8),

              ElevatedButtonWithSound.icon(
                icon: const Icon(Icons.remove),
                label: Text(
                  LOCALIZATION.localize("inventory_page.bulk_remove") ??
                      "Bulk Remove",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showBulkActionDialog(context, "remove");
                },
              ),
              const SizedBox(height: 8),

              ElevatedButtonWithSound.icon(
                icon: const Icon(Icons.add),
                label: Text(
                  LOCALIZATION.localize("inventory_page.bulk_add_stock") ??
                      "Bulk Add Stock",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showBulkActionDialog(context, "add_stock");
                },
              ),
            ],
          ),
          actions: [
            TextButtonWithSound(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(LOCALIZATION.localize("main_word.close") ?? "Close"),
            ),
          ],
        );
      },
    );
  }

  void _showBulkActionDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (context) {
        String title;
        Widget content;
        switch (action) {
          case "add":
            title =
                LOCALIZATION.localize("inventory_page.bulk_add_items") ??
                "Bulk Add items";
            content = _buildBulkAddItemWidget(
              context,
              onConfirm: () async {
                await _loadProducts();
              },
              inventoryItems: inventoryItems,
            );
            break;
          case "remove":
            title =
                LOCALIZATION.localize("inventory_page.bulk_remove") ??
                "Bulk Remove";
            content = _buildBulkDeleteItemWidget(
              context,
              products: inventoryItems,
              onConfirm: () async {
                await _loadProducts();
              },
            );
            break;
          case "add_stock":
            title =
                LOCALIZATION.localize("inventory_page.bulk_add_stock") ??
                "Bulk Add Stock";
            content = _buildBulkAddStockWidget(
              context,
              products: inventoryItems,
              onConfirm: () async {
                await _loadProducts();
              },
            );
            break;
          default:
            title = "Bulk";
            content = const SizedBox();
        }
        return AlertDialog(content: content, actions: []);
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: LOCALIZATION.localize("inventory_page.search_product"),
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
    );
  }

  Widget _buildStockStatus(int stock) {
    Color color;
    String text;
    if (stock == 0) {
      color = Colors.red;
      text = LOCALIZATION.localize("inventory_page.stock_out");
    } else if (stock < 20) {
      color = Colors.orange;
      text = LOCALIZATION.localize("inventory_page.stock_low");
    } else {
      color = Colors.green;
      text = LOCALIZATION.localize("inventory_page.stock_ok");
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLogsSection() {
    // Dummy logs for demonstration
    final logs = [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LOCALIZATION.localize("inventory_page.recent_activity"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...logs.map(
          (log) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(log, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  // --- Bulk Widget for product---
  Widget _buildBulkAddItemWidget(
    BuildContext context, {
    Future<void> Function()? onConfirm,
    required List<Map<String, dynamic>> inventoryItems,
  }) {
    bool _showForm = false;
    final List<Map<String, dynamic>> itemsList = [];

    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final shortformController = TextEditingController();
    final categoriesController = TextEditingController();
    final priceController = TextEditingController();
    final totalStocksController = TextEditingController();
    final totalPiecesController = TextEditingController();
    bool exist = true;
    String? imagePath;
    Uint8List? imageBlob;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        void resetForm() {
          nameController.clear();
          shortformController.clear();
          categoriesController.clear();
          priceController.clear();
          totalStocksController.clear();
          totalPiecesController.clear();
          imagePath = null;
          exist = true;
          setDialogState(() => _showForm = false);
        }

        void pickImage() async {
          final picker = ImagePicker();
          final picked = await picker.pickImage(source: ImageSource.gallery);
          if (picked != null) {
            File file = File(picked.path);
            Uint8List bytes = await file.readAsBytes();
            double sizeInMB = bytes.lengthInBytes / (1024 * 1024);

            // Try compressing until under 5MB or minimum quality
            int quality = 90;
            while (sizeInMB > 5 && quality > 10) {
              bytes =
                  (await FlutterImageCompress.compressWithList(
                    bytes,
                    quality: quality,
                  ))!;
              sizeInMB = bytes.lengthInBytes / (1024 * 1024);
              quality -= 10;
            }

            if (sizeInMB > 5) {
              showToastMessage(
                context,
                LOCALIZATION.localize("main_word.image_too_large") ??
                    "Image size exceeds 5MB even after compression. Please pick a smaller image.",
                ToastLevel.error,
              );
              return;
            }

            setDialogState(() {
              imagePath = picked.path;
              imageBlob = bytes;
            });
          }
        }

        void confirmItem() {
          if (!_formKey.currentState!.validate()) return;

          final newName = nameController.text.trim();
          final newShortform = shortformController.text.trim().toUpperCase();

          // Duplicate check (case-insensitive) against both itemsList and inventoryItems
          final isDuplicateName =
              itemsList.any(
                (item) =>
                    (item['name']?.toString().toLowerCase() ?? '') ==
                    newName.toLowerCase(),
              ) ||
              inventoryItems.any(
                (item) =>
                    (item['name']?.toString().toLowerCase() ?? '') ==
                    newName.toLowerCase(),
              );

          final isDuplicateShortform =
              newShortform.isNotEmpty &&
              (itemsList.any(
                    (item) =>
                        (item['shortform']?.toString() ?? '') == newShortform,
                  ) ||
                  inventoryItems.any(
                    (item) =>
                        (item['shortform']?.toString() ?? '') == newShortform,
                  ));

          if (isDuplicateName) {
            showToastMessage(
              context,
              LOCALIZATION.localize("inventory_page.duplicate_name") ??
                  "Product name already exists.",
              ToastLevel.error,
            );
            return;
          }
          if (isDuplicateShortform) {
            showToastMessage(
              context,
              LOCALIZATION.localize("inventory_page.duplicate_shortform") ??
                  "Product shortform already exists.",
              ToastLevel.error,
            );
            return;
          }

          final newItem = {
            "name": newName,
            "shortform": newShortform,
            "categories": categoriesController.text.trim().toUpperCase(),
            "price": double.tryParse(priceController.text.trim()) ?? 0.0,
            "total_stocks":
                int.tryParse(totalStocksController.text.trim()) ?? 0,
            "total_pieces":
                int.tryParse(totalPiecesController.text.trim()) ?? 0,
            "total_pieces_used": 0,
            "exist": exist ? 1 : 0,
            "image": imageBlob,
          };

          setDialogState(() {
            itemsList.add(newItem);
            resetForm();
          });
        }

        return SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LOCALIZATION.localize(
                                "inventory_page.bulk_add_products",
                              ) ??
                              "Bulk Add Products",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),

                        if (itemsList.isNotEmpty) ...[
                          Text(
                            LOCALIZATION.localize(
                                  "inventory_page.added_items",
                                ) ??
                                "✅ Added Items",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...itemsList.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading:
                                    item["image"] != null
                                        ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Image.memory(
                                            item["image"],
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                        : Icon(
                                          Icons.image_outlined,
                                          color: Colors.grey.shade400,
                                        ),
                                title: Text(item["name"] ?? ""),
                                subtitle: Text(
                                  "${globalAppConfig["userPreferences"]["currency"]} ${item["price"]}",
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => setDialogState(
                                        () => itemsList.removeAt(index),
                                      ),
                                  tooltip: LOCALIZATION.localize(
                                    "main_word.delete",
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          const Divider(height: 32),
                        ],

                        if (!_showForm)
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: Text(
                                LOCALIZATION.localize("main_word.add_item"),
                              ),
                              onPressed:
                                  () => setDialogState(() => _showForm = true),
                            ),
                          ),

                        if (_showForm)
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(top: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Form(
                                key: _formKey,
                                child: Wrap(
                                  runSpacing: 12,
                                  children: [
                                    TextFormField(
                                      controller: nameController,
                                      decoration: InputDecoration(
                                        labelText:
                                            LOCALIZATION.localize(
                                              "main_word.name",
                                            ) ??
                                            "Name",
                                      ),
                                      validator:
                                          (v) =>
                                              (v == null || v.isEmpty)
                                                  ? LOCALIZATION.localize(
                                                        "main_word.required",
                                                      ) ??
                                                      "Required"
                                                  : null,
                                    ),

                                    TextFormField(
                                      controller: shortformController,
                                      decoration: InputDecoration(
                                        labelText: LOCALIZATION.localize(
                                          "inventory_page.shortform",
                                        ),
                                      ),
                                    ),

                                    TextFormField(
                                      controller: categoriesController,
                                      decoration: InputDecoration(
                                        labelText:
                                            LOCALIZATION.localize(
                                              "main_word.category",
                                            ) ??
                                            "Category",
                                      ),
                                      validator:
                                          (v) =>
                                              (v == null || v.isEmpty)
                                                  ? LOCALIZATION.localize(
                                                        "main_word.required",
                                                      ) ??
                                                      "Required"
                                                  : null,
                                    ),

                                    TextFormField(
                                      controller: priceController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText:
                                            "${LOCALIZATION.localize("main_word.price") ?? "Price"} (${globalAppConfig["userPreferences"]["currency"]})",
                                      ),
                                      validator:
                                          (v) =>
                                              double.tryParse(v ?? '') == null
                                                  ? LOCALIZATION.localize(
                                                        "main_word.invalid",
                                                      ) ??
                                                      "Invalid"
                                                  : null,
                                    ),

                                    TextFormField(
                                      controller: totalStocksController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText:
                                            LOCALIZATION.localize(
                                              "main_word.total_stock",
                                            ) ??
                                            "Total Stocks",
                                      ),
                                      validator:
                                          (v) =>
                                              int.tryParse(v ?? '') == null
                                                  ? LOCALIZATION.localize(
                                                        "main_word.invalid",
                                                      ) ??
                                                      "Invalid"
                                                  : null,
                                    ),

                                    TextFormField(
                                      controller: totalPiecesController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: LOCALIZATION.localize(
                                          "main_word.total_pieces",
                                        ),
                                      ),
                                      validator: (v) {
                                        final val = int.tryParse(v ?? '');
                                        if (val == null || val < 1) {
                                          return LOCALIZATION.localize(
                                                "main_word.invalid",
                                              ) ??
                                              "Invalid";
                                        }
                                        return null;
                                      },
                                    ),

                                    Row(
                                      children: [
                                        Checkbox(
                                          value: exist,
                                          onChanged:
                                              (v) => setDialogState(
                                                () => exist = v ?? true,
                                              ),
                                        ),
                                        Text(
                                          LOCALIZATION.localize(
                                                "main_word.active",
                                              ) ??
                                              "Active",
                                        ),
                                      ],
                                    ),

                                    Row(
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child:
                                              imagePath != null
                                                  ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: Image.file(
                                                      File(imagePath!),
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                  : Icon(
                                                    Icons.image,
                                                    color: Colors.grey.shade400,
                                                  ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          onPressed: pickImage,
                                          icon: const Icon(Icons.upload),
                                          label: Text(
                                            LOCALIZATION.localize(
                                              "main_word.select_image",
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: resetForm,
                                          child: Text(
                                            LOCALIZATION.localize(
                                                  "main_word.cancel",
                                                ) ??
                                                "Cancel",
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton(
                                          onPressed: confirmItem,
                                          child: Text(
                                            LOCALIZATION.localize(
                                                  "main_word.confirm",
                                                ) ??
                                                "Confirm",
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child:
                        itemsList.isNotEmpty
                            ? ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(
                                LOCALIZATION.localize(
                                      "main_word.confirm_all",
                                    ) ??
                                    "Confirm All",
                              ),
                              onPressed: () async {
                                if (itemsList.isEmpty) return;

                                List<int> checkSuccess = await inventory
                                    .addProducts(itemsList);

                                if (checkSuccess.isNotEmpty) {
                                  showToastMessage(
                                    context,
                                    "${LOCALIZATION.localize("inventory_page.bulk_add_success") ?? "Bulk add success"}: ${checkSuccess.length}",
                                    ToastLevel.success,
                                    position: ToastPosition.topRight,
                                  );
                                  if (onConfirm != null) onConfirm();
                                } else {
                                  showToastMessage(
                                    context,
                                    LOCALIZATION.localize(
                                          "inventory_page.bulk_add_failed",
                                        ) ??
                                        "Bulk add failed",
                                    ToastLevel.error,
                                    position: ToastPosition.topRight,
                                  );
                                }

                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            )
                            : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBulkAddStockWidget(
    BuildContext context, {
    Future<void> Function()? onConfirm,
    required List<Map<String, dynamic>> products,
  }) {
    final _formKey = GlobalKey<FormState>();
    final List<Map<String, dynamic>> stockList = [];
    Map<String, dynamic>? selectedProduct;
    final stockController = TextEditingController();
    final productController = TextEditingController();

    void resetForm(StateSetter setDialogState) {
      selectedProduct = null;
      productController.clear();
      stockController.clear();
      setDialogState(() {});
    }

    void confirmStock(StateSetter setDialogState) {
      if (!_formKey.currentState!.validate() || selectedProduct == null) return;
      final int addAmount = int.tryParse(stockController.text.trim()) ?? 0;
      if (addAmount <= 0) return;

      // Prevent duplicate product in the list
      if (stockList.any((item) => item['id'] == selectedProduct!['id'])) {
        showToastMessage(
          context,
          LOCALIZATION.localize("inventory_page.duplicate_product") ??
              "Product already in the list.",
          ToastLevel.error,
        );
        return;
      }

      stockList.add({
        "id": selectedProduct!['id'],
        "name": selectedProduct!['name'],
        "categories": selectedProduct!['categories'],
        "image": selectedProduct!['image'],
        "add_stock": addAmount,
        "total_stocks": selectedProduct!['total_stocks'],
      });
      // Reset both selectedProduct and productController for next entry
      selectedProduct = null;
      productController.clear();
      stockController.clear();
      setDialogState(() {});
    }

    return StatefulBuilder(
      builder: (context, setDialogState) {
        // Use MediaQuery to get available height minus keyboard
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;
        final availableHeight =
            MediaQuery.of(context).size.height * 0.8 - viewInsets;

        return SizedBox(
          width: 500,
          height: availableHeight > 400 ? availableHeight : 400,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: 12,
              right: MediaQuery.of(context).viewInsets.right,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LOCALIZATION.localize("inventory_page.bulk_add_stock") ??
                      "Bulk Add Stock",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),

                // Make the whole content scrollable to avoid overflow
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: viewInsets + 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TypeAheadField<Map<String, dynamic>>(
                                suggestionsCallback: (pattern) {
                                  return products
                                      .where((p) => (p['exist'] ?? 1) == 1)
                                      .where(
                                        (p) =>
                                            (p['name']?.toLowerCase() ?? '')
                                                .contains(
                                                  pattern.toLowerCase(),
                                                ) ||
                                            (p['shortform']?.toLowerCase() ??
                                                    '')
                                                .contains(
                                                  pattern.toLowerCase(),
                                                ),
                                      )
                                      .toList();
                                },
                                builder: (context, controller, focusNode) {
                                  controller.text = productController.text;
                                  controller
                                      .selection = TextSelection.fromPosition(
                                    TextPosition(
                                      offset: controller.text.length,
                                    ),
                                  );
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText:
                                          LOCALIZATION.localize(
                                            "main_word.product",
                                          ) ??
                                          "Product",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        productController.text = val;
                                        selectedProduct = null;
                                      });
                                    },
                                  );
                                },
                                itemBuilder: (context, product) {
                                  return ListTile(
                                    leading:
                                        product['image'] != null
                                            ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Image.memory(
                                                product['image'],
                                                width: 32,
                                                height: 32,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                            : Icon(
                                              Icons.inventory_2,
                                              color: Colors.grey.shade400,
                                            ),
                                    title: Text(product['name'] ?? ''),
                                    subtitle: Text(product['categories'] ?? ''),
                                  );
                                },
                                onSelected: (product) {
                                  setDialogState(() {
                                    selectedProduct = product;
                                    productController.text =
                                        product['name'] ?? '';
                                  });
                                },
                                emptyBuilder:
                                    (context) => Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        LOCALIZATION.localize(
                                              "inventory_page.no_product_found",
                                            ) ??
                                            "No product found",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText:
                                      LOCALIZATION.localize(
                                        "main_word.amount",
                                      ) ??
                                      "Amount",
                                  border: const OutlineInputBorder(),
                                ),
                                validator:
                                    (v) =>
                                        (int.tryParse(v ?? '') ?? 0) <= 0
                                            ? LOCALIZATION.localize(
                                                  "main_word.invalid",
                                                ) ??
                                                "Invalid"
                                            : null,
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: Text(
                                    LOCALIZATION.localize(
                                          "main_word.add_item",
                                        ) ??
                                        "Add",
                                  ),
                                  onPressed: () => confirmStock(setDialogState),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bulk list at the bottom, scrollable
                        if (stockList.isNotEmpty) ...[
                          Text(
                            LOCALIZATION.localize(
                                  "inventory_page.added_items",
                                ) ??
                                "✅ Added Items",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: stockList.length,
                            itemBuilder: (context, index) {
                              final item = stockList[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading:
                                      item["image"] != null
                                          ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Image.memory(
                                              item["image"],
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                          : Icon(
                                            Icons.inventory_2,
                                            color: Colors.grey.shade400,
                                          ),
                                  title: Text(item["name"] ?? ""),
                                  subtitle: Text(
                                    "${LOCALIZATION.localize("main_word.current_stock") ?? "Current"}: ${item["total_stocks"] ?? 0}  +${item["add_stock"]}",
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed:
                                        () => setDialogState(
                                          () => stockList.removeAt(index),
                                        ),
                                    tooltip: LOCALIZATION.localize(
                                      "main_word.delete",
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 32),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                LOCALIZATION.localize("main_word.cancel") ??
                                    "Cancel",
                              ),
                            ),
                            const SizedBox(width: 12),

                            ElevatedButton(
                              onPressed: () async {
                                if (stockList.isEmpty) return;
                                // Prepare map for bulkAddStocks
                                final Map<dynamic, int> bulkMap = {
                                  for (var item in stockList)
                                    item['id']: item['add_stock'] ?? 0,
                                };
                                final result = await inventory.addStocks(
                                  bulkMap,
                                );

                                if (result) {
                                  showToastMessage(
                                    context,
                                    LOCALIZATION.localize(
                                          "inventory_page.add_stock_success",
                                        ) ??
                                        "Stock added.",
                                    ToastLevel.success,
                                  );

                                  if (onConfirm != null) onConfirm();
                                } else {
                                  showToastMessage(
                                    context,
                                    LOCALIZATION.localize(
                                          "inventory_page.bulk_add_failed",
                                        ) ??
                                        "Bulk add failed",
                                    ToastLevel.error,
                                  );
                                }
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                LOCALIZATION.localize("main_word.confirm_all"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBulkDeleteItemWidget(
    BuildContext context, {
    required List<Map<String, dynamic>> products,
    Future<void> Function()? onConfirm,
  }) {
    final List<Map<String, dynamic>> selectedProducts = [];
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';

    return StatefulBuilder(
      builder: (context, setDialogState) {
        // Filter products by search
        final filteredProducts =
            products.where((p) {
              final name = (p['name'] ?? '').toLowerCase();
              final shortform = (p['shortform'] ?? '').toLowerCase();
              return name.contains(searchQuery.toLowerCase()) ||
                  shortform.contains(searchQuery.toLowerCase());
            }).toList();

        void toggleSelection(Map<String, dynamic> product) {
          setDialogState(() {
            if (selectedProducts.contains(product)) {
              selectedProducts.remove(product);
            } else {
              selectedProducts.add(product);
            }
          });
        }

        Future<void> confirmDelete() async {
          if (selectedProducts.isEmpty) return;
          final ids = selectedProducts.map((p) => p['id']).toList();
          final result = await inventory.deleteProducts(ids);
          if (result) {
            showToastMessage(
              context,
              "${LOCALIZATION.localize("inventory_page.bulk_delete_success") ?? "Bulk delete success"}: ${ids.length}",
              ToastLevel.success,
              position: ToastPosition.topRight,
            );
            if (onConfirm != null) await onConfirm();
          } else {
            showToastMessage(
              context,
              LOCALIZATION.localize("inventory_page.bulk_delete_failed") ??
                  "Bulk delete failed",
              ToastLevel.error,
              position: ToastPosition.topRight,
            );
          }
          Navigator.of(context).pop();
        }

        return SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LOCALIZATION.localize(
                        "inventory_page.bulk_delete_products",
                      ) ??
                      "Bulk Delete Products",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText:
                        LOCALIZATION.localize(
                          "inventory_page.search_product",
                        ) ??
                        "Search product",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child:
                      filteredProducts.isEmpty
                          ? Center(
                            child: Text(
                              LOCALIZATION.localize(
                                    "inventory_page.no_product_found",
                                  ) ??
                                  "No product found",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                          : ListView.builder(
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              final isSelected = selectedProducts.contains(
                                product,
                              );
                              return Card(
                                color:
                                    isSelected
                                        ? Colors.red.withOpacity(0.08)
                                        : null,
                                child: ListTile(
                                  leading:
                                      product['image'] != null
                                          ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Image.memory(
                                              product['image'],
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                          : Icon(
                                            Icons.inventory_2,
                                            color: Colors.grey.shade400,
                                          ),
                                  title: Text(product['name'] ?? ''),
                                  subtitle: Text(product['categories'] ?? ''),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => toggleSelection(product),
                                  ),
                                  onTap: () => toggleSelection(product),
                                ),
                              );
                            },
                          ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child:
                        selectedProducts.isNotEmpty
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButtonWithSound(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    LOCALIZATION.localize("main_word.cancel") ??
                                        "Cancel",
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.delete_forever),
                                  label: Text(
                                    LOCALIZATION.localize(
                                          "inventory_page.confirm_delete",
                                        ) ??
                                        "Delete Selected",
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: Text(
                                              LOCALIZATION.localize(
                                                    "inventory_page.confirm_delete_title",
                                                  ) ??
                                                  "Confirm Delete",
                                            ),
                                            content: Text(
                                              LOCALIZATION.localize(
                                                    "inventory_page.confirm_delete_desc",
                                                  ) ??
                                                  "Are you sure you want to delete the selected products? This action cannot be undone.",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(false),
                                                child: Text(
                                                  LOCALIZATION.localize(
                                                        "main_word.cancel",
                                                      ) ??
                                                      "Cancel",
                                                ),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                onPressed:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(true),
                                                child: Text(
                                                  LOCALIZATION.localize(
                                                        "main_word.confirm",
                                                      ) ??
                                                      "Confirm",
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                    if (confirm == true) {
                                      await confirmDelete();
                                    }
                                  },
                                ),
                              ],
                            )
                            : TextButtonWithSound(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                LOCALIZATION.localize("main_word.cancel") ??
                                    "Cancel",
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _buildEditProductDialog(
    BuildContext context, {
    required Map<String, dynamic> productData,
    required Future<void> Function() onConfirm,
  }) async {
    final nameController = TextEditingController(
      text: productData['name'] ?? '',
    );
    final shortformController = TextEditingController(
      text: productData['shortform'] ?? '',
    );
    final categoriesController = TextEditingController(
      text: productData['categories'] ?? '',
    );
    final priceController = TextEditingController(
      text: productData['price']?.toString() ?? '',
    );
    final totalStocksController = TextEditingController(
      text: productData['total_stocks']?.toString() ?? '',
    );
    final totalPiecesController = TextEditingController(
      text: productData['total_pieces']?.toString() ?? '',
    );
    bool exist = (productData['exist'] ?? 1) == 1;
    Uint8List? imageBlob = productData['image'];
    String? imagePath;

    final _formKey = GlobalKey<FormState>();

    Future<void> pickImage(StateSetter setStateDialog) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        File file = File(picked.path);
        Uint8List bytes = await file.readAsBytes();
        double sizeInMB = bytes.lengthInBytes / (1024 * 1024);

        int quality = 90;
        while (sizeInMB > 5 && quality > 10) {
          bytes =
              (await FlutterImageCompress.compressWithList(
                bytes,
                quality: quality,
              ))!;
          sizeInMB = bytes.lengthInBytes / (1024 * 1024);
          quality -= 10;
        }

        if (sizeInMB > 5) {
          showToastMessage(
            context,
            LOCALIZATION.localize("main_word.image_too_large") ??
                "Image size exceeds 5MB even after compression. Please pick a smaller image.",
            ToastLevel.error,
          );
          return;
        }

        setStateDialog(() {
          imagePath = picked.path;
          imageBlob = bytes;
        });
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                LOCALIZATION.localize("main_word.edit_item") ?? "Edit Item",
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText:
                              LOCALIZATION.localize("main_word.name") ?? "Name",
                        ),
                        validator:
                            (v) =>
                                (v == null || v.isEmpty)
                                    ? LOCALIZATION.localize(
                                          "main_word.required",
                                        ) ??
                                        "Required"
                                    : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: shortformController,
                        decoration: InputDecoration(
                          labelText: LOCALIZATION.localize(
                            "inventory_page.shortform",
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: categoriesController,
                        decoration: InputDecoration(
                          labelText:
                              LOCALIZATION.localize("main_word.category") ??
                              "Category",
                        ),
                        validator:
                            (v) =>
                                (v == null || v.isEmpty)
                                    ? LOCALIZATION.localize(
                                          "main_word.required",
                                        ) ??
                                        "Required"
                                    : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              "${LOCALIZATION.localize("main_word.price") ?? "Price"} (${globalAppConfig["userPreferences"]["currency"]})",
                        ),
                        validator:
                            (v) =>
                                double.tryParse(v ?? '') == null
                                    ? LOCALIZATION.localize(
                                          "main_word.invalid",
                                        ) ??
                                        "Invalid"
                                    : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: totalStocksController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              LOCALIZATION.localize("main_word.total_stock") ??
                              "Total Stocks",
                        ),
                        validator:
                            (v) =>
                                int.tryParse(v ?? '') == null
                                    ? LOCALIZATION.localize(
                                          "main_word.invalid",
                                        ) ??
                                        "Invalid"
                                    : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: totalPiecesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: LOCALIZATION.localize(
                            "main_word.total_pieces",
                          ),
                        ),
                        validator:
                            (v) =>
                                int.tryParse(v ?? '') == null
                                    ? LOCALIZATION.localize(
                                          "main_word.invalid",
                                        ) ??
                                        "Invalid"
                                    : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: exist,
                            onChanged:
                                (v) => setStateDialog(() => exist = v ?? true),
                          ),
                          Text(
                            LOCALIZATION.localize("main_word.active") ??
                                "Active",
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:
                                imageBlob != null
                                    ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.memory(
                                            imageBlob!,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: GestureDetector(
                                            onTap: () {
                                              setStateDialog(() {
                                                imageBlob = null;
                                                imagePath = null;
                                              });
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              child: const Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                    : Icon(
                                      Icons.image,
                                      color: Colors.grey.shade400,
                                    ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => pickImage(setStateDialog),
                            icon: const Icon(Icons.upload),
                            label: Text(
                              LOCALIZATION.localize("main_word.select_image"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    LOCALIZATION.localize("main_word.cancel") ?? "Cancel",
                  ),
                ),

                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  label: Text(
                    LOCALIZATION.localize("main_word.delete") ?? "Delete",
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text(
                              LOCALIZATION.localize(
                                    "inventory_page.confirm_delete_title",
                                  ) ??
                                  "Confirm Delete",
                            ),
                            content: Text(
                              LOCALIZATION.localize(
                                    "inventory_page.confirm_delete_desc",
                                  ) ??
                                  "Are you sure you want to delete this product? This action cannot be undone.",
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: Text(
                                  LOCALIZATION.localize("main_word.cancel") ??
                                      "Cancel",
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: Text(
                                  LOCALIZATION.localize("main_word.confirm") ??
                                      "Confirm",
                                ),
                              ),
                            ],
                          ),
                    );
                    if (confirm == true) {
                      await inventory.deleteProducts([productData['id']]);
                      await onConfirm();
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.bulk_delete_success",
                            ) ??
                            "Product deleted.",
                        ToastLevel.success,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final updatedData = {
                      "name": nameController.text.trim(),
                      "shortform":
                          shortformController.text.trim().toUpperCase(),
                      "categories":
                          categoriesController.text.trim().toUpperCase(),
                      "price":
                          double.tryParse(priceController.text.trim()) ?? 0.0,
                      "total_stocks":
                          int.tryParse(totalStocksController.text.trim()) ?? 0,
                      "total_pieces":
                          int.tryParse(totalPiecesController.text.trim()) ?? 0,
                      "exist": exist ? 1 : 0,
                      "image": imageBlob,
                    };

                    bool checkSame = true;
                    for (var entry in updatedData.entries) {
                      if (productData[entry.key] != entry.value) {
                        checkSame = false;
                        break;
                      }
                    }

                    if (checkSame) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize("main_word.no_changes") ??
                            "No changes made.",
                        ToastLevel.warning,
                      );
                      Navigator.of(context).pop();
                      return;
                    }

                    // Check for name and shortform duplicates
                    final duplicateName = inventoryItems.any(
                      (item) =>
                          item['name'] == updatedData['name'] &&
                          item['id'] != productData['id'],
                    );
                    final duplicateShortform =
                        updatedData['shortform'].toString().isNotEmpty &&
                        inventoryItems.any(
                          (item) =>
                              item['shortform'] == updatedData['shortform'] &&
                              item['id'] != productData['id'],
                        );

                    if (duplicateName) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.duplicate_name",
                            ) ??
                            "Product name already exists.",
                        ToastLevel.error,
                      );
                      return;
                    }
                    if (duplicateShortform) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.duplicate_shortform",
                            ) ??
                            "Product shortform already exists.",
                        ToastLevel.error,
                      );
                      return;
                    }

                    await inventory.updateKioskProductData(
                      bulkData: {"${productData['id']}": updatedData},
                    );
                    await onConfirm();
                    Navigator.of(context).pop();
                    showToastMessage(
                      context,
                      "#${productData['id']} ${LOCALIZATION.localize("main_word.edit_success")}" ??
                          "Product updated.",
                      ToastLevel.success,
                    );
                  },
                  child: Text(
                    LOCALIZATION.localize("main_word.confirm") ?? "Confirm",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter by search and category
    var filteredProducts =
        inventoryItems.where((p) {
          final matchesSearch =
              (p['name']?.toLowerCase() ?? '').contains(
                searchQuery.toLowerCase(),
              ) ||
              (p['shortform']?.toLowerCase() ?? '').contains(
                searchQuery.toLowerCase(),
              );
          final matchesCategory =
              selectedCategory == null ||
              selectedCategory == '' ||
              p['categories'] == selectedCategory;
          return matchesSearch && matchesCategory;
        }).toList();

    // Sort
    filteredProducts.sort((a, b) {
      int cmp;
      if (sortBy == 'Name') {
        cmp = (a['name'] ?? '').compareTo(b['name'] ?? '');
      } else if (sortBy == 'Stock') {
        cmp = (a['total_stocks'] ?? 0).compareTo(b['total_stocks'] ?? 0);
      } else if (sortBy == 'Price') {
        cmp = (a['price'] ?? 0).compareTo(b['price'] ?? 0);
      } else {
        cmp = 0;
      }
      return sortAsc ? cmp : -cmp;
    });

    final selectedProduct =
        selectedProductId != null
            ? inventoryItems.firstWhere(
              (p) => p['id'] == selectedProductId,
              orElse:
                  () =>
                      filteredProducts.isNotEmpty
                          ? filteredProducts[0]
                          : <String, dynamic>{},
            )
            : (filteredProducts.isNotEmpty ? filteredProducts[0] : null);

    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Row(
        children: [
          // Left: Product List
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Row(
                  children: [
                    // Category Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: LOCALIZATION.localize(
                            "main_word.category",
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              LOCALIZATION.localize("main_word.all_categories"),
                            ),
                          ),
                          ...categories.map(
                            (cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sorter Dropdown
                    DropdownButton<String>(
                      value: sortBy,
                      items: [
                        DropdownMenuItem(
                          value: 'Name',
                          child: Text(
                            "${LOCALIZATION.localize("main_word.sort_by")} ${LOCALIZATION.localize("main_word.name")}",
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Stock',
                          child: Text(
                            "${LOCALIZATION.localize("main_word.sort_by")} ${LOCALIZATION.localize("main_word.stock")}",
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Price',
                          child: Text(
                            "${LOCALIZATION.localize("main_word.sort_by")} ${LOCALIZATION.localize("main_word.price")}",
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => sortBy = value);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                      ),
                      tooltip: LOCALIZATION.localize(
                        "inventory_page.toggle_sort_order",
                      ),
                      onPressed: () => setState(() => sortAsc = !sortAsc),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 12),
                // Product List
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final isSelected =
                            selectedProduct != null &&
                            product['id'] == selectedProduct['id'];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child:
                                product['image'] == null
                                    ? Icon(
                                      Icons.inventory_2,
                                      color: Colors.grey.shade600,
                                    )
                                    : ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.memory(
                                        product['image'],
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                          ),
                          title: Text(product['name'] ?? ''),
                          subtitle: Text(product['categories'] ?? ''),
                          trailing: _buildStockStatus(
                            product['total_stocks'] ?? 0,
                          ),
                          selected: isSelected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08),
                          onTap: () {
                            setState(() {
                              selectedProductId = product['id'];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Bulk Section: One button, opens dialog with more actions
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButtonWithSound.icon(
                    icon: const Icon(Icons.all_inbox),
                    label: Text(
                      LOCALIZATION.localize(
                            "inventory_page.bulk_section_title",
                          ) ??
                          "Bulk",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _showBulkDialog(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // Right: Details & Analytics
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Top: Product Details
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        selectedProduct == null
                            ? Center(
                              child: Text(
                                LOCALIZATION.localize(
                                  "inventory_page.no_product_selected",
                                ),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                            : Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Row(
                                children: [
                                  // Product Image
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child:
                                        selectedProduct['image'] == null
                                            ? Icon(
                                              Icons.image_not_supported,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            )
                                            : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(
                                                selectedProduct['image'],
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                  ),
                                  const SizedBox(width: 24),

                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          selectedProduct['name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        ),

                                        Text(
                                          selectedProduct['categories'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        Row(
                                          children: [
                                            Text(
                                              "${LOCALIZATION.localize("main_word.price")}: ",
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              "${globalAppConfig["userPreferences"]["currency"]} ${selectedProduct['price'].toStringAsFixed(2) ?? '0.00'}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        Row(
                                          children: [
                                            Text(
                                              "${LOCALIZATION.localize("main_word.stock")}: ",
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              "${selectedProduct['total_stocks'] ?? 0}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildStockStatus(
                                              selectedProduct['total_stocks'] ??
                                                  0,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        Row(
                                          children: [
                                            Text(
                                              "${LOCALIZATION.localize("inventory_page.pieces")}: ",
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              "${selectedProduct['total_pieces'] ?? 0}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              "${LOCALIZATION.localize("main_word.used")}: ${selectedProduct['total_pieces_used'] ?? 0}",
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        Row(
                                          children: [
                                            Text(
                                              "${LOCALIZATION.localize("main_word.status")}: ",
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              selectedProduct['exist'] == 1
                                                  ? LOCALIZATION.localize(
                                                    "main_word.active",
                                                  )
                                                  : LOCALIZATION.localize(
                                                    "main_word.inactive",
                                                  ),
                                              style: TextStyle(
                                                color:
                                                    selectedProduct['exist'] ==
                                                            1
                                                        ? Colors.green
                                                        : Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quick Actions
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Edit Button
                                      ElevatedButtonWithSound.icon(
                                        icon: const Icon(Icons.edit, size: 18),
                                        label: Text(
                                          LOCALIZATION.localize(
                                            "main_word.edit",
                                          ),
                                        ),
                                        onPressed:
                                            selectedProduct == null
                                                ? null
                                                : () async {
                                                  await _buildEditProductDialog(
                                                    context,
                                                    productData:
                                                        selectedProduct,
                                                    onConfirm: () async {
                                                      await _loadProducts();
                                                    },
                                                  );
                                                },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Add Stock Button
                                      ElevatedButtonWithSound.icon(
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(
                                          LOCALIZATION.localize(
                                            "main_word.stock",
                                          ),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              final stockController =
                                                  TextEditingController();
                                              return AlertDialog(
                                                title: Text(
                                                  LOCALIZATION.localize(
                                                        "inventory_page.add_stock",
                                                      ) ??
                                                      "Add Stock",
                                                ),
                                                content: TextField(
                                                  controller: stockController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        LOCALIZATION.localize(
                                                          "main_word.amount",
                                                        ) ??
                                                        "Amount",
                                                    border:
                                                        const OutlineInputBorder(),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButtonWithSound(
                                                    onPressed:
                                                        () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(),
                                                    child: Text(
                                                      LOCALIZATION.localize(
                                                            "main_word.cancel",
                                                          ) ??
                                                          "Cancel",
                                                    ),
                                                  ),
                                                  ElevatedButtonWithSound(
                                                    onPressed: () async {
                                                      final addAmount =
                                                          int.tryParse(
                                                            stockController.text
                                                                .trim(),
                                                          ) ??
                                                          0;
                                                      if (addAmount > 0) {
                                                        await inventory
                                                            .updateKioskProductData(
                                                              bulkData: {
                                                                "${selectedProduct['id']}": {
                                                                  "total_stocks":
                                                                      (selectedProduct['total_stocks'] ??
                                                                          0) +
                                                                      addAmount,
                                                                },
                                                              },
                                                            );
                                                        await _loadProducts();
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                        showToastMessage(
                                                          context,
                                                          LOCALIZATION.localize(
                                                                "inventory_page.add_stock_success",
                                                              ) ??
                                                              "Stock added.",
                                                          ToastLevel.success,
                                                        );
                                                      } else {
                                                        showToastMessage(
                                                          context,
                                                          LOCALIZATION.localize(
                                                                "main_word.invalid",
                                                              ) ??
                                                              "Invalid amount.",
                                                          ToastLevel.error,
                                                        );
                                                      }
                                                    },
                                                    child: Text(
                                                      LOCALIZATION.localize(
                                                            "main_word.confirm",
                                                          ) ??
                                                          "Confirm",
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Add Pieces Button
                                      ElevatedButtonWithSound.icon(
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(
                                          LOCALIZATION.localize(
                                                "inventory_page.used_pieces",
                                              ) ??
                                              "Add Pieces",
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              final packageController =
                                                  TextEditingController();
                                              final int currentStock =
                                                  selectedProduct['total_stocks'] ??
                                                  0;
                                              final int piecesPerStock =
                                                  selectedProduct['total_pieces'] ??
                                                  1;
                                              return AlertDialog(
                                                title: Text(
                                                  LOCALIZATION.localize(
                                                        "inventory_page.add_pieces",
                                                      ) ??
                                                      "Convert Stock to Pieces",
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${LOCALIZATION.localize("main_word.current_stock") ?? "Current Stock"}: $currentStock",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      "${LOCALIZATION.localize("main_word.pieces_per_stock") ?? "1 Stock ="} $piecesPerStock ${LOCALIZATION.localize("inventory_page.pieces") ?? "Pieces"}",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    TextField(
                                                      controller:
                                                          packageController,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            LOCALIZATION.localize(
                                                              "inventory_page.how_many_package",
                                                            ) ??
                                                            "How many stock to convert?",
                                                        hintText:
                                                            LOCALIZATION.localize(
                                                              "inventory_page.enter_package_count",
                                                            ) ??
                                                            "Enter number of stock to convert",
                                                        border:
                                                            const OutlineInputBorder(),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButtonWithSound(
                                                    onPressed:
                                                        () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(),
                                                    child: Text(
                                                      LOCALIZATION.localize(
                                                            "main_word.cancel",
                                                          ) ??
                                                          "Cancel",
                                                    ),
                                                  ),
                                                  ElevatedButtonWithSound(
                                                    onPressed: () async {
                                                      final int convertCount =
                                                          int.tryParse(
                                                            packageController
                                                                .text
                                                                .trim(),
                                                          ) ??
                                                          0;
                                                      if (convertCount <= 0) {
                                                        showToastMessage(
                                                          context,
                                                          LOCALIZATION.localize(
                                                                "main_word.invalid",
                                                              ) ??
                                                              "Invalid amount.",
                                                          ToastLevel.error,
                                                        );
                                                        return;
                                                      }
                                                      if (convertCount >
                                                          currentStock) {
                                                        showToastMessage(
                                                          context,
                                                          LOCALIZATION.localize(
                                                                "inventory_page.not_enough_stock",
                                                              ) ??
                                                              "Not enough stock to convert.",
                                                          ToastLevel.error,
                                                        );
                                                        return;
                                                      }
                                                      // Calculate new values
                                                      final int newStock =
                                                          currentStock -
                                                          convertCount;
                                                      final int addPieces =
                                                          convertCount *
                                                          piecesPerStock;
                                                      final int prevUsed =
                                                          selectedProduct['total_pieces_used'] ??
                                                          0;
                                                      final int newUsed =
                                                          prevUsed + addPieces;

                                                      await inventory
                                                          .updateKioskProductData(
                                                            bulkData: {
                                                              "${selectedProduct['id']}": {
                                                                "total_stocks":
                                                                    newStock,
                                                                "total_pieces_used":
                                                                    newUsed,
                                                              },
                                                            },
                                                          );
                                                      await _loadProducts();
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      showToastMessage(
                                                        context,
                                                        LOCALIZATION.localize(
                                                              "inventory_page.add_pieces_success",
                                                            ) ??
                                                            "Pieces added.",
                                                        ToastLevel.success,
                                                      );
                                                    },
                                                    child: Text(
                                                      LOCALIZATION.localize(
                                                            "main_word.confirm",
                                                          ) ??
                                                          "Confirm",
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Activate/Deactivate Button
                                      ElevatedButtonWithSound.icon(
                                        icon: Icon(
                                          selectedProduct['exist'] == 1
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 18,
                                        ),
                                        label: Text(
                                          selectedProduct['exist'] == 1
                                              ? LOCALIZATION.localize(
                                                "main_word.deactivate",
                                              )
                                              : LOCALIZATION.localize(
                                                "main_word.activate",
                                              ),
                                        ),
                                        onPressed: () async {
                                          final checkSuccessToggle =
                                              await inventory.toggleItemExistence(
                                                id: selectedProduct['id'],
                                                isProduct: true,
                                                forceValue:
                                                    selectedProduct['exist'] ==
                                                            1
                                                        ? 0
                                                        : 1,
                                              );

                                          if (checkSuccessToggle &&
                                              selectedProduct['exist'] == 1) {
                                            showToastMessage(
                                              context,
                                              LOCALIZATION.localize(
                                                    "inventory_page.deactivate_success",
                                                  ) ??
                                                  "Product updated.",
                                              ToastLevel.success,
                                            );
                                          } else if (checkSuccessToggle &&
                                              selectedProduct['exist'] == 0) {
                                            showToastMessage(
                                              context,
                                              LOCALIZATION.localize(
                                                    "inventory_page.activate_success",
                                                  ) ??
                                                  "Product updated.",
                                              ToastLevel.success,
                                            );
                                          } else {
                                            showToastMessage(
                                              context,
                                              LOCALIZATION.localize(
                                                    "inventory_page.toggle_product_failed",
                                                  ) ??
                                                  "Failed to toggle product.",
                                              ToastLevel.error,
                                            );
                                          }

                                          await _loadProducts();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 18),
                // Bottom: Analytics & Logs
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      // Logs
                      Expanded(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: _buildLogsSection(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
