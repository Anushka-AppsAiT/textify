import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_recognition_flutter/components/image_widget.dart';
import 'package:text_recognition_flutter/models/recognition_response.dart';
import 'package:text_recognition_flutter/recognizer/interface/text_recognizer.dart';
import 'package:text_recognition_flutter/recognizer/mlkit_text_recognizer.dart';
import 'package:text_recognition_flutter/recognizer/tesseract_text_recognizer.dart';

import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // For working with files

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late ImagePicker _picker;
  late ITextRecognizer _recognizer;
  bool _processing = false; // Indicator for processing state

  RecognitionResponse? _response;
  String? _currentImagePath; // To keep track of the last processed image

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _recognizer = TesseractTextRecognizer(); // Default recognizer
    // _recognizer = MLKitTextRecognizer();
  }

  @override
  void dispose() {
    super.dispose();
    // Dispose recognizer if necessary
    if (_recognizer is MLKitTextRecognizer) {
      (_recognizer as MLKitTextRecognizer).dispose();
    }
  }

  void processImage(String imgPath) async {
    setState(() {
      _processing = true; // Start processing indicator
    });

    // Process image using selected recognizer
    final recognizedText = await _recognizer.processImage(imgPath);
    setState(() {
      _response = RecognitionResponse(
        imgPath: imgPath,
        recognizedText: recognizedText,
      );
      _currentImagePath = imgPath; // Keep track of the current image path
      _processing = false; // Stop processing indicator
    });
  }

  Future<String?> obtainImage(ImageSource source) async {
    // Pick image from camera or gallery
    final file = await _picker.pickImage(source: source);
    return file?.path;
  }

  Future<void> obtainPdf() async {
    setState(() {
      _processing = true;
    });

    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null) return;

    final filePath = result.files.single.path!;
    final document = await PdfDocument.openFile(filePath);

    String allRecognizedText = '';

    for (int pageNum = 1; pageNum <= document.pagesCount; pageNum++) {
      final page = await document.getPage(pageNum);
      final pageImage = await page.render(
        width: page.width * 2, // Increase width
        height: page.height * 2, // Increase height
        format: PdfPageImageFormat.png,
      );
      final imgPath = await saveImageToTemporaryDirectory(pageImage!);

      String recognizedText = await _recognizer.processImage(imgPath);
      allRecognizedText += recognizedText + '\n';

      await page.close();
    }

    await document.close();

    setState(() {
      _response = RecognitionResponse(
        imgPath: _currentImagePath ?? filePath,
        recognizedText: allRecognizedText,
      );
      _processing = false;
    });
  }

  Future<String> saveImageToTemporaryDirectory(PdfPageImage pageImage) async {
    // Save rendered PDF page image to temporary directory
    final tempDir = await getTemporaryDirectory();
    final imgPath =
        '${tempDir.path}/page_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(imgPath);
    await file.writeAsBytes(pageImage.bytes!);
    return imgPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Recognition'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => imagePickAlert(
              onPdfPressed: () async {
                Navigator.of(context).pop();
                await obtainPdf(); // Handle PDF selection and processing
              },
              onGalleryPressed: () async {
                final imgPath = await obtainImage(ImageSource.gallery);
                if (imgPath == null) return;
                Navigator.of(context).pop();
                processImage(imgPath); // Process selected image
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: _processing
          ? Center(
              child: CircularProgressIndicator(), // Loading indicator
            )
          : _response == null
              ? const Center(
                  child: Text('Pick image or PDF to continue'),
                )
              : ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.width,
                      width: MediaQuery.of(context).size.width,
                      child: _response!.imgPath != null
                          ? Image.file(File(_response!.imgPath))
                          : Container(), // Display the last image processed
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Recognized Text",
                                  style: Theme.of(context).textTheme.headline6,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                        text: _response!.recognizedText),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Copied to Clipboard'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(_response!.recognizedText),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// void main() {
//   runApp(MaterialApp(
//     home: HomeView(),
//   ));
// }
