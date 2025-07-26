import '../../configs/configs.dart';

import 'package:intl/intl.dart'; // <-- Add this line

import '../../services/homepage/homepage_service.dart';

class LiveSalesSummarySection extends StatefulWidget {
  final Map<String, dynamic> liveSalesSummary;
  final Color mainColor;
  final String currency;

  const LiveSalesSummarySection({
    super.key,
    required this.liveSalesSummary,
    required this.mainColor,
    required this.currency,
  });

  @override
  State<LiveSalesSummarySection> createState() =>
      _LiveSalesSummarySectionState();
}

class _LiveSalesSummarySectionState extends State<LiveSalesSummarySection> {
  bool _loadingAdvancedSales = false;
  DateTimeRange? _selectedRange;
  String _selectedFilter = 'today';

  /// Builds a single, styled tile for the summary grid with enhanced mobile-first responsive sizing.
  Widget _buildSummaryTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth;
        final tileHeight = constraints.maxHeight;
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 480;
        final isVerySmallScreen = screenWidth < 360;

        // Enhanced mobile-first responsive sizing calculations
        double iconSize;
        double labelFontSize;
        double valueFontSize;
        double spacing;
        double padding;

        if (isVerySmallScreen) {
          // Very small phones - prioritize readability
          iconSize = (tileWidth * 0.2).clamp(20.0, 28.0);
          labelFontSize = (tileWidth * 0.065).clamp(9.0, 11.0);
          valueFontSize = (tileWidth * 0.075).clamp(11.0, 14.0);
          spacing = (tileHeight * 0.06).clamp(3.0, 6.0);
          padding = (tileWidth * 0.04).clamp(6.0, 10.0);
        } else if (isSmallScreen) {
          // Small phones like OPPO Reno 7a
          iconSize = (tileWidth * 0.22).clamp(22.0, 32.0);
          labelFontSize = (tileWidth * 0.07).clamp(10.0, 12.0);
          valueFontSize = (tileWidth * 0.08).clamp(12.0, 16.0);
          spacing = (tileHeight * 0.07).clamp(4.0, 8.0);
          padding = (tileWidth * 0.045).clamp(8.0, 12.0);
        } else {
          // Larger screens - original sizing
          iconSize = (tileWidth * 0.25).clamp(24.0, 40.0);
          labelFontSize = (tileWidth * 0.08).clamp(10.0, 14.0);
          valueFontSize = (tileWidth * 0.09).clamp(12.0, 18.0);
          spacing = (tileHeight * 0.08).clamp(4.0, 12.0);
          padding = (tileWidth * 0.05).clamp(8.0, 16.0);
        }

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: isSmallScreen ? 2 : 4,
                offset: Offset(0, isSmallScreen ? 1 : 2),
              ),
            ],
            border: Border.all(
              color: iconColor.withValues(alpha: 0.2),
              width: isSmallScreen ? 0.8 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: iconSize),
              SizedBox(height: spacing),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: isSmallScreen ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: labelFontSize,
                    height: isSmallScreen ? 1.1 : 1.2,
                  ),
                ),
              ),
              SizedBox(height: spacing * 0.5),
              Flexible(
                flex: isSmallScreen ? 3 : 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    maxLines: isSmallScreen ? 1 : 2,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                      fontSize: valueFontSize,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows the advanced sales summary as a new page instead of dialog
  Future<void> _showAdvancedSalesSummaryDialog() async {
    await _updateAdvancedData();

    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Better responsive logic: consider both dimensions and aspect ratio
    // Mobile if: width < 600 OR height < 500 OR aspect ratio suggests phone in landscape
    final isPortraitPhone = screenWidth < 600 && screenHeight > screenWidth;
    final isLandscapePhone = screenHeight < 500 && screenWidth > screenHeight;
    final isSmallScreen = screenWidth < 600 || screenHeight < 500;
    final isMobileDevice = isPortraitPhone || isLandscapePhone || isSmallScreen;

    if (isMobileDevice) {
      // Navigate to a new page for mobile/small screens
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => _AdvancedSalesSummaryPage(
                updateAdvancedData: _updateAdvancedData,
                loadingAdvancedSales: _loadingAdvancedSales,
                selectedFilter: _selectedFilter,
                selectedRange: _selectedRange,
                onFilterChanged: (filter, range) {
                  setState(() {
                    _selectedFilter = filter;
                    _selectedRange = range;
                  });
                },
                currency: widget.currency,
                mainColor: widget.mainColor,
              ),
        ),
      );
    } else {
      // Enhanced dialog for desktop/tablet with better overflow handling
      showDialog(
        context: context,
        barrierDismissible: true,
        builder:
            (context) => StatefulBuilder(
              builder: (context, setDialogState) {
                final screenHeight = MediaQuery.of(context).size.height;
                return Dialog(
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: (screenHeight * 0.05).clamp(24.0, 60.0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (screenWidth * 0.9).clamp(600.0, 1200.0),
                      maxHeight: (screenHeight * 0.9).clamp(400.0, 900.0),
                      minHeight: 400.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header - Fixed
                        Container(
                          padding: EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.insights,
                                color: Theme.of(context).primaryColor,
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  LOCALIZATION.localize(
                                    'home_page.advanced_sales_summary',
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (_loadingAdvancedSales)
                                Padding(
                                  padding: EdgeInsets.only(right: 16.0),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(Icons.close),
                                iconSize: 28.0,
                              ),
                            ],
                          ),
                        ),

                        // Scrollable content area
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Filter controls
                                Container(
                                  padding: EdgeInsets.all(24.0),
                                  child: Column(
                                    children: [
                                      _buildFilterControls(setDialogState),
                                      if (_selectedFilter == 'custom' &&
                                          _selectedRange != null)
                                        Padding(
                                          padding: EdgeInsets.only(top: 16.0),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 8.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "${DateFormat.yMMMd().format(_selectedRange!.start)} - ${DateFormat.yMMMd().format(_selectedRange!.end)}",
                                              style: TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Content
                                Container(
                                  constraints: BoxConstraints(
                                    minHeight: 300.0,
                                    maxHeight: screenHeight * 0.5,
                                  ),
                                  child:
                                      _loadingAdvancedSales
                                          ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                CircularProgressIndicator(),
                                                SizedBox(height: 16),
                                                Text(
                                                  'Loading sales data...',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          : _buildDesktopContent(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Footer - Fixed
                        Container(
                          padding: EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  LOCALIZATION.localize('main_word.close'),
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      );
    }
  }

  /// Desktop content with side-by-side layout
  Widget _buildDesktopContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sales section
            Expanded(
              flex: 2,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bar_chart,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sales Analytics',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      // Fixed height for sales tabs to prevent overflow
                      SizedBox(height: 400.0, child: _buildSalesTabs()),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(width: 24),

            // Payment methods section
            Expanded(
              flex: 1,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.payment,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Payments',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      // Fixed height for payments to prevent overflow
                      SizedBox(
                        height: 400.0,
                        child: SingleChildScrollView(
                          child: _buildPaymentMethodSummary(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Updates all data needed for the advanced summary dialog.
  Future<void> _updateAdvancedData([StateSetter? setDialogState]) async {
    final updateState = setDialogState ?? setState;
    updateState(() => _loadingAdvancedSales = true);

    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day);
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_selectedFilter == 'hour') {
      start = DateTime(now.year, now.month, now.day, now.hour);
      end = start
          .add(const Duration(hours: 1))
          .subtract(const Duration(seconds: 1));
    } else if (_selectedFilter == 'custom' && _selectedRange != null) {
      start = _selectedRange!.start;
      end = DateTime(
        _selectedRange!.end.year,
        _selectedRange!.end.month,
        _selectedRange!.end.day,
        23,
        59,
        59,
      );
    }

    // Fetch both sales and payment data concurrently.
    await Future.wait([
      homepageService.updateAdvancedSalesSummaryWithRange(
        start: start,
        end: end,
      ),
      homepageService.updatePaymentMethodSummaryWithRange(
        start: start,
        end: end,
      ),
    ]);

    updateState(() => _loadingAdvancedSales = false);
  }

  // [Filter Controls Section] - Enhanced design
  Widget _buildFilterControls(StateSetter setDialogState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1),
      ),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'today',
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.today, size: 18),
                SizedBox(width: 8),
                Text('Today'),
              ],
            ),
          ),
          ButtonSegment(
            value: 'hour',
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 18),
                SizedBox(width: 8),
                Text('This Hour'),
              ],
            ),
          ),
          ButtonSegment(
            value: 'custom',
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.date_range, size: 18),
                SizedBox(width: 8),
                Text('Custom Range'),
              ],
            ),
          ),
        ],
        selected: {_selectedFilter},
        onSelectionChanged: (newSelection) async {
          setDialogState(() => _selectedFilter = newSelection.first);
          if (newSelection.first == 'custom') {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange:
                  _selectedRange ??
                  DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 7)),
                    end: DateTime.now(),
                  ),
            );
            if (picked != null) {
              setDialogState(() => _selectedRange = picked);
            } else {
              setDialogState(() => _selectedFilter = 'today');
            }
          }
          _updateAdvancedData(setDialogState);
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.grey.shade700,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: Theme.of(context).primaryColor,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  // [Sales Tabs Section] - No changes needed
  Widget _buildSalesTabs() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3.0,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.coffee),
                    const SizedBox(width: 8),
                    Text(LOCALIZATION.localize('home_page.by_product')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.category),
                    const SizedBox(width: 8),
                    Text(LOCALIZATION.localize('home_page.by_category')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              children: [
                _buildSalesChart(homepageService.productSales),
                _buildSalesChart(homepageService.categorySales),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // [Sales Chart Section] - No changes needed
  Widget _buildSalesChart(Map<String, int> data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          LOCALIZATION.localize('main_word.no_data'),
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      );
    }
    final sortedEntries =
        data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1;
    return ListView.builder(
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  entry.key,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth =
                        (entry.value / maxValue) * constraints.maxWidth;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 35,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          height: 35,
                          width: barWidth,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.7),
                                Theme.of(context).primaryColor,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns a specific icon based on the payment method name.
  IconData _getPaymentMethodIcon(String methodName) {
    final lowerCaseMethod = methodName.toLowerCase();
    if (lowerCaseMethod.contains('card')) {
      return Icons.credit_card;
    } else if (lowerCaseMethod.contains('cash')) {
      return Icons.money;
    } else if (lowerCaseMethod.contains('qr')) {
      return Icons.qr_code_scanner;
    }
    return Icons.payment; // Default icon
  }

  /// Builds the styled payment method summary component with mobile optimization.
  Widget _buildPaymentMethodSummary() {
    final data = homepageService.paymentMethodSummary;
    if (data.isEmpty) {
      return Center(
        child: Text(
          LOCALIZATION.localize('main_word.no_payment_data'),
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      );
    }
    final sorted =
        data.entries.toList()..sort(
          (a, b) =>
              (b.value['count'] as int).compareTo(a.value['count'] as int),
        );

    final screenWidth = MediaQuery.of(context).size.width;
    final isAndroidPhone = screenWidth < 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LOCALIZATION.localize('home_page.payment_method_summary'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isAndroidPhone ? 16 : 18,
          ),
        ),
        SizedBox(height: isAndroidPhone ? 12 : 16),

        // Mobile-optimized layout
        if (isAndroidPhone) ...[
          // Android: Simple list layout to prevent overflow
          ...sorted.map((e) {
            final count = e.value['count'] ?? 0;
            final total = e.value['total'] ?? 0.0;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getPaymentMethodIcon(e.key),
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          "${LOCALIZATION.localize('main_word.transactions')}: $count",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "${widget.currency} ${total.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ] else ...[
          // Desktop/Tablet: Keep original wrap layout
          Wrap(
            spacing: 14.0,
            runSpacing: 14.0,
            children:
                sorted.map((e) {
                  final count = e.value['count'] ?? 0;
                  final total = e.value['total'] ?? 0.0;

                  return Container(
                    width: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.13),
                          child: Icon(
                            _getPaymentMethodIcon(e.key),
                            color: Theme.of(context).primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${LOCALIZATION.localize('main_word.transactions')}: $count",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${widget.currency} ${total.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isAndroidPhone = screenWidth < 500; // Android phone detection

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isAndroidPhone ? 12.0 : 16.0,
        vertical: isAndroidPhone ? 8.0 : 12.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Android-optimized Advanced Summary Button
          SizedBox(
            width: double.infinity,
            height: isAndroidPhone ? 44.0 : 48.0,
            child: ElevatedButton.icon(
              icon: Icon(Icons.insights, size: isAndroidPhone ? 18.0 : 20.0),
              label: Flexible(
                child: Text(
                  LOCALIZATION.localize('home_page.advanced_summary'),
                  style: TextStyle(
                    fontSize: isAndroidPhone ? 14.0 : 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.mainColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _showAdvancedSalesSummaryDialog,
            ),
          ),

          SizedBox(height: isAndroidPhone ? 16.0 : 20.0),

          // Android-friendly Card Layout (No Grid)
          if (isAndroidPhone) ...[
            // Mobile: Vertical stack of cards
            _buildMobileSummaryCard(
              icon: Icons.shopping_cart_checkout,
              iconColor: widget.mainColor,
              label: LOCALIZATION.localize('home_page.orders'),
              value:
                  (widget.liveSalesSummary['orders'] == 0 ||
                          widget.liveSalesSummary['orders'] == null)
                      ? LOCALIZATION.localize('main_word.no_data')
                      : widget.liveSalesSummary['orders'].toString(),
            ),
            SizedBox(height: 12.0),
            _buildMobileSummaryCard(
              icon: Icons.monetization_on,
              iconColor: Colors.green.shade600,
              label: LOCALIZATION.localize('home_page.profit'),
              value:
                  (widget.liveSalesSummary['profit'] == 0 ||
                          widget.liveSalesSummary['profit'] == null)
                      ? LOCALIZATION.localize('main_word.no_data')
                      : "${widget.currency} ${widget.liveSalesSummary['profit']?.toStringAsFixed(2) ?? '0.00'}",
            ),
            SizedBox(height: 12.0),
            _buildMobileSummaryCard(
              icon: Icons.star,
              iconColor: Colors.amber.shade700,
              label: LOCALIZATION.localize('home_page.best_selling_item'),
              value:
                  widget.liveSalesSummary['bestSellingItem'] ??
                  LOCALIZATION.localize('main_word.no_data'),
            ),
          ] else ...[
            // Desktop/Tablet: Keep grid layout
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 1.2,
              ),
              children: [
                _buildSummaryTile(
                  icon: Icons.shopping_cart_checkout,
                  iconColor: widget.mainColor,
                  label: LOCALIZATION.localize('home_page.orders'),
                  value:
                      (widget.liveSalesSummary['orders'] == 0 ||
                              widget.liveSalesSummary['orders'] == null)
                          ? LOCALIZATION.localize('main_word.no_data')
                          : widget.liveSalesSummary['orders'].toString(),
                ),
                _buildSummaryTile(
                  icon: Icons.monetization_on,
                  iconColor: Colors.green.shade600,
                  label: LOCALIZATION.localize('home_page.profit'),
                  value:
                      (widget.liveSalesSummary['profit'] == 0 ||
                              widget.liveSalesSummary['profit'] == null)
                          ? LOCALIZATION.localize('main_word.no_data')
                          : "${widget.currency} ${widget.liveSalesSummary['profit']?.toStringAsFixed(2) ?? '0.00'}",
                ),
                _buildSummaryTile(
                  icon: Icons.star,
                  iconColor: Colors.amber.shade700,
                  label: LOCALIZATION.localize('home_page.best_selling_item'),
                  value:
                      widget.liveSalesSummary['bestSellingItem'] ??
                      LOCALIZATION.localize('main_word.no_data'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Android-optimized summary card with horizontal layout and improved readability
  Widget _buildMobileSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(20.0), // Increased padding for better spacing
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1.0),
      ),
      child: Row(
        children: [
          // Icon section - larger and more prominent
          Container(
            width: 56, // Increased from 48
            height: 56, // Increased from 48
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(
                16,
              ), // Increased border radius
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28, // Increased from 24
            ),
          ),
          SizedBox(width: 20), // Increased spacing
          // Content section with better typography
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 15, // Increased from 13
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6), // Increased spacing
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                    fontSize: 20, // Significantly increased from 16
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Separate page for advanced sales summary on mobile devices
class _AdvancedSalesSummaryPage extends StatefulWidget {
  final Future<void> Function([StateSetter?]) updateAdvancedData;
  final bool loadingAdvancedSales;
  final String selectedFilter;
  final DateTimeRange? selectedRange;
  final Function(String, DateTimeRange?) onFilterChanged;
  final String currency;
  final Color mainColor;

  const _AdvancedSalesSummaryPage({
    required this.updateAdvancedData,
    required this.loadingAdvancedSales,
    required this.selectedFilter,
    required this.selectedRange,
    required this.onFilterChanged,
    required this.currency,
    required this.mainColor,
  });

  @override
  State<_AdvancedSalesSummaryPage> createState() =>
      _AdvancedSalesSummaryPageState();
}

class _AdvancedSalesSummaryPageState extends State<_AdvancedSalesSummaryPage> {
  bool _loading = false;
  late String _selectedFilter;
  DateTimeRange? _selectedRange;
  String _selectedDataType = 'Products'; // Products, Categories, Payments

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.selectedFilter;
    _selectedRange = widget.selectedRange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          LOCALIZATION.localize('home_page.advanced_sales_summary'),
          style: TextStyle(
            fontSize: 16, // Smaller font for small screens
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 1,
        actions: [
          if (_loading)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Compact filter controls
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Time filter dropdown
                _buildCompactFilterDropdown(),

                if (_selectedFilter == 'custom' && _selectedRange != null)
                  Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "${DateFormat.yMMMd().format(_selectedRange!.start)} - ${DateFormat.yMMMd().format(_selectedRange!.end)}",
                      style: TextStyle(
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                SizedBox(height: 12),

                // Data type selector
                _buildDataTypeSelector(),
              ],
            ),
          ),

          // Content area
          Expanded(
            child:
                _loading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Loading data...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _buildMobileOptimizedContent(),
          ),
        ],
      ),
    );
  }

  /// Compact filter dropdown instead of segmented buttons
  Widget _buildCompactFilterDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          isExpanded: true,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          icon: Icon(Icons.keyboard_arrow_down, size: 20),
          items: [
            DropdownMenuItem(
              value: 'today',
              child: Row(
                children: [
                  Icon(Icons.today, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text('Today'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'hour',
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text('This Hour'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'custom',
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text('Custom Range'),
                ],
              ),
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;

            setState(() => _selectedFilter = value);

            if (value == 'custom') {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange:
                    _selectedRange ??
                    DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 7)),
                      end: DateTime.now(),
                    ),
              );
              if (picked != null) {
                setState(() => _selectedRange = picked);
              } else {
                setState(() => _selectedFilter = 'today');
                return;
              }
            }

            widget.onFilterChanged(value, _selectedRange);
            await _updateData();
          },
        ),
      ),
    );
  }

  /// Horizontal data type selector
  Widget _buildDataTypeSelector() {
    final options = ['Products', 'Categories', 'Payments'];

    return Container(
      height: 36, // Compact height
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children:
            options.map((option) {
              final isSelected = _selectedDataType == option;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDataType = option),
                  child: Container(
                    margin: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  /// Mobile-optimized content based on selected data type
  Widget _buildMobileOptimizedContent() {
    switch (_selectedDataType) {
      case 'Products':
        return _buildCompactChart(homepageService.productSales, 'Products');
      case 'Categories':
        return _buildCompactChart(homepageService.categorySales, 'Categories');
      case 'Payments':
        return _buildCompactPaymentSummary();
      default:
        return _buildCompactChart(homepageService.productSales, 'Products');
    }
  }

  /// Ultra-compact chart for small screens
  Widget _buildCompactChart(Map<String, int> data, String title) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 12),
            Text(
              'No $title Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Data will appear here once available',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final sortedEntries =
        data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1;

    return ListView.separated(
      padding: EdgeInsets.all(12.0),
      itemCount: sortedEntries.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final percentage = (entry.value / maxValue * 100).round();

        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item name and value
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              // Progress bar
              Row(
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: entry.value / maxValue,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compact payment summary
  Widget _buildCompactPaymentSummary() {
    final data = homepageService.paymentMethodSummary;

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_outlined, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 12),
            Text(
              'No Payment Data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final sorted =
        data.entries.toList()..sort(
          (a, b) =>
              (b.value['count'] as int).compareTo(a.value['count'] as int),
        );

    return ListView.separated(
      padding: EdgeInsets.all(12.0),
      itemCount: sorted.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = sorted[index];
        final count = entry.value['count'] ?? 0;
        final total = entry.value['total'] ?? 0.0;

        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getPaymentMethodIcon(entry.key),
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
              ),
              SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '$count transactions',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '${widget.currency} ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns a specific icon based on the payment method name.
  IconData _getPaymentMethodIcon(String methodName) {
    final lowerCaseMethod = methodName.toLowerCase();
    if (lowerCaseMethod.contains('card')) {
      return Icons.credit_card;
    } else if (lowerCaseMethod.contains('cash')) {
      return Icons.money;
    } else if (lowerCaseMethod.contains('qr')) {
      return Icons.qr_code_scanner;
    }
    return Icons.payment; // Default icon
  }

  /// Update data and refresh the page
  Future<void> _updateData() async {
    setState(() => _loading = true);
    await widget.updateAdvancedData();
    setState(() => _loading = false);
  }
}
