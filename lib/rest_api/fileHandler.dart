import 'dart:async';
import 'dart:io';
import 'package:alfred/alfred.dart';
import 'package:assistance_kit/api/helpers/fileHelper.dart';
import 'package:assistance_kit/api/helpers/urlHelper.dart';
import 'package:assistance_kit/dateFormatter/date_format.dart';
import 'package:assistance_kit/api/helpers/pathHelper.dart';
import 'package:assistance_kit/api/helpers/textHelper.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/publicAccess.dart';

class FileHandler {
  FileHandler._();

  static String staticPath = PathsNs.getCurrentPath() + PathHelper.getSeparator();
  static RegExp rangeRex = RegExp(r'^bytes=\s*\d*-\d*(,\d*-\d*)*$');

  static FutureOr response(HttpRequest req, HttpResponse res) async {
    var fileName = req.uri.path;
    fileName = UrlHelper.decodeUrl(fileName)!;

    if(fileName.startsWith('/')){
      fileName = fileName.substring(1);
    }

    var path = staticPath + fileName;
    //path = PathsNs.removeBasePathFromLocalPath(PathsNs.getCurrentPath(), path)!;
    //path = PathHelper.removeIfStartBy(path, PathsNs.getCurrentPath());
    final file = File(path);
    final exist = await file.exists();

    //PublicAccess.logInDebug('#@# $fileName,  $exist,  $path  ');

    if(exist){
      var modifier = await file.lastModified();
      modifier = modifier.toUtc();
      final formattedModified = formatDate(modifier, [D, ', ', d, ' ', M, ' ', yyyy, ' ', HH, ':', nn, ':', ss, ' ', z]);
      final ifRange = req.headers.value('If-Range');
      final range = req.headers.value('range');

      if(FileHelper.getDotExtension(file.path).endsWith('html')){
        res.headers.add('Content-Type', 'text/html; charset=utf-8');
      }
      else {
        res.setContentTypeFromFile(file);
        res.setDownload(filename: PathHelper.getFileName(file.path));
        res.headers.add('Accept-Ranges', 'bytes');
        res.headers.add('Content-Encoding', 'identity');
        res.headers.add('X-Powered-By', 'Dart, Alfred');
        res.headers.add('X-Frame-Options', 'SAMEORIGIN');
      }
      
      if(ifRange != null && ifRange.isNotEmpty) {
        res.headers.add('ETag', ifRange);
      }
      else {
        res.headers.add('Last-Modified', formattedModified);
      }

      if(TextHelper.isEmptyOrNull(range)) {
        res.headers.add('Content-Length', await file.length());
        return file;
      }
      else {
        if(!rangeRex.hasMatch(range!)){
          res.statusCode = 416;
          await res.send('this rang not supported');
          return;
        }

        final ranges = range.split('=')[1].split('-');
        final len = await file.length();
        final r1 = int.tryParse(ranges[0])?? 0;
        var r2 = len - 1;

        if (ranges.length > 1 && !TextHelper.isEmptyOrNull(ranges[1])) {
          r2 = int.tryParse(ranges[1])!;
        }

        final responseRange = 'bytes $r1-$r2/$len';

        res.headers.add('Content-Length', ((r2-r1)+1).toString());
        res.headers.add('Content-Range', responseRange);

        res.statusCode = 206;

        return file.openRead(r1, r2+1);
      }
    }
  }
}