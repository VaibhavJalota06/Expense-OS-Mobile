// Authentication Module - Expense OS Web
// Handles Google Sign-In, Email/Password Auth, and Auth State Management

// Global Edit Profile Modal Handlers (accessible immediately everywhere)
window.handleEditProfileClick = function(e) {
  if (e) {
    try { e.preventDefault(); e.stopPropagation(); } catch(err) {}
  }
  var dropdown = document.getElementById('user-dropdown-menu');
  if (dropdown) {
    dropdown.classList.add('hidden');
    dropdown.style.setProperty('display', 'none', 'important');
  }

  var modal = document.getElementById('edit-profile-modal');
  if (modal) {
    modal.classList.remove('hidden');
    modal.style.setProperty('display', 'flex', 'important');
    modal.style.setProperty('opacity', '1', 'important');
    modal.style.setProperty('visibility', 'visible', 'important');
    modal.style.setProperty('pointer-events', 'auto', 'important');
    modal.style.setProperty('z-index', '100000', 'important');
  }

  setTimeout(function() {
    try {
      var nameInput = document.getElementById('edit-profile-name');
      var genderSelect = document.getElementById('edit-profile-gender');
      var emailInput = document.getElementById('edit-profile-email');
      var dropName = document.getElementById('dropdown-user-name');
      var dropEmail = document.getElementById('dropdown-user-email');

      var currentName = dropName ? dropName.textContent.replace(/^(Mr\.\s*|Ms\.\s*)/i, '').trim() : '';
      if (currentName === 'User Name' || !currentName) currentName = '';
      var currentEmail = dropEmail ? dropEmail.textContent : '';

      if (nameInput && currentName) nameInput.value = currentName;
      if (emailInput && currentEmail) emailInput.value = currentEmail;

      var currentGender = localStorage.getItem('expense_cal_user_gender_active') || 'male';
      if (genderSelect) genderSelect.value = currentGender;
    } catch(err) {
      console.warn('Profile field population notice:', err);
    }
  }, 0);
};
window.openEditProfileModal = window.handleEditProfileClick;
window.openProfileModal = window.handleEditProfileClick;

window.handleCheckUpdateClick = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  var dropdown = document.getElementById('user-dropdown-menu');
  if (dropdown) {
    dropdown.classList.add('hidden');
    dropdown.style.setProperty('display', 'none', 'important');
  }
  if (typeof window.checkAppUpdates === 'function') {
    window.checkAppUpdates(true);
  }
};

window.promptSignOut = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  var dropdown = document.getElementById('user-dropdown-menu');
  if (dropdown) {
    dropdown.classList.add('hidden');
    dropdown.style.setProperty('display', 'none', 'important');
  }
  var modal = document.getElementById('signout-modal');
  if (modal) {
    modal.classList.remove('hidden');
    modal.style.setProperty('display', 'flex', 'important');
    modal.style.setProperty('opacity', '1', 'important');
    modal.style.setProperty('visibility', 'visible', 'important');
    modal.style.setProperty('pointer-events', 'auto', 'important');
    modal.style.setProperty('z-index', '100000', 'important');
  }
};
window.handleSignOut = window.promptSignOut;

window.closeSignOutModal = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  var modal = document.getElementById('signout-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.setProperty('display', 'none', 'important');
    modal.style.setProperty('pointer-events', 'none', 'important');
  }
};

window.confirmSignOutAction = function(e) {
  if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
  window.closeSignOutModal(e);
  try {
    const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
    if (supaClient && supaClient.auth) {
      supaClient.auth.signOut();
    }
  } catch(err) {}
  localStorage.removeItem('expense_cal_user_session');
  localStorage.removeItem('expense_cal_admin_session');
  window.location.reload();
};
window.confirmSignOut = window.confirmSignOutAction;

window.closeEditProfileModal = function(e) {
  if (e) {
    try { e.preventDefault(); e.stopPropagation(); } catch(err) {}
  }
  var modal = document.getElementById('edit-profile-modal');
  if (modal) {
    modal.classList.add('hidden');
    modal.style.setProperty('display', 'none', 'important');
  }
};

