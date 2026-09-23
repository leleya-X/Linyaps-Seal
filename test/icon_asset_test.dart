// 验证 packaging/linyaps-seal.svg 能被 flutter_svg 正确画出来。
//
// 关于页直接引用这张源文件（见 about_dialog.dart），它里面有 linearGradient
// 和 mask。flutter_svg 遇到画不出来的特性不会报错，只会静默少画一层 ——
// 图标看着"有点不对"但不至于发现，所以这里直接查像素。

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const int _side = 512;

void main() {
  testWidgets('图标 SVG 的渐变 / 镂空 / 圆角都画出来了', (WidgetTester tester) async {
    final svg = File('packaging/linyaps-seal.svg').readAsStringSync();
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SvgPicture.string(svg, width: _side.toDouble(), height: _side.toDouble()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bytes;
    });

    final ByteData pixels = data!;
    ({int r, int g, int b, int a}) px (int x, int y) {
      final i = (y * _side + x) * 4;
      return (
        r: pixels.getUint8(i),
        g: pixels.getUint8(i + 1),
        b: pixels.getUint8(i + 2),
        a: pixels.getUint8(i + 3),
      );
    }

    // 方块的圆角外侧：应当被切掉，露出底下对话框的背景（不是图标的蓝）
    final corner = px(2, 2);
    expect(corner.b > 200 && corner.r < 100, isFalse,
        reason: '左上角圆角外不该还是图标的蓝，实际 ${corner.r},${corner.g},${corner.b},${corner.a}');

    // 立方体顶面：白色
    final top = px(256, 130);
    expect([top.r, top.g, top.b], everyElement(greaterThan(240)),
        reason: '顶面应当是白的，实际 ${top.r},${top.g},${top.b},${top.a}');

    // 背景上部与下部：都该是蓝的，且下面比上面深（渐变生效）
    final bright = px(60, 60);
    final dark = px(60, 500);
    expect(bright.b, greaterThan(bright.r), reason: '背景应当是蓝的');
    expect(dark.b, lessThan(bright.b),
        reason: '背景渐变应当自上而下变深，实际 ${bright.b} -> ${dark.b}');

    // 钥匙孔圆心：被 mask 挖掉，透出的是背景的蓝而不是立方体的白。
    // flutter_svg 若不支持 mask，这一处会留着白色 —— 那就是静默画错了
    final keyhole = px(256, 215);
    expect(keyhole.b, greaterThan(keyhole.r),
        reason: '钥匙孔应当透出底色，实际 ${keyhole.r},${keyhole.g},${keyhole.b}');
  });
}
