// HyperMojo Demo JavaScript

document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 HyperMojo Ultimate Demo Loaded!');

    // Add some interactive features
    const demoCards = document.querySelectorAll('.demo-card');

    demoCards.forEach(card => {
        card.addEventListener('click', function(e) {
            // Add a subtle animation
            this.style.transform = 'scale(0.95)';
            setTimeout(() => {
                this.style.transform = '';
            }, 150);
        });
    });

    // Fetch health check on page load
    fetch('/api/v1/health')
        .then(response => response.json())
        .then(data => {
            console.log('✅ API Health:', data);
            showNotification('API is healthy! 🚀', 'success');
        })
        .catch(error => {
            console.error('❌ API Health check failed:', error);
            showNotification('API health check failed', 'error');
        });

    // Add some dynamic content
    updateVisitCounter();
});

function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 1rem;
        border-radius: 5px;
        color: white;
        font-weight: bold;
        z-index: 1000;
        animation: slideIn 0.3s ease-out;
    `;

    if (type === 'success') {
        notification.style.backgroundColor = '#27ae60';
    } else if (type === 'error') {
        notification.style.backgroundColor = '#e74c3c';
    } else {
        notification.style.backgroundColor = '#3498db';
    }

    document.body.appendChild(notification);

    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease-out';
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 3000);
}

function updateVisitCounter() {
    // This would normally be handled server-side, but we can show some client-side magic
    const counter = document.querySelector('.visit-counter strong');
    if (counter) {
        const currentCount = parseInt(counter.textContent) || 1;
        // Add some animation
        counter.style.transition = 'all 0.3s ease';
        counter.style.transform = 'scale(1.1)';
        setTimeout(() => {
            counter.style.transform = 'scale(1)';
        }, 300);
    }
}

// Add some CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }

    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }

    .demo-card {
        cursor: pointer;
    }

    .visit-counter strong {
        display: inline-block;
    }
`;
document.head.appendChild(style);

// Add some HyperMojo branding to console
console.log(`
██╗░░██╗██╗░░░██╗██████╗░███████╗██████╗░███╗░░░███╗░█████╗░░░░░░░░██╗░█████╗░
██║░░██║╚██╗░██╔╝██╔══██╗██╔════╝██╔══██╗████╗░████║██╔══██╗░░░░░░░██║██╔══██╗
███████║░╚████╔╝░██████╔╝█████╗░░██████╔╝██╔████╔██║██║░░██║░░██╗░░██║██║░░██║
██╔══██║░░╚██╔╝░░██╔═══╝░██╔══╝░░██╔══██╗██║╚██╔╝██║██║░░██║░░╚═╝░░╚╝██║░░██║
██║░░██║░░░██║░░░██║░░░░░███████╗██║░░██║██║░╚═╝░██║╚█████╔╝░░░░░░░░░╚█████╔╝
╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░░░░╚══════╝╚═╝░░╚═╝╚═╝░░░░░╚═╝░╚════╝░░░░░░░░░░╚════╝░

Welcome to HyperMojo 2.0 - The Ultimate Web Framework for Mojo! 🔥

Features loaded:
✅ Advanced routing with groups and parameters
✅ Security middleware (CORS, CSRF, security headers)
✅ Session management with memory store
✅ Template engine with custom functions
✅ File upload and static file serving
✅ Request validation and error handling
✅ Rate limiting and compression
✅ Auto-generated API documentation

Visit: http://localhost:8080
Docs: http://localhost:8080/docs
`);
