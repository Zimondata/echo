// Telegram Auth Handler
function onTelegramAuth(user) {
    console.log('Telegram auth:', user);
    
    // Отправляем данные на сервер
    fetch('/telegram_auth', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(user)
    })
    .then(response => response.json())
    .then(data => {
        if (data.status === 'success') {
            // Показываем успешное уведомление
            showNotification('Добро пожаловать в Echo! Перенаправляем...', 'success');
            
            // Перенаправляем на дашборд через 2 секунды
            setTimeout(() => {
                window.location.href = data.redirect;
            }, 2000);
        } else {
            showNotification('Ошибка входа. Попробуйте ещё раз.', 'error');
        }
    })
    .catch(error => {
        console.error('Auth error:', error);
        showNotification('Ошибка входа. Попробуйте ещё раз.', 'error');
    });
}

// Notification System
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <div class="notification-content">
            <span class="notification-icon">${type === 'success' ? '✅' : '❌'}</span>
            <span class="notification-message">${message}</span>
        </div>
    `;
    
    document.body.appendChild(notification);
    
    // Показываем с анимацией
    setTimeout(() => {
        notification.classList.add('show');
    }, 100);
    
    // Убираем через 4 секунды
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 4000);
}

// Smooth scroll functions
function scrollToDemo() {
    document.querySelector('.how-it-works').scrollIntoView({ 
        behavior: 'smooth' 
    });
}

function scrollToAuth() {
    document.querySelector('.final-cta').scrollIntoView({ 
        behavior: 'smooth' 
    });
}

// Intersection Observer for animations
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('animate-in');
        }
    });
}, observerOptions);

// Mobile Menu Controller
class MobileMenu {
    constructor() {
        this.button = document.getElementById('mobile-menu-btn');
        this.menu = document.getElementById('mobile-menu');
        this.isOpen = false;
        
        if (this.button && this.menu) {
            this.init();
        }
    }
    
    init() {
        this.button.addEventListener('click', () => this.toggle());
        
        // Close menu when clicking on links
        this.menu.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => this.close());
        });
        
        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!this.button.contains(e.target) && !this.menu.contains(e.target)) {
                this.close();
            }
        });
    }
    
    toggle() {
        this.isOpen ? this.close() : this.open();
    }
    
    open() {
        this.isOpen = true;
        this.menu.style.transform = 'translateY(0)';
        this.menu.style.opacity = '1';
        this.menu.style.pointerEvents = 'auto';
        
        // Change hamburger to X
        this.button.innerHTML = `
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
        `;
    }
    
    close() {
        this.isOpen = false;
        this.menu.style.transform = 'translateY(-100%)';
        this.menu.style.opacity = '0';
        this.menu.style.pointerEvents = 'none';
        
        // Change X back to hamburger
        this.button.innerHTML = `
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
            </svg>
        `;
    }
}

// Observe elements when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Initialize interactive components
    new InteractiveBackground();
    new FloatingCards();
    new MobileMenu();
    
    // Animate on scroll
    const animateElements = document.querySelectorAll('.feature-card, .step, .insight-card, .workflow-header, .workflow-step, .workflow-cta');
    animateElements.forEach(el => {
        observer.observe(el);
    });
    
    // Add initial animation classes
    const heroElements = document.querySelectorAll('.hero-title, .hero-subtitle, .hero-cta');
    heroElements.forEach((el, index) => {
        setTimeout(() => {
            el.classList.add('fade-in');
        }, index * 200);
    });
    
    // Navbar scroll effect
    window.addEventListener('scroll', () => {
        const navbar = document.getElementById('main-nav');
        if (!navbar) return;
        
        const scrollY = window.scrollY;
        
        if (scrollY > 50) {
            navbar.style.backgroundColor = 'rgba(15, 23, 42, 0.95)';
            navbar.style.borderBottomColor = 'rgba(71, 85, 105, 0.7)';
            navbar.style.boxShadow = '0 4px 6px -1px rgba(0, 0, 0, 0.1)';
        } else {
            navbar.style.backgroundColor = 'rgba(15, 23, 42, 0.8)';
            navbar.style.borderBottomColor = 'rgba(71, 85, 105, 0.5)';
            navbar.style.boxShadow = 'none';
        }
    });
    
    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
});

// Interactive Background Canvas
class InteractiveBackground {
    constructor() {
        this.canvas = document.getElementById('hero-canvas');
        if (!this.canvas) return;
        
        this.ctx = this.canvas.getContext('2d');
        this.dots = [];
        this.mouse = { x: null, y: null };
        
        this.init();
        this.bindEvents();
        this.animate();
    }
    
    init() {
        this.resize();
        this.createDots();
    }
    
    resize() {
        const container = this.canvas.parentElement;
        this.canvas.width = container.clientWidth;
        this.canvas.height = container.clientHeight;
    }
    
    createDots() {
        this.dots = [];
        const spacing = 30;
        const cols = Math.ceil(this.canvas.width / spacing);
        const rows = Math.ceil(this.canvas.height / spacing);
        
        for (let i = 0; i < cols; i++) {
            for (let j = 0; j < rows; j++) {
                this.dots.push({
                    x: i * spacing + spacing / 2,
                    y: j * spacing + spacing / 2,
                    baseRadius: 1,
                    currentRadius: 1,
                    baseOpacity: Math.random() * 0.3 + 0.2,
                    currentOpacity: Math.random() * 0.3 + 0.2,
                    targetOpacity: Math.random() * 0.5 + 0.3,
                    opacitySpeed: (Math.random() * 0.01) + 0.005
                });
            }
        }
    }
    
    bindEvents() {
        window.addEventListener('resize', () => {
            this.resize();
            this.createDots();
        });
        
        this.canvas.addEventListener('mousemove', (e) => {
            const rect = this.canvas.getBoundingClientRect();
            this.mouse.x = e.clientX - rect.left;
            this.mouse.y = e.clientY - rect.top;
        });
        
        this.canvas.addEventListener('mouseleave', () => {
            this.mouse.x = null;
            this.mouse.y = null;
        });
    }
    
    animate() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        
        this.dots.forEach(dot => {
            // Animate opacity
            dot.currentOpacity += dot.opacitySpeed;
            if (dot.currentOpacity >= dot.targetOpacity || dot.currentOpacity <= 0.1) {
                dot.opacitySpeed = -dot.opacitySpeed;
                dot.targetOpacity = Math.random() * 0.5 + 0.3;
            }
            
            // Mouse interaction
            let interactionFactor = 0;
            if (this.mouse.x !== null && this.mouse.y !== null) {
                const dx = dot.x - this.mouse.x;
                const dy = dot.y - this.mouse.y;
                const distance = Math.sqrt(dx * dx + dy * dy);
                const maxDistance = 100;
                
                if (distance < maxDistance) {
                    interactionFactor = (maxDistance - distance) / maxDistance;
                }
            }
            
            // Update properties
            const finalOpacity = Math.min(1, dot.currentOpacity + interactionFactor * 0.6);
            dot.currentRadius = dot.baseRadius + interactionFactor * 3;
            
            // Draw dot
            this.ctx.beginPath();
            this.ctx.fillStyle = `rgba(16, 185, 129, ${finalOpacity})`;
            this.ctx.arc(dot.x, dot.y, dot.currentRadius, 0, Math.PI * 2);
            this.ctx.fill();
        });
        
        requestAnimationFrame(() => this.animate());
    }
}

// Floating Cards Animation
class FloatingCards {
    constructor() {
        this.cards = document.querySelectorAll('.floating-card');
        this.init();
    }
    
    init() {
        this.cards.forEach((card, index) => {
            // Initial position and animation delay
            card.style.opacity = '0';
            card.style.transform = 'translateY(20px) scale(0.9)';
            
            setTimeout(() => {
                card.style.transition = 'all 0.8s cubic-bezier(0.23, 1, 0.32, 1)';
                card.style.opacity = '1';
                card.style.transform = 'translateY(0) scale(1)';
                
                // Add floating animation
                this.addFloatingAnimation(card, index);
            }, 1000 + index * 300);
        });
    }
    
    addFloatingAnimation(card, index) {
        const duration = 4000 + index * 500;
        const amplitude = 8 + index * 2;
        
        setInterval(() => {
            const time = Date.now() / 1000;
            const randomY = Math.sin(time / (duration / 1000)) * amplitude;
            const randomX = Math.cos(time / ((duration * 1.5) / 1000)) * amplitude * 0.5;
            const randomRotate = Math.sin(time / ((duration * 2) / 1000)) * 1.5;
            
            card.style.transform = `translateY(${randomY}px) translateX(${randomX}px) rotate(${randomRotate}deg)`;
        }, 50);
    }
}

// Add CSS for notifications and animations
const style = document.createElement('style');
style.textContent = `
    .notification {
        position: fixed;
        top: 24px;
        right: 24px;
        background: white;
        border-radius: 16px;
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
        padding: 16px 24px;
        transform: translateX(100%);
        transition: all 0.3s ease;
        z-index: 1000;
        border-left: 4px solid #706DFE;
    }
    
    .notification.notification-success {
        border-left-color: #4CAF50;
    }
    
    .notification.notification-error {
        border-left-color: #f44336;
    }
    
    .notification.show {
        transform: translateX(0);
    }
    
    .notification-content {
        display: flex;
        align-items: center;
        gap: 12px;
    }
    
    .notification-icon {
        font-size: 1.2rem;
    }
    
    .notification-message {
        font-weight: 500;
        color: #333;
    }
    
    .fade-in {
        animation: fadeInUp 0.8s ease forwards;
        opacity: 0;
        transform: translateY(30px);
    }
    
    .animate-in {
        animation: slideInUp 0.6s ease forwards;
        opacity: 0;
        transform: translateY(50px);
    }
    
    .workflow-header.animate-in,
    .workflow-step.animate-in,
    .workflow-cta.animate-in {
        animation: workflowFadeIn 0.8s ease forwards;
    }
    
    @keyframes workflowFadeIn {
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    
    @keyframes fadeInUp {
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    
    @keyframes slideInUp {
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
`;
document.head.appendChild(style);