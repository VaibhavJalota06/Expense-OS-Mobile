/* ==========================================================================
   Expense OS - Modern Financial Ambient Landing Script Engine
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {

  // ---------- 0. Cosmic Preloader Lifecycle Controller ----------
  const preloader = document.getElementById('landing-preloader');
  const progressBar = document.getElementById('preloader-progress-bar');
  const statusText = document.getElementById('preloader-status-text');

  if (preloader) {
    let progress = 35;
    if (progressBar) progressBar.style.width = '35%';

    const progressInterval = setInterval(() => {
      if (progress < 90) {
        progress += 20;
        if (progressBar) progressBar.style.width = `${progress}%`;
        if (statusText && progress > 60) statusText.textContent = 'INITIALIZING SYSTEM...';
      }
    }, 60);

    const finishPreloader = () => {
      clearInterval(progressInterval);
      if (progressBar) progressBar.style.width = '100%';
      if (statusText) statusText.textContent = 'EXPENSE OS READY';

      setTimeout(() => {
        preloader.classList.add('loaded');
        setTimeout(() => {
          if (preloader && preloader.parentNode) {
            preloader.style.display = 'none';
          }
        }, 500);
      }, 150);
    };

    setTimeout(finishPreloader, 450);
  }

  // ---------- 1. Soothing Financial Ambient Node Canvas ----------
  const canvas = document.getElementById('bg-canvas');
  if (canvas) {
    const ctx = canvas.getContext('2d');
    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;

    let mouseX = width / 2;
    let mouseY = height / 2;

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    });

    window.addEventListener('mousemove', (e) => {
      mouseX = e.clientX;
      mouseY = e.clientY;
    });

    const nodeCount = Math.min(Math.floor(window.innerWidth / 22), 55);
    const nodes = [];
    const colors = ['rgba(52, 211, 153, ', 'rgba(56, 189, 248, ', 'rgba(167, 139, 250, '];

    for (let i = 0; i < nodeCount; i++) {
      nodes.push({
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * 0.45,
        vy: (Math.random() - 0.5) * 0.45,
        radius: Math.random() * 1.6 + 1.0,
        baseAlpha: Math.random() * 0.35 + 0.15,
        colorPrefix: colors[Math.floor(Math.random() * colors.length)]
      });
    }

    function animateAmbientNetwork() {
      ctx.clearRect(0, 0, width, height);

      // Draw subtle connecting links
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const dx = nodes[i].x - nodes[j].x;
          const dy = nodes[i].y - nodes[j].y;
          const dist = Math.sqrt(dx * dx + dy * dy);

          if (dist < 140) {
            const alpha = (1 - dist / 140) * 0.12;
            ctx.beginPath();
            ctx.moveTo(nodes[i].x, nodes[i].y);
            ctx.lineTo(nodes[j].x, nodes[j].y);
            ctx.strokeStyle = `rgba(148, 163, 184, ${alpha})`;
            ctx.lineWidth = 0.8;
            ctx.stroke();
          }
        }
      }

      // Update & draw nodes
      nodes.forEach(node => {
        // Move slowly
        node.x += node.vx;
        node.y += node.vy;

        // Soft bounce at boundaries
        if (node.x < 0 || node.x > width) node.vx *= -1;
        if (node.y < 0 || node.y > height) node.vy *= -1;

        // Subtle mouse interactivity
        const mdx = node.x - mouseX;
        const mdy = node.y - mouseY;
        const mDist = Math.sqrt(mdx * mdx + mdy * mdy);
        if (mDist < 120) {
          const push = (1 - mDist / 120) * 0.3;
          node.x += (mdx / mDist) * push;
          node.y += (mdy / mDist) * push;
        }

        ctx.beginPath();
        ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
        ctx.fillStyle = `${node.colorPrefix}${node.baseAlpha})`;
        ctx.shadowBlur = 8;
        ctx.shadowColor = 'rgba(56, 189, 248, 0.4)';
        ctx.fill();
        ctx.shadowBlur = 0;
      });

      requestAnimationFrame(animateAmbientNetwork);
    }

    animateAmbientNetwork();
  }

  // ---------- 2. Navbar Scroll Elevation ----------
  const navbar = document.querySelector('.navbar');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 40) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });

  // ---------- 4. Live FX Currency Calculation Matrix ----------
  const fxRates = {
    USD: 1.0,
    EUR: 0.92,
    GBP: 0.79,
    INR: 83.50,
    CAD: 1.36,
    JPY: 154.20
  };

  const fxSymbols = {
    USD: '$',
    EUR: '€',
    GBP: '£',
    INR: '₹',
    CAD: 'CA$',
    JPY: '¥'
  };

  const fxAmountInput = document.getElementById('fx-amount');
  const fxFromSelect = document.getElementById('fx-from');
  const fxToSelect = document.getElementById('fx-to');
  const fxResult = document.getElementById('fx-result');

  function calculateFx() {
    if (!fxAmountInput || !fxFromSelect || !fxToSelect || !fxResult) return;
    const amt = parseFloat(fxAmountInput.value) || 0;
    const from = fxFromSelect.value;
    const to = fxToSelect.value;

    const baseInUsd = amt / (fxRates[from] || 1.0);
    const converted = baseInUsd * (fxRates[to] || 1.0);
    const symbol = fxSymbols[to] || '';

    fxResult.textContent = `${symbol}${converted.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${to}`;
  }

  if (fxAmountInput) fxAmountInput.addEventListener('input', calculateFx);
  if (fxFromSelect) fxFromSelect.addEventListener('change', calculateFx);
  if (fxToSelect) fxToSelect.addEventListener('change', calculateFx);
  calculateFx();

  // ---------- 5. AI Categorization Classifier Simulation ----------
  const aiInput = document.getElementById('ai-sim-input');
  const aiResult = document.getElementById('ai-sim-result');

  const categoryMap = [
    { keywords: ['coffee', 'starbucks', 'cafe', 'mcdonald', 'burger', 'pizza', 'restaurant', 'food', 'dinner', 'lunch', 'swiggy', 'zomato'], category: '☕ Food & Dining', color: 'var(--planet-emerald)' },
    { keywords: ['uber', 'lyft', 'fuel', 'petrol', 'gas', 'shell', 'flight', 'airline', 'taxi', 'metro', 'train'], category: '🚗 Travel & Commute', color: 'var(--planet-blue)' },
    { keywords: ['netflix', 'spotify', 'prime', 'hulu', 'game', 'playstation', 'cinema', 'movie'], category: '🎬 Entertainment', color: 'var(--planet-purple)' },
    { keywords: ['grocery', 'whole foods', 'walmart', 'supermarket', 'market', 'veggies', 'milk'], category: '🛒 Groceries', color: 'var(--planet-gold)' },
    { keywords: ['amazon', 'apple', 'nike', 'clothes', 'shoes', 'electronics', 'shopping'], category: '🛍️ Shopping', color: 'var(--planet-cyan)' },
    { keywords: ['rent', 'electricity', 'water', 'wifi', 'internet', 'broadband', 'utility', 'bill'], category: '💡 Utilities & Bills', color: '#f43f5e' }
  ];

  function classifyExpense() {
    if (!aiInput || !aiResult) return;
    const val = aiInput.value.toLowerCase().trim();
    if (!val) {
      aiResult.textContent = '⚡ Type an expense...';
      aiResult.style.color = 'var(--text-dim)';
      return;
    }

    let found = categoryMap.find(c => c.keywords.some(k => val.includes(k)));
    if (!found) {
      found = { category: '💼 General Expense', color: 'var(--planet-cyan)' };
    }

    aiResult.textContent = found.category;
    aiResult.style.color = found.color;
  }

  if (aiInput) {
    aiInput.addEventListener('input', classifyExpense);
    classifyExpense();
  }

  // ---------- 5b. Interactive Yearly Savings Simulator ----------
  const simSpendSlider = document.getElementById('sim-spend');
  const simSpendVal = document.getElementById('sim-spend-val');
  const simSavingsResult = document.getElementById('sim-savings-result');

  function updateSavingsSim() {
    if (!simSpendSlider || !simSpendVal || !simSavingsResult) return;
    const spend = parseFloat(simSpendSlider.value) || 1800;
    simSpendVal.textContent = `$${spend.toLocaleString()} / mo`;

    // 18% average optimization rate via AI budget capping
    const annualSavings = Math.round(spend * 12 * 0.18);
    simSavingsResult.textContent = `+$${annualSavings.toLocaleString()}.00 / yr`;
  }

  if (simSpendSlider) {
    simSpendSlider.addEventListener('input', updateSavingsSim);
    updateSavingsSim();
  }

  // ---------- 6. Interactive 3D Showcase Tabs ----------
  const showcaseScreens = {
    dashboard: `
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 1.5rem;">
        <div class="glass-panel" style="padding: 1.25rem; background: rgba(16, 185, 129, 0.08); border-color: rgba(16, 185, 129, 0.3);">
          <div style="font-size: 0.75rem; color: var(--planet-emerald); text-transform: uppercase; font-weight: 700;">Net Balance</div>
          <div style="font-size: 1.5rem; font-weight: 800; color: #fff; margin-top: 4px;">$14,250.00</div>
          <div style="font-size: 0.75rem; color: var(--planet-emerald); margin-top: 4px;">↑ +18.4% this month</div>
        </div>
        <div class="glass-panel" style="padding: 1.25rem; background: rgba(56, 189, 248, 0.08); border-color: rgba(56, 189, 248, 0.3);">
          <div style="font-size: 0.75rem; color: var(--planet-blue); text-transform: uppercase; font-weight: 700;">Monthly Income</div>
          <div style="font-size: 1.5rem; font-weight: 800; color: #fff; margin-top: 4px;">$6,500.00</div>
          <div style="font-size: 0.75rem; color: var(--text-dim); margin-top: 4px;">Paycheck received</div>
        </div>
        <div class="glass-panel" style="padding: 1.25rem; background: rgba(244, 63, 94, 0.08); border-color: rgba(244, 63, 94, 0.3);">
          <div style="font-size: 0.75rem; color: #fb7185; text-transform: uppercase; font-weight: 700;">Total Spending</div>
          <div style="font-size: 1.5rem; font-weight: 800; color: #fff; margin-top: 4px;">$2,145.80</div>
          <div style="font-size: 0.75rem; color: #34d399; margin-top: 4px;">$1,854.20 left in budget</div>
        </div>
      </div>
      <div style="font-size: 0.85rem; color: var(--text-dim); text-align: center;">✓ Everything is saved automatically and synced across your devices.</div>
    `,
    bills: `
      <div style="display: flex; flex-direction: column; gap: 0.75rem;">
        <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1.25rem; background: rgba(255, 255, 255, 0.03); border-radius: 8px; border: 1px solid var(--glass-border);">
          <div style="display: flex; align-items: center; gap: 0.75rem;">
            <div style="width: 36px; height: 36px; border-radius: 8px; background: rgba(239, 68, 68, 0.15); color: #ef4444; display: flex; align-items: center; justify-content: center; font-weight: 800;">N</div>
            <div>
              <div style="font-weight: 700; color: #fff;">Netflix Subscription</div>
              <div style="font-size: 0.75rem; color: var(--text-dim);">Due on the 28th of every month</div>
            </div>
          </div>
          <div style="text-align: right;">
            <div style="font-weight: 800; color: #fff;">$22.99 / mo</div>
            <div style="font-size: 0.75rem; color: var(--planet-emerald);">● Recurring Bill</div>
          </div>
        </div>
        <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1.25rem; background: rgba(255, 255, 255, 0.03); border-radius: 8px; border: 1px solid var(--glass-border);">
          <div style="display: flex; align-items: center; gap: 0.75rem;">
            <div style="width: 36px; height: 36px; border-radius: 8px; background: rgba(16, 185, 129, 0.15); color: #10b981; display: flex; align-items: center; justify-content: center; font-weight: 800;">S</div>
            <div>
              <div style="font-weight: 700; color: #fff;">Spotify Premium</div>
              <div style="font-size: 0.75rem; color: var(--text-dim);">Due on the 15th of every month</div>
            </div>
          </div>
          <div style="text-align: right;">
            <div style="font-weight: 800; color: #fff;">$16.99 / mo</div>
            <div style="font-size: 0.75rem; color: var(--planet-emerald);">● Recurring Bill</div>
          </div>
        </div>
      </div>
    `,
    split: `
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem;">
        <div class="glass-panel" style="padding: 1.25rem;">
          <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.5rem;">
            <span style="font-weight: 700; color: #fff;">Weekend Cabin Trip</span>
            <span style="font-size: 0.75rem; color: var(--planet-blue); font-family: var(--font-mono);">4 Friends</span>
          </div>
          <div style="font-size: 1.3rem; font-weight: 800; color: var(--planet-emerald);">$1,240.00 Total</div>
          <div style="font-size: 0.8rem; color: var(--text-dim); margin-top: 4px;">Your share: $310.00 (Paid)</div>
        </div>
        <div class="glass-panel" style="padding: 1.25rem;">
          <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.5rem;">
            <span style="font-weight: 700; color: #fff;">Apartment Wi-Fi Internet</span>
            <span style="font-size: 0.75rem; color: var(--planet-purple); font-family: var(--font-mono);">2 Roommates</span>
          </div>
          <div style="font-size: 1.3rem; font-weight: 800; color: var(--planet-purple);">$90.00 / mo</div>
          <div style="font-size: 0.8rem; color: var(--text-dim); margin-top: 4px;">You owe: $45.00 (Due soon)</div>
        </div>
      </div>
    `,
    export: `
      <div style="text-align: center; padding: 1rem 0;">
        <div style="font-size: 1.2rem; font-weight: 700; color: #fff; margin-bottom: 0.5rem;">Export your data anytime</div>
        <div style="display: flex; gap: 1rem; justify-content: center;">
          <a href="/index.html" target="_blank" class="hud-calc-btn" style="padding: 0.75rem 1.75rem; text-decoration: none; display: inline-flex; align-items: center; gap: 0.5rem;"><i class="fa-solid fa-file-csv"></i> Open App Exporter</a>
        </div>
      </div>
    `
  };

  window.switchShowcaseTab = function(tabKey, btn) {
    const container = document.getElementById('showcase-content');
    if (container && showcaseScreens[tabKey]) {
      container.innerHTML = showcaseScreens[tabKey];
    }
    document.querySelectorAll('.mockup-tab-btn').forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');
  };

  // Initial tab render
  window.switchShowcaseTab('dashboard', document.querySelector('.mockup-tab-btn'));

  // ---------- 7. Mobile Navigation Toggle ----------
  const mobileToggle = document.getElementById('mobile-menu-toggle');
  const navLinks = document.getElementById('nav-links');
  if (mobileToggle && navLinks) {
    mobileToggle.addEventListener('click', () => {
      const isVisible = navLinks.style.display === 'flex';
      navLinks.style.display = isVisible ? 'none' : 'flex';
      if (!isVisible) {
        navLinks.style.flexDirection = 'column';
        navLinks.style.position = 'absolute';
        navLinks.style.top = '100%';
        navLinks.style.left = '0';
        navLinks.style.right = '0';
        navLinks.style.marginTop = '0.75rem';
        navLinks.style.padding = '1.25rem';
        navLinks.style.background = 'rgba(7, 13, 26, 0.95)';
        navLinks.style.borderRadius = '16px';
        navLinks.style.border = '1px solid var(--glass-border)';
        navLinks.style.boxShadow = '0 15px 35px rgba(0,0,0,0.8)';
      }
    });

    document.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', () => {
        if (window.innerWidth <= 768) {
          navLinks.style.display = 'none';
        }
      });
    });
  }

  // ---------- 8. Live Dynamic GitHub Releases Fetcher ----------
  async function fetchLatestRelease() {
    try {
      const res = await fetch('https://api.github.com/repos/VaibhavJalota06/Expense-OS-Mobile/releases');
      if (!res.ok) return;
      const releases = await res.json();
      if (!Array.isArray(releases) || releases.length === 0) return;

      const latest = releases[0];
      const tagName = latest.tag_name || 'v3.3.6';

      // Update all release version tags on page
      document.querySelectorAll('.release-version-tag, .footer-status-text').forEach(el => {
        if (el.classList.contains('footer-status-text')) {
          el.textContent = `All Systems Operational · ${tagName}`;
        } else {
          el.textContent = tagName;
        }
      });

      // Scan releases to find latest available binaries
      let foundApk = false;
      let foundExe = false;
      let foundIpa = false;

      for (const release of releases) {
        if (Array.isArray(release.assets)) {
          for (const asset of release.assets) {
            const name = (asset.name || '').toLowerCase();
            const downloadUrl = asset.browser_download_url;

            if (!foundApk && name.endsWith('.apk') && !name.includes('debug')) {
              document.querySelectorAll('a[data-platform="android"]').forEach(btn => {
                btn.href = downloadUrl;
              });
              foundApk = true;
            }
            if (!foundExe && (name.endsWith('.exe') || name.endsWith('.msi'))) {
              document.querySelectorAll('a[data-platform="windows"]').forEach(btn => {
                btn.href = downloadUrl;
              });
              foundExe = true;
            }
            if (!foundIpa && name.endsWith('.ipa')) {
              document.querySelectorAll('a[data-platform="ios"]').forEach(btn => {
                btn.href = downloadUrl;
              });
              foundIpa = true;
            }
          }
        }
        if (foundApk && foundExe && foundIpa) break;
      }
    } catch (e) {
      console.log('Using default universal release endpoints:', e);
    }
  }

  // ---------- 9. Interactive FAQ Accordion & Live Filter ----------
  const faqContainer = document.getElementById('faq-grid-container');
  const faqSearchInput = document.getElementById('faq-search-input');

  if (faqContainer) {
    faqContainer.addEventListener('click', (e) => {
      const btn = e.target.closest('.faq-question-btn');
      if (!btn) return;

      const card = btn.closest('.faq-card');
      if (!card) return;

      const isOpen = card.classList.contains('active');

      // Close all other cards for a clean single-open accordion feel
      faqContainer.querySelectorAll('.faq-card').forEach(c => {
        if (c !== card) {
          c.classList.remove('active');
          const b = c.querySelector('.faq-question-btn');
          if (b) b.setAttribute('aria-expanded', 'false');
        }
      });

      card.classList.toggle('active', !isOpen);
      btn.setAttribute('aria-expanded', String(!isOpen));
    });
  }

  if (faqSearchInput && faqContainer) {
    faqSearchInput.addEventListener('input', () => {
      const query = faqSearchInput.value.toLowerCase().trim();
      const cards = faqContainer.querySelectorAll('.faq-card');

      cards.forEach(card => {
        const text = card.textContent.toLowerCase();
        if (!query || text.includes(query)) {
          card.style.display = 'block';
          if (query) card.classList.add('active'); // auto expand when matching search
        } else {
          card.style.display = 'none';
        }
      });
    });
  }

  // ---------- 10. Animated Numbers & Stats Counters ----------
  const statCounters = document.querySelectorAll('.stat-counter');
  if (statCounters.length > 0) {
    const observer = new IntersectionObserver((entries, obs) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const el = entry.target;
          const target = parseInt(el.getAttribute('data-target'), 10);
          if (!isNaN(target)) {
            let start = 0;
            const duration = 1200;
            const stepTime = 20;
            const steps = duration / stepTime;
            const increment = target / steps;

            const timer = setInterval(() => {
              start += increment;
              if (start >= target) {
                el.textContent = target;
                clearInterval(timer);
              } else {
                el.textContent = Math.floor(start);
              }
            }, stepTime);
          }
          obs.unobserve(el);
        }
      });
    }, { threshold: 0.5 });

    statCounters.forEach(c => observer.observe(c));
  }

  // ---------- 11. Floating Scroll-To-Top Controller ----------
  const scrollTopBtn = document.getElementById('scroll-to-top');
  if (scrollTopBtn) {
    window.addEventListener('scroll', () => {
      if (window.scrollY > 450) {
        scrollTopBtn.classList.add('visible');
      } else {
        scrollTopBtn.classList.remove('visible');
      }
    }, { passive: true });

    scrollTopBtn.addEventListener('click', () => {
      window.scrollTo({
        top: 0,
        behavior: 'smooth'
      });
    });
  }

  // ---------- 12. Device Frame Switcher (Desktop vs Mobile) ----------
  window.setMockupDevice = function(mode) {
    const frame = document.getElementById('mockup-frame-element');
    const header = document.getElementById('mockup-header-element');
    const btnDesktop = document.getElementById('btn-view-desktop');
    const btnMobile = document.getElementById('btn-view-mobile');

    if (!frame) return;

    if (mode === 'mobile') {
      frame.className = 'phone-mockup-frame';
      if (header) {
        header.innerHTML = `
          <div class="phone-island">
            <span class="phone-camera-dot"></span>
            <span style="font-size: 0.65rem; color: #94a3b8; font-family: var(--font-mono);">9:41</span>
          </div>
        `;
      }
      if (btnDesktop) btnDesktop.classList.remove('active');
      if (btnMobile) btnMobile.classList.add('active');
    } else {
      frame.className = 'mockup-frame';
      if (header) {
        header.innerHTML = `
          <div class="mockup-dots">
            <span class="dot dot-red"></span>
            <span class="dot dot-yellow"></span>
            <span class="dot dot-green"></span>
          </div>
          <div class="mockup-url-bar"><i class="fa-solid fa-lock" style="color: var(--planet-emerald); font-size: 0.7rem;"></i> https://expenseos.app/dashboard</div>
          <a href="/index.html" target="_blank" class="nav-cta-btn" style="padding: 4px 12px; font-size: 0.75rem;">
            Try Live Demo <i class="fa-solid fa-arrow-up-right-from-square"></i>
          </a>
        `;
      }
      if (btnDesktop) btnDesktop.classList.add('active');
      if (btnMobile) btnMobile.classList.remove('active');
    }
  };

  // ---------- 13. Sideloading & Installation Modal Guides ----------
  const installGuides = {
    android: `
      <div class="install-step-list">
        <div class="install-step">
          <div class="step-number">1</div>
          <div class="step-body">
            <h4>Download the APK</h4>
            <p>Tap <strong>Download APK</strong> on this page to download the latest <code>ExpenseOS-Android.apk</code> build directly.</p>
          </div>
        </div>
        <div class="install-step">
          <div class="step-number">2</div>
          <div class="step-body">
            <h4>Allow Install from Browser</h4>
            <p>When prompted by Android, tap <strong>Settings</strong> &rarr; enable <em>"Allow from this source"</em> &rarr; tap <strong>Install</strong>.</p>
          </div>
        </div>
        <div class="install-step">
          <div class="step-number">3</div>
          <div class="step-body">
            <h4>Launch &amp; Enable Biometrics</h4>
            <p>Open Expense OS from your app drawer. You can optionally enable Fingerprint / Face Unlock from Settings for instant privacy.</p>
          </div>
        </div>
      </div>
    `,
    windows: `
      <div class="install-step-list">
        <div class="install-step">
          <div class="step-number">1</div>
          <div class="step-body">
            <h4>Download Windows Executable</h4>
            <p>Click <strong>Download .EXE</strong> to get the lightweight 5MB standalone package.</p>
          </div>
        </div>
        <div class="install-step">
          <div class="step-number">2</div>
          <div class="step-body">
            <h4>SmartScreen Notice (First Run)</h4>
            <p>Because Expense OS is an indie open-source tool, Windows Defender may show a prompt. Click <strong>"More info"</strong> &rarr; <strong>"Run anyway"</strong>.</p>
          </div>
        </div>
        <div class="install-step">
          <div class="step-number">3</div>
          <div class="step-body">
            <h4>Ready to Use</h4>
            <p>Expense OS runs natively on both 64-bit and 32-bit Windows with zero background telemetry services.</p>
          </div>
        </div>
      </div>
    `,
    ios: `
      <div class="install-step-list">
        <div class="install-step">
          <div class="step-number">1</div>
          <div class="step-body">
            <h4>Download the IPA</h4>
            <p>Click <strong>Download .IPA</strong> to save the iOS package file on your computer or iPhone.</p>
          </div>
        </div>
        <div class="install-step">
          <div class="step-number">2</div>
          <div class="step-body">
            <h4>Sideload with AltStore / Sideloadly</h4>
            <p>Open <strong>AltStore</strong>, <strong>Sideloadly</strong>, <strong>TrollStore</strong>, or <strong>Scarlet</strong>, select <code>ExpenseOS-iOS.ipa</code>, and sign it with your Apple ID.</p>
          </div>
        </div>
        <div class="install-step">
          <div class="step-number">3</div>
          <div class="step-body">
            <h4>Trust Developer Certificate</h4>
            <p>On your iPhone, go to <em>Settings &rarr; General &rarr; VPN &amp; Device Management</em> &rarr; tap your Apple ID &rarr; tap <strong>Trust</strong>.</p>
          </div>
        </div>
      </div>
    `,
    web: `
      <div class="install-step-list">
        <div class="install-step">
          <div class="step-number">1</div>
          <div class="step-body">
            <h4>Launch in Any Browser</h4>
            <p>Open <strong><a href="/index.html" target="_blank" style="color: var(--planet-blue); text-decoration: underline;">https://expenseos.app</a></strong> on Chrome, Safari, Edge, or Firefox.</p>
          </div>
        </div>
        <div class="install-step">
          <div class="step-number">2</div>
          <div class="step-body">
            <h4>Install as Desktop App / Home Screen Shortcut</h4>
            <p>Click the <strong>Install</strong> icon in the address bar (Chrome/Edge), or tap <strong>Share &rarr; Add to Home Screen</strong> on iOS Safari.</p>
          </div>
        </div>
        <div class="install-step">
          <div class="step-number">3</div>
          <div class="step-body">
            <h4>Works 100% Offline</h4>
            <p>Your records are stored securely in browser IndexedDB with zero server dependency.</p>
          </div>
        </div>
      </div>
    `
  };

  window.openInstallModal = function(platform) {
    const modal = document.getElementById('install-modal');
    if (modal) {
      modal.classList.add('active');
      modal.setAttribute('aria-hidden', 'false');
      window.switchInstallTab(platform || 'android');
    }
  };

  window.closeInstallModal = function() {
    const modal = document.getElementById('install-modal');
    if (modal) {
      modal.classList.remove('active');
      modal.setAttribute('aria-hidden', 'true');
    }
  };

  window.switchInstallTab = function(platform) {
    const content = document.getElementById('install-tab-content');
    if (content && installGuides[platform]) {
      content.innerHTML = installGuides[platform];
    }
    document.querySelectorAll('.modal-tab-btn').forEach(btn => {
      if (btn.getAttribute('data-tab') === platform) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });
  };

  // Close modal on outside click or ESC key
  const modalOverlay = document.getElementById('install-modal');
  if (modalOverlay) {
    modalOverlay.addEventListener('click', (e) => {
      if (e.target === modalOverlay) window.closeInstallModal();
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && modalOverlay.classList.contains('active')) {
        window.closeInstallModal();
      }
    });
  }

  // ---------- 14. 3D Card Tilt Physics ----------
  const tiltCards = document.querySelectorAll('.tilt-card');
  tiltCards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const centerX = rect.width / 2;
      const centerY = rect.height / 2;
      const rotateX = ((y - centerY) / centerY) * -6;
      const rotateY = ((x - centerX) / centerX) * 6;

      card.style.transform = `perspective(1000px) rotateX(${rotateX.toFixed(2)}deg) rotateY(${rotateY.toFixed(2)}deg) translateY(-4px)`;
    });

    card.addEventListener('mouseleave', () => {
      card.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) translateY(0)';
    });
  });

  // ---------- 15. Live GitHub Telemetry & Stars ----------
  async function fetchRepoStats() {
    try {
      const res = await fetch('https://api.github.com/repos/VaibhavJalota06/Expense-OS-Mobile');
      if (res.ok) {
        const data = await res.json();
        const stars = data.stargazers_count || 0;
        const navStar = document.getElementById('nav-star-count');
        const heroStar = document.getElementById('hero-star-count');
        if (navStar) navStar.textContent = `${stars} Stars`;
        if (heroStar) heroStar.textContent = `Star on GitHub (${stars} ⭐)`;
      }
    } catch (e) {
      console.warn('GitHub stats fetch notice:', e);
    }
  }

  fetchRepoStats();
  fetchLatestRelease();

});



