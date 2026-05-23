import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 1:1 裁切头像对话框
class CropAvatarDialog extends StatefulWidget {
  final String imagePath;
  const CropAvatarDialog({super.key, required this.imagePath});

  /// 返回裁切后的文件路径，用户取消返回 null
  static Future<String?> show(BuildContext context, String imagePath) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => CropAvatarDialog(imagePath: imagePath),
    );
  }

  @override
  State<CropAvatarDialog> createState() => _CropAvatarDialogState();
}

class _CropAvatarDialogState extends State<CropAvatarDialog> {
  final TransformationController _transformCtrl = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<String?> _cropAndSave() async {
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final dir = Directory.systemTemp;
    final croppedPath = '${dir.path}${Platform.pathSeparator}crop_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(croppedPath).writeAsBytes(bytes);
    return croppedPath;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cropSize = screenSize.width * 0.55; // 裁切区域大小

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 裁切预览区
          SizedBox(
            width: cropSize,
            height: cropSize,
            child: RepaintBoundary(
              key: _repaintKey,
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transformCtrl,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.file(
                    File(widget.imagePath),
                    width: cropSize,
                    height: cropSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 32),
              ElevatedButton(
                onPressed: () async {
                  final path = await _cropAndSave();
                  if (mounted) Navigator.pop(context, path);
                },
                child: const Text('确认裁切', style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
