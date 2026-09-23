// 命令行脚本，结果就是往 stdout 打，不需要换成日志框架
// ignore_for_file: avoid_print

// linyapsd 的端到端冒烟测试。
//
// 故意不预先启动 linyapsd：让它由 session bus 按需激活，
// 这样一次跑通既验证了四个方法，也验证了激活链路本身
// （激活这条路上出过问题，手工启动正常、bus 拉起就没响应）。
//
//   dart run tool/dbus_smoke.dart
//
// 前提：~/.local/share/dbus-1/services/ 下已装好服务文件，见 linyapsd/README.md。
import 'package:dbus/dbus.dart';
import 'package:linyaps_seal/utils/Backend_API/host_bridge.dart';

// 名字/路径/接口直接用应用自己那份常量，不在这里另抄一遍：
// 两边各写一份的话，哪天改了一处、这里照样通过，测的就成了别的东西。
const busName = HostBridge.busName;
const objectPath = HostBridge.objectPath;
const iface = HostBridge.interface;

Future<void> main() async {
  final client = DBusClient.session();
  final object = DBusRemoteObject(client,
      name: busName, path: DBusObjectPath(objectPath));

  final pong = await object.callMethod(
      iface, 'Ping', const [], replySignature: DBusSignature('s'));
  print('Ping      -> ${pong.returnValues[0].asString()}');

  final ver = await object.callMethod(
      iface, 'Version', const [], replySignature: DBusSignature('s'));
  print('Version   -> ${ver.returnValues[0].asString()}');

  final states = await object.callMethod(
      iface, 'ReadStates', const [], replySignature: DBusSignature('s'));
  final text = states.returnValues[0].asString();
  print('ReadStates-> ${text.length} 字符, 开头: ${text.substring(0, 40)}');

  final ll = await object.callMethod(iface, 'ExecLlCli',
      [DBusArray.string(['list'])], replySignature: DBusSignature('iss'));
  print('ExecLlCli -> 退出码 ${ll.returnValues[0].asInt32()}, '
      'stdout ${ll.returnValues[1].asString().length} 字符');

  try {
    await object.callMethod(iface, 'ExecLlCli',
        [DBusArray.string(['uninstall'])], replySignature: DBusSignature('iss'));
    print('ExecLlCli uninstall -> 竟然通过了，白名单没生效！');
  } on DBusErrorException catch (e) {
    print('ExecLlCli uninstall -> 已拒绝 (${e.errorName}: ${e.message})');
  }

  await client.close();
}
