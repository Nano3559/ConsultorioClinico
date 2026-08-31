/**
 * Rate limiter ligero en memoria para proteger endpoints sensibles
 * (login, registro) contra fuerza bruta.
 *
 * Nota para Vercel/serverless: al ser en memoria, el límite se aplica por
 * instancia. Aun así reduce notablemente el riesgo de ataques básicos.
 * La cabecera x-forwarded-for permite detectar la IP real detrás de proxies.
 */

const ventanas = new Map();

function obtenerIp(req) {
  const fwd = req.headers['x-forwarded-for'];
  if (fwd) return String(fwd).split(',')[0].trim();
  return req.ip || req.socket?.remoteAddress || 'desconocida';
}

function limpiarVentanasViejas(ahora) {
  for (const [key, ventana] of ventanas) {
    if (ventana.resetEn <= ahora) ventanas.delete(key);
  }
}

/**
 * Crea un middleware rate limiter.
 * @param {object} opciones
 * @param {number} opciones.max - Número máximo de peticiones permitidas
 * @param {number} opciones.windowMs - Ventana de tiempo en milisegundos
 * @param {string} opciones.mensaje - Mensaje al exceder el límite
 */
function rateLimit({ max = 20, windowMs = 15 * 60 * 1000, mensaje = 'Demasiadas peticiones. Intente más tarde' } = {}) {
  return (req, res, next) => {
    const ip = obtenerIp(req);
    const clave = `${req.method}:${req.baseUrl}${req.path}:${ip}`;
    const ahora = Date.now();

    limpiarVentanasViejas(ahora);

    const ventana = ventanas.get(clave);
    if (!ventana || ventana.resetEn <= ahora) {
      ventanas.set(clave, { count: 1, resetEn: ahora + windowMs });
      res.setHeader('X-RateLimit-Limit', max);
      res.setHeader('X-RateLimit-Remaining', max - 1);
      return next();
    }

    if (ventana.count >= max) {
      res.setHeader('Retry-After', Math.ceil((ventana.resetEn - ahora) / 1000));
      return res.status(429).json({
        success: false,
        message: mensaje,
      });
    }

    ventana.count += 1;
    res.setHeader('X-RateLimit-Limit', max);
    res.setHeader('X-RateLimit-Remaining', max - ventana.count);
    next();
  };
}

module.exports = { rateLimit };