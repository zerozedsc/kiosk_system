import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../configs/configs.dart';
import '../../components/buttonswithsound.dart';
import '../../services/inventory/inventory_services.dart';
import '../../configs/responsive_layout.dart';

class ResponsiveSetSelectionDialog extends StatefulWidget {
  final Map<String, dynamic> setDetail;
  final String setType;
  final Map<int, dynamic> outOfStockItems;
  final Function(Map<String, dynamic>) increaseQuantity;
  final Function(Map<String, dynamic>) onAddToCart;

  const ResponsiveSetSelectionDialog({
    super.key,
    required this.setDetail,
    required this.setType,
    required this.outOfStockItems,
    required this.increaseQuantity,
    required this.onAddToCart,
  });

  @override
  State<ResponsiveSetSelectionDialog> createState() =>
      _ResponsiveSetSelectionDialogState();
}

class _ResponsiveSetSelectionDialogState
    extends State<ResponsiveSetSelectionDialog> {
  late List<Map<String, dynamic>> setDetails;
  late Map<int, int> selectedQuantities;
  late int totalSelectedQuantity;
  late int totalMaxQuantity;
  late List<String> groupNames;
  late List<List<Map<String, dynamic>>> setOptionsGroups;
  late List<int> outOfStockId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    setDetails = List<Map<String, dynamic>>.from(
      widget.setDetail['details'] ?? [],
    );
    selectedQuantities = {};
    totalSelectedQuantity = 0;
    totalMaxQuantity = widget.setDetail['total_max_qty'] ?? 0;
    outOfStockId = [];

    // Get group names from inventory.setCatalog
    groupNames = [];
    if (inventory.setCatalog != null &&
        inventory.setCatalog!.containsKey(widget.setDetail['id'])) {
      String? groupNamesStr =
          inventory.setCatalog![widget.setDetail['id']]!['group_names'];
      if (groupNamesStr != null && groupNamesStr.isNotEmpty) {
        groupNames = groupNamesStr.split(',');
      }
    }

    // Find matching products for each set item based on the IDs in details
    setOptionsGroups = [];

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
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallWidth = screenSize.width < 700;
    final isShortHeight = screenSize.height < 600;
    final isLandscapeOrientation = screenSize.width > screenSize.height;
    final isPhoneSized = screenSize.width < 800 || screenSize.height < 800;
    final shouldUseMobileLayout =
        isSmallWidth || isShortHeight || isLandscapeOrientation || isPhoneSized;

    // Calculate optimal height for the bottom sheet
    double sheetHeight;
    if (shouldUseMobileLayout) {
      // Mobile: Use 90% of screen height
      sheetHeight = screenSize.height * 0.9;
    } else {
      // Desktop/Tablet: Use 80% of screen height
      sheetHeight = screenSize.height * 0.8;
    }

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          _buildSheetHeader(),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSetInfoHeader(),
                  const SizedBox(height: 12),
                  _buildProgressIndicator(),
                  const SizedBox(height: 16),
                  _buildProductGroups(),
                ],
              ),
            ),
          ),
          // Bottom action bar
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.setDetail['name'] ??
                  LOCALIZATION.localize("cashier_page.set_selection"),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () {
              for (var id in outOfStockId) {
                if (widget.outOfStockItems.containsKey(id)) {
                  widget.outOfStockItems.remove(id);
                }
              }
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final screenSize = MediaQuery.of(context).size;
    final isLandscapeOrientation = screenSize.width > screenSize.height;

    return Container(
      padding: EdgeInsets.all(isLandscapeOrientation ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButtonWithSound(
              onPressed: () {
                for (var id in outOfStockId) {
                  if (widget.outOfStockItems.containsKey(id)) {
                    widget.outOfStockItems.remove(id);
                  }
                }
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: isLandscapeOrientation ? 12 : 16,
                ),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                LOCALIZATION.localize("main_word.cancel"),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButtonWithSound(
              onPressed:
                  totalSelectedQuantity == totalMaxQuantity
                      ? () {
                        // Create a copy of the set product with selected items
                        Map<String, dynamic> setProductToAdd = {
                          ...widget.setDetail,
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
                                'type': widget.setType,
                              });
                            }
                          }
                        }

                        // Add selected items to the set product
                        setProductToAdd['set'] = selectedItems;
                        setProductToAdd['type'] = widget.setType;

                        // Add the set to cart
                        widget.onAddToCart(setProductToAdd);
                        Navigator.of(context).pop();
                      }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: EdgeInsets.symmetric(
                  vertical: isLandscapeOrientation ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "${LOCALIZATION.localize("main_word.add")} (${globalAppConfig["userPreferences"]["currency"]}${widget.setDetail['price']?.toStringAsFixed(2) ?? '0.00'})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetInfoHeader() {
    return Container(
      padding: ResponsiveLayout.getResponsivePadding(
        context,
        mobile: 8,
        tablet: 10,
        desktop: 12,
      ),
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
                  widget.setDetail['name'] ?? "",
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      16,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${LOCALIZATION.localize("cashier_page.select_items")} ($totalSelectedQuantity/$totalMaxQuantity)",
                  style: TextStyle(
                    fontSize: ResponsiveLayout.getResponsiveFontSize(
                      context,
                      12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${globalAppConfig["userPreferences"]["currency"]}${widget.setDetail['price']?.toStringAsFixed(2) ?? '0.00'}",
            style: TextStyle(
              fontSize: ResponsiveLayout.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return LinearProgressIndicator(
      value:
          totalMaxQuantity > 0 ? totalSelectedQuantity / totalMaxQuantity : 0,
      backgroundColor: Colors.grey[200],
      valueColor: AlwaysStoppedAnimation<Color>(
        totalSelectedQuantity == totalMaxQuantity ? Colors.green : primaryColor,
      ),
    );
  }

  Widget _buildProductGroups() {
    // Enhanced responsive logic for Set Selection Dialog
    // Consider a device as mobile if ANY of these conditions are true:
    // 1. Screen width is small (< 700px) - increased from 600 for better mobile detection
    // 2. Screen height is short (< 600px) - increased from 500 for landscape phones
    // 3. Device is in landscape orientation (width > height)
    // 4. OR if it's clearly a phone-sized device
    final screenSize = MediaQuery.of(context).size;
    final isSmallWidth =
        screenSize.width < 700; // More aggressive mobile detection
    final isShortHeight =
        screenSize.height < 600; // Better landscape phone detection
    final isLandscapeOrientation = screenSize.width > screenSize.height;
    final isPhoneSized = screenSize.width < 800 || screenSize.height < 800;

    final shouldUseMobileLayout =
        isSmallWidth || isShortHeight || isLandscapeOrientation || isPhoneSized;

    if (shouldUseMobileLayout) {
      return _buildMobileExpansionTileGroups();
    } else {
      return _buildDesktopColumnGroups();
    }
  }

  Widget _buildMobileExpansionTileGroups() {
    final screenSize = MediaQuery.of(context).size;
    final isLandscapeOrientation = screenSize.width > screenSize.height;

    return Column(
      children:
          setOptionsGroups.asMap().entries.map((entry) {
            int groupIndex = entry.key;
            List<Map<String, dynamic>> products = entry.value;

            final maxQtyForGroup = setDetails[groupIndex]['max_qty'] ?? 0;
            String groupName =
                groupIndex < groupNames.length
                    ? groupNames[groupIndex].trim()
                    : "${LOCALIZATION.localize("cashier_page.group")} ${groupIndex + 1}";

            // Calculate current selected quantity for this group
            int groupSelectedQty = 0;
            for (var product in products) {
              groupSelectedQty += (product['quantity'] as int? ?? 0);
            }

            bool isComplete = groupSelectedQty >= maxQtyForGroup;

            return Card(
              margin: EdgeInsets.only(bottom: isLandscapeOrientation ? 6 : 12),
              elevation: 2,
              child: ExpansionTile(
                initiallyExpanded: !isComplete,
                dense: isLandscapeOrientation,
                tilePadding: EdgeInsets.symmetric(
                  horizontal: isLandscapeOrientation ? 12 : 16,
                  vertical: isLandscapeOrientation ? 4 : 8,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        groupName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isLandscapeOrientation ? 14 : 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscapeOrientation ? 8 : 12,
                        vertical: isLandscapeOrientation ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isComplete
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$groupSelectedQty/$maxQtyForGroup",
                        style: TextStyle(
                          fontSize: isLandscapeOrientation ? 10 : 12,
                          fontWeight: FontWeight.bold,
                          color:
                              isComplete
                                  ? Colors.green
                                  : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  Container(
                    padding: EdgeInsets.all(isLandscapeOrientation ? 8 : 12),
                    child: _buildMobileProductList(
                      products,
                      groupIndex,
                      maxQtyForGroup,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildMobileProductList(
    List<Map<String, dynamic>> products,
    int groupIndex,
    int maxQtyForGroup,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscapeOrientation = screenSize.width > screenSize.height;

    return Wrap(
      spacing: isLandscapeOrientation ? 6 : 8,
      runSpacing: isLandscapeOrientation ? 6 : 8,
      children:
          products.asMap().entries.map((entry) {
            return _buildCompactProductCard(
              entry.value,
              groupIndex,
              maxQtyForGroup,
            );
          }).toList(),
    );
  }

  Widget _buildCompactProductCard(
    Map<String, dynamic> item,
    int groupIndex,
    int maxQtyForGroup,
  ) {
    final int id = item['id'] ?? 0;
    final int currentQty = item['quantity'] ?? 0;
    final bool isOutOfStock =
        ((item[widget.setType] ?? 0) <= 0) ||
        (widget.outOfStockItems.containsKey(id) &&
            widget.outOfStockItems[id].containsKey(widget.setType));

    // Calculate current selected quantity for this group
    int groupSelectedQty = 0;
    for (var product in setOptionsGroups[groupIndex]) {
      groupSelectedQty += (product['quantity'] as int? ?? 0);
    }
    final bool reachedGroupMax = groupSelectedQty >= maxQtyForGroup;

    final screenSize = MediaQuery.of(context).size;
    final isLandscapeOrientation = screenSize.width > screenSize.height;

    // Optimize card sizes for bottom sheet
    final cardWidth = 100.0;
    final imageHeight = 50.0;
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        border: Border.all(
          color: currentQty > 0 ? primaryColor : Colors.grey.shade300,
          width: currentQty > 0 ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isOutOfStock ? Colors.grey.shade200 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact product image
          SizedBox(
            height: imageHeight,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
              child: _buildProductImage(item, isOutOfStock),
            ),
          ),
          // Product name and controls
          Padding(
            padding: EdgeInsets.all(isLandscapeOrientation ? 3 : 4),
            child: Column(
              children: [
                Text(
                  item['shortform'] ?? item['name'],
                  style: TextStyle(
                    fontSize: isLandscapeOrientation ? 9 : 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                _buildQuantityControls(item, isOutOfStock, reachedGroupMax),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopColumnGroups() {
    return Column(
      children:
          setOptionsGroups.asMap().entries.map((entry) {
            int groupIndex = entry.key;
            List<Map<String, dynamic>> products = entry.value;

            final maxQtyForGroup = setDetails[groupIndex]['max_qty'] ?? 0;
            String groupName =
                groupIndex < groupNames.length
                    ? groupNames[groupIndex].trim()
                    : "${LOCALIZATION.localize("cashier_page.group")} ${groupIndex + 1}";

            // Calculate current selected quantity for this group
            int groupSelectedQty = 0;
            for (var product in products) {
              groupSelectedQty += (product['quantity'] as int? ?? 0);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                // Products in horizontal scroll
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _buildDesktopProductCard(
                        products[index],
                        groupIndex,
                        maxQtyForGroup,
                      );
                    },
                  ),
                ),
                const Divider(height: 24),
              ],
            );
          }).toList(),
    );
  }

  Widget _buildDesktopProductCard(
    Map<String, dynamic> item,
    int groupIndex,
    int maxQtyForGroup,
  ) {
    final int id = item['id'] ?? 0;
    final int currentQty = item['quantity'] ?? 0;
    final bool isOutOfStock =
        ((item[widget.setType] ?? 0) <= 0) ||
        (widget.outOfStockItems.containsKey(id) &&
            widget.outOfStockItems[id].containsKey(widget.setType));

    // Calculate current selected quantity for this group
    int groupSelectedQty = 0;
    for (var product in setOptionsGroups[groupIndex]) {
      groupSelectedQty += (product['quantity'] as int? ?? 0);
    }
    final bool reachedGroupMax = groupSelectedQty >= maxQtyForGroup;
    final bool isSingleItemGroup = setOptionsGroups[groupIndex].length == 1;

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: currentQty > 0 ? primaryColor : Colors.grey.shade300,
          width: currentQty > 0 ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isOutOfStock ? Colors.grey.shade200 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
              child: _buildProductImage(item, isOutOfStock),
            ),
          ),
          // Product name and quantity controls
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  item['shortform'] ?? item['name'],
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                if (!isSingleItemGroup)
                  _buildQuantityControls(item, isOutOfStock, reachedGroupMax),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> item, bool isOutOfStock) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter:
              isOutOfStock
                  ? const ColorFilter.matrix([
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
                  ])
                  : const ColorFilter.mode(
                    Colors.transparent,
                    BlendMode.srcOver,
                  ),
          child:
              item['image'] is Uint8List &&
                      (item['image'] as Uint8List).isNotEmpty
                  ? Image.memory(item['image'], fit: BoxFit.cover)
                  : Icon(
                    Icons.image_not_supported,
                    size: 30,
                    color: Colors.grey,
                  ),
        ),
        if (isOutOfStock)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Text(
                LOCALIZATION.localize("cashier_page.no_stock"),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveLayout.getResponsiveFontSize(context, 8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuantityControls(
    Map<String, dynamic> item,
    bool isOutOfStock,
    bool reachedGroupMax,
  ) {
    final int currentQty = item['quantity'] ?? 0;
    final int id = item['id'] ?? 0;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Decrease button
        InkWell(
          onTap: () async {
            await AudioManager().playSound(
              soundPath: 'assets/sounds/click.mp3',
            );

            if (currentQty > 0) {
              setState(() {
                item['quantity'] = currentQty - 1;
                if (widget.outOfStockItems.containsKey(item["id"]) &&
                    widget.outOfStockItems[item["id"]]?.containsKey(
                      item["type"],
                    )) {
                  widget.outOfStockItems[item["id"]].remove(item["type"]);
                }
                selectedQuantities[id] = item['quantity'];
                totalSelectedQuantity--;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.all(isMobile ? 4 : 6),
            decoration: BoxDecoration(
              color: currentQty > 0 ? primaryColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(isMobile ? 4 : 6),
            ),
            child: Icon(
              Icons.remove,
              size: isMobile ? 12 : 18,
              color: currentQty > 0 ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
        // Quantity display
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10),
          child: Text(
            "$currentQty",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 16,
            ),
          ),
        ),
        // Increase button
        InkWell(
          onTap: () async {
            await AudioManager().playSound(
              soundPath: 'assets/sounds/click.mp3',
            );
            if (!isOutOfStock &&
                !reachedGroupMax &&
                totalSelectedQuantity < totalMaxQuantity) {
              setState(() {
                if (!item.containsKey("type")) {
                  item['type'] = widget.setType;
                }
                final quantityBefore = item['quantity'] ?? 0;

                // Try to increase quantity using the parent method
                if (widget.increaseQuantity(item)) {
                  outOfStockId.add(item['id']);
                }

                if (item['quantity'] != quantityBefore) {
                  totalSelectedQuantity++;
                }
                selectedQuantities[id] = item['quantity'];
              });
            }
          },
          child: Container(
            padding: EdgeInsets.all(isMobile ? 4 : 6),
            decoration: BoxDecoration(
              color:
                  (!isOutOfStock &&
                          !reachedGroupMax &&
                          totalSelectedQuantity < totalMaxQuantity)
                      ? primaryColor
                      : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(isMobile ? 4 : 6),
            ),
            child: Icon(
              Icons.add,
              size: isMobile ? 12 : 18,
              color:
                  (!isOutOfStock &&
                          !reachedGroupMax &&
                          totalSelectedQuantity < totalMaxQuantity)
                      ? Colors.white
                      : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}
