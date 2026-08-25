const especialidades = [
  {
    id: 1,
    nombre: 'Medicina General',
    imagen: '/images/medicina-general.jpg',
    descripcion: 'Atención médica integral para pacientes de todas las edades. Diagnóstico y tratamiento de enfermedades comunes, chequeos preventivos y seguimiento de pacientes crónicos.',
    medico: 'Dr. Carlos Mendoza',
    horarios: 'Lunes a Viernes: 8:00 - 17:00',
    icono: 'bi-heart-pulse'
  },
  {
    id: 2,
    nombre: 'Pediatría',
    imagen: '/images/pediatria.jpg',
    descripcion: 'Cuidado especializado para niños y adolescentes. Vacunas, control de crecimiento, desarrollo infantil y tratamiento de enfermedades pediátricas.',
    medico: 'Dra. María García',
    horarios: 'Lunes a Viernes: 9:00 - 16:00',
    icono: 'bi-emoji-smile'
  },
  {
    id: 3,
    nombre: 'Ginecología',
    imagen: '/images/ginecologia.jpg',
    descripcion: 'Atención integral de la salud femenina. Control prenatal, planificación familiar, chequeos ginecológicos y tratamiento de patologías.',
    medico: 'Dra. Ana López',
    horarios: 'Lunes, Miércoles, Viernes: 8:00 - 15:00',
    icono: 'bi-gender-female'
  },
  {
    id: 4,
    nombre: 'Cardiología',
    imagen: '/images/cardiologia.jpg',
    descripcion: 'Diagnóstico y tratamiento de enfermedades del corazón. Electrocardiogramas, ecocardiogramas, pruebas de esfuerzo y seguimiento cardiológico.',
    medico: 'Dr. Roberto Sánchez',
    horarios: 'Martes y Jueves: 10:00 - 18:00',
    icono: 'bi-heart'
  },
  {
    id: 5,
    nombre: 'Dermatología',
    imagen: '/images/dermatologia.jpg',
    descripcion: 'Tratamiento de enfermedades de la piel, cabello y uñas. Acné, eccemas, alergias cutáneas, láser dermatológico y procedimientos estéticos.',
    medico: 'Dra. Laura Martínez',
    horarios: 'Miércoles y Viernes: 9:00 - 14:00',
    icono: 'bi-bandaid'
  },
  {
    id: 6,
    nombre: 'Odontología',
    imagen: '/images/odontologia.jpg',
    descripcion: 'Salud bucal integral. Limpiezas, empastes, extracciones, ortodoncia, blanqueamiento y cirugía oral.',
    medico: 'Dr. Fernando Ruiz',
    horarios: 'Lunes a Viernes: 8:00 - 17:00',
    icono: 'bi-emoji-laughing'
  }
];

