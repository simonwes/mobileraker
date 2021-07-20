import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/WebSocket.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';
import 'connectionState_viewmodel.dart';

class ConnectionStateView extends StatelessWidget {
  ConnectionStateView({required this.pChild, Key? key}) : super(key: key);

  final Widget pChild;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<ConnectionStateViewModel>.reactive(
      builder: (context, model, child) {
        switch (model.connectionState) {
          case WebSocketState.connected:
            return pChild;

          case WebSocketState.disconnected:
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Icon(Icons.warning_amber_outlined),
              SizedBox(
                height: 30,
              ),
              Text(
                  "Error while trying to connect. Please retry later."),
              TextButton.icon(
                  onPressed: model.onRetryPressed,
                  icon: Icon(Icons.stream),
                  label: Text("Reconnect"))
                ],
              ),
            );
          case WebSocketState.connecting:
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitPouringHourglass(
                    color: Theme.of(context).accentColor,
                  ),
                  SizedBox(
                    height: 30,
                  ),
                  FadingText("Trying to connect ..."),
                ],
              ),
            );
          case WebSocketState.error:
          default:
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Icon(Icons.warning_amber_outlined),
              SizedBox(
                height: 30,
              ),
              Text(
                  "Error while trying to connect. Please retry later."),
              TextButton.icon(
                  onPressed: model.onRetryPressed,
                  icon: Icon(Icons.stream),
                  label: Text("Reconnect"))
                ],
              ),
            );
        }
      },
      viewModelBuilder: () => ConnectionStateViewModel(),
    );
  }
}
