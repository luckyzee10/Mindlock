// WEBSITE FILE: MindLock Landing Page JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Smooth scrolling for navigation links
    const navLinks = document.querySelectorAll('.nav-links a[href^="#"]');
    
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            const targetSection = document.querySelector(targetId);
            
            if (targetSection) {
                const headerHeight = document.querySelector('.header').offsetHeight;
                const targetPosition = targetSection.offsetTop - headerHeight;
                
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });

    // Header background on scroll
    const header = document.querySelector('.header');
    
    window.addEventListener('scroll', function() {
        if (window.scrollY > 50) {
            header.style.background = 'rgba(255, 255, 255, 0.98)';
            header.style.boxShadow = '0 2px 20px rgba(0, 0, 0, 0.1)';
        } else {
            header.style.background = 'rgba(255, 255, 255, 0.95)';
            header.style.boxShadow = 'none';
        }
    });

    // Animate elements on scroll
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);

    // Observe elements for animation
    const animateElements = document.querySelectorAll('.feature-card, .step, .charity-card');
    
    animateElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(30px)';
        el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(el);
    });

    // Button hover effects
    const buttons = document.querySelectorAll('.btn');
    
    buttons.forEach(button => {
        button.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-2px)';
        });
        
        button.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0)';
        });
    });

    // Phone mockup animation
    const phoneMockup = document.querySelector('.phone-mockup');
    
    if (phoneMockup) {
        phoneMockup.style.opacity = '0';
        phoneMockup.style.transform = 'translateX(50px)';
        phoneMockup.style.transition = 'opacity 1s ease, transform 1s ease';
        
        setTimeout(() => {
            phoneMockup.style.opacity = '1';
            phoneMockup.style.transform = 'translateX(0)';
        }, 500);
    }

    // Waitlist button functionality
    const waitlistButtons = document.querySelectorAll('.btn-primary');
    
    waitlistButtons.forEach(button => {
        if (button.textContent.includes('Waitlist')) {
            button.addEventListener('click', function() {
                // For now, just show an alert
                // In production, this would open a form or modal
                alert('Thank you for your interest! We\'ll notify you when MindLock launches.');
            });
        }
    });

    // Mobile menu toggle (if needed in the future)
    function setupMobileMenu() {
        const navLinks = document.querySelector('.nav-links');
        const mobileMenuButton = document.createElement('button');
        mobileMenuButton.className = 'mobile-menu-btn';
        mobileMenuButton.innerHTML = '☰';
        mobileMenuButton.style.display = 'none';
        
        const navContainer = document.querySelector('.nav-container');
        navContainer.appendChild(mobileMenuButton);
        
        mobileMenuButton.addEventListener('click', function() {
            navLinks.classList.toggle('show');
        });
        
        // Show mobile menu button on small screens
        function checkScreenSize() {
            if (window.innerWidth <= 768) {
                mobileMenuButton.style.display = 'block';
                navLinks.style.display = 'none';
            } else {
                mobileMenuButton.style.display = 'none';
                navLinks.style.display = 'flex';
            }
        }
        
        checkScreenSize();
        window.addEventListener('resize', checkScreenSize);
    }

    // Initialize mobile menu
    setupMobileMenu();

    // Add loading animation
    window.addEventListener('load', function() {
        document.body.style.opacity = '0';
        document.body.style.transition = 'opacity 0.5s ease';
        
        setTimeout(() => {
            document.body.style.opacity = '1';
        }, 100);
    });

    // Parallax effect for hero section
    const hero = document.querySelector('.hero');
    
    if (hero) {
        window.addEventListener('scroll', function() {
            const scrolled = window.pageYOffset;
            const rate = scrolled * -0.5;
            hero.style.transform = `translateY(${rate}px)`;
        });
    }

    // Console welcome message
    console.log('🔒 Welcome to MindLock!');
    console.log('Building healthier digital habits through charitable impact.');
    console.log('Website loaded successfully.');
});