const medicos = [
  {
    id: 1,
    nombre: 'Dr. Carlos Mendoza',
    especialidad: 'Medicina General',
    imagen: '/images/medico-1.jpg',
    descripcion: 'Médico general con amplia experiencia en atención primaria. Especialista en medicina familiar y preventiva.',
    horarios: 'Lunes a Viernes: 8:00 - 17:00',
    experiencia: '15 años',
    formacion: 'Universidad Central - Medicina General'
  },
  {
    id: 2,
    nombre: 'Dra. María García',
    especialidad: 'Pediatría',
    imagen: '/images/medico-2.jpg',
    descripcion: 'Pediatra certificada con enfoque en desarrollo infantil y vacunación. Cariñosa y dedicada con los más pequeños.',
    horarios: 'Lunes a Viernes: 9:00 - 16:00',
    experiencia: '12 años',
    formacion: 'Universidad Nacional - Pediatría'
  },
  {
    id: 3,
    nombre: 'Dra. Ana López',
    especialidad: 'Ginecología',
    imagen: '/images/medico-3.jpg',
    descripcion: 'Ginecóloga obstetra con experiencia en alto riesgo. Comprometida con la salud femenina.',
    horarios: 'Lunes, Miércoles, Viernes: 8:00 - 15:00',
    experiencia: '18 años',
    formacion: 'Universidad Médica - Ginecología'
  },
  {
    id: 4,
    nombre: 'Dr. Roberto Sánchez',
    especialidad: 'Cardiología',
    imagen: '/images/medico-4.jpg',
    descripcion: 'Cardiólogo intervencionista con fellowship en cardiología intervencionista. Experto en prevención cardiovascular.',
    horarios: 'Martes y Jueves: 10:00 - 18:00',
    experiencia: '20 años',
    formacion: 'Instituto Cardiovascular - Cardiología'
  },
  {
    id: 5,
    nombre: 'Dra. Laura Martínez',
    especialidad: 'Dermatología',
    imagen: '/images/medico-5.jpg',
    descripcion: 'Dermatóloga certificada con especialización en dermatología estética y láser.',
    horarios: 'Miércoles y Viernes: 9:00 - 14:00',
    experiencia: '10 años',
    formacion: 'Universidad Dermatológica - Dermatología'
  },
  {
    id: 6,
    nombre: 'Dr. Fernando Ruiz',
    especialidad: 'Odontología',
    imagen: '/images/medico-6.jpg',
    descripcion: 'Odontólogo general con especialización en implantes y cirugía oral. Tecnología de vanguardia.',
    horarios: 'Lunes a Viernes: 8:00 - 17:00',
    experiencia: '14 años',
    formacion: 'Universidad Odontológica - Odontología'
  }
];

const servicios = [
  { id: 1, nombre: 'Consulta General', descripcion: 'Atención médica integral para adultos y niños', precio: '$30' },
  { id: 2, nombre: 'Control Prenatal', descripcion: 'Seguimiento del embarazo con ecografías', precio: '$50' },
  { id: 3, nombre: 'Chequeo Preventivo', descripcion: 'Exámenes médicos completos anuales', precio: '$80' },
  { id: 4, nombre: 'Laboratorio Clínico', descripcion: 'Análisis de sangre, orina y otros estudios', precio: 'Desde $15' },
  { id: 5, nombre: 'Ecografía', descripcion: 'Estudios por imagen de alta resolución', precio: '$45' },
  { id: 6, nombre: 'Vacunación', descripcion: 'Aplicación de vacunas para todas las edades', precio: 'Desde $10' },
  { id: 7, nombre: 'Electrocardiograma', descripcion: 'Registro de la actividad eléctrica del corazón', precio: '$25' },
  { id: 8, nombre: 'Limpieza Dental', descripcion: 'Profilaxis y limpieza dental profesional', precio: '$35' },
  { id: 9, nombre: 'Blanqueamiento Dental', descripcion: 'Blanqueamiento dental de vanguardia', precio: '$120' },
  { id: 10, nombre: 'Dermatología Estética', descripcion: 'Tratamientos faciales y corporales', precio: 'Desde $60' },
  { id: 11, nombre: 'Urgencias', descripcion: 'Atención de emergencias médicas 24/7', precio: 'Según caso' },
  { id: 12, nombre: 'Nutrición', descripcion: 'Planes alimentarios personalizados', precio: '$40' }
];

