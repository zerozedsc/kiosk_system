import "../../configs/configs.dart";
import 'db.dart';

class DatabaseViewPage extends StatefulWidget {
  const DatabaseViewPage({super.key});

  @override
  State<DatabaseViewPage> createState() => DatabaseViewPageState();
}

class DatabaseViewPageState extends State<DatabaseViewPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _data = <Map<String, dynamic>>[];
  String _tableName = "";

  @override
  void initState() {
    super.initState();
    _loadData(
      tableName: "spot_table",
    ); // Load initial data when the widget is initialized
  }

  // Method to load data from the database with an optional search query
  Future<void> _loadData({required String? tableName}) async {
    final DatabaseQuery dbQuery = DatabaseQuery(db: DB, LOGS: APP_LOGS);

    // Use the query to fetch specific data if provided, otherwise fetch all data
    final List<Map<String, dynamic>> data = await dbQuery.fetchAllData(
      tableName!,
    );
    _tableName = tableName ?? "";

    setState(() {
      _data = data;
    });
  }

  // Method to check if an image asset exists, use like this -> ('assets/images/S1) without file extension
  Future<String?> checkImageAsset(String basePath) async {
    // Possible file extensions to check
    final List<String> extensions = ['.png', '.jpg', '.jpeg'];

    // Iterate over possible extensions
    for (String ext in extensions) {
      String filePath = '$basePath$ext';
      try {
        // Try loading the asset with each extension
        await rootBundle.load(filePath);
        // If no exception, the file exists, return the path
        return filePath;
      } catch (e) {
        // Continue to the next extension if the file doesn't exist
        continue;
      }
    }
    // Return null if no file was found with the provided extensions
    return null;
  }

  // Method to handle search
  void _onSearchChanged() {
    String query = _searchController.text.trim();
    _loadData(tableName: query); // Load data based on the search query
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Database View'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Input Table Name...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged:
                  (text) => _onSearchChanged(), // Trigger search on text change
            ),
          ),
        ),
      ),
      body:
          _data.isEmpty
              ? const Center(child: Text('No data found'))
              : ListView.builder(
                itemCount: _data.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> item = Map<String, dynamic>.from(
                    _data[index],
                  );
                  final String tableFirstLetter = _tableName[0].toUpperCase();
                  int id = item['id'];
                  item["img_link"] = 'assets/images/$tableFirstLetter$id.jpg';

                  return InkWell(
                    onTap: () {
                      // Navigate to RelatedTabScreen with the selected item data
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) =>
                      //         RelatedTabScreen(data: item, dataType: _tableName),
                      //   ),
                      // );
                      print(item);
                    },
                    child: ListTile(
                      title: Text(item['id'].toString()),
                      subtitle: Text(item['name'].toString()),
                    ),
                  );
                },
              ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
