import 'package:flutter/cupertino.dart';
import 'package:patch_maker/patch_maker/patch_maker_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: '微软雅黑',
            color: CupertinoColors.black,
          ),
        ),
      ),
      home: PatchMakerWidget(),
    );
  }
}
