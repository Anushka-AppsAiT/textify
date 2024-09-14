import 'package:flutter/material.dart';

Widget imagePickAlert({
  void Function()? onPdfPressed,
  void Function()? onGalleryPressed,
}) {
  return AlertDialog(
    title: const Text(
      "Pick a source:",
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.picture_as_pdf),
          title: const Text(
            "PDF",
          ),
          onTap: onPdfPressed,
        ),
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text(
            "Gallery",
          ),
          onTap: onGalleryPressed,
        ),
      ],
    ),
  );
}
