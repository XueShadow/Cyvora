document.addEventListener('DOMContentLoaded', () => {
    const form = document.querySelector('[data-reset-form]');
    if (!form) {
        return;
    }

    const tokenField = form.querySelector('input[name="access_token"]');
    const submitButton = form.querySelector('button[type="submit"]');
    const message = form.querySelector('[data-reset-message]');
    const hash = new URLSearchParams(window.location.hash.slice(1));
    const accessToken = hash.get('access_token');

    window.history.replaceState(null, document.title, window.location.pathname + window.location.search);

    if (hash.get('type') !== 'recovery' || !accessToken) {
        message.textContent = 'This recovery link is invalid or expired. Request a new link.';
        return;
    }

    tokenField.value = accessToken;
    submitButton.disabled = false;
    message.textContent = 'Recovery link verified. Choose a new password.';
});
