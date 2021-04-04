import 'dart:convert';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:mobileraker/WsHelper.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:rxdart/rxdart.dart';
import 'package:simple_logger/simple_logger.dart';

final Set<String> skipGCodes = {"PAUSE", "RESUME", "CANCEL_PRINT"};

class PrinterService {
  final _webSocket = locator<WebSocketsNotifications>();
  final logger = locator<SimpleLogger>();

  ObserverList<MapEntry<String, Function>> _statusUpdateListener =
      new ObserverList();

  final List<String> subToPrinterObjects = [
    'toolhead',
    'extruder',
    'gcode_move',
    'heater_bed',
    'fan',
    'virtual_sdcard',
    'configfile',
    'print_stats',
    'heater_fan',
  ];
  BehaviorSubject<Printer> _printerStream;

  PrinterService() {
    _webSocket.addMethodListener(_onStatusUpdate, "notify_status_update");
  }

  Stream<Printer> fetchPrinter() {
    _printerStream = BehaviorSubject<Printer>();
    _webSocket.sendObject("printer.info", _printerInfo);
    _webSocket.sendObject("printer.objects.list", _printerObjectsList);

    return _printerStream.stream;
  }

  resumePrint() {
    _webSocket.sendObject("printer.print.resume", null);
  }

  pausePrint() {
    _webSocket.sendObject("printer.print.pause", null);
  }

  cancelPrint() {
    _webSocket.sendObject("printer.print.cancel", null);
  }

  addStatusUpdateListener(Function callback, [String object = ""]) {
    _statusUpdateListener.add(new MapEntry(object, callback));
  }

