import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Tabla estándar para el modo web del sistema interno.
/// Se usa solo en pantallas anchas; en móvil las páginas usan tarjetas.
class AppTable extends StatelessWidget {
  const AppTable({super.key, required this.headers, required this.rows});

  final List<String> headers;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: const TableBorder(horizontalInside: BorderSide(color: AppColors.border)),
        columnWidths: {
          for (var i = 0; i < headers.length; i++) i: const FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.background),
            children: [
              for (final h in headers)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    h,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark, fontSize: 13),
                  ),
                ),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                for (final cell in row)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: cell,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Texto de celda con elisión para no desbordar la columna.
class TableText extends StatelessWidget {
  const TableText(this.text, {super.key, this.bold = false});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.dark,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}