import '../configs/configs.dart';

/// An ElevatedButton that plays a sound when clicked
class ElevatedButtonWithSound extends StatelessWidget {
  final Widget? child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final String? soundPath;
  final MaterialStatesController? statesController;

  const ElevatedButtonWithSound({
    Key? key,
    required this.onPressed,
    this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.soundPath,
    this.statesController,
  }) : super(key: key);

  /// Create an elevated button with an icon and a label as its [child].
  factory ElevatedButtonWithSound.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    String? soundPath,
    MaterialStatesController? statesController,
  }) {
    return ElevatedButtonWithSound(
      key: key,
      onPressed: onPressed,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      soundPath: soundPath,
      statesController: statesController,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(width: 8.0), label],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed:
          onPressed == null
              ? null
              : () async {
                await AudioManager().playSound(soundPath: soundPath);
                onPressed!();
              },
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child ?? const SizedBox(),
    );
  }
}

/// A TextButton that plays a sound when clicked
class TextButtonWithSound extends StatelessWidget {
  final Widget? child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;
  final String? soundPath;
  final MaterialStatesController? statesController;

  const TextButtonWithSound({
    Key? key,
    required this.onPressed,
    this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
    this.soundPath,
    this.statesController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed:
          onPressed == null
              ? null
              : () async {
                await AudioManager().playSound(soundPath: soundPath);
                onPressed!();
              },
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child ?? const SizedBox(),
    );
  }
}
