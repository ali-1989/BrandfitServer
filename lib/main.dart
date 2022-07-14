import 'dart:io';
import 'package:assistance_kit/database/psql2.dart';
import 'package:assistance_kit/api/helpers/jsonHelper.dart';
import 'package:assistance_kit/api/logger/logger.dart';
import 'package:assistance_kit/net/netHelper.dart';
import 'package:assistance_kit/api/system.dart';
import 'package:brandfit_server/app/cronAssistance.dart';
import 'package:brandfit_server/app/smsKaveh.dart';
import 'package:brandfit_server/app/pathNs.dart';
import 'package:brandfit_server/constants.dart';
import 'package:brandfit_server/database/databaseNs.dart';
import 'package:brandfit_server/models/countryModel.dart';
import 'package:brandfit_server/models/currencyModel.dart';
import 'package:brandfit_server/publicAccess.dart';
import 'package:brandfit_server/rest_api/ServerNs.dart';
import 'package:brandfit_server/rest_api/wsServerNs.dart';

// db[bigint]   == dart[int]
// db[numeric]  == dart[bigint]


void main(List<String> arguments) async {
  PathsNs.init();
  PublicAccess.logger = Logger(PathsNs.getLogPath());
  await PublicAccess.logger.isPrepare();

  var startInfo = '''
    ====================================================================================
    ==== Name: ${Constants.serverName}
    ==== Ver: ${Constants.serverVersion}
    ====================================================================================
    start at: ${DateTime.now().toUtc()}  UTC | ${DateTime.now()}  Local
    execute path: ${PathsNs.getExecutePath()}
    current path: ${PathsNs.getCurrentPath()}
    Dart path: ${Platform.executable}
    Process: ${Platform.numberOfProcessors}
    OS: ${Platform.operatingSystem}  (${Platform.operatingSystemVersion})
    Locale: ${Platform.localeName}
    Domain: ${PublicAccess.domain}
    ports: ${Constants.port}   | WS: ${Constants.wsPort}
    IPs: ${await NetHelper.getIps()}
    *ram*
    #######################################################################''';

  if (System.isLinux()) {
    MemoryInfo.initial();
    var ramInfo = 'RAM:  all: ${MemoryInfo.mem_total_mb} MB,   free: ${MemoryInfo.mem_free_mb} MB';
    ramInfo += '\n    SWAP:  all: ${MemoryInfo.swap_total_mb} MB,   free: ${MemoryInfo.swap_free_mb} MB';
    startInfo = startInfo.replaceFirst(r'*ram*', ramInfo);
  }
  else {
    startInfo = startInfo.replaceFirst('*ram*', '');
  }

  // ignore: unawaited_futures
  PublicAccess.logger.logToAll(startInfo);

  //PublicAccess.psql = Psql();
  //PublicAccess.psql.open(dbName: Constants.dbName, user: Constants.dbUserName, pass: Constants.dbPassword);

  PublicAccess.psql2 = Psql2();
  await PublicAccess.psql2.open(dbName: Constants.dbName, user: Constants.dbUserName, pass: Constants.dbPassword);

  await DatabaseNs.initial();

  var countryJs = JsonHelper.jsonToMap<String, dynamic>(await PublicAccess.loadAssets('countries.json'))!;
  CountryModel.countries = countryJs;
  CurrencyModel.countries = countryJs;

  PublicAccess.server = ServerNs.prepareServer();
  await PublicAccess.server.listen(Constants.port);

  PublicAccess.wsServer = WsServerNs.prepareWsServer();
  await PublicAccess.wsServer.listen(Constants.wsPort);

  CronAssistance.startCronJobs();
  Kaveh.init();
  // ignore: unawaited_futures
  PublicAccess.logger.logToAll('-------------| All things is Ok');
  codes();
}

void codes() async {
  //DatabaseAlters.simulate_addTicketMessage(ticketIds: [102,103,105]);
  //FakeAndHack.simulate_addTicketWithMessage(102, 102);
}








/*
String text = stdin.readLineSync().toLowerCase();
  String capitalize(Match m) => m[0].substring(0, 1).toUpperCase() + m[0].substring(1);
  String skip(String s) => "";
  prin(text.splitMapJoin(new RegExp(r'[a-z]+'), onMatch: capitalize, onNonMatch: skip));
 */