// Minimal script for navigation scroll effect
// Using vanilla JS to keep it simple and Rails-friendly

document.addEventListener('DOMContentLoaded', function() {
  const nav = document.getElementById('main-nav');
  if (!nav) return;
  
  window.addEventListener('scroll', function() {
    if (window.pageYOffset > 50) {
      nav.classList.add('scrolled');
    } else {
      nav.classList.remove('scrolled');
    }
  }, { passive: true });
});
