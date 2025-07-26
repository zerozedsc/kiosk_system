import '../../configs/configs.dart';
import '../../services/inventory/inventory_services.dart';

import '../../components/buttonswithsound.dart';
import '../../components/toastmsg.dart';

class SetInventoryTab extends StatefulWidget {
  final ValueNotifier<int> reloadNotifier;
  const SetInventoryTab({super.key, required this.reloadNotifier});

  @override
  State<SetInventoryTab> createState() => _SetInventoryTabState();
}

class _SetInventoryTabState extends State<SetInventoryTab> {
  List<Map<String, dynamic>> setItems = [];
  String searchQuery = '';
  int? selectedSetId;
  String sortBy = 'Name';
  bool sortAsc = true;

  @override
  void initState() {
    super.initState();
    _loadSets();
    widget.reloadNotifier.addListener(() async {
      await _loadSets();
    });
  }

  @override
  void dispose() {
    widget.reloadNotifier.removeListener(() async {
      await _loadSets();
    });
    super.dispose();
  }

  Future<void> _loadSets() async {
    final setList =
        inventory.setCatalog?.entries
            .map((e) => {"id": e.key, ...e.value})
            .toList();
    setState(() {
      setItems = setList ?? [];
    });
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText:
            LOCALIZATION.localize("inventory_page.search_set") ?? "Search set",
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

  Widget _buildStatus(int exist) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:
            exist == 1
                ? Colors.green.withOpacity(0.15)
                : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        exist == 1
            ? LOCALIZATION.localize("main_word.active") ?? "Active"
            : LOCALIZATION.localize("main_word.inactive") ?? "Inactive",
        style: TextStyle(
          color: exist == 1 ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _parseSetItems(String setItemsStr) {
    // Simple parser for display
    if (setItemsStr.isEmpty) return '';
    final parts = setItemsStr.split(',');
    if (parts.isEmpty) return '';
    final type = parts[0].trim();
    final items = parts
        .skip(1)
        .map((e) => e.trim().replaceAll('#', ' '))
        .join(', ');
    return "$type: $items";
  }

  List<Map<String, dynamic>> _getSetProductList(String setItemsStr) {
    if (setItemsStr.isEmpty) return [];
    final List<Map<String, dynamic>> result = [];
    final parts = setItemsStr.split(',');
    if (parts.isEmpty) return [];
    // skip the first part (PIECE/PACKAGE)
    for (var i = 1; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty) continue;

      // Handle "15 PIECE" or "15 PACKAGE" (no underscore, just product id and type)
      if (part.contains('PIECE') || part.contains('PACKAGE')) {
        final tokens = part.split(' ');
        if (tokens.length == 2) {
          final id = int.tryParse(tokens[0]);
          if (id != null) {
            final prod = inventory.productCatalog?[id];
            if (prod != null) {
              result.add({"type": "product", "id": id, "qty": 1, ...prod});
            }
          }
        }
        continue;
      }

      // Handle normal "id_or_cat_qty" format
      final split = part.split('_');
      if (split.length != 2) continue;
      final idOrCat = split[0].trim();
      final qty = int.tryParse(split[1].trim()) ?? 1;

      // If idOrCat is int, treat as product id
      final id = int.tryParse(idOrCat);
      if (id != null) {
        final prod = inventory.productCatalog?[id];
        if (prod != null) {
          result.add({"type": "product", "id": id, "qty": qty, ...prod});
        }
      } else {
        // Treat as category (replace # with space)
        final cat = idOrCat.replaceAll('#', ' ');
        final productsInCat =
            inventory.productCatalog?.entries
                .where(
                  (e) =>
                      (e.value['categories'] ?? '').toString().toUpperCase() ==
                      cat.toUpperCase(),
                )
                .map(
                  (e) => {
                    "type": "category",
                    "id": e.key,
                    "qty": qty,
                    ...e.value,
                  },
                )
                .toList();
        if (productsInCat != null) {
          result.addAll(productsInCat);
        }
      }
    }
    return result;
  }

  Future<void> _buildAddSetDialog(
    BuildContext context, {
    required Future<void> Function() onConfirm,
    required List<Map<String, dynamic>> products,
    required List<String> categories,
    required List<String> setNames,
  }) async {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final maxQtyController = TextEditingController();
    String mode = 'PIECE';
    final List<Map<String, dynamic>> items = [];
    bool isSinglePiece = false;
    int? singleProductId;
    Uint8List? imageBlob;
    String? imagePath;

    String? itemType; // 'product' or 'category'
    dynamic itemValue; // id or category string
    final qtyController = TextEditingController();

    // Helper to pick image
    Future<void> pickImage(StateSetter setState) async {
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

        setState(() {
          imagePath = picked.path;
          imageBlob = bytes;
        });
      }
    }

    // Compose group_names from selected items
    String getGroupNames() {
      final Set<String> groupSet = {};
      if (isSinglePiece && singleProductId != null) {
        final prod = products.firstWhere(
          (p) => p['id'] == singleProductId,
          orElse: () => {},
        );
        if (prod['categories'] != null) groupSet.add(prod['categories']);
      } else {
        for (final item in items) {
          if (item['type'] == 'product') {
            final prod = products.firstWhere(
              (p) => p['id'] == item['id'],
              orElse: () => {},
            );
            if (prod['categories'] != null) groupSet.add(prod['categories']);
          } else if (item['type'] == 'category') {
            groupSet.add(item['category']);
          }
        }
      }
      return groupSet.map((e) => e.toString().replaceAll('#', ' ')).join(', ');
    }

    // Compose set_items string as per your format
    String getSetItemsString() {
      if (isSinglePiece && singleProductId != null && mode == 'PIECE') {
        // Special pattern: PIECE,15 PIECE
        return 'PIECE,${singleProductId!} PIECE';
      }
      final buffer = StringBuffer(mode);
      for (final item in items) {
        buffer.write(',');
        if (item['type'] == 'product') {
          buffer.write('${item['id']} _${item['qty']}');
        } else {
          buffer.write(
            '${item['category'].replaceAll(' ', '#')} _${item['qty']}',
          );
        }
      }
      return buffer.toString();
    }

    // Calculate max_qty from items
    int getMaxQty() {
      if (isSinglePiece && singleProductId != null && mode == 'PIECE') {
        return 1;
      }
      int sum = 0;
      for (final item in items) {
        sum += (item['qty'] ?? 0) as int;
      }
      return sum > 0 ? sum : 1;
    }

    void resetItemFields(StateSetter setState) {
      itemType = null;
      itemValue = null;
      qtyController.clear();
      setState(() {});
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Update maxQtyController in real time
            maxQtyController.text = getMaxQty().toString();

            return AlertDialog(
              title: Text(
                LOCALIZATION.localize("inventory_page.add_set") ?? "Add Set",
              ),
              content: SizedBox(
                width: 800,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Set Name
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize("main_word.name") ??
                                "Set Name",
                            border: const OutlineInputBorder(),
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? LOCALIZATION.localize(
                                            "main_word.required",
                                          ) ??
                                          "Required"
                                      : null,
                        ),
                        const SizedBox(height: 12),

                        // Price
                        TextFormField(
                          controller: priceController,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize("main_word.price") ??
                                "Price",
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator:
                              (v) =>
                                  (double.tryParse(v ?? '') == null)
                                      ? LOCALIZATION.localize(
                                            "main_word.invalid",
                                          ) ??
                                          "Invalid price"
                                      : null,
                        ),
                        const SizedBox(height: 12),

                        // Image Picker
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
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          imageBlob!,
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
                              onPressed: () => pickImage(setState),
                              icon: const Icon(Icons.upload),
                              label: Text(
                                LOCALIZATION.localize(
                                      "main_word.select_image",
                                    ) ??
                                    "Select Image",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Selling Mode (PIECE/PACKAGE, not localized)
                        DropdownButtonFormField<String>(
                          value: mode,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize(
                                  "inventory_page.selling_mode",
                                ) ??
                                "Selling Mode",
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'PIECE',
                              child: Text('PIECE'),
                            ),
                            DropdownMenuItem(
                              value: 'PACKAGE',
                              child: Text('PACKAGE'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => mode = v);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Single Product PIECE Checkbox
                        if (mode == 'PIECE')
                          Row(
                            children: [
                              Checkbox(
                                value: isSinglePiece,
                                onChanged: (v) {
                                  isSinglePiece = v ?? false;
                                  if (!isSinglePiece) singleProductId = null;
                                  setState(() {});
                                },
                              ),
                              Text(
                                LOCALIZATION.localize(
                                      "inventory_page.set_single_piece_checkbox",
                                    ) ??
                                    "This set is for selling a single product in PIECE mode",
                              ),
                            ],
                          ),
                        if (mode == 'PIECE' && isSinglePiece)
                          Padding(
                            padding: const EdgeInsets.only(left: 32, bottom: 8),
                            child: DropdownButtonFormField<int>(
                              value: singleProductId,
                              hint: Text(
                                LOCALIZATION.localize("main_word.product") ??
                                    "Product",
                              ),
                              isExpanded: true,
                              items:
                                  products
                                      .map(
                                        (p) => DropdownMenuItem<int>(
                                          value: p['id'] as int,
                                          child: Text(p['name'] ?? ''),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                singleProductId = v;
                                setState(() {});
                              },
                              validator: (v) {
                                if (isSinglePiece && (v == null)) {
                                  return LOCALIZATION.localize(
                                        "main_word.required",
                                      ) ??
                                      "Required";
                                }
                                return null;
                              },
                            ),
                          ),

                        // Add Item Section (hide if single PIECE mode)
                        if (!(mode == 'PIECE' && isSinglePiece))
                          Row(
                            children: [
                              // Type Selector
                              DropdownButton<String>(
                                value: itemType,
                                hint: Text(
                                  LOCALIZATION.localize("main_word.type") ??
                                      "Type",
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'product',
                                    child: Text(
                                      LOCALIZATION.localize(
                                            "main_word.product",
                                          ) ??
                                          'Product',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'category',
                                    child: Text(
                                      LOCALIZATION.localize(
                                            "main_word.category",
                                          ) ??
                                          'Category',
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  itemType = v;
                                  itemValue = null;
                                  setState(() {});
                                },
                              ),
                              const SizedBox(width: 8),
                              // Value Selector
                              if (itemType == 'product')
                                Expanded(
                                  child: DropdownButton<int>(
                                    value: itemValue,
                                    hint: Text(
                                      LOCALIZATION.localize(
                                            "main_word.product",
                                          ) ??
                                          "Product",
                                    ),
                                    isExpanded: true,
                                    items:
                                        products
                                            .map(
                                              (p) => DropdownMenuItem<int>(
                                                value: p['id'] as int,
                                                child: Text(p['name'] ?? ''),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) {
                                      itemValue = v;
                                      setState(() {});
                                    },
                                  ),
                                ),
                              if (itemType == 'category')
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: itemValue,
                                    hint: Text(
                                      LOCALIZATION.localize(
                                            "main_word.category",
                                          ) ??
                                          "Category",
                                    ),
                                    isExpanded: true,
                                    items:
                                        categories
                                            .map(
                                              (c) => DropdownMenuItem(
                                                value: c,
                                                child: Text(c),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) {
                                      itemValue = v;
                                      setState(() {});
                                    },
                                  ),
                                ),
                              const SizedBox(width: 8),
                              // Quantity
                              SizedBox(
                                width: 60,
                                child: TextFormField(
                                  controller: qtyController,
                                  decoration: InputDecoration(
                                    labelText:
                                        LOCALIZATION.localize(
                                          "main_word.qty",
                                        ) ??
                                        "Qty",
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  final qty = int.tryParse(
                                    qtyController.text.trim(),
                                  );
                                  if (itemType == null ||
                                      itemValue == null ||
                                      qty == null ||
                                      qty < 1) {
                                    showToastMessage(
                                      context,
                                      LOCALIZATION.localize(
                                            "inventory_page.fill_all_item_fields",
                                          ) ??
                                          "Please fill all item fields.",
                                      ToastLevel.error,
                                    );
                                    return;
                                  }
                                  // Prevent duplicate
                                  if (itemType == 'product' &&
                                      items.any(
                                        (e) =>
                                            e['type'] == 'product' &&
                                            e['id'] == itemValue,
                                      )) {
                                    showToastMessage(
                                      context,
                                      LOCALIZATION.localize(
                                            "inventory_page.product_already_added",
                                          ) ??
                                          "Product already added.",
                                      ToastLevel.error,
                                    );
                                    return;
                                  }
                                  if (itemType == 'category' &&
                                      items.any(
                                        (e) =>
                                            e['type'] == 'category' &&
                                            e['category'] == itemValue,
                                      )) {
                                    showToastMessage(
                                      context,
                                      LOCALIZATION.localize(
                                            "inventory_page.category_already_added",
                                          ) ??
                                          "Category already added.",
                                      ToastLevel.error,
                                    );
                                    return;
                                  }
                                  if (itemType == 'product') {
                                    items.add({
                                      'type': 'product',
                                      'id': itemValue,
                                      'qty': qty,
                                      'name':
                                          products.firstWhere(
                                            (p) => p['id'] == itemValue,
                                          )['name'],
                                    });
                                  } else {
                                    items.add({
                                      'type': 'category',
                                      'category': itemValue,
                                      'qty': qty,
                                    });
                                  }
                                  resetItemFields(setState);
                                  // Update maxQtyController after adding
                                  maxQtyController.text =
                                      getMaxQty().toString();
                                },
                                child: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        if (!(mode == 'PIECE' && isSinglePiece))
                          const SizedBox(height: 12),

                        // Preview List
                        if (!(mode == 'PIECE' && isSinglePiece) &&
                            items.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LOCALIZATION.localize(
                                      "inventory_page.items_in_set",
                                    ) ??
                                    "Items in Set:",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...items.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      item['type'] == 'product'
                                          ? Icons.inventory_2
                                          : Icons.category,
                                    ),
                                    title: Text(
                                      item['type'] == 'product'
                                          ? "${item['name']} (ID: ${item['id']})"
                                          : (item['category'] as String)
                                              .replaceAll('#', ' '),
                                    ),
                                    subtitle: Text(
                                      "${LOCALIZATION.localize("main_word.qty") ?? "Qty"}: ${item['qty']}",
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        items.removeAt(i);
                                        setState(() {
                                          maxQtyController.text =
                                              getMaxQty().toString();
                                        });
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        const SizedBox(height: 12),

                        // Generated set_items string
                        Text(
                          LOCALIZATION.localize(
                                "inventory_page.generated_set_items",
                              ) ??
                              "Generated set_items:",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            getSetItemsString(),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),

                        // Show calculated max_qty
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              Text(
                                "${LOCALIZATION.localize("main_word.max_qty") ?? "Max Qty"}: ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                getMaxQty().toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    if (mode == 'PIECE' && isSinglePiece) {
                      if (singleProductId == null) {
                        showToastMessage(
                          context,
                          LOCALIZATION.localize("main_word.required") ??
                              "Please select a product.",
                          ToastLevel.error,
                        );
                        return;
                      }
                    } else if (items.isEmpty) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.add_at_least_one_item",
                            ) ??
                            "Add at least one item.",
                        ToastLevel.error,
                      );
                      return;
                    }

                    final name = nameController.text.trim();

                    if (setNames.contains(name)) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.set_name_already_exists",
                            ) ??
                            "Set name already exists.",
                        ToastLevel.error,
                      );
                      return;
                    }

                    final price =
                        double.tryParse(priceController.text.trim()) ?? 0.0;
                    final maxQty = getMaxQty();
                    final setItems = getSetItemsString();
                    final groupNames = getGroupNames();

                    // Compose data for set_product table
                    final data = [
                      {
                        'name': name.toUpperCase(),
                        'group_names': groupNames.toUpperCase(),
                        'price': price,
                        'set_items': setItems,
                        'max_qty': maxQty,
                        'exist': 1,
                        'image': imageBlob,
                      },
                    ];

                    // Save to DB here if needed
                    final checkSendData = await inventory.createNewSets(data);

                    if (checkSendData.isEmpty) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.set_added_failed",
                            ) ??
                            "Set added failed.",
                        ToastLevel.error,
                      );
                      INVENTORY_LOGS.error(
                        "Failed to add set: $name",
                        checkSendData,
                        StackTrace.current,
                      );
                      return;
                    }

                    await onConfirm();

                    showToastMessage(
                      context,
                      LOCALIZATION.localize(
                            "inventory_page.set_added_successfully",
                          ) ??
                          "Set added successfully.",
                      ToastLevel.success,
                    );

                    Navigator.of(context).pop();
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

  Future<void> _buildAdjustSetDialog(
    BuildContext context, {
    required Map<String, dynamic> setData,
    required List<Map<String, dynamic>> products,
    required List<String> categories,
    required Future<void> Function() onConfirm,
  }) async {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: setData['name'] ?? '');
    final priceController = TextEditingController(
      text: setData['price']?.toString() ?? '',
    );
    final maxQtyController = TextEditingController();
    String mode =
        setData['set_items']?.toString().startsWith('PACKAGE') == true
            ? 'PACKAGE'
            : 'PIECE';
    final List<Map<String, dynamic>> items = [];
    bool isSinglePiece = false;
    int? singleProductId;
    Uint8List? imageBlob = setData['image'];
    String? imagePath;

    String? itemType;
    dynamic itemValue;
    final qtyController = TextEditingController();

    // Parse set_items to fill items list and single product mode
    void parseSetItems() {
      final setItemsStr = setData['set_items'] ?? '';
      if (setItemsStr.isEmpty) return;
      final parts = setItemsStr.split(',');
      if (parts.isEmpty) return;
      mode = parts[0].trim();
      if (parts.length == 2 && parts[1].trim().endsWith('PIECE')) {
        // PIECE,15 PIECE
        isSinglePiece = true;
        final idStr = parts[1].trim().split(' ')[0];
        singleProductId = int.tryParse(idStr);
        return;
      }
      for (var i = 1; i < parts.length; i++) {
        final part = parts[i].trim();
        if (part.isEmpty) continue;
        final split = part.split('_');
        if (split.length != 2) continue;
        final idOrCat = split[0].trim();
        final qty = int.tryParse(split[1].trim()) ?? 1;
        final id = int.tryParse(idOrCat);
        if (id != null) {
          final prod = products.firstWhere(
            (p) => p['id'] == id,
            orElse: () => {},
          );
          items.add({
            'type': 'product',
            'id': id,
            'qty': qty,
            'name': prod['name'] ?? '',
          });
        } else {
          items.add({
            'type': 'category',
            'category': idOrCat.replaceAll('#', ' '),
            'qty': qty,
          });
        }
      }
    }

    parseSetItems();

    // Helper to pick image
    Future<void> pickImage(StateSetter setState) async {
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

        setState(() {
          imagePath = picked.path;
          imageBlob = bytes;
        });
      }
    }

    String getGroupNames() {
      final Set<String> groupSet = {};
      if (isSinglePiece && singleProductId != null) {
        final prod = products.firstWhere(
          (p) => p['id'] == singleProductId,
          orElse: () => {},
        );
        if (prod['categories'] != null) groupSet.add(prod['categories']);
      } else {
        for (final item in items) {
          if (item['type'] == 'product') {
            final prod = products.firstWhere(
              (p) => p['id'] == item['id'],
              orElse: () => {},
            );
            if (prod['categories'] != null) groupSet.add(prod['categories']);
          } else if (item['type'] == 'category') {
            groupSet.add(item['category']);
          }
        }
      }
      return groupSet.map((e) => e.toString().replaceAll('#', ' ')).join(', ');
    }

    String getSetItemsString() {
      if (isSinglePiece && singleProductId != null && mode == 'PIECE') {
        return 'PIECE,${singleProductId!} PIECE';
      }
      final buffer = StringBuffer(mode);
      for (final item in items) {
        buffer.write(',');
        if (item['type'] == 'product') {
          buffer.write('${item['id']} _${item['qty']}');
        } else {
          buffer.write(
            '${item['category'].replaceAll(' ', '#')} _${item['qty']}',
          );
        }
      }
      return buffer.toString();
    }

    int getMaxQty() {
      if (isSinglePiece && singleProductId != null && mode == 'PIECE') {
        return 1;
      }
      int sum = 0;
      for (final item in items) {
        sum += (item['qty'] ?? 0) as int;
      }
      return sum > 0 ? sum : 1;
    }

    void resetItemFields(StateSetter setState) {
      itemType = null;
      itemValue = null;
      qtyController.clear();
      setState(() {});
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            maxQtyController.text = getMaxQty().toString();

            return AlertDialog(
              title: Text(
                LOCALIZATION.localize("inventory_page.adjust_set") ??
                    "Adjust Set",
              ),
              content: SizedBox(
                width: 800,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Set Name
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize("main_word.name") ??
                                "Set Name",
                            border: const OutlineInputBorder(),
                          ),
                          validator:
                              (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? LOCALIZATION.localize(
                                            "main_word.required",
                                          ) ??
                                          "Required"
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        // Price
                        TextFormField(
                          controller: priceController,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize("main_word.price") ??
                                "Price",
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator:
                              (v) =>
                                  (double.tryParse(v ?? '') == null)
                                      ? LOCALIZATION.localize(
                                            "main_word.invalid",
                                          ) ??
                                          "Invalid price"
                                      : null,
                        ),
                        const SizedBox(height: 12),
                        // Max Qty (auto-calculated)
                        TextFormField(
                          controller: maxQtyController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize("main_word.max_qty") ??
                                "Max Qty",
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Image Picker
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
                                                setState(() {
                                                  imageBlob = null;
                                                  imagePath = null;
                                                });
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
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
                              onPressed: () => pickImage(setState),
                              icon: const Icon(Icons.upload),
                              label: Text(
                                LOCALIZATION.localize(
                                      "main_word.select_image",
                                    ) ??
                                    "Select Image",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Selling Mode (PIECE/PACKAGE, not localized)
                        DropdownButtonFormField<String>(
                          value: mode,
                          decoration: InputDecoration(
                            labelText:
                                LOCALIZATION.localize(
                                  "inventory_page.selling_mode",
                                ) ??
                                "Selling Mode",
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'PIECE',
                              child: Text('PIECE'),
                            ),
                            DropdownMenuItem(
                              value: 'PACKAGE',
                              child: Text('PACKAGE'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null && v != mode) {
                              // Reset all items if mode changed
                              setState(() {
                                mode = v;
                                isSinglePiece = false;
                                singleProductId = null;
                                items.clear();
                                maxQtyController.text = getMaxQty().toString();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Single Product PIECE Checkbox
                        if (mode == 'PIECE')
                          Row(
                            children: [
                              Checkbox(
                                value: isSinglePiece,
                                onChanged: (v) {
                                  setState(() {
                                    isSinglePiece = v ?? false;
                                    if (!isSinglePiece) singleProductId = null;
                                  });
                                },
                              ),
                              Text(
                                LOCALIZATION.localize(
                                      "inventory_page.set_single_piece_checkbox",
                                    ) ??
                                    "This set is for selling a single product in PIECE mode",
                              ),
                            ],
                          ),
                        if (mode == 'PIECE' && isSinglePiece)
                          Padding(
                            padding: const EdgeInsets.only(left: 32, bottom: 8),
                            child: DropdownButtonFormField<int>(
                              value: singleProductId,
                              hint: Text(
                                LOCALIZATION.localize("main_word.product") ??
                                    "Product",
                              ),
                              isExpanded: true,
                              items:
                                  products
                                      .map(
                                        (p) => DropdownMenuItem<int>(
                                          value: p['id'] as int,
                                          child: Text(p['name'] ?? ''),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                setState(() {
                                  singleProductId = v;
                                });
                              },
                              validator: (v) {
                                if (isSinglePiece && (v == null)) {
                                  return LOCALIZATION.localize(
                                        "main_word.required",
                                      ) ??
                                      "Required";
                                }
                                return null;
                              },
                            ),
                          ),
                        // Add Item Section (hide if single PIECE mode)
                        if (!(mode == 'PIECE' && isSinglePiece))
                          Row(
                            children: [
                              // Type Selector
                              DropdownButton<String>(
                                value: itemType,
                                hint: Text(
                                  LOCALIZATION.localize("main_word.type") ??
                                      "Type",
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'product',
                                    child: Text(
                                      LOCALIZATION.localize(
                                            "main_word.product",
                                          ) ??
                                          'Product',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'category',
                                    child: Text(
                                      LOCALIZATION.localize(
                                            "main_word.category",
                                          ) ??
                                          'Category',
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() {
                                    itemType = v;
                                    itemValue = null;
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              // Value Selector
                              if (itemType == 'product')
                                Expanded(
                                  child: DropdownButton<int>(
                                    value: itemValue,
                                    hint: Text(
                                      LOCALIZATION.localize(
                                            "main_word.product",
                                          ) ??
                                          "Product",
                                    ),
                                    isExpanded: true,
                                    items:
                                        products
                                            .map(
                                              (p) => DropdownMenuItem<int>(
                                                value: p['id'] as int,
                                                child: Text(p['name'] ?? ''),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        itemValue = v;
                                      });
                                    },
                                  ),
                                ),
                              if (itemType == 'category')
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: itemValue,
                                    hint: Text(
                                      LOCALIZATION.localize(
                                            "main_word.category",
                                          ) ??
                                          "Category",
                                    ),
                                    isExpanded: true,
                                    items:
                                        categories
                                            .map(
                                              (c) => DropdownMenuItem(
                                                value: c,
                                                child: Text(c),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        itemValue = v;
                                      });
                                    },
                                  ),
                                ),
                              const SizedBox(width: 8),
                              // Quantity
                              SizedBox(
                                width: 60,
                                child: TextFormField(
                                  controller: qtyController,
                                  decoration: InputDecoration(
                                    labelText:
                                        LOCALIZATION.localize(
                                          "main_word.qty",
                                        ) ??
                                        "Qty",
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  final qty = int.tryParse(
                                    qtyController.text.trim(),
                                  );
                                  if (itemType == null ||
                                      itemValue == null ||
                                      qty == null ||
                                      qty < 1) {
                                    showToastMessage(
                                      context,
                                      LOCALIZATION.localize(
                                            "inventory_page.fill_all_item_fields",
                                          ) ??
                                          "Please fill all item fields.",
                                      ToastLevel.error,
                                    );
                                    return;
                                  }
                                  // Prevent duplicate
                                  if (itemType == 'product' &&
                                      items.any(
                                        (e) =>
                                            e['type'] == 'product' &&
                                            e['id'] == itemValue,
                                      )) {
                                    showToastMessage(
                                      context,
                                      LOCALIZATION.localize(
                                            "inventory_page.product_already_added",
                                          ) ??
                                          "Product already added.",
                                      ToastLevel.error,
                                    );
                                    return;
                                  }
                                  if (itemType == 'category' &&
                                      items.any(
                                        (e) =>
                                            e['type'] == 'category' &&
                                            e['category'] == itemValue,
                                      )) {
                                    showToastMessage(
                                      context,
                                      LOCALIZATION.localize(
                                            "inventory_page.category_already_added",
                                          ) ??
                                          "Category already added.",
                                      ToastLevel.error,
                                    );
                                    return;
                                  }
                                  setState(() {
                                    if (itemType == 'product') {
                                      items.add({
                                        'type': 'product',
                                        'id': itemValue,
                                        'qty': qty,
                                        'name':
                                            products.firstWhere(
                                              (p) => p['id'] == itemValue,
                                            )['name'],
                                      });
                                    } else {
                                      items.add({
                                        'type': 'category',
                                        'category': itemValue,
                                        'qty': qty,
                                      });
                                    }
                                    resetItemFields(setState);
                                    maxQtyController.text =
                                        getMaxQty().toString();
                                  });
                                },
                                child: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        if (!(mode == 'PIECE' && isSinglePiece))
                          const SizedBox(height: 12),
                        // Preview List with delete button for each item
                        if (!(mode == 'PIECE' && isSinglePiece) &&
                            items.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LOCALIZATION.localize(
                                      "inventory_page.items_in_set",
                                    ) ??
                                    "Items in Set:",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...items.asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      item['type'] == 'product'
                                          ? Icons.inventory_2
                                          : Icons.category,
                                    ),
                                    title: Text(
                                      item['type'] == 'product'
                                          ? "${item['name']} (ID: ${item['id']})"
                                          : (item['category'] as String)
                                              .replaceAll('#', ' '),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Text(
                                          "${LOCALIZATION.localize("main_word.qty") ?? "Qty"}: ",
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: TextFormField(
                                            initialValue:
                                                item['qty'].toString(),
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) {
                                              final newQty =
                                                  int.tryParse(val) ?? 1;
                                              setState(() {
                                                items[i]['qty'] = newQty;
                                                maxQtyController.text =
                                                    getMaxQty().toString();
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          items.removeAt(i);
                                          maxQtyController.text =
                                              getMaxQty().toString();
                                        });
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        const SizedBox(height: 12),
                        // Generated set_items string
                        Text(
                          LOCALIZATION.localize(
                                "inventory_page.generated_set_items",
                              ) ??
                              "Generated set_items:",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            getSetItemsString(),
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        // Show calculated max_qty
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              Text(
                                "${LOCALIZATION.localize("main_word.max_qty") ?? "Max Qty"}: ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                getMaxQty().toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                // Delete Set Button
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
                                  "Are you sure you want to delete this set? This action cannot be undone.",
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
                      final checkDeleteSuccess = await inventory.deleteSets([
                        setData['id'] as int,
                      ]);

                      if (!checkDeleteSuccess) {
                        showToastMessage(
                          context,
                          LOCALIZATION.localize(
                                "inventory_page.set_delete_failed",
                              ) ??
                              "Set delete failed.",
                          ToastLevel.error,
                        );
                        INVENTORY_LOGS.error(
                          "Failed to delete set product: ${setData['id']}",
                        );
                        return;
                      }

                      await onConfirm();

                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.set_deleted_successfully",
                            ) ??
                            "Set deleted.",
                        ToastLevel.success,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                ),

                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    LOCALIZATION.localize("main_word.cancel") ?? "Cancel",
                  ),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    if (mode == 'PIECE' && isSinglePiece) {
                      if (singleProductId == null) {
                        showToastMessage(
                          context,
                          LOCALIZATION.localize("main_word.required") ??
                              "Please select a product.",
                          ToastLevel.error,
                        );
                        return;
                      }
                    } else if (items.isEmpty) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.add_at_least_one_item",
                            ) ??
                            "Add at least one item.",
                        ToastLevel.error,
                      );
                      return;
                    }

                    final name = nameController.text.trim();
                    final price =
                        double.tryParse(priceController.text.trim()) ?? 0.0;
                    final maxQty = getMaxQty();
                    final setItems = getSetItemsString();
                    final groupNames = getGroupNames();

                    // Compose data for set_product table
                    final updatedSet = {
                      ...setData,
                      'name': name,
                      'group_names': groupNames,
                      'price': price,
                      'set_items': setItems,
                      'max_qty': maxQty,
                      'image': imageBlob,
                    };

                    final checkUpdateSuccess = await inventory
                        .updateSetProductData(
                          bulkData: {setData['id'].toString(): updatedSet},
                        );

                    if (!checkUpdateSuccess) {
                      showToastMessage(
                        context,
                        LOCALIZATION.localize(
                              "inventory_page.set_update_failed",
                            ) ??
                            "Set update failed.",
                        ToastLevel.error,
                      );
                      INVENTORY_LOGS.error(
                        "Failed to update set product data: $updatedSet",
                      );
                      return;
                    }

                    await onConfirm();

                    showToastMessage(
                      context,
                      LOCALIZATION.localize(
                            "inventory_page.set_adjusted_successfully",
                          ) ??
                          "Set adjusted successfully.",
                      ToastLevel.success,
                    );

                    Navigator.of(context).pop();
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
    // Filter by search
    var filteredSets =
        setItems.where((s) {
          final matchesSearch = (s['name']?.toLowerCase() ?? '').contains(
            searchQuery.toLowerCase(),
          );
          return matchesSearch;
        }).toList();

    // Sort
    filteredSets.sort((a, b) {
      int cmp;
      if (sortBy == 'Name') {
        cmp = (a['name'] ?? '').compareTo(b['name'] ?? '');
      } else if (sortBy == 'Price') {
        cmp = (a['price'] ?? 0).compareTo(b['price'] ?? 0);
      } else {
        cmp = 0;
      }
      return sortAsc ? cmp : -cmp;
    });

    final selectedSet =
        selectedSetId != null
            ? setItems.firstWhere(
              (s) => s['id'] == selectedSetId,
              orElse:
                  () =>
                      filteredSets.isNotEmpty
                          ? filteredSets[0]
                          : <String, dynamic>{},
            )
            : (filteredSets.isNotEmpty ? filteredSets[0] : null);

    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Row(
        children: [
          // Left: Set List
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Row(
                  children: [
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

                // Set List
                Expanded(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: filteredSets.length,
                      itemBuilder: (context, index) {
                        final set = filteredSets[index];
                        final isSelected =
                            selectedSet != null &&
                            set['id'] == selectedSet['id'];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child:
                                set['image'] == null
                                    ? Icon(
                                      Icons.layers,
                                      color: Colors.grey.shade600,
                                    )
                                    : ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.memory(
                                        set['image'],
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                          ),
                          title: Text(set['name'] ?? ''),
                          subtitle: Text(
                            _parseSetItems(set['set_items'] ?? ''),
                          ),
                          trailing: _buildStatus(set['exist'] ?? 1),
                          selected: isSelected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08),
                          onTap: () {
                            setState(() {
                              selectedSetId = set['id'];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Add Set Button (you can expand with bulk if needed)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButtonWithSound.icon(
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(
                      LOCALIZATION.localize("inventory_page.add_set") ??
                          "Add Set",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await _buildAddSetDialog(
                        context,
                        onConfirm: () async {
                          await _loadSets();
                        },
                        products:
                            inventory.productCatalog?.entries
                                .map((e) => {"id": e.key, ...e.value})
                                .toList() ??
                            [],
                        categories:
                            inventory.productCatalog?.values
                                .map((p) => p['categories'] as String)
                                .toSet()
                                .toList() ??
                            [],
                        setNames:
                            setItems
                                .map((s) => s['name'] as String)
                                .toSet()
                                .toList() ??
                            [],
                      );
                    },
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
                // Top: Set Details
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        selectedSet == null
                            ? Center(
                              child: Text(
                                LOCALIZATION.localize(
                                      "inventory_page.no_set_selected",
                                    ) ??
                                    "No set selected",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                            : Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Row(
                                children: [
                                  // Set Image
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child:
                                        selectedSet['image'] == null
                                            ? Icon(
                                              Icons.image_not_supported,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            )
                                            : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(
                                                selectedSet['image'],
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Set Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          selectedSet['name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        ),
                                        Text(
                                          _parseSetItems(
                                            selectedSet['set_items'] ?? '',
                                          ),
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
                                              "${globalAppConfig["userPreferences"]["currency"]} ${selectedSet['price']?.toStringAsFixed(2) ?? '0.00'}",
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
                                              "${LOCALIZATION.localize("main_word.max_qty") ?? "Max Qty"}: ",
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              "${selectedSet['max_qty'] ?? 0}",
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
                                              "${LOCALIZATION.localize("main_word.status")}: ",
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              selectedSet['exist'] == 1
                                                  ? LOCALIZATION.localize(
                                                        "main_word.active",
                                                      ) ??
                                                      "Active"
                                                  : LOCALIZATION.localize(
                                                        "main_word.inactive",
                                                      ) ??
                                                      "Inactive",
                                              style: TextStyle(
                                                color:
                                                    selectedSet['exist'] == 1
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
                                  // Quick Actions (Edit, Delete, Activate/Deactivate)
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButtonWithSound.icon(
                                        icon: const Icon(Icons.edit, size: 18),
                                        label: Text(
                                          LOCALIZATION.localize(
                                                "main_word.edit",
                                              ) ??
                                              "Edit",
                                        ),
                                        onPressed:
                                            selectedSet == null
                                                ? null
                                                : () async {
                                                  await _buildAdjustSetDialog(
                                                    context,
                                                    setData: selectedSet,
                                                    onConfirm: () async {
                                                      await _loadSets();
                                                    },
                                                    products:
                                                        inventory
                                                            .productCatalog
                                                            ?.entries
                                                            .map(
                                                              (e) => {
                                                                "id": e.key,
                                                                ...e.value,
                                                              },
                                                            )
                                                            .toList() ??
                                                        [],
                                                    categories:
                                                        inventory
                                                            .productCatalog
                                                            ?.values
                                                            .map(
                                                              (p) =>
                                                                  p['categories']
                                                                      as String,
                                                            )
                                                            .toSet()
                                                            .toList() ??
                                                        [],
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

                                      ElevatedButtonWithSound.icon(
                                        icon: Icon(
                                          selectedSet['exist'] == 1
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 18,
                                        ),
                                        label: Text(
                                          selectedSet['exist'] == 1
                                              ? LOCALIZATION.localize(
                                                    "main_word.deactivate",
                                                  ) ??
                                                  "Deactivate"
                                              : LOCALIZATION.localize(
                                                    "main_word.activate",
                                                  ) ??
                                                  "Activate",
                                        ),
                                        onPressed: () async {
                                          final checkSuccessToggle =
                                              await inventory
                                                  .toggleItemExistence(
                                                    id: selectedSet['id'],
                                                    isProduct: false,
                                                    forceValue:
                                                        selectedSet['exist'] ==
                                                                1
                                                            ? 0
                                                            : 1,
                                                  );

                                          if (checkSuccessToggle &&
                                              selectedSet['exist'] == 1) {
                                            showToastMessage(
                                              context,
                                              LOCALIZATION.localize(
                                                    "inventory_page.deactivate_success",
                                                  ) ??
                                                  "Set updated.",
                                              ToastLevel.success,
                                            );
                                          } else if (checkSuccessToggle &&
                                              selectedSet['exist'] == 0) {
                                            showToastMessage(
                                              context,
                                              LOCALIZATION.localize(
                                                    "inventory_page.activate_success",
                                                  ) ??
                                                  "Set updated.",
                                              ToastLevel.success,
                                            );
                                          } else {
                                            showToastMessage(
                                              context,
                                              LOCALIZATION.localize(
                                                    "inventory_page.toggle_set_failed",
                                                  ) ??
                                                  "Failed to toggle set.",
                                              ToastLevel.error,
                                            );
                                          }

                                          await _loadSets();
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
                // Bottom: Set Items List (always at the bottom)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LOCALIZATION.localize(
                                "inventory_page.set_items_list",
                              ) ??
                              "Set Items:",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                _getSetProductList(
                                  selectedSet?['set_items'] ?? '',
                                ).map((item) {
                                  return Container(
                                    width: 180,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            item['image'] != null
                                                ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: Image.memory(
                                                    item['image'],
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                                : Icon(
                                                  Icons.inventory_2,
                                                  color: Colors.grey.shade400,
                                                  size: 40,
                                                ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['name'] ?? '',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    item['categories'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "x${item['qty']}",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Theme.of(
                                                                context,
                                                              ).primaryColor,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      if (item['type'] ==
                                                          'category')
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 4,
                                                              ),
                                                          child: Text(
                                                            "(Category)",
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Colors
                                                                      .orange
                                                                      .shade700,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ],
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
}
