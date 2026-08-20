const ROLES = {
  ADMIN: 'admin',
  MEDICO: 'medico',
  RECEPCION: 'recepcion',
  PACIENTE: 'paciente',
};

const ESTADOS_CITA = {
  PROGRAMADA: 'programada',
  EN_CURSO: 'en_curso',
  COMPLETADA: 'completada',
  CANCELADA: 'cancelada',
  NO_SHOW: 'no_show',
};

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
  METODOS_PAGO,
  ESTADOS_PAGO,
  DIAS_SEMANA,
};
