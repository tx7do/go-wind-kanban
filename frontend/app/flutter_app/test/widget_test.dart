// UI 冒烟：完整初始化依赖网络（NTP 时间同步/接口拉取），CI/单测环境不可达，
// 此处 skip；真实冒烟在联调阶段（flutter run）执行。
// 领域逻辑的单测见 board_models_test.dart。
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widget smoke is deferred to runtime integration', () {
    // 占位：防止空测试文件告警。
    expect(1 + 1, 2);
  }, skip: 'requires networked init (NTP/API); run via flutter run instead');
}
