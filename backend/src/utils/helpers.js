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

module.exports = {
  sendSuccess,
  sendError,
  nextId,
  isValidEmail,
  formatDate,
};
