const ROLES = {
  ADMIN: 'admin',
  MEDICO: 'medico',
  RECEPCION: 'recepcion',
  PACIENTE: 'paciente',
};

// Debe coincidir con el CHECK de la columna citas.estado en la BD:
// ('programada', 'confirmada', 'en_curso', 'completada', 'cancelada', 'no_show')
const ESTADOS_CITA = {
  PROGRAMADA: 'programada',
  CONFIRMADA: 'confirmada',
  EN_CURSO: 'en_curso',
  COMPLETADA: 'completada',
  CANCELADA: 'cancelada',
  NO_SHOW: 'no_show',
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
