/**
 * Rate limiter ligero en memoria para proteger endpoints sensibles
 * (login, registro) contra fuerza bruta.
 *
 * LIMITACIÓN CONOCIDA (serverless / Vercel):
 * Al estar en memoria, el límite se aplica por instancia. En un entorno
 * serverless cada invocación (o conjunto) puede ejecutarse en una instancia
 * distinta, por lo que un atacante que distribuya sus intentos entre
 * instancias podría eludir el límite.
 *
 * Es ACEPTABLE para controlar ataques básicos de fuerza bruta de un solo
 * nodo. Para producción con escalado horizontal se recomienda reemplazarlo
 * por un limitador distribuido que comparta el contador entre instancias:
 *   - Tabla SQL (Supabase/Postgres): intentos_acceso ya guarda por
 *     ip_address; se puede consultar el conteo reciente para bloquear.
 *   - Servicio externo: Upstash Redis, Cloudflare Rate Limiting, etc.
 *
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