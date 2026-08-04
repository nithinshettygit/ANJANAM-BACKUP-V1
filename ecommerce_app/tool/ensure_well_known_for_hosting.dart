// Run before `firebase deploy` (hosting.predeploy in firebase.json).
// 1) Copies web/.well-known/assetlinks.json → build/web/.well-known/
// 2) Copies static legal/support HTML pages → build/web/...
// 3) Copies SEO assets (robots.txt, sitemap.xml, llms.txt, seo-bootstrap.js)
// 4) Copies web/app-config.json → build/web/ if present (web runtime Supabase config).
import 'dart:io';

void main() {
  final root = Directory.current;

  final appCfgSrc = File.fromUri(root.uri.resolve('web/app-config.json'));
  if (appCfgSrc.existsSync()) {
    final appCfgDst = File.fromUri(root.uri.resolve('build/web/app-config.json'));
    appCfgDst.parent.createSync(recursive: true);
    appCfgDst.writeAsBytesSync(appCfgSrc.readAsBytesSync());
    stdout.writeln('Copied app-config.json -> ${appCfgDst.path}');
  } else {
    stdout.writeln('Skip app-config.json (create web/app-config.json from web/app-config.json.example if needed).');
  }

  final assetSrc = File.fromUri(root.uri.resolve('web/.well-known/assetlinks.json'));
  if (!assetSrc.existsSync()) {
    stderr.writeln('Missing ${assetSrc.path}');
    exitCode = 1;
    return;
  }
  final assetDstDir = Directory.fromUri(root.uri.resolve('build/web/.well-known'));
  assetDstDir.createSync(recursive: true);
  final assetDst = File.fromUri(assetDstDir.uri.resolve('assetlinks.json'));
  assetDst.writeAsBytesSync(assetSrc.readAsBytesSync());
  stdout.writeln('Copied assetlinks.json -> ${assetDst.path}');

  const staticHtmlDirs = [
    'privacy-policy',
    'terms',
    'refund-policy',
    'support',
    'delete-account',
    'about',
  ];
  for (final name in staticHtmlDirs) {
    final srcHtml = File.fromUri(root.uri.resolve('web/$name/index.html'));
    if (!srcHtml.existsSync()) {
      stderr.writeln('Missing ${srcHtml.path}');
      exitCode = 1;
      return;
    }
    final dstHtml = File.fromUri(root.uri.resolve('build/web/$name/index.html'));
    dstHtml.parent.createSync(recursive: true);
    dstHtml.writeAsBytesSync(srcHtml.readAsBytesSync());
    stdout.writeln('Copied $name/index.html -> ${dstHtml.path}');
  }

  const seoRootFiles = ['robots.txt', 'sitemap.xml', 'llms.txt', 'seo-bootstrap.js'];
  for (final name in seoRootFiles) {
    final src = File.fromUri(root.uri.resolve('web/$name'));
    if (!src.existsSync()) {
      stderr.writeln('Missing ${src.path}');
      exitCode = 1;
      return;
    }
    final dst = File.fromUri(root.uri.resolve('build/web/$name'));
    dst.parent.createSync(recursive: true);
    dst.writeAsBytesSync(src.readAsBytesSync());
    stdout.writeln('Copied $name -> ${dst.path}');
  }
}
