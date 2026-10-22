# 自建多平台弹幕

キラキラ可连接自行部署的 [LogVar danmu_api](https://github.com/huangxd-/danmu_api)，也保留具有合法应用权限的弹弹play接口兼容性。

自建服务选择 bilibili、bahamut、tencent、iqiyi、youku、imgo 等直接平台来源，不启用 dandan 来源，因此不需要申请弹弹play应用权限。具体弹幕覆盖、集数和时间轴受源平台及片源版本影响。

## 构建配置

把配置保存在源码仓库之外，例如 `%LOCALAPPDATA%\kirakira-build\danmaku-credentials.json`：

```json
{
  "DANMAKU_API_BASE_URL": "https://your-host.example/your-service/your-private-token"
}
```

这是占位示例。实际地址和 token 不要提交到 GitHub。此配置只使用普通播放权限 token，不要填写服务的 ADMIN_TOKEN，也不需要同时注入弹弹play的 AppSecret。发行客户端中的 token 无法作为永久保密的管理员凭据，服务必须限制可访问的接口和请求频率。

构建助手默认读取这个文件。也可使用 `--dart-define-from-file=<配置文件>`。没有自建服务配置时，原弹弹play接口仍需 `DANDANAPI_APPID` 和 `DANDANAPI_KEY`。

`tools/check-danmaku-access.ps1` 实际验证搜索接口；加 `-ConfigurationOnly` 只校验配置。

## 播放行为

- 自动匹配发送番剧中文名、首播年份和当前集数，保留标题中的季度标记；未匹配时尝试原文标题。
- 使用服务返回的 episodeId 获取弹幕，不按弹弹play的集数编码规则拼接 ID。
- 手动检索、完整选集列表、下载缓存与原有弹幕样式/屏蔽功能继续使用。
- 网络或服务错误仍显示失败；无匹配或无弹幕显示为空，二者不混淆。
- 自建请求不携带弹弹play签名/密钥。客户端网络日志隐藏私有接口地址。

## 部署建议

服务仅绑定本机端口，由 HTTPS 反向代理公开播放所需的 search、bangumi、match、comment 和 segmentcomment 路由。配置、日志、上传和管理路由保留在本机，不对应用客户端开放。使用随机 token、持久化缓存、内存上限、日志轮转和固定镜像摘要，保留原站点配置及回滚方法。
