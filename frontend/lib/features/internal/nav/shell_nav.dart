import 'package:flutter/widgets.dart';

/// Permite que una vista interna (p. ej. el panel del médico) cambie de módulo
/// dentro del shell actual, sin abandonar la vista `/app`.
class ShellNav extends InheritedWidget {
  const ShellNav({
    super.key,
    required this.onSelect,
    required super.child,
  });

  /// Callback que recibe la clave del [NavModule] a mostrar.
  final void Function(String moduleKey) onSelect;

  /// Cambia de módulo si el shell lo tiene disponible; si no, no hace nada.
  static void select(BuildContext context, String moduleKey) {
    context
        .dependOnInheritedWidgetOfExactType<ShellNav>()
        ?.onSelect(moduleKey);
  }

  @override
  bool updateShouldNotify(ShellNav oldWidget) => onSelect != oldWidget.onSelect;
}
