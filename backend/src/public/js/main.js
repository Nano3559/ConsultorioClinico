document.addEventListener('DOMContentLoaded', function() {
  const navLinks = document.querySelectorAll('.navbar-nav .nav-link');
  const currentPath = window.location.pathname;
  
  navLinks.forEach(link => {
    if (link.getAttribute('href') === currentPath) {
      link.classList.add('active');
    }
  });

  const forms = document.querySelectorAll('form');
  forms.forEach(form => {
    form.addEventListener('submit', function(e) {
      const requiredFields = form.querySelectorAll('[required]');
      let isValid = true;
      
      requiredFields.forEach(field => {
        if (!field.value.trim()) {
          isValid = false;
          field.classList.add('is-invalid');
        } else {
          field.classList.remove('is-invalid');
        }
      });
      
      if (!isValid) {
        e.preventDefault();
      }
    });
  });

  const appointmentForm = document.querySelector('form[action="/cita"]');
  if (appointmentForm) {
    const fechaInput = appointmentForm.querySelector('input[name="fechaCita"]');
    if (fechaInput) {
      const today = new Date().toISOString().split('T')[0];
      fechaInput.setAttribute('min', today);
    }
  }

  const specialtySelect = document.querySelector('select[name="especialidad"]');
  const doctorSelect = document.querySelector('select[name="medico"]');
  
  if (specialtySelect && doctorSelect) {
    specialtySelect.addEventListener('change', function() {
      const selectedSpecialty = this.value;
      const options = doctorSelect.options;
      
      for (let i = 0; i < options.length; i++) {
        if (options[i].value && options[i].text.includes(selectedSpecialty)) {
          options[i].style.display = '';
        } else if (options[i].value) {
          options[i].style.display = 'none';
        }
      }
      
      if (selectedSpecialty) {
        doctorSelect.value = '';
      }
    });
  }

  const alertSuccess = document.querySelector('.alert-success');
  if (alertSuccess) {
    setTimeout(() => {
      alertSuccess.style.transition = 'opacity 0.5s';
      alertSuccess.style.opacity = '0';
      setTimeout(() => alertSuccess.remove(), 500);
    }, 5000);
  }
});
