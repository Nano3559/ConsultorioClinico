import 'package:flutter/material.dart';

/// Métodos de pago aceptados.
enum PaymentMethod {
  efectivo('Efectivo', Icons.payments_outlined),
  qr('QR', Icons.qr_code_outlined),
  transferencia('Transferencia', Icons.account_balance_outlined),
  tarjeta('Tarjeta', Icons.credit_card_outlined);

  const PaymentMethod(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Estados de un pago.
enum PaymentStatus {
  pagado('Pagado', Color(0xFF16A34A), Color(0xFFDCFCE7)),
  pendiente('Pendiente', Color(0xFFD97706), Color(0xFFFEF3C7)),
  anulado('Anulado', Color(0xFFDC2626), Color(0xFFFEE2E2));

  const PaymentStatus(this.label, this.color, this.bg);
  final String label;
  final Color color;
  final Color bg;

  String toApi() {
    switch (this) {
      case PaymentStatus.pagado:
        return 'pagado';
      case PaymentStatus.pendiente:
        return 'pendiente';
      case PaymentStatus.anulado:
        return 'cancelado';
    }
  }

  static PaymentStatus fromApi(String? value) {
    switch (value) {
      case 'pagado':
        return PaymentStatus.pagado;
      case 'pendiente':
        return PaymentStatus.pendiente;
      case 'cancelado':
        return PaymentStatus.anulado;
      default:
        return PaymentStatus.pendiente;
    }
  }
}

extension PaymentMethodApi on PaymentMethod {
  String toApi() {
    switch (this) {
      case PaymentMethod.efectivo:
        return 'efectivo';
      case PaymentMethod.tarjeta:
        return 'tarjeta';
      case PaymentMethod.transferencia:
        return 'transferencia';
      case PaymentMethod.qr:
        return 'otro';
    }
  }

  static PaymentMethod fromApi(String? value) {
    switch (value) {
      case 'tarjeta':
        return PaymentMethod.tarjeta;
      case 'transferencia':
        return PaymentMethod.transferencia;
      case 'efectivo':
        return PaymentMethod.efectivo;
      default:
        return PaymentMethod.efectivo;
    }
  }
}

/// Registro de pago de una consulta.
class Payment {
  const Payment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.appointmentId,
    required this.amount,
    required this.date,
    required this.method,
    required this.status,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final String appointmentId;
  final double amount;
  final DateTime date;
  final PaymentMethod method;
  final PaymentStatus status;

  /// Construye un Payment desde la fila de Supabase.
  factory Payment.fromApi(Map<String, dynamic> json) {
    final monto = json['monto'];
    final fecha = json['fecha_pago'] ?? json['creado_en'];
    return Payment(
      id: json['id'].toString(),
      patientId: json['paciente_id'].toString(),
      doctorId: '',
      appointmentId: (json['cita_id'] ?? '').toString(),
      amount: monto is num ? monto.toDouble() : double.tryParse(monto?.toString() ?? '') ?? 0,
      date: fecha is DateTime
          ? fecha
          : DateTime.tryParse(fecha?.toString() ?? '') ?? DateTime.now(),
      method: PaymentMethodApi.fromApi(json['metodo_pago']),
      status: PaymentStatus.fromApi(json['estado']),
    );
  }

  Payment copyWith({PaymentStatus? status, PaymentMethod? method}) {
    return Payment(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      appointmentId: appointmentId,
      amount: amount,
      date: date,
      method: method ?? this.method,
      status: status ?? this.status,
    );
  }
}