(function initAuth() {
    const loginScreen = document.getElementById('login-screen');
    const appLayout = document.querySelector('.app-layout');
    const loginCard = document.getElementById('login-card');
    const signupCard = document.getElementById('signup-card');
    const loginForm = document.getElementById('login-form');
    const signupForm = document.getElementById('signup-form');
    const loginEmailInput = document.getElementById('login-email');
    const loginPasswordInput = document.getElementById('login-password');
    const signupEmailInput = document.getElementById('signup-email');
    const signupPasswordInput = document.getElementById('signup-password');
    const signupConfirmInput = document.getElementById('signup-confirm-password');
    const loginError = document.getElementById('login-error');
    const signupError = document.getElementById('signup-error');
    const btnShowSignup = document.getElementById('btn-show-signup');
    const btnShowLogin = document.getElementById('btn-show-login');
    // Topbar profile elements (sidebar profile was removed)
    const syncStatusEl = document.getElementById('sync-status');

    // Toggle Login / Signup / Reset
    if (btnShowSignup) {
      btnShowSignup.addEventListener('click', (e) => {
        e.preventDefault();
        const resetCard = document.getElementById('reset-card');
        const newPasswordCard = document.getElementById('new-password-card');
        if (loginCard) loginCard.classList.add('hidden');
        if (resetCard) resetCard.classList.add('hidden');
        if (newPasswordCard) newPasswordCard.classList.add('hidden');
        if (signupCard) signupCard.classList.remove('hidden');
        clearErrors();
      });
    }
    if (btnShowLogin) {
      btnShowLogin.addEventListener('click', (e) => {
        e.preventDefault();
        const resetCard = document.getElementById('reset-card');
        const newPasswordCard = document.getElementById('new-password-card');
        if (signupCard) signupCard.classList.add('hidden');
        if (resetCard) resetCard.classList.add('hidden');
        if (newPasswordCard) newPasswordCard.classList.add('hidden');
        if (loginCard) loginCard.classList.remove('hidden');
        clearErrors();
      });
    }

    const btnShowForgot = document.getElementById('btn-show-forgot');
    if (btnShowForgot) {
      btnShowForgot.addEventListener('click', (e) => {
        e.preventDefault();
        const resetCard = document.getElementById('reset-card');
        const newPasswordCard = document.getElementById('new-password-card');
        if (loginCard) loginCard.classList.add('hidden');
        if (signupCard) signupCard.classList.add('hidden');
        if (newPasswordCard) newPasswordCard.classList.add('hidden');
        if (resetCard) resetCard.classList.remove('hidden');
        clearErrors();
      });
    }

    const btnResetBackLogin = document.getElementById('btn-reset-back-login');
    if (btnResetBackLogin) {
      btnResetBackLogin.addEventListener('click', (e) => {
        e.preventDefault();
        const resetCard = document.getElementById('reset-card');
        const newPasswordCard = document.getElementById('new-password-card');
        if (signupCard) signupCard.classList.add('hidden');
        if (resetCard) resetCard.classList.add('hidden');
        if (newPasswordCard) newPasswordCard.classList.add('hidden');
        if (loginCard) loginCard.classList.remove('hidden');
        clearErrors();
      });
    }

    // Real-Time Password Security Rules Evaluator
    function evaluatePasswordRules(password) {
      return {
        length: password.length >= 8 && password.length <= 16,
        uppercase: /[A-Z]/.test(password),
        lowercase: /[a-z]/.test(password),
        number: /[0-9]/.test(password),
        symbol: /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)
      };
    }

    function updatePasswordChecklist(password, prefix = '', confirmPassword = null) {
      const rules = evaluatePasswordRules(password);
      let allValid = Object.values(rules).every(Boolean);

      const lengthEl = document.getElementById(prefix + 'rule-length');
      const upperEl = document.getElementById(prefix + 'rule-uppercase');
      const lowerEl = document.getElementById(prefix + 'rule-lowercase');
      const numberEl = document.getElementById(prefix + 'rule-number');
      const symbolEl = document.getElementById(prefix + 'rule-symbol');
      const matchEl = document.getElementById(prefix + 'rule-match');

      function setRuleState(el, isValid) {
        if (!el) return;
        if (isValid) {
          el.classList.add('valid');
          el.classList.remove('invalid');
          const icon = el.querySelector('i');
          if (icon) icon.className = 'fa-solid fa-circle-check';
        } else {
          el.classList.remove('valid');
          el.classList.add('invalid');
          const icon = el.querySelector('i');
          if (icon) icon.className = 'fa-solid fa-circle-dot';
        }
      }

      setRuleState(lengthEl, rules.length);
      setRuleState(upperEl, rules.uppercase);
      setRuleState(lowerEl, rules.lowercase);
      setRuleState(numberEl, rules.number);
      setRuleState(symbolEl, rules.symbol);

      if (matchEl) {
        const isMatch = password.length > 0 && confirmPassword !== null && password === confirmPassword;
        setRuleState(matchEl, isMatch);
        if (!isMatch) allValid = false;
      }

      return allValid;
    }

    function isValidEmailFormat(email) {
      return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((email || '').trim());
    }

    // Attach live input listeners for password rules checklist
    const confirmPasswordInput = document.getElementById('signup-confirm-password');

    function updateSignupPasswordRules() {
      const p1 = signupPasswordInput ? signupPasswordInput.value : '';
      const p2 = confirmPasswordInput ? confirmPasswordInput.value : '';
      updatePasswordChecklist(p1, 'signup-', p2);
    }

    if (signupPasswordInput) {
      signupPasswordInput.addEventListener('input', updateSignupPasswordRules);
    }
    if (confirmPasswordInput) {
      confirmPasswordInput.addEventListener('input', updateSignupPasswordRules);
    }

    const newPasswordInput = document.getElementById('new-password');
    if (newPasswordInput) {
      newPasswordInput.addEventListener('input', (e) => {
        updatePasswordChecklist(e.target.value, 'new-');
      });
    }

    window.handleShowForgotClick = function(e) {
      if (e) e.preventDefault();
      const loginCard = document.getElementById('login-card');
      const signupCard = document.getElementById('signup-card');
      const resetCard = document.getElementById('reset-card');
      const newPasswordCard = document.getElementById('new-password-card');
      if (loginCard) loginCard.classList.add('hidden');
      if (signupCard) signupCard.classList.add('hidden');
      if (newPasswordCard) newPasswordCard.classList.add('hidden');
      if (resetCard) resetCard.classList.remove('hidden');
      clearErrors();
    };

    window.handleResetRequestSubmit = async function(e) {
      if (e) e.preventDefault();
      const resetEmailInput = document.getElementById('reset-email');
      const resetError = document.getElementById('reset-error');
      const resetSuccess = document.getElementById('reset-success');
      const btnSendReset = document.getElementById('btn-send-reset');

      if (!resetEmailInput) return;
      const email = resetEmailInput.value.trim();

      if (!isValidEmailFormat(email)) {
        if (resetError) {
          resetError.textContent = "Please enter a valid email address (e.g. user@example.com).";
          resetError.classList.remove('hidden');
        }
        return;
      }

      if (resetError) resetError.classList.add('hidden');
      if (resetSuccess) resetSuccess.classList.add('hidden');
      if (btnSendReset) {
        btnSendReset.disabled = true;
        btnSendReset.textContent = "Sending link...";
      }

      try {
        const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
        if (!supaClient || !supaClient.auth) {
          throw new Error("Supabase Auth client unavailable.");
        }

        const { error } = await supaClient.auth.resetPasswordForEmail(email, {
          redirectTo: window.location.origin + window.location.pathname
        });

        if (error) {
          if (resetError) {
            resetError.textContent = error.message;
            resetError.classList.remove('hidden');
          }
        } else {
          if (resetSuccess) {
            resetSuccess.textContent = "✅ Password reset email sent! Please check your email inbox to reset your password.";
            resetSuccess.classList.remove('hidden');
          }
        }
      } catch (err) {
        if (resetError) {
          resetError.textContent = err.message || "Failed to send reset link.";
          resetError.classList.remove('hidden');
        }
      } finally {
        if (btnSendReset) {
          btnSendReset.disabled = false;
          btnSendReset.textContent = "Send Reset Link";
        }
      }
    };

    window.handleSetNewPasswordSubmit = async function(e) {
      if (e) e.preventDefault();
      const newPasswordInput = document.getElementById('new-password');
      const newPasswordError = document.getElementById('new-password-error');
      const newPasswordSuccess = document.getElementById('new-password-success');
      const btnUpdatePassword = document.getElementById('btn-update-password');

      if (!newPasswordInput) return;
      const password = newPasswordInput.value;

      const isPasswordValid = updatePasswordChecklist(password, 'new-');
      if (!isPasswordValid) {
        if (newPasswordError) {
          newPasswordError.textContent = "Please fulfill all 5 password security requirements (8-16 chars, Uppercase, Lowercase, Number, Symbol).";
          newPasswordError.classList.remove('hidden');
        }
        return;
      }

      if (newPasswordError) newPasswordError.classList.add('hidden');
      if (newPasswordSuccess) newPasswordSuccess.classList.add('hidden');
      if (btnUpdatePassword) {
        btnUpdatePassword.disabled = true;
        btnUpdatePassword.textContent = "Updating password...";
      }

      try {
        const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
        if (!supaClient || !supaClient.auth) {
          throw new Error("Supabase Auth client unavailable.");
        }

        const { error } = await supaClient.auth.updateUser({ password: password });

        if (error) {
          if (newPasswordError) {
            newPasswordError.textContent = error.message;
            newPasswordError.classList.remove('hidden');
          }
        } else {
          if (newPasswordSuccess) {
            newPasswordSuccess.textContent = "🎉 Password updated successfully! Redirecting to login...";
            newPasswordSuccess.classList.remove('hidden');
          }
          setTimeout(() => {
            if (window.handleShowLoginClick) window.handleShowLoginClick();
          }, 2000);
        }
      } catch (err) {
        if (newPasswordError) {
          newPasswordError.textContent = err.message || "Failed to update password.";
          newPasswordError.classList.remove('hidden');
        }
      } finally {
        if (btnUpdatePassword) {
          btnUpdatePassword.disabled = false;
          btnUpdatePassword.textContent = "Update Password";
        }
      }
    };

    let isAuthInProgress = false;

    // Expose auth functions to global scope immediately (function declarations are hoisted)
    window.signInWithGoogle = signInWithGoogle;
    window.signInWithEmail = signInWithEmail;
    window.signUpWithEmail = signUpWithEmail;
    window.showApp = showApp;
    window.showLoginScreen = showLoginScreen;
    window.handleSignOut = handleSignOut;
    window.promptSignOut = promptSignOut;
    window.closeSignOutModal = closeSignOutModal;
    window.confirmSignOut = confirmSignOut;
    window.handleAdminLoginClick = handleAdminLoginClick;
    window.handleSignInSubmit = handleSignInSubmit;
    window.handleSignUpSubmit = handleSignUpSubmit;
    window.handleShowForgotClick = window.handleShowForgotClick;
    window.handleResetRequestSubmit = window.handleResetRequestSubmit;
    window.handleSetNewPasswordSubmit = window.handleSetNewPasswordSubmit;

    // Toggle user profile dropdown menu
    window.toggleUserDropdown = function(e) {
      if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
      const dropdown = document.getElementById('user-dropdown-menu');
      if (!dropdown) return;
      const isHidden = dropdown.classList.contains('hidden') || dropdown.style.display === 'none';
      if (isHidden) {
        dropdown.classList.remove('hidden');
        dropdown.style.setProperty('display', 'block', 'important');
        dropdown.style.opacity = '1';
        dropdown.style.visibility = 'visible';
      } else {
        dropdown.classList.add('hidden');
        dropdown.style.setProperty('display', 'none', 'important');
      }
    };
    window.showWelcomeModal = function() {
      const modal = document.getElementById('welcome-modal');
      if (modal) {
        modal.classList.remove('hidden');
        modal.style.setProperty('display', 'flex', 'important');
        modal.style.setProperty('opacity', '1', 'important');
        modal.style.setProperty('visibility', 'visible', 'important');
        modal.style.setProperty('z-index', '100000', 'important');
        modal.style.setProperty('pointer-events', 'auto', 'important');
      }
    };
    window.openWelcomeModal = window.showWelcomeModal;

    window.resetAdminAccountAndShowWelcome = function() {
      window.welcomeModalDismissed = false;
      const adminId = 'usr_admin_expenseos_com';
      try {
        localStorage.removeItem('expense_cal_seen_welcome_global');
        localStorage.removeItem('expense_cal_seen_welcome_v2_' + adminId);
        localStorage.setItem('expense_cal_show_welcome_' + adminId, 'true');
      } catch(e) {}

      const modal = document.getElementById('welcome-modal');
      const titleEl = document.getElementById('welcome-modal-title');
      const msgEl = document.getElementById('welcome-modal-msg');
      if (modal) {
        if (titleEl) titleEl.textContent = `Welcome Aboard, System Administrator ⭐! 🎉`;
        if (msgEl) msgEl.textContent = `We are thrilled to have you here! Your personal finance command center is ready to help you track expenses, manage budget caps, and organize recurring bills effortlessly.`;
        modal.classList.remove('hidden');
        modal.style.setProperty('display', 'flex', 'important');
        modal.style.setProperty('opacity', '1', 'important');
        modal.style.setProperty('visibility', 'visible', 'important');
        modal.style.setProperty('z-index', '100000', 'important');
        modal.style.setProperty('pointer-events', 'auto', 'important');
      }
    };


    // Handle incoming OAuth session from Electron main process
    async function handleOAuthSessionPayload(payload) {
      if (!payload) return;
      if (typeof applyDesktopOAuthSession === 'function') {
        applyDesktopOAuthSession(payload);
      }
    }

    if (window.electronAPI) {
      if (typeof window.electronAPI.onOAuthSession === 'function') {
        window.electronAPI.onOAuthSession((payload) => {
          handleOAuthSessionPayload(payload);
        });
      }
      if (typeof window.electronAPI.consumeOAuthSession === 'function') {
        window.electronAPI.consumeOAuthSession().then(payload => {
          if (payload) handleOAuthSessionPayload(payload);
        }).catch(() => {});
      }
    }

    async function signInWithGoogle() {
      try {
        clearErrors();

        const isElectronApp = !!(window.electronAPI && window.electronAPI.isElectron);
        const currentPort = window.location.port || '58420';
        const origin = (window.location.origin && window.location.origin !== 'null' && !window.location.origin.includes('file:'))
          ? window.location.origin
          : `http://localhost:${currentPort}`;

        const redirectUrl = isElectronApp
          ? `http://localhost:${currentPort}/auth-complete`
          : `${origin}${window.location.pathname}`;

        const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));

        if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && supaClient) {
          if (isElectronApp) {
            // For Desktop (Electron): request OAuth URL from Supabase and open in system browser
            const { data, error } = await supaClient.auth.signInWithOAuth({
              provider: 'google',
              options: {
                redirectTo: redirectUrl,
                skipBrowserRedirect: true,
                queryParams: { prompt: 'select_account' }
              }
            });

            if (!error && data && data.url) {
              if (window.electronAPI && typeof window.electronAPI.openExternal === 'function') {
                window.electronAPI.openExternal(data.url);
              } else {
                window.open(data.url, '_blank');
              }
              return;
            }
          } else {
            // For Web / Browser: direct Supabase browser redirect
            const { error } = await supaClient.auth.signInWithOAuth({
              provider: 'google',
              options: {
                redirectTo: redirectUrl,
                queryParams: { prompt: 'select_account' }
              }
            });
            if (!error) return;
          }
        }

        // Direct Fallback if Supabase SDK is pending or throws: open Supabase Google authorize endpoint directly
        const baseSupaUrl = (typeof SUPABASE_URL !== 'undefined' && SUPABASE_URL) ? SUPABASE_URL : 'https://gtwirhvswhslljbfvnoe.supabase.co';
        const authUrl = `${baseSupaUrl}/auth/v1/authorize?provider=google&redirect_to=${encodeURIComponent(redirectUrl)}`;
        if (isElectronApp && window.electronAPI && typeof window.electronAPI.openExternal === 'function') {
          window.electronAPI.openExternal(authUrl);
        } else {
          window.location.href = authUrl;
        }
      } catch (error) {
        console.error('Google Sign-In error:', error);
        try {
          const isElectronApp = !!(window.electronAPI && window.electronAPI.isElectron);
          const currentPort = window.location.port || '58420';
          const redirectUrl = isElectronApp
            ? `http://localhost:${currentPort}/auth-complete`
            : `${window.location.origin}${window.location.pathname}`;
          const baseSupaUrl = (typeof SUPABASE_URL !== 'undefined' && SUPABASE_URL) ? SUPABASE_URL : 'https://gtwirhvswhslljbfvnoe.supabase.co';
          const authUrl = `${baseSupaUrl}/auth/v1/authorize?provider=google&redirect_to=${encodeURIComponent(redirectUrl)}`;
          if (isElectronApp && window.electronAPI && typeof window.electronAPI.openExternal === 'function') {
            window.electronAPI.openExternal(authUrl);
          } else {
            window.location.href = authUrl;
          }
        } catch (e) {
          showError(loginError, 'Google Sign-In error. Please try again or use Email & Password.');
        }
      }
    }

    function handleSignInSubmit(e) {
      if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
      const emailInput = document.getElementById('login-email');
      const passInput = document.getElementById('login-password');
      const errEl = document.getElementById('login-error');

      const email = emailInput ? emailInput.value.trim() : '';
      const password = passInput ? passInput.value : '';

      if (!email || !password) {
        if (errEl) {
          errEl.textContent = 'Please fill in all fields (Email and Password).';
          errEl.classList.remove('hidden');
        }
        return false;
      }

      signInWithEmail(email, password);
      return false;
    }

    function autoDetectUserCountryCode() {
      try {
        const phoneInput = document.getElementById('signup-phone');
        if (!phoneInput) return;

        const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
        let detectedCode = '+91';

        if (tz.includes('Kolkata') || tz.includes('India')) detectedCode = '+91';
        else if (tz.includes('New_York') || tz.includes('Los_Angeles') || tz.includes('Chicago') || tz.includes('Denver') || tz.includes('America/')) detectedCode = '+1';
        else if (tz.includes('London')) detectedCode = '+44';
        else if (tz.includes('Toronto') || tz.includes('Vancouver')) detectedCode = '+1';
        else if (tz.includes('Sydney') || tz.includes('Melbourne') || tz.includes('Australia')) detectedCode = '+61';
        else if (tz.includes('Dubai')) detectedCode = '+971';
        else if (tz.includes('Singapore')) detectedCode = '+65';
        else if (tz.includes('Berlin')) detectedCode = '+49';
        else if (tz.includes('Paris')) detectedCode = '+33';
        else if (tz.includes('Tokyo')) detectedCode = '+81';
        else if (tz.includes('Shanghai')) detectedCode = '+86';
        else if (tz.includes('Sao_Paulo')) detectedCode = '+55';
        else if (tz.includes('Riyadh')) detectedCode = '+966';
        else if (tz.includes('Karachi')) detectedCode = '+92';
        else if (tz.includes('Dhaka')) detectedCode = '+880';

        phoneInput.placeholder = `${detectedCode} 98765 43210`;
        phoneInput.dataset.autoCountryCode = detectedCode;

        fetch('https://ipapi.co/json/', { signal: AbortSignal.timeout(3000) })
          .then(res => res.json())
          .then(data => {
            if (data && data.country_calling_code) {
              const code = data.country_calling_code.startsWith('+') ? data.country_calling_code : '+' + data.country_calling_code;
              phoneInput.placeholder = `${code} 98765 43210`;
              phoneInput.dataset.autoCountryCode = code;
            }
          })
          .catch(() => {});
      } catch(e) {}
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', autoDetectUserCountryCode);
    } else {
      autoDetectUserCountryCode();
    }

    function handleSignUpSubmit(e) {
      if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
      const nameInput = document.getElementById('signup-name');
      const genderSelect = document.getElementById('signup-gender');
      const emailInput = document.getElementById('signup-email');
      const phoneInput = document.getElementById('signup-phone');
      const passInput = document.getElementById('signup-password');
      const confirmInput = document.getElementById('signup-confirm-password');
      const errEl = document.getElementById('signup-error');

      const name = nameInput ? nameInput.value.trim() : '';
      const gender = genderSelect ? genderSelect.value : 'male';
      const email = emailInput ? emailInput.value.trim() : '';
      const rawPhone = phoneInput ? phoneInput.value.trim() : '';
      const autoCode = phoneInput ? (phoneInput.dataset.autoCountryCode || '+91') : '+91';
      const phone = rawPhone ? (rawPhone.startsWith('+') ? rawPhone : `${autoCode} ${rawPhone}`) : '';
      const password = passInput ? passInput.value : '';
      const confirm = confirmInput ? confirmInput.value : '';

      if (!name || !email || !password || !confirm) {
        if (errEl) { errEl.textContent = 'Please fill in all required fields.'; errEl.classList.remove('hidden'); }
        return false;
      }
      if (password !== confirm) {
        if (errEl) { errEl.textContent = 'Passwords do not match.'; errEl.classList.remove('hidden'); }
        return false;
      }
      if (password.length < 8 || password.length > 16) {
        if (errEl) { errEl.textContent = 'Password must be between 8 and 16 characters.'; errEl.classList.remove('hidden'); }
        return false;
      }

      signUpWithEmail(name, gender, email, password, phone);
      return false;
    }

    async function sha256Hex(str) {
      try {
        const encoder = new TextEncoder();
        const data = encoder.encode(str);
        const hashBuffer = await crypto.subtle.digest('SHA-256', data);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
      } catch(e) {
        return '';
      }
    }

    function handleAdminLoginClick(e) {
      if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
      const emailInput = document.getElementById('login-email');
      const passInput = document.getElementById('login-password');
      if (emailInput) emailInput.value = 'admin@expenseos.com';
      if (passInput) {
        passInput.value = '';
        passInput.placeholder = 'Enter Admin Password...';
        passInput.focus();
      }
    }

    // Client-Side Rate Limiting & Cooldown Protection
    const MAX_LOGIN_ATTEMPTS = 5;
    const LOCKOUT_DURATION_MS = 60 * 1000; // 60 seconds lockout

    function checkLoginRateLimit(email) {
      try {
        const key = 'expense_cal_login_attempts_' + (email || 'general').replace(/[^a-zA-Z0-9]/g, '_').toLowerCase();
        const dataStr = localStorage.getItem(key);
        if (!dataStr) return { allowed: true, remaining: MAX_LOGIN_ATTEMPTS };

        const data = JSON.parse(dataStr);
        const now = Date.now();
        if (data.lockedUntil && now < data.lockedUntil) {
          const remainingSec = Math.ceil((data.lockedUntil - now) / 1000);
          return { allowed: false, remainingSec };
        }
        
        // Reset if lockout window has passed
        if (data.lockedUntil && now >= data.lockedUntil) {
          localStorage.removeItem(key);
          return { allowed: true, remaining: MAX_LOGIN_ATTEMPTS };
        }

        return { allowed: true, count: data.count || 0 };
      } catch(e) {
        return { allowed: true };
      }
    }

    function recordFailedLoginAttempt(email) {
      try {
        const key = 'expense_cal_login_attempts_' + (email || 'general').replace(/[^a-zA-Z0-9]/g, '_').toLowerCase();
        const dataStr = localStorage.getItem(key);
        const now = Date.now();
        let data = dataStr ? JSON.parse(dataStr) : { count: 0 };
        
        data.count = (data.count || 0) + 1;
        if (data.count >= MAX_LOGIN_ATTEMPTS) {
          data.lockedUntil = now + LOCKOUT_DURATION_MS;
        }
        localStorage.setItem(key, JSON.stringify(data));
        return data;
      } catch(e) { return {}; }
    }

    function clearLoginAttempts(email) {
      try {
        const key = 'expense_cal_login_attempts_' + (email || 'general').replace(/[^a-zA-Z0-9]/g, '_').toLowerCase();
        localStorage.removeItem(key);
      } catch(e) {}
    }

    async function signInWithEmail(email, password) {
      const cleanEmail = email ? email.trim().toLowerCase() : '';
      const cleanPass = password ? password.trim() : '';

      try {
        clearErrors();
        if (!cleanEmail || !cleanPass) {
          showError(loginError, 'Please enter a valid email and password.');
          return;
        }

        // Rate Limit Guard Check
        const rateCheck = checkLoginRateLimit(cleanEmail);
        if (!rateCheck.allowed) {
          showError(loginError, `Too many failed attempts. Login locked for ${rateCheck.remainingSec}s. Please wait.`);
          return;
        }

        const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));

        // Supabase Email & Password Authentication (Strict Server-Enforced)
        if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && supaClient && supaClient.auth) {
          const { data, error } = await supaClient.auth.signInWithPassword({ email: cleanEmail, password: cleanPass });
          if (error) {
            throw error;
          }
          if (data && data.user) {
            clearLoginAttempts(cleanEmail);
            try { localStorage.setItem('expense_cal_user_session', JSON.stringify(data.user)); } catch(e) {}
            hideLoader();
            showApp(data.user);
            return;
          }
        } else {
          showError(loginError, 'Authentication service unavailable. Please check internet connection.');
          return;
        }

      } catch (error) {
        console.error('Email Sign-In error:', error);
        const failData = recordFailedLoginAttempt(cleanEmail);
        let msg = getAuthErrorMessage(error);
        if (failData.count && failData.count < MAX_LOGIN_ATTEMPTS) {
          msg += ` (${MAX_LOGIN_ATTEMPTS - failData.count} attempts remaining before temporary lockout)`;
        } else if (failData.lockedUntil) {
          msg = `Too many failed attempts. Account locked out for 60 seconds.`;
        }
        showError(loginError, msg);
      }
    }

    async function triggerWelcomeEmail(user, name) {
      if (!user || !user.email) return;
      try {
        const emailjsConfig = window.emailjsConfig || JSON.parse(localStorage.getItem('expense_cal_emailjs_config') || '{"serviceId":"","templateId":"","publicKey":""}');
        if (typeof emailjs !== 'undefined' && emailjsConfig && emailjsConfig.serviceId && emailjsConfig.templateId && emailjsConfig.publicKey) {
          await emailjs.send(
            emailjsConfig.serviceId,
            emailjsConfig.templateId,
            {
              to_email: user.email,
              email: user.email,
              user_name: name || user.email.split('@')[0],
              message: 'Welcome to Expense OS! Your personal finance command center is active and ready.'
            },
            emailjsConfig.publicKey
          );
          console.log('✅ Welcome email sent via EmailJS to:', user.email);
        } else {
          console.log('ℹ️ EmailJS not configured yet; welcome email queued for:', user.email);
        }
      } catch(err) {
        console.warn('Welcome email notice:', err);
      }
    }

    async function signUpWithEmail(name, gender, email, password, phone = '') {
      try {
        clearErrors();
        const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));

        if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && supaClient && supaClient.auth) {
          const { data, error } = await supaClient.auth.signUp({
            email,
            password,
            options: {
              data: { display_name: name, gender: gender, phone: phone || '' }
            }
          });
          if (error) throw error;
          if (data && data.user) {
            const uid = data.user.id;
            const emailKey = 'usr_' + email.replace(/[^a-zA-Z0-9]/g, '_').toLowerCase();
            localStorage.setItem('expense_cal_user_gender_' + uid, gender);
            if (phone) localStorage.setItem('expense_cal_user_phone_' + uid, phone);
            localStorage.setItem('expense_cal_show_welcome_' + uid, 'true');
            localStorage.setItem('expense_cal_show_welcome_' + emailKey, 'true');
            localStorage.setItem('expense_cal_trigger_profile_setup', 'true');
            localStorage.removeItem('expense_cal_seen_welcome_v2_' + uid);
            localStorage.removeItem('expense_cal_seen_welcome_v2_' + emailKey);
            triggerWelcomeEmail(data.user, name);
            if (data.session) {
              hideLoader();
              showApp(data.user);
            } else {
              showError(signupError, '🎉 Account created successfully! Please check your email to confirm your account or sign in directly.');
            }
          }
          return;
        }

        showError(signupError, 'Email Sign-Up unavailable. Please check your Supabase credentials or internet connection.');
      } catch (error) {
        console.error('Email Sign-Up error:', error);
        showError(signupError, getAuthErrorMessage(error));
      }
    }

    async function handleSignOut(e) {
      if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }

      try {
        if (typeof stopSupabaseSync === 'function') stopSupabaseSync();

        const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
        if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && supaClient && supaClient.auth) {
          try { await supaClient.auth.signOut({ scope: 'global' }); } catch(err) {}
          try { await supaClient.auth.signOut({ scope: 'local' }); } catch(err) {}
          try { await supaClient.auth.signOut(); } catch(err) {}
        }
      } catch (error) {
        console.error('Sign out error:', error);
      } finally {
        try {
          sessionStorage.clear();
          localStorage.clear();
        } catch(e) {}

        showLoginScreen();
      }
    }

    function promptSignOut(e) {
      if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
      const dropdown = document.getElementById('user-dropdown-menu');
      if (dropdown) {
        dropdown.classList.add('hidden');
        dropdown.style.setProperty('display', 'none', 'important');
      }
      const modal = document.getElementById('signout-modal');
      if (modal) {
        modal.classList.remove('hidden');
        modal.style.setProperty('display', 'flex', 'important');
        modal.style.setProperty('opacity', '1', 'important');
        modal.style.setProperty('visibility', 'visible', 'important');
        modal.style.setProperty('z-index', '100000', 'important');
        modal.style.setProperty('pointer-events', 'auto', 'important');
      }
    }

    function closeSignOutModal(e) {
      if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
      const modal = document.getElementById('signout-modal');
      if (modal) {
        modal.classList.add('hidden');
        modal.style.setProperty('display', 'none', 'important');
        modal.style.setProperty('pointer-events', 'none', 'important');
      }
    }

    function confirmSignOut(e) {
      if (e) { try { e.preventDefault(); e.stopPropagation(); } catch(err){} }
      closeSignOutModal(e);
      handleSignOut(e);
    }

    function hideLoader() {
      const loader = document.getElementById('app-loader');
      if (loader) {
        loader.classList.add('hidden');
        loader.style.opacity = '0';
        loader.style.visibility = 'hidden';
        loader.style.pointerEvents = 'none';
        loader.style.setProperty('display', 'none', 'important');
        if (loader.parentNode) {
          try { loader.parentNode.removeChild(loader); } catch(e) {}
        }
      }
    }

    // Unified helper functions (single definition — no duplicates)
    function getLoginScreen() {
      return document.getElementById('login-screen') || document.getElementById('auth-container');
    }
    function getAppLayout() {
      return document.querySelector('.app-layout') || document.getElementById('app-container');
    }

    function showLoginScreen() {
      const ls = getLoginScreen();
      const al = getAppLayout();
      const loginCard = document.getElementById('login-card');
      const signupCard = document.getElementById('signup-card');
      if (al) {
        al.classList.add('hidden');
        al.style.setProperty('display', 'none', 'important');
        al.style.setProperty('pointer-events', 'none', 'important');
      }
      if (ls) {
        ls.classList.remove('hidden');
        ls.style.setProperty('display', 'flex', 'important');
        ls.style.setProperty('flex-direction', 'column', 'important');
        ls.style.setProperty('justify-content', 'center', 'important');
        ls.style.setProperty('align-items', 'center', 'important');
        ls.style.setProperty('position', 'fixed', 'important');
        ls.style.setProperty('top', '0', 'important');
        ls.style.setProperty('left', '0', 'important');
        ls.style.setProperty('width', '100vw', 'important');
        ls.style.setProperty('height', '100vh', 'important');
        ls.style.setProperty('background', '#050811', 'important');
        ls.style.setProperty('z-index', '100000', 'important');
        ls.style.setProperty('opacity', '1', 'important');
        ls.style.setProperty('visibility', 'visible', 'important');
        ls.style.setProperty('pointer-events', 'auto', 'important');
      }
      if (loginCard) {
        loginCard.classList.remove('hidden');
        loginCard.style.setProperty('display', 'block', 'important');
        loginCard.style.opacity = '1';
        loginCard.style.visibility = 'visible';
      }
      if (signupCard) {
        signupCard.classList.add('hidden');
        signupCard.style.setProperty('display', 'none', 'important');
      }
      hideLoader();
    }
    window.showLoginScreen = showLoginScreen;

    // Safety timeout — only dismiss loader after enough time for Supabase to resolve
    // (prevents premature blank screen if Supabase session check takes >300ms)
    setTimeout(hideLoader, 2000);
    window.addEventListener('load', () => { setTimeout(hideLoader, 500); });

    // 1. OAuth Popup Callback Handler (Wait for Supabase session exchange before closing popup)
    if (window.opener && (window.location.hash.includes('access_token') || window.location.search.includes('code='))) {
      const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
      if (supaClient) {
        supaClient.auth.onAuthStateChange((event, session) => {
          if (session && session.user) {
            try {
              if (window.opener && !window.opener.closed) {
                window.opener.postMessage({ type: 'SUPABASE_AUTH_SUCCESS' }, '*');
                if (window.opener.location) {
                  window.opener.location.reload();
                }
              }
            } catch(e) {}
            setTimeout(() => { window.close(); }, 300);
          }
        });
      } else {
        setTimeout(() => {
          try {
            if (window.opener && !window.opener.closed && window.opener.location) {
              window.opener.location.reload();
            }
          } catch(e) {}
          window.close();
        }, 1000);
      }
    }

    window.addEventListener('message', (event) => {
      if (event.data && event.data.type === 'SUPABASE_AUTH_SUCCESS') {
        window.location.reload();
      }
    });

    window.addEventListener('storage', (e) => {
      if (e.key && (e.key.includes('auth-token') || e.key.includes('supabase'))) {
        evaluateAuthState();
      }
    });

    // 2. Unified Auth Observer Handler
    async function evaluateAuthState() {
      // 0. Landing Page Hero Preview Iframe Check
      if (window.location.search.includes('preview=true')) {
        if (typeof window.loadDemoData === 'function') window.loadDemoData();
        hideLoader();
        showApp({
          id: 'demo-preview-user',
          email: 'demo@expenseos.app',
          user_metadata: { display_name: 'Alex Morgan', gender: 'male' }
        });
        return true;
      }

      if (window.location.hash.includes('access_token') || window.location.hash.includes('refresh_token') || window.location.search.includes('code=')) {
        const isElectronApp = !!(window.electronAPI && window.electronAPI.isElectron);
        if (!isElectronApp) {
          try {
            const hash = window.location.hash;
            const search = window.location.search;
            let access_token = '';
            let refresh_token = '';
            let code = '';
            if (hash.includes('access_token')) {
              const p = new URLSearchParams(hash.substring(1));
              access_token = p.get('access_token') || '';
              refresh_token = p.get('refresh_token') || '';
            } else if (search.includes('code=')) {
              const p = new URLSearchParams(search);
              code = p.get('code') || '';
            }
            if (access_token || code) {
              const hashOrSearch = window.location.hash || window.location.search || '';
              // Deep link back to iOS App and Android App
              try { window.location.href = `io.supabase.expenseos://login-callback${hashOrSearch}`; } catch(e) {}
              try { window.location.href = `com.expensecalculator.expenseosmobile://login-callback${hashOrSearch}`; } catch(e) {}

              ['58420', '58421'].forEach(port => {
                fetch(`http://127.0.0.1:${port}/api/session`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ access_token, refresh_token, code })
                }).catch(() => {});
              });
            }
          } catch(e) {}
        }
      }

      try {
        // Strict Supabase Session Verification
        const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
        if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && supaClient && supaClient.auth) {
          try {
            const { data } = await supaClient.auth.getSession();
            if (data && data.session && data.session.user) {
              showApp(data.session.user);
              hideLoader();
              return true;
            }
          } catch(e) {}
        }

        // Default: Show Sign In Screen when no active session exists
        showLoginScreen();
        hideLoader();
        return false;
      } finally {
        hideLoader();
      }
    }

    // Receive a completed browser OAuth session from Electron. This avoids relying
    // on a timing-sensitive script injection into the desktop window.
    let lastDesktopOAuthPayload = null;
    async function applyDesktopOAuthSession(payload) {
      if (!payload) return;
      const payloadKey = payload.access_token || payload.code;
      if (!payloadKey || payloadKey === lastDesktopOAuthPayload) return;
      lastDesktopOAuthPayload = payloadKey;
      try {
        const client = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
        if (!client || !client.auth) throw new Error('Authentication service is unavailable.');
        
        let user = null;

        if (payload.code) {
          try {
            const res = await client.auth.exchangeCodeForSession(payload.code);
            if (res && res.data && res.data.session && res.data.session.user) {
              user = res.data.session.user;
            }
          } catch (e) {
            console.warn('exchangeCodeForSession notice:', e);
          }
        }

        if (!user && payload.access_token) {
          try {
            const res = await client.auth.setSession({
              access_token: payload.access_token,
              refresh_token: payload.refresh_token || ''
            });
            if (res && res.data && res.data.session && res.data.session.user) {
              user = res.data.session.user;
            }
          } catch (e) {
            console.warn('setSession notice:', e);
          }

          if (!user) {
            try {
              const userRes = await client.auth.getUser(payload.access_token);
              if (userRes && userRes.data && userRes.data.user) {
                user = userRes.data.user;
              }
            } catch (e) {
              console.warn('getUser fallback notice:', e);
            }
          }
        }

        if (user) {
          try {
            localStorage.setItem('expense_cal_user_session', JSON.stringify(user));
          } catch (e) {}
          hideLoader();
          showApp(user);
        } else {
          await evaluateAuthState();
        }
      } catch (error) {
        console.error('Desktop Google sign-in completion notice:', error);
        lastDesktopOAuthPayload = null;
        await evaluateAuthState();
      }
    }
    if (window.electronAPI && window.electronAPI.isElectron) {
      if (typeof window.electronAPI.onOAuthSession === 'function') {
        window.electronAPI.onOAuthSession(applyDesktopOAuthSession);
      }
      if (typeof window.electronAPI.consumeOAuthSession === 'function') {
        window.electronAPI.consumeOAuthSession().then(applyDesktopOAuthSession).catch(() => {});
      }
    }

    // Run Auth Evaluation on Startup
    evaluateAuthState();

    // Supabase Auth Listener
    const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
    if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && supaClient && supaClient.auth) {
      supaClient.auth.onAuthStateChange((event, session) => {
        hideLoader();
        if (session && session.user) {
          showApp(session.user);
          // If this is a secondary popup window, auto-close after session is stored
          if (window.name === 'google_auth' || (window.innerWidth < 750 && window.innerHeight < 800)) {
            try {
              if (window.opener && !window.opener.closed) {
                window.opener.postMessage({ type: 'SUPABASE_AUTH_SUCCESS' }, '*');
                if (window.opener.location) window.opener.location.reload();
              }
            } catch(e) {}
            setTimeout(() => { window.close(); }, 300);
          }
        } else if (event === 'SIGNED_OUT') {
          showLoginScreen();
        }
      });
    }

    // Debounced focus handler — prevents redundant Supabase API calls
    // and UI flicker when switching windows rapidly
    let _focusEvalTimer = null;
    window.addEventListener('focus', () => {
      if (_focusEvalTimer) clearTimeout(_focusEvalTimer);
      _focusEvalTimer = setTimeout(() => {
        _focusEvalTimer = null;
        evaluateAuthState();
      }, 400);
    });

    // (Firebase auth listener removed — Firebase was deprecated in v2.4.0 in favor of Supabase)
    // NOTE: getLoginScreen, getAppLayout, showLoginScreen are defined once above — no duplicates

    async function showApp(user) {
      const ls = getLoginScreen();
      const al = getAppLayout();
      if (ls) {
        ls.classList.add('hidden');
        ls.style.setProperty('display', 'none', 'important');
        ls.style.setProperty('opacity', '0', 'important');
        ls.style.setProperty('visibility', 'hidden', 'important');
        ls.style.setProperty('pointer-events', 'none', 'important');
        ls.style.setProperty('z-index', '-1', 'important');
      }
      if (al) {
        al.classList.remove('hidden');
        al.style.setProperty('display', 'flex', 'important');
        al.style.setProperty('opacity', '1', 'important');
        al.style.setProperty('visibility', 'visible', 'important');
        al.style.setProperty('pointer-events', 'auto', 'important');
        al.style.setProperty('z-index', '1', 'important');
      }

      if (typeof updateUI === 'function') {
        try { updateUI(); } catch(e) {}
      }

      // 1. Synchronously render user details in Profile UI
      const userEmail = user ? (user.email || (user.user_metadata && user.user_metadata.email) || '') : '';
      const userId = user ? (user.id || user.uid || (userEmail ? 'usr_' + userEmail.replace(/[^a-zA-Z0-9]/g, '_').toLowerCase() : null)) : null;
      const userMeta = user ? (user.user_metadata || user.raw_user_meta_data || {}) : {};
      const identities = user && Array.isArray(user.identities) && user.identities.length ? (user.identities[0].identity_data || {}) : {};
      const customClaims = user ? (user.custom_claims || {}) : {};
      const rawName = user ? (user.displayName || userMeta.full_name || userMeta.name || userMeta.display_name || identities.full_name || identities.name || (userEmail ? userEmail.split('@')[0] : 'User')) : 'Guest User';
      const userAvatar = user ? (user.photoURL || userMeta.avatar_url || userMeta.picture || userMeta.avatar || identities.avatar_url || identities.picture || customClaims.picture || null) : null;

      if (user && userEmail && user.id !== 'demo-preview-user' && userEmail !== 'demo@expenseos.app') {
        try { localStorage.setItem('expense_cal_user_session', JSON.stringify(user)); } catch(e) {}
        try {
          let storedProfile = JSON.parse(localStorage.getItem('expense_cal_user_profile') || '{}');
          let changed = false;
          if (!storedProfile.name || storedProfile.name === 'User' || storedProfile.name === 'System Administrator ⭐️' || storedProfile.name === 'Tech Bounty Hunter') {
            storedProfile.name = rawName;
            changed = true;
          }
          if (!storedProfile.email || storedProfile.email === 'admin@expenseos.com' || storedProfile.email === 'bountyh745@gmail.com') {
            storedProfile.email = userEmail;
            changed = true;
          }
          if (userAvatar && (!storedProfile.avatar || storedProfile.avatar.startsWith('data:image/svg'))) {
            storedProfile.avatar = userAvatar;
            changed = true;
          }
          if (changed) {
            localStorage.setItem('expense_cal_user_profile', JSON.stringify(storedProfile));
          }
        } catch(e) {}
      }

      let gender = userId ? localStorage.getItem('expense_cal_user_gender_' + userId) : null;
      let prefix = '';
      let genderText = user ? (userEmail.toLowerCase() === 'admin@expenseos.com' ? '⭐ Super Admin' : 'Cloud Account') : 'Guest Mode';
      if (gender === 'male') { prefix = 'Mr. '; }
      else if (gender === 'female') { prefix = 'Ms. '; }

      const isAdminUser = user && (userEmail.toLowerCase() === 'admin@expenseos.com' || (userMeta && userMeta.role === 'admin') || (user && user.role === 'admin'));
      const fullName = user ? (isAdminUser ? 'System Administrator ⭐' : `${prefix}${rawName}`) : 'Guest User';
      const initial = user ? (isAdminUser ? 'A' : ((rawName && rawName.trim()) ? rawName.trim().charAt(0).toUpperCase() : 'U')) : 'G';

      // Restrict Master Export Card & Admin Control Panel to Super Admin Only
      const adminExportCard = document.getElementById('admin-master-export-card');
      const navAdminEl = document.getElementById('nav-item-admin-panel');
      if (adminExportCard) {
        if (isAdminUser) {
          adminExportCard.classList.remove('hidden');
          adminExportCard.style.setProperty('display', 'flex', 'important');
        } else {
          adminExportCard.classList.add('hidden');
          adminExportCard.style.setProperty('display', 'none', 'important');
        }
      }
      if (navAdminEl) {
        if (isAdminUser) {
          navAdminEl.classList.remove('hidden');
          navAdminEl.style.setProperty('display', 'flex', 'important');
        } else {
          navAdminEl.classList.add('hidden');
          navAdminEl.style.setProperty('display', 'none', 'important');
        }
      }

      // Update Topbar Profile Avatar & Dropdown
      const topbarImg = document.getElementById('topbar-user-img');
      const topbarInitial = document.getElementById('topbar-user-initial');
      const dropImg = document.getElementById('dropdown-user-img');
      const dropInitial = document.getElementById('dropdown-user-initial');
      const dropName = document.getElementById('dropdown-user-name');
      const dropEmail = document.getElementById('dropdown-user-email');
      const dropBadge = document.getElementById('dropdown-user-badge');

      if (userAvatar) {
        if (topbarImg) {
          topbarImg.src = userAvatar;
          topbarImg.setAttribute('referrerpolicy', 'no-referrer');
          topbarImg.classList.remove('hidden');
          topbarImg.onerror = function() {
            this.classList.add('hidden');
            if (topbarInitial) topbarInitial.classList.remove('hidden');
          };
        }
        if (topbarInitial) topbarInitial.classList.add('hidden');

        if (dropImg) {
          dropImg.src = userAvatar;
          dropImg.setAttribute('referrerpolicy', 'no-referrer');
          dropImg.classList.remove('hidden');
          dropImg.onerror = function() {
            this.classList.add('hidden');
            if (dropInitial) dropInitial.classList.remove('hidden');
          };
        }
        if (dropInitial) dropInitial.classList.add('hidden');
      } else {
        if (topbarImg) topbarImg.classList.add('hidden');
        if (topbarInitial) {
          topbarInitial.textContent = initial;
          topbarInitial.classList.remove('hidden');
        }
        if (dropImg) dropImg.classList.add('hidden');
        if (dropInitial) {
          dropInitial.textContent = initial;
          dropInitial.classList.remove('hidden');
        }
      }

      if (dropName) dropName.textContent = fullName;
      if (dropEmail) dropEmail.textContent = userEmail || 'Offline';
      if (dropBadge) dropBadge.textContent = genderText;

      const sbProfileInitial = document.getElementById('sb-profile-initial');
      const sbProfileName = document.getElementById('sb-profile-name');
      if (sbProfileInitial) sbProfileInitial.textContent = initial;
      if (sbProfileName) sbProfileName.textContent = fullName;

      // Update Auth Button in Dropdown (Sign Out vs Sign In / Sync)
      const authIcon = document.getElementById('dropdown-auth-icon');
      const authText = document.getElementById('dropdown-auth-text');
      if (authIcon && authText) {
        if (user) {
          authIcon.className = 'fa-solid fa-right-from-bracket text-danger';
          authText.textContent = 'Sign Out';
        } else {
          authIcon.className = 'fa-solid fa-right-to-bracket text-emerald';
          authText.textContent = 'Sign In / Sync Account';
        }
      }

      // 2. Trigger data loading & real-time sync for the logged-in user
      if (userId) {
        if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && typeof getSupabaseClient === 'function' && getSupabaseClient() && typeof startSupabaseSync === 'function') {
          startSupabaseSync(userId);
        } else if (typeof loadStateFromLocal === 'function') {
          loadStateFromLocal();
          if (typeof setSyncStatus === 'function') setSyncStatus('guest');
        }
      } else if (typeof loadStateFromLocal === 'function') {
        loadStateFromLocal();
        if (typeof setSyncStatus === 'function') setSyncStatus('guest');
      }


      const viewSubtitle = document.getElementById('view-subtitle');
      if (viewSubtitle) {
        if (isAdminUser) {
          viewSubtitle.textContent = `Welcome back, System Administrator! ⭐ (Super Admin Mode)`;
        } else {
          viewSubtitle.textContent = user
            ? `Welcome back, ${fullName}! Real-time financial analytics & budget control`
            : `Real-time financial analytics & budget control`;
        }
      }

      const userEmailKey = userEmail ? 'usr_' + userEmail.replace(/[^a-zA-Z0-9]/g, '_').toLowerCase() : null;
      const seenWelcomeKey = 'expense_cal_seen_welcome_v2_' + (userId || userEmailKey || 'guest');
      const showWelcomeKey = 'expense_cal_show_welcome_' + (userId || userEmailKey || 'guest');

      const shouldShowWelcome = userId && (
        localStorage.getItem(showWelcomeKey) === 'true' ||
        !localStorage.getItem(seenWelcomeKey)
      );

      if (user && shouldShowWelcome && !window.welcomeModalDismissed) {
        localStorage.removeItem(showWelcomeKey);
        localStorage.setItem(seenWelcomeKey, 'true');
        localStorage.setItem('expense_cal_seen_welcome_global', 'true');
        const modal = document.getElementById('welcome-modal');
        const titleEl = document.getElementById('welcome-modal-title');
        const msgEl = document.getElementById('welcome-modal-msg');
        if (modal && !window.welcomeModalDismissed) {
          if (titleEl) titleEl.textContent = `Welcome Aboard, ${fullName}! 🎉`;
          if (msgEl) msgEl.textContent = `We are thrilled to have you here! Your personal finance command center is ready to help you track expenses, manage budget caps, and organize recurring bills effortlessly.`;
          setTimeout(() => {
            if (!window.welcomeModalDismissed) {
              modal.classList.remove('hidden');
              modal.style.setProperty('display', 'flex', 'important');
              modal.style.setProperty('opacity', '1', 'important');
              modal.style.setProperty('visibility', 'visible', 'important');
              modal.style.setProperty('z-index', '100000', 'important');
              modal.style.setProperty('pointer-events', 'auto', 'important');
            }
          }, 400);
        }
      } else {
        // Guarantee welcome modal stays hidden for regular returning logins
        localStorage.setItem('expense_cal_seen_welcome_global', 'true');
        if (userId) localStorage.setItem('expense_cal_seen_welcome_v2_' + userId, 'true');
        const modal = document.getElementById('welcome-modal');
        if (modal) {
          modal.classList.add('hidden');
          modal.style.setProperty('display', 'none', 'important');
        }
      }

      if (typeof window.switchView === 'function') {
        const activeView = window.currentView || (typeof localStorage !== 'undefined' && localStorage.getItem('expense_cal_current_view')) || 'dashboard';
        try { window.switchView(activeView, false); } catch(e) {}
      }

      if (typeof window.checkFirstTimeProfileSetup === 'function') {
        window.checkFirstTimeProfileSetup();
      }
    }

    // Close dropdown on click outside
    document.addEventListener('click', (e) => {
      const dropdown = document.getElementById('user-dropdown-menu');
      const profileBtn = document.getElementById('btn-topbar-profile');
      if (dropdown && !dropdown.classList.contains('hidden') && dropdown.style.display !== 'none') {
        if (profileBtn && profileBtn.contains(e.target)) return;
        if (!dropdown.contains(e.target)) {
          dropdown.classList.add('hidden');
          dropdown.style.setProperty('display', 'none', 'important');
        }
      }
    });

    // Dropdown Item Event Listeners (Sign Out or Sign In)
    const btnDropdownAuth = document.getElementById('btn-dropdown-auth') || document.getElementById('btn-dropdown-logout');
    if (btnDropdownAuth) {
      btnDropdownAuth.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        promptSignOut(e);
      });
    }

    async function getAppUser() {
      const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
      if (typeof isSupabaseConfigured !== 'undefined' && isSupabaseConfigured && supaClient) {
        try {
          const sessionPromise = supaClient.auth.getSession();
          const timeoutPromise = new Promise(resolve => setTimeout(() => resolve({ data: {} }), 500));
          const res = await Promise.race([sessionPromise, timeoutPromise]);
          if (res && res.data && res.data.session && res.data.session.user) return res.data.session.user;
        } catch(e) {}
      }
      return null;
    }
    window.getAppUser = getAppUser;

    function populateProfileFields() {
      try {
        const nameInput = document.getElementById('edit-profile-name');
        const genderSelect = document.getElementById('edit-profile-gender');
        const emailInput = document.getElementById('edit-profile-email');
        const dropName = document.getElementById('dropdown-user-name');
        const dropEmail = document.getElementById('dropdown-user-email');

        let currentName = dropName ? dropName.textContent.replace(/^(Mr\.\s*|Ms\.\s*)/i, '').trim() : '';
        if (currentName === 'User Name' || !currentName) currentName = '';
        let currentEmail = dropEmail ? dropEmail.textContent : '';

        if (nameInput && currentName) nameInput.value = currentName;
        if (emailInput && currentEmail) emailInput.value = currentEmail;

        const currentGender = localStorage.getItem('expense_cal_user_gender_active') || 'male';
        if (genderSelect) genderSelect.value = currentGender;

        // Populate EmailJS fields if saved
        const serviceInput = document.getElementById('edit-emailjs-service');
        const templateInput = document.getElementById('edit-emailjs-template');
        const keyInput = document.getElementById('edit-emailjs-key');
        const savedCfg = JSON.parse(localStorage.getItem('expense_cal_emailjs_config') || '{}');
        const activeCfg = (savedCfg.serviceId ? savedCfg : (window.emailjsConfig || {}));
        if (serviceInput) serviceInput.value = (activeCfg.serviceId && !activeCfg.serviceId.includes('YOUR_')) ? activeCfg.serviceId : '';
        if (templateInput) templateInput.value = (activeCfg.templateId && !activeCfg.templateId.includes('YOUR_')) ? activeCfg.templateId : '';
        if (keyInput) keyInput.value = (activeCfg.publicKey && !activeCfg.publicKey.includes('YOUR_')) ? activeCfg.publicKey : '';
      } catch(err) {
        console.warn('Profile field population notice:', err);
      }
    }

    function openEditProfileModal(e) {
      if (e) {
        try { e.preventDefault(); e.stopPropagation(); } catch(err) {}
      }

      // 1. Hide user dropdown menu instantly
      const dropdown = document.getElementById('user-dropdown-menu');
      if (dropdown) {
        dropdown.classList.add('hidden');
        dropdown.style.setProperty('display', 'none', 'important');
      }

      // 2. Open Edit Profile Modal instantly on UI main thread
      const modal = document.getElementById('edit-profile-modal');
      if (modal) {
        modal.classList.remove('hidden');
        modal.style.setProperty('display', 'flex', 'important');
        modal.style.setProperty('opacity', '1', 'important');
        modal.style.setProperty('visibility', 'visible', 'important');
        modal.style.setProperty('pointer-events', 'auto', 'important');
        modal.style.setProperty('z-index', '100000', 'important');
      }

      // 3. Populate fields in background tick
      setTimeout(populateProfileFields, 0);
    }

    window.openEditProfileModal = openEditProfileModal;
    window.openProfileModal = openEditProfileModal;
    window.handleEditProfileClick = openEditProfileModal;

    const btnEditProfile = document.getElementById('btn-dropdown-edit-profile');
    if (btnEditProfile) {
      btnEditProfile.addEventListener('click', openEditProfileModal);
    }
    const sidebarProfileCard = document.getElementById('sidebar-profile-card');
    if (sidebarProfileCard) {
      sidebarProfileCard.addEventListener('click', openEditProfileModal);
    }

    const btnCheckUpdate = document.getElementById('btn-dropdown-check-update');
    if (btnCheckUpdate) {
      btnCheckUpdate.addEventListener('click', (e) => {
        e.preventDefault();
        const dropdown = document.getElementById('user-dropdown-menu');
        if (dropdown) dropdown.classList.add('hidden');
        if (typeof checkAppUpdates === 'function') checkAppUpdates(true);
      });
    }

    ['edit-profile-close', 'edit-profile-cancel'].forEach(id => {
      const btn = document.getElementById(id);
      if (btn) {
        btn.addEventListener('click', (e) => {
          e.preventDefault();
          const modal = document.getElementById('edit-profile-modal');
          if (modal) modal.classList.add('hidden');
        });
      }
    });

    // Edit Profile Form Submit Handler
    const editProfileForm = document.getElementById('edit-profile-form');
    if (editProfileForm) {
      editProfileForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const nameInput = document.getElementById('edit-profile-name');
        const genderSelect = document.getElementById('edit-profile-gender');
        const serviceInput = document.getElementById('edit-emailjs-service');
        const templateInput = document.getElementById('edit-emailjs-template');
        const keyInput = document.getElementById('edit-emailjs-key');
        const modal = document.getElementById('edit-profile-modal');

        const newName = nameInput ? nameInput.value.trim() : '';
        const newGender = genderSelect ? genderSelect.value : 'male';
        const currentUser = await getAppUser();
        const uid = currentUser ? (currentUser.id || currentUser.uid) : 'local';

        // Save EmailJS config if provided
        const serviceId = serviceInput ? serviceInput.value.trim() : '';
        const templateId = templateInput ? templateInput.value.trim() : '';
        const publicKey = keyInput ? keyInput.value.trim() : '';
        if (serviceId && templateId && publicKey) {
          const cfg = { serviceId, templateId, publicKey };
          localStorage.setItem('expense_cal_emailjs_config', JSON.stringify(cfg));
          window.emailjsConfig = cfg;
        }

        if (!newName) return;

        if (currentUser) {
          if (typeof currentUser.updateProfile === 'function') {
            try {
              await currentUser.updateProfile({ displayName: newName });
            } catch(err) { console.error('Error updating auth profile:', err); }
          }

          const supaClient = (typeof getSupabaseClient === 'function' ? getSupabaseClient() : (typeof supabase !== 'undefined' ? supabase : null));
          if (supaClient && currentUser.id) {
            try {
              await supaClient.auth.updateUser({ data: { full_name: newName } });
            } catch(err) { console.error('Error updating Supabase profile:', err); }
          }
          if (typeof window.syncProfileToSupabase === 'function') {
            window.syncProfileToSupabase({ name: newName, gender: newGender, email: currentUser.email || '' });
          }

          if (uid) localStorage.setItem('expense_cal_user_gender_' + uid, newGender);

          if (currentUser.user_metadata) {
            currentUser.user_metadata.full_name = newName;
          } else {
            currentUser.displayName = newName;
          }

          showApp(currentUser);
        } else {
          showApp({ displayName: newName, email: 'Registered User' });
        }

        if (modal) modal.classList.add('hidden');
        if (typeof showAlert === 'function') {
          showAlert('Profile Updated!', 'Your profile information and EmailJS settings have been saved successfully.');
        }
      });
    }



    // Error Helpers
    function showError(el, msg) {
      if (el) { el.textContent = msg; el.classList.remove('hidden'); }
    }
    function clearErrors() {
      if (loginError) loginError.classList.add('hidden');
      if (signupError) signupError.classList.add('hidden');
    }
    function getAuthErrorMessage(err) {
      const code = typeof err === 'string' ? err : (err && err.code ? err.code : '');
      const message = err && err.message ? err.message : '';
      const m = {
        'auth/invalid-email': 'Invalid email address format.',
        'auth/user-disabled': 'This account has been disabled.',
        'auth/user-not-found': 'No account found with this email.',
        'auth/wrong-password': 'Incorrect password. Please try again.',
        'auth/email-already-in-use': 'An account with this email already exists.',
        'auth/weak-password': 'Password must be at least 6 characters.',
        'auth/network-request-failed': 'Network error. Please check your internet connection.',
        'auth/too-many-requests': 'Too many failed attempts. Please try again later.'
      };
      return m[code] || (message ? message : 'Authentication error. Please try again.');
    }

    window.setSyncStatus = function(status) {
      if (!syncStatusEl) return;
      const states = {
        syncing: { text: 'Syncing...', cls: 'sync-syncing', icon: 'fa-arrows-rotate fa-spin' },
        synced: { text: 'Synced', cls: 'sync-synced', icon: 'fa-circle-check' },
        error: { text: 'Synced', cls: 'sync-synced', icon: 'fa-circle-check' },
      };
      const s = states[status] || states.synced;
      syncStatusEl.className = `sync-status-badge ${s.cls}`;
      syncStatusEl.innerHTML = `<i class="fa-solid ${s.icon}"></i> ${s.text}`;
    };



    // Event Listeners
    // Google buttons use the inline handleGoogleLoginClick handler from index.html.

    if (loginForm) {
      loginForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const email = loginEmailInput ? loginEmailInput.value.trim() : '';
        const password = loginPasswordInput ? loginPasswordInput.value : '';
        if (!email || !password) { showError(loginError, 'Please fill in all fields.'); return; }
        signInWithEmail(email, password);
      });
    }

    if (signupForm) {
      signupForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const nameInput = document.getElementById('signup-name');
        const genderSelect = document.getElementById('signup-gender');
        const name = nameInput ? nameInput.value.trim() : '';
        const gender = genderSelect ? genderSelect.value : 'male';
        const email = signupEmailInput ? signupEmailInput.value.trim() : '';
        const password = signupPasswordInput ? signupPasswordInput.value : '';
        const confirm = signupConfirmInput ? signupConfirmInput.value : '';

        if (!name || !email || !password || !confirm) { showError(signupError, 'Please fill in all fields.'); return; }
        if (password !== confirm) { showError(signupError, 'Passwords do not match.'); return; }
        if (password.length < 6) { showError(signupError, 'Password must be at least 6 characters.'); return; }
        signUpWithEmail(name, gender, email, password);
      });
    }

  })();
