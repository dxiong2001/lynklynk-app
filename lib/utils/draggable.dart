import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:window_manager/window_manager.dart';

class DraggebleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Brightness brightness;
  final Color backgroundColor;

  const DraggebleAppBar({
    super.key,
    required this.title,
    required this.brightness,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        getAppBarTitle(title),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            height: kToolbarHeight,
            width: 200,
            child: WindowCaption(
              backgroundColor: backgroundColor,
              brightness: brightness,
            ),
          ),
        )
      ],
    );
  }

  Widget getAppBarTitle(String title) {
    if (UniversalPlatform.isWeb) {
      return Align(
        alignment: AlignmentDirectional.center,
        child: Text(title),
      );
    } else {
      return DragToMoveArea(
        child: SizedBox(
          height: kToolbarHeight,
          child: Align(
            alignment: AlignmentDirectional.center,
            child: Text(title),
          ),
        ),
      );
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
