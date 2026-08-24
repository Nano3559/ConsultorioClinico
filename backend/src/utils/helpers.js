const { DIAS_SEMANA } = require('./constants');

/**
 * Genera respuesta JSON estándar para la API
 */
const sendSuccess = (res, data = null, message = 'Operación exitosa', statusCode = 200) => {
  const response = { success: true, message };
  if (data !== null) response.data = data;
  return res.status(statusCode).json(response);
};

/**
 * Genera respuesta de error estándar
 */
const sendError = (res, message = 'Error interno', statusCode = 500, errors = null) => {
  const response = { success: false, message };
  if (errors) response.errors = errors;
  return res.status(statusCode).json(response);
};

/**
 * Genera ID auto-increment
 */
const nextId = (array) => {
  if (array.length === 0) return 1;
  return Math.max(...array.map((item) => item.id)) + 1;
};

/**
 * Valida si un string es un email válido
 */
const isValidEmail = (email) => {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
};

/**
 * Formatea una fecha a YYYY-MM-DD
 */
const formatDate = (date) => {
  const d = new Date(date);
  return d.toISOString().split('T')[0];
};

/**
 * Normaliza texto para comparaciones insensibles a mayúsculas y tildes
 */
const normalizarTexto = (texto) =>
  String(texto).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

/**
 * Devuelve el día de la semana (Lunes..Domingo) de una fecha YYYY-MM-DD
 */
const obtenerDiaSemana = (fecha) => {
  const d = new Date(`${fecha}T12:00:00`);
  return DIAS_SEMANA[(d.getDay() + 6) % 7];
};

/**
 * Convierte una hora HH:MM a minutos desde medianoche
 */
const horaAMinutos = (hora) => {
  const [h, m] = hora.split(':').map(Number);
  return h * 60 + m;
};

/**
 * Convierte minutos desde medianoche a hora HH:MM
 */
const minutosAHora = (minutos) => {
  const h = String(Math.floor(minutos / 60)).padStart(2, '0');
  const m = String(minutos % 60).padStart(2, '0');
  return `${h}:${m}`;
};

module.exports = {
  sendSuccess,
  sendError,
  nextId,
  isValidEmail,
  formatDate,
  normalizarTexto,
  obtenerDiaSemana,
  horaAMinutos,
  minutosAHora,
};
