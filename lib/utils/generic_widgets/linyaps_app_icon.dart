// 应用图标: 本地导出的字节优先, 没有才去取商店给的链接, 都没有就显示通用图标

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names

import 'dart:typed_data';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:yaru/widgets.dart';

class LinyapsAppIcon extends StatelessWidget {

  /// 宿主导出的图标字节(见 host_bridge.dart 的 readEntries)
  final Uint8List? iconBytes;

  /// 图标是不是 SVG。只有拿到字节时才用得上
  final bool iconIsSvg;

  /// 玲珑商店给的图标链接, 本地没有图标时用它
  final String imageUrl;

  /// 边长(逻辑像素)
  final double size;

  const LinyapsAppIcon ({
    super.key,
    required this.iconBytes,
    required this.iconIsSvg,
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build (BuildContext context) {
    final bytes = iconBytes;

    // 本地这份直接用, 不走缓存也不联网: 文件就在手上
    if (bytes != null) {
      return SizedBox(
        height: size, width: size,
        child: iconIsSvg
            ? SvgPicture.memory(bytes)
            : Image.memory(bytes, fit: BoxFit.contain),
      );
    }

    if (imageUrl.isEmpty) return _generic();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: size, width: size,
      placeholder: (context, loadingProgress) {
        return Center(
          child: YaruCircularProgressIndicator(
            strokeWidth: 3.0,
          ),
        );
      },
      // fallback for .svg
      unsupportedImageBuilder: (context, url, bytes) {
        // `bytes` are the already-cached file bytes.
        return SvgPicture.memory(bytes); // from flutter_svg
      },
      errorBuilder: (context, error, stackTrace) => _generic(),
    );
  }

  // 一个图标都没有时的兜底: 玲珑自己的通用图标
  Widget _generic () {
    return Center(
      child: Image(
        height: size, width: size,
        image: AssetImage(
          'assets/images/linyaps-generic-app.png',
        ),
      ),
    );
  }
}