  void setGcodeOffset({double x, double y, double z, int move}) {
    List<String> moves = [];
    if (x != null) moves.add("X_ADJUST=$x");
    if (y != null) moves.add("Y_ADJUST=$y");
    if (z != null) moves.add("Z_ADJUST=$z");

    String gcode = "SET_GCODE_OFFSET ${moves.join(" ")}";
    if (move != null) gcode += " MOVE=$move";

    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  void movePrintHead({x, y, z}) {
    List<String> moves = [];
    if (x != null) moves.add(_gcodeMoveCode("X", x));
    if (y != null) moves.add(_gcodeMoveCode("Y", y));
    if (z != null) moves.add(_gcodeMoveCode("Z", z));

    String gcode = "G91\n" + "G1 ${moves.join(" ")} F${100 * 60}\nG90";
    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  void moveExtruder(double length, [double feedRate = 5]) {
    String gcode = "M83\n" + "G1 E$length F${feedRate * 60}";
    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  void homePrintHead(Set<PrinterAxis> axis) {
    if (axis.contains(PrinterAxis.E)) {
      throw FormatException("E axis cant be homed");
    }
    String gcode = "G28 ";
    if (axis.length < 3) {
      gcode += axis.map(EnumToString.convertToString).join(" ");
    }

    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  void quadGantryLevel() {
    _webSocket.sendObject("printer.gcode.script", null,
        params: {'script': "QUAD_GANTRY_LEVEL"});
  }

  void bedMeshLevel() {
    _webSocket.sendObject("printer.gcode.script", null,
        params: {'script': "BED_MESH_CALIBRATE"});
  }

  void gCodeMacro(String macro) {
    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': macro});
  }

  void setTemperature(String heater, int target) {
    String gcode = "SET_HEATER_TEMPERATURE  HEATER=$heater TARGET=$target";

    _webSocket
        .sendObject("printer.gcode.script", null, params: {'script': gcode});
  }

  String _gcodeMoveCode(String axis, double value) {
    return "$axis${value <= 0 ? '' : '+'}${value.toStringAsFixed(2)}";
  }

  _onStatusUpdate(Map<String, dynamic> rawMessage) {
    Map<String, dynamic> params = rawMessage['params'][0];
    Printer latestPrinter = _getLatestPrinter();
    for (MapEntry<String, Function> listener in _statusUpdateListener) {
      if (params[listener.key] != null)
        listener.value(params[listener.key], printer: latestPrinter);
    }
    _printerStream.add(latestPrinter);
  }

  Printer _getLatestPrinter() {
    return _printerStream.hasValue ? _printerStream.value : new Printer();
  }

  _printerInfo(response) {
    Printer printer = _getLatestPrinter();
    logger.shout('PrinterInfo: $response');
    var fromString =
        EnumToString.fromString(PrinterState.values, response['state']);
    printer.state = fromString ?? PrinterState.error;
    _printerStream.add(printer);
  }

  _printerObjectsList(response) {
    Printer printer = _getLatestPrinter();
    logger.shout('PrinterObjList: $response');
    List<String> objects = response['objects'].cast<String>();

    if (objects != null)
      objects.forEach((element) {
        printer.queryableObjects.add(element);

        if (element.startsWith("gcode_macro ")) {
          String macro = element.split(" ")[1];
          if (!skipGCodes.contains(macro)) printer.gcodeMacros.add(macro);
        }
      });
    _printerStream.add(printer);

    _queryImportant(printer);
    _makeSubscribeRequest(printer);
  }

  _printerObjectsQuery(response) {
    Printer printer = _getLatestPrinter();
    logger.shout('PrinterObjectsQuery: $response');
    Map<String, dynamic> data = response['status'];
    if (data.containsKey('toolhead')) {
      var toolHeadJson = data['toolhead'];

      _updateToolhead(toolHeadJson, printer: printer);
    }

    if (data.containsKey('extruder')) {
      var extruderJson = data['extruder'];

      _updateExtruder(extruderJson, printer: printer);
    }

    if (data.containsKey('heater_bed')) {
      var heatedBedJson = data['heater_bed'];

      _updateHeaterBed(heatedBedJson, printer: printer);
    }

    if (data.containsKey('virtual_sdcard')) {
      var virtualSDJson = data['virtual_sdcard'];

      _updateVirtualSd(virtualSDJson, printer: printer);
    }

    if (data.containsKey('gcode_move')) {
      var gCodeJson = data['gcode_move'];

      _updateGCodeMove(gCodeJson, printer: printer);
    }

    if (data.containsKey('print_stats')) {
      var printStateJson = data['print_stats'];

      _updatePrintStat(printStateJson, printer: printer);
    }

    if (data.containsKey('configfile')) {
      var printConfigJson = data['configfile'];
      _updateConfigFile(printConfigJson, printer: printer);
    }

    if (data.containsKey('fan')) {
      var fanJson = data['fan'];
      if (fanJson.containsKey('speed'))
        printer.printFan.speed = fanJson['speed'];
    }

    var heaterFans =
        data.keys.where((element) => element.startsWith('heater_fan'));
    if (heaterFans.isNotEmpty) {
      for (var heaterFanName in heaterFans) {
        var fanJson = data[heaterFanName];
        List<String> split = heaterFanName.split(" ");
        String hName = split.length > 1 ? split[1] : split[0];

        HeaterFan heaterFan = printer.heaterFans.firstWhere(
            (element) => element.name == hName,
            orElse: () => new HeaterFan(hName));
        if (fanJson.containsKey('speed')) heaterFan.speed = fanJson['speed'];
        printer.heaterFans.add(heaterFan);
      }
    }
    _printerStream.add(printer);
  }

  void _updateGCodeMove(Map<String, dynamic> gCodeJson, {Printer printer}) {
    printer ??= _getLatestPrinter();
    if (gCodeJson.containsKey('speed_factor'))
      printer.gCodeMove.speedFactor = gCodeJson['speed_factor'];
    if (gCodeJson.containsKey('speed'))
      printer.gCodeMove.speed = gCodeJson['speed'];
    if (gCodeJson.containsKey('extrude_factor'))
      printer.gCodeMove.extrudeFactor = gCodeJson['extrude_factor'];
    if (gCodeJson.containsKey('absolute_coordinates'))
      printer.gCodeMove.absoluteCoordinates = gCodeJson['absolute_coordinates'];
    if (gCodeJson.containsKey('absolute_extrude'))
      printer.gCodeMove.absoluteExtrude = gCodeJson['absolute_extrude'];

    if (gCodeJson.containsKey('position')) {
      List<double> posJson = gCodeJson['position'].cast<double>();
      printer.gCodeMove.position = posJson;
    }
    if (gCodeJson.containsKey('homing_origin')) {
      List<double> posJson = gCodeJson['homing_origin'].cast<double>();
      printer.gCodeMove.homingOrigin = posJson;
    }
    if (gCodeJson.containsKey('gcode_position')) {
      List<double> posJson = gCodeJson['gcode_position'].cast<double>();
      printer.gCodeMove.gcodePosition = posJson;
    }
  }

  void _updateVirtualSd(Map<String, dynamic> virtualSDJson, {Printer printer}) {
    printer ??= _getLatestPrinter();
    if (virtualSDJson.containsKey('progress'))
      printer.virtualSdCard.progress = virtualSDJson['progress'];
    if (virtualSDJson.containsKey('is_active'))
      printer.virtualSdCard.isActive = virtualSDJson['is_active'];
    if (virtualSDJson.containsKey('file_position'))
      printer.virtualSdCard.filePosition = virtualSDJson['file_position'];
  }

  void _updatePrintStat(Map<String, dynamic> printStatJson, {Printer printer}) {
    printer ??= _getLatestPrinter();
    if (printStatJson.containsKey('state'))
      printer.print.state =
          EnumToString.fromString(PrintState.values, printStatJson['state']);
    if (printStatJson.containsKey('filename'))
      printer.print.filename = printStatJson['filename'];
    if (printStatJson.containsKey('total_duration'))
      printer.print.totalDuration = printStatJson['total_duration'];
    if (printStatJson.containsKey('print_duration'))
      printer.print.printDuration = printStatJson['print_duration'];
    if (printStatJson.containsKey('filament_used'))
      printer.print.filamentUsed = printStatJson['filament_used'];
    if (printStatJson.containsKey('message'))
      printer.print.message = printStatJson['message'];
  }

  void _updateConfigFile(Map<String, dynamic> printStatJson,
      {Printer printer}) {
    printer ??= _getLatestPrinter();

    if (printStatJson.containsKey('config'))
      printer.configFile.config = printStatJson['config'];
    if (printStatJson.containsKey('save_config_pending'))
      printer.configFile.saveConfigPending =
          printStatJson['save_config_pending'];
  }

  void _updateHeaterBed(Map<String, dynamic> heatedBedJson, {Printer printer}) {
    printer ??= _getLatestPrinter();
    if (heatedBedJson.containsKey('temperature'))
      printer.heaterBed.temperature = heatedBedJson['temperature'];
    if (heatedBedJson.containsKey('target'))
      printer.heaterBed.target = heatedBedJson['target'];
    if (heatedBedJson.containsKey('power'))
      printer.heaterBed.power = heatedBedJson['power'];
  }

  void _updateExtruder(Map<String, dynamic> extruderJson, {Printer printer}) {
    printer ??= _getLatestPrinter();
    if (extruderJson.containsKey('temperature'))
      printer.extruder.temperature = extruderJson['temperature'];
    if (extruderJson.containsKey('target'))
      printer.extruder.target = extruderJson['target'];
    if (extruderJson.containsKey('pressure_advance'))
      printer.extruder.pressureAdvance = extruderJson['pressure_advance'];
    if (extruderJson.containsKey('smooth_time'))
      printer.extruder.smoothTime = extruderJson['smooth_time'];
    if (extruderJson.containsKey('power'))
      printer.extruder.power = extruderJson['power'];
  }

  void _updateToolhead(Map<String, dynamic> toolHeadJson, {Printer printer}) {
    printer ??= _getLatestPrinter();
    if (toolHeadJson.containsKey('homed_axes')) {
      String hAxes = toolHeadJson['homed_axes'];
      Set<PrinterAxis> homed = {};
      hAxes.toUpperCase().split('').forEach(
          (e) => homed.add(EnumToString.fromString(PrinterAxis.values, e)));
      printer.toolhead.homedAxes = homed;
    }

    if (toolHeadJson.containsKey('position')) {
      List<double> posJson = toolHeadJson['position'].cast<double>();
      printer.toolhead.position = posJson;
    }
    if (toolHeadJson.containsKey('print_time'))
      printer.toolhead.printTime = toolHeadJson['print_time'];
    if (toolHeadJson.containsKey('max_velocity'))
      printer.toolhead.maxVelocity = toolHeadJson['max_velocity'];
    if (toolHeadJson.containsKey('max_accel'))
      printer.toolhead.maxAccel = toolHeadJson['max_accel'];
    if (toolHeadJson.containsKey('max_accel_to_decel'))
      printer.toolhead.maxAccelToDecel = toolHeadJson['max_accel_to_decel'];
    if (toolHeadJson.containsKey('extruder'))
      printer.toolhead.activeExtruder = toolHeadJson['extruder'];
    if (toolHeadJson.containsKey('square_corner_velocity'))
      printer.toolhead.squareCornerVelocity =
          toolHeadJson['square_corner_velocity'];
    if (toolHeadJson.containsKey('estimated_print_time'))
      printer.toolhead.estimatedPrintTime =
          toolHeadJson['estimated_print_time'];
  }

  _queryImportant(Printer printer) {
    Map<String, List<String>> queryObjects = new Map();
    printer.queryableObjects.forEach((element) {
      List<String> split = element.split(" ");

      if (subToPrinterObjects.contains(split[0])) queryObjects[element] = null;
    });

    _webSocket.sendObject("printer.objects.query", _printerObjectsQuery,
        params: {'objects': queryObjects});
  }

  _makeSubscribeRequest(Printer printer) {
    Map<String, List<String>> queryObjects = new Map();
    _addToSubParams(printer, queryObjects, 'toolhead', _updateToolhead);
    _addToSubParams(printer, queryObjects, 'extruder', _updateExtruder);
    _addToSubParams(printer, queryObjects, 'heater_bed', _updateHeaterBed);
    _addToSubParams(printer, queryObjects, 'configfile', _updateConfigFile);
    _addToSubParams(printer, queryObjects, 'gcode_move', _updateGCodeMove);
    _addToSubParams(printer, queryObjects, 'print_stats', _updatePrintStat);
    _addToSubParams(printer, queryObjects, 'virtual_sdcard', _updateVirtualSd);

    _webSocket.sendObject("printer.objects.subscribe", null,
        params: {'objects': queryObjects});
  }

  void _addToSubParams(Printer printer, Map<String, List<String>> queryObjects,
      String key, Function func) {
    if (printer.queryableObjects.contains(key)) {
      addStatusUpdateListener(func, key);
      queryObjects[key] =
          null; //Kinda dirty here since it has a SideEffect (queryObjects changes) but I am to lazy doing it another way rn :)
    }
  }
}
