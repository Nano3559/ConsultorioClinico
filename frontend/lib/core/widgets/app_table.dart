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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: const TableBorder(
          horizontalInside: BorderSide(color: AppColors.border, width: 0.8),
        ),
        columnWidths: {
          for (var i = 0; i < headers.length; i++) i: const FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF0FDFA), Color(0xFFE0F2FE)],
              ),
            ),
            children: [
              for (final h in headers)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    h,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 13),
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