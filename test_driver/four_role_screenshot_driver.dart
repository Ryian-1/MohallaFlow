import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  const outputPath = 'build/publication_screenshots';
  final output = Directory(outputPath);
  await output.create(recursive: true);

  await integrationDriver(
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      if (!RegExp(r'^0[1-4]-(admin|resident|cleanliness-manager|worker)-dashboard$')
          .hasMatch(screenshotName)) {
        return false;
      }

      final file = File('$outputPath/$screenshotName.png');
      await file.writeAsBytes(screenshotBytes, flush: true);
      return await file.exists() && await file.length() > 0;
    },
  );
}
