/// Routes that require this application's credentials on the Kazumi mirror.
/// Their public Bangumi equivalents can be read without those mirror keys.
bool isProtectedBangumiMirrorRoute(String method, String path) {
  if (method == 'POST' && path == '/v0/search/subjects') return true;
  if (method != 'GET') return false;
  return path.startsWith('/p1/subjects/') && path.endsWith('/comments') ||
      path.startsWith('/p1/episodes/') && path.endsWith('/comments') ||
      path.startsWith('/p1/characters/') && path.endsWith('/comments');
}
