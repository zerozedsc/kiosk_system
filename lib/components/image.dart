import '../configs/configs.dart';

import 'package:image/image.dart' as img;

Future<Uint8List> convertToBlackAndWhite(String assetPath) async {
  final ByteData bytes = await rootBundle.load(assetPath);
  final Uint8List originalImage = bytes.buffer.asUint8List();

  final img.Image? decodedImage = img.decodeImage(originalImage);
  if (decodedImage == null) throw Exception('Failed to decode image');

  final img.Image bwImage = img.grayscale(decodedImage);
  for (var y = 0; y < bwImage.height; y++) {
    for (var x = 0; x < bwImage.width; x++) {
      var pixel = bwImage.getPixel(x, y);
      var gray = img.getLuminance(pixel);
      bwImage.setPixel(
        x,
        y,
        gray < 128
            ? img.ColorInt8.rgb(0, 0, 0)
            : img.ColorInt8.rgb(255, 255, 255),
      );
    }
  }

  return Uint8List.fromList(img.encodePng(bwImage));
}

Future<Uint8List> convertToGrayscale(String assetPath) async {
  final ByteData bytes = await rootBundle.load(assetPath);
  final Uint8List originalImage = bytes.buffer.asUint8List();

  final img.Image? decodedImage = img.decodeImage(originalImage);
  if (decodedImage == null) throw Exception('Failed to decode image');

  final img.Image grayscaleImage = img.grayscale(decodedImage);

  return Uint8List.fromList(img.encodePng(grayscaleImage));
}

Future<Uint8List> convertForThermalPrinter(String assetPath) async {
  final ByteData bytes = await rootBundle.load(assetPath);
  final Uint8List originalImage = await convertToBlackAndWhite(
    assetPath,
  ); //bytes.buffer.asUint8List();

  final img.Image? decodedImage = img.decodeImage(originalImage);
  if (decodedImage == null) throw Exception('Failed to decode image');

  // Resize image to typical thermal printer width (usually 384px)
  final int targetWidth = 384;
  final double ratio = targetWidth / decodedImage.width;
  final int targetHeight = (decodedImage.height * ratio).round();

  final img.Image resizedImage = img.copyResize(
    decodedImage,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.linear,
  );

  // Convert to black and white with dithering for better print quality
  final img.Image thermalImage = img.grayscale(resizedImage);
  // Apply Floyd-Steinberg dithering for better thermal printer output
  final img.Image ditheredImage = img.ditherImage(
    thermalImage,
    kernel: img.DitherKernel.floydSteinberg,
    serpentine: true,
  );

  // Copy the dithered result back to thermalImage
  for (var y = 0; y < thermalImage.height; y++) {
    for (var x = 0; x < thermalImage.width; x++) {
      thermalImage.setPixel(x, y, ditheredImage.getPixel(x, y));
    }
  }

  return Uint8List.fromList(img.encodePng(thermalImage));
}

/// [080725] Resize an image to a reasonable size (e.g., 800px width)
/// and encode it with reduced quality (e.g., 80%).
/// This function can handle both [File] and [Uint8List] as input sources.
/// If the source is a [File], it reads the bytes from the file.
/// If the source is a [Uint8List], it uses the bytes directly.
/// Returns the resized image as a [Uint8List].
/// If the source is neither, it throws an [ArgumentError].
/// This is useful for optimizing images for display in the app,
/// especially when dealing with large images that need to be resized
/// and compressed for better performance.
/// /// Example usage:
/// /// ```dart
///   Uint8List resizedImage = await resizeImage(
///     source: myFile, // or Uint8List
///    width: 450,
///   height: 450,
/// ///   quality: 80,
/// /// );
Future<Uint8List> resizeImage({
  required dynamic source,
  int width = 450,
  int height = 450,
  int quality = 80,
}) async {
  Uint8List bytes;

  // Handle different source types
  if (source is File) {
    // Read the image from file
    bytes = await source.readAsBytes();
  } else if (source is Uint8List) {
    // Source is already Uint8List
    bytes = source;
  } else {
    throw ArgumentError('Source must be either File or Uint8List');
  }

  final img.Image? image = img.decodeImage(bytes);
  if (image == null) return bytes;

  // Resize the image to a reasonable size (e.g., 800px width)
  final img.Image resizedImage = img.copyResize(
    image,
    width: width,
    height: (height * image.height / image.width).round(),
  );

  // Encode the image with reduced quality (80%)
  return Uint8List.fromList(img.encodeJpg(resizedImage, quality: quality));
}

class CardImage extends StatelessWidget {
  final dynamic imageSource;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Widget? placeholderWidget;

  const CardImage({
    Key? key,
    required this.imageSource,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.backgroundColor,
    this.placeholderWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _buildImage();
  }

  Widget _buildImage() {
    // Case 1: null check
    if (imageSource == null) {
      return _buildPlaceholder();
    }

    // Case 2: Check if it's a base64 string (blob)
    if (imageSource is String) {
      if (imageSource.startsWith('data:image') || _isBase64(imageSource)) {
        try {
          String base64String =
              imageSource.contains(',')
                  ? imageSource.split(',')[1]
                  : imageSource;
          Uint8List bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } catch (e) {
          return _buildPlaceholder();
        }
      }

      // Case 3: Assume it's an asset path
      return Image.asset(
        imageSource,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // Case 4: Invalid type
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? Colors.grey[300],
      child:
          placeholderWidget ??
          const Center(
            child: Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
          ),
    );
  }

  bool _isBase64(String str) {
    try {
      base64Decode(str.replaceAll(RegExp(r'\s'), ''));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Static utility method for easy use in other parts
  static Widget getImage({
    required dynamic source,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Color? backgroundColor,
    Widget? placeholder,
  }) {
    return CardImage(
      imageSource: source,
      fit: fit,
      width: width,
      height: height,
      backgroundColor: backgroundColor,
      placeholderWidget: placeholder,
    );
  }
}
