const ROLES = {
  ADMIN: 'admin',
  MEDICO: 'medico',
  RECEPCION: 'recepcion',
  PACIENTE: 'paciente',
};

const ESTADOS_CITA = {
  PENDIENTE: 'pendiente',
  CONFIRMADA: 'confirmada',
  ATENDIDA: 'atendida',
  CANCELADA: 'cancelada',
  NO_ASISTIO: 'no_asistio',
};

// Duración de cada turno al generar los slots de disponibilidad (minutos)
const INTERVALO_CITA_MINUTOS = 30;

const METODOS_PAGO = {
  EFECTIVO: 'efectivo',
  TARJETA: 'tarjeta',
  TRANSFERENCIA: 'transferencia',
  OTRO: 'otro',
};

const ESTADOS_PAGO = {
  PENDIENTE: 'pendiente',
  PAGADO: 'pagado',
  CANCELADO: 'cancelado',
};

const DIAS_SEMANA = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

module.exports = {
  ROLES,
  ESTADOS_CITA,
  INTERVALO_CITA_MINUTOS,
  METODOS_PAGO,
  ESTADOS_PAGO,
  DIAS_SEMANA,
};
