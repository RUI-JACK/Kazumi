/// Upstream Kazumi releases belong to another application. This local
/// distribution has no published application update feed of its own.
abstract final class UpdateChannel {
  static const applicationUpdatesEnabled = false;
  static const title = '定制版更新';
  static const notice = '请使用 キラキラ 定制安装包更新，播放源规则仍可单独更新。';
}
