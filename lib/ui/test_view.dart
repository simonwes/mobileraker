import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

class TestView extends StatelessWidget {
  const TestView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TestViewModel>.reactive(
      builder: (context, model, child) => Scaffold(
        appBar: AppBar(
          title: Text("Example player"),
        ),
        // body: Mjpeg(
        //   stream: 'http://192.168.178.135/webcam/?action=stream',
        // )

        // AspectRatio(
        //   aspectRatio: 16 / 9,
        //   child: BetterPlayer.network(
        //     "http://192.168.178.135/webcam/?action=stream",
        //     betterPlayerConfiguration: BetterPlayerConfiguration(
        //       aspectRatio: 16 / 9,
        //     ),
        //   ),
        // ),
      ),
      viewModelBuilder: () => TestViewModel(),
    );
  }
}

class TestViewModel extends BaseViewModel {}
