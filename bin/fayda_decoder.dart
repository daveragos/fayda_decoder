import 'dart:io';

import 'package:fayda_decoder/src/cli/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