const horarios = [
  { dia: 'Lunes', medico: 'Dr. Carlos Mendoza', especialidad: 'Medicina General', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Lunes', medico: 'Dra. María García', especialidad: 'Pediatría', horaInicio: '09:00', horaFin: '16:00' },
  { dia: 'Lunes', medico: 'Dra. Ana López', especialidad: 'Ginecología', horaInicio: '08:00', horaFin: '15:00' },
  { dia: 'Lunes', medico: 'Dr. Fernando Ruiz', especialidad: 'Odontología', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Martes', medico: 'Dr. Carlos Mendoza', especialidad: 'Medicina General', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Martes', medico: 'Dr. Roberto Sánchez', especialidad: 'Cardiología', horaInicio: '10:00', horaFin: '18:00' },
  { dia: 'Martes', medico: 'Dr. Fernando Ruiz', especialidad: 'Odontología', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Miércoles', medico: 'Dr. Carlos Mendoza', especialidad: 'Medicina General', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Miércoles', medico: 'Dra. María García', especialidad: 'Pediatría', horaInicio: '09:00', horaFin: '16:00' },
  { dia: 'Miércoles', medico: 'Dra. Ana López', especialidad: 'Ginecología', horaInicio: '08:00', horaFin: '15:00' },
  { dia: 'Miércoles', medico: 'Dra. Laura Martínez', especialidad: 'Dermatología', horaInicio: '09:00', horaFin: '14:00' },
  { dia: 'Miércoles', medico: 'Dr. Fernando Ruiz', especialidad: 'Odontología', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Jueves', medico: 'Dr. Carlos Mendoza', especialidad: 'Medicina General', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Jueves', medico: 'Dr. Roberto Sánchez', especialidad: 'Cardiología', horaInicio: '10:00', horaFin: '18:00' },
  { dia: 'Jueves', medico: 'Dr. Fernando Ruiz', especialidad: 'Odontología', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Viernes', medico: 'Dr. Carlos Mendoza', especialidad: 'Medicina General', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Viernes', medico: 'Dra. María García', especialidad: 'Pediatría', horaInicio: '09:00', horaFin: '16:00' },
  { dia: 'Viernes', medico: 'Dra. Ana López', especialidad: 'Ginecología', horaInicio: '08:00', horaFin: '15:00' },
  { dia: 'Viernes', medico: 'Dra. Laura Martínez', especialidad: 'Dermatología', horaInicio: '09:00', horaFin: '14:00' },
  { dia: 'Viernes', medico: 'Dr. Fernando Ruiz', especialidad: 'Odontología', horaInicio: '08:00', horaFin: '17:00' },
  { dia: 'Sábado', medico: 'Dr. Carlos Mendoza', especialidad: 'Medicina General', horaInicio: '08:00', horaFin: '13:00' },
  { dia: 'Sábado', medico: 'Dr. Fernando Ruiz', especialidad: 'Odontología', horaInicio: '08:00', horaFin: '13:00' }
];

const contacto = {
  direccion: 'Av. Principal #123, Centro Médico Plaza, Piso 3',
  telefono: '+593 99 123 4567',
  whatsapp: '+593 99 123 4567',
  email: 'info@medicore.com',
  horariosGenerales: 'Lunes a Viernes: 8:00 - 17:00 | Sábados: 8:00 - 13:00',
  redes: {
    facebook: '#',
    instagram: '#',
    twitter: '#'
  }
};

exports.index = (req, res) => {
  res.render('index', { especialidades: especialidades.slice(0, 3), medicos: medicos.slice(0, 3), contacto });
};

exports.nosotros = (req, res) => {
  res.render('nosotros', { contacto });
};

exports.especialidades = (req, res) => {
  res.render('especialidades', { especialidades, contacto });
};

exports.medicos = (req, res) => {
  res.render('medicos', { medicos, contacto });
};

exports.servicios = (req, res) => {
  res.render('servicios', { servicios, contacto });
};

exports.horarios = (req, res) => {
  res.render('horarios', { horarios, contacto });
};

exports.cita = (req, res) => {
  res.render('cita', { especialidades, medicos, contacto, success: null });
};

exports.citaPost = (req, res) => {
  console.log('Cita solicitada:', req.body);
  res.render('cita', { especialidades, medicos, contacto, success: '¡Cita solicitada exitosamente! Nos contactaremos pronto para confirmar.' });
};

exports.contactoPage = (req, res) => {
  res.render('contacto', { contacto, success: null });
};

exports.contactoPost = (req, res) => {
  console.log('Mensaje de contacto:', req.body);
  res.render('contacto', { contacto, success: '¡Mensaje enviado exitosamente! Le responderemos pronto.' });
};

exports.login = (req, res) => {
  res.render('login', { error: null });
};

exports.loginPost = (req, res) => {
  console.log('Intento de login:', req.body);
  res.render('login', { error: 'Credenciales incorrectas. Intente de nuevo.' });
};
