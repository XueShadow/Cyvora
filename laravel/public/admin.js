document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('[data-auto-submit]').forEach((control) => {
        control.addEventListener('change', () => control.form?.requestSubmit());
    });

    const toggle = document.querySelector('[data-nav-toggle]');
    const sidebar = document.getElementById('admin-sidebar');

    if (!toggle || !sidebar) {
        return;
    }

    toggle.addEventListener('click', () => {
        const isOpen = document.body.classList.toggle('nav-open');
        toggle.setAttribute('aria-expanded', String(isOpen));
    });

    sidebar.addEventListener('click', (event) => {
        if (event.target instanceof HTMLAnchorElement && window.matchMedia('(max-width: 760px)').matches) {
            document.body.classList.remove('nav-open');
            toggle.setAttribute('aria-expanded', 'false');
        }
    });
});
