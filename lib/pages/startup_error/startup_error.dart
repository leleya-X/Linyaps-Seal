// 启动阶段取数失败时的界面
//
// 存在的意义只有一个: 把话说出来。
// 应用列表取不到的时候如果照常进主界面, 摆给用户的是一张空列表, 而空列表和
// "这台机器上确实没装玲珑应用"长得一模一样 —— 出错这件事就这么被吞掉了。
// 所以这里不留退路, 也不装作没事: 直接说哪一步没成、原始报错是什么, 让用户能查。

import 'package:flutter/material.dart';

class StartupErrorView extends StatelessWidget {
  const StartupErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// 原始报错。原样显示, 不加工成"操作失败, 请重试"这类什么也没说的话
  final String message;

  /// 重试。取数是一次性的, 修好宿主侧的东西之后得能再试一次
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '读不到玲珑的应用列表',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  '应用列表来自宿主机的 /var/lib/linglong/states.json, '
                  '由宿主侧助手 linyapsd 经 D-Bus 提供。'
                  '这一条链路没走通, 所以现在没有列表可显示。',
                ),
                const SizedBox(height: 20),
                SelectableText(
                  message,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      onRetry();
                    },
                    child: const Text('重试'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
