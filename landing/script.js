/* ==========================================================================
   Expense OS - Modern Financial Ambient Landing Script Engine
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {

  // ---------- 0. Cosmic Preloader Lifecycle Controller ----------
  const preloader = document.getElementById('landing-preloader');
  const progressBar = document.getElementById('preloader-progress-bar');
  const statusText = document.getElementById('preloader-status-text');

  if (preloader && progressBar && statusText) {
    let progress = 20;
    progressBar.style.width = '20%';

    const statusSteps = [
      { at: 35, msg: 'LOADING LOCAL DATABASE SCHEMAS...' },
      { at: 65, msg: 'INITIALIZING CLIENT-SIDE ENCRYPTION...' },
      { at: 85, msg: 'VERIFYING ECOSYSTEM PROTOCOLS...' },
      { at: 100, msg: 'EXPENSE OS READY' }
    ];

    const progressInterval = setInterval(() => {
      if (progress < 92) {
        progress += Math.floor(Math.random() * 12) + 6;
        if (progress > 92) progress = 92;
        progressBar.style.width = `${progress}%`;

        for (const step of statusSteps) {
          if (progress >= step.at && step.at < 100) {
            statusText.textContent = step.msg;
          }
        }
      }
    }, 75);

    const finishPreloader = () => {
      clearInterval(progressInterval);
      progressBar.style.width = '100%';
      statusText.textContent = 'EXPENSE OS READY';

      setTimeout(() => {
        preloader.classList.add('loaded');
        setTimeout(() => {
          if (preloader.parentNode) {
            preloader.style.display = 'none';
          }
        }, 650);
      }, 300);
    };

    // Ensure smooth minimum duration so loading screen is visually crisp and never flashes abruptly
    const minLoadTime = new Promise(resolve => setTimeout(resolve, 800));
    const pageLoaded = new Promise(resolve => {
      if (document.readyState === 'complete') {
        resolve();
      } else {
        window.addEventListener('load', resolve);
      }
    });

    Promise.all([minLoadTime, pageLoaded]).then(finishPreloader);

    // Fallback safety timeout
    setTimeout(finishPreloader, 2200);
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

  // ---------- 5c. Searchable FAQ Accordion Filter ----------
  const faqSearchInput = document.getElementById('faq-search-input');
  const faqCards = document.querySelectorAll('.faq-card');

  if (faqSearchInput && faqCards.length > 0) {
    faqSearchInput.addEventListener('input', () => {
      const query = faqSearchInput.value.toLowerCase().trim();
      faqCards.forEach(card => {
        const text = card.textContent.toLowerCase();
        if (!query || text.includes(query)) {
          card.style.display = 'block';
        } else {
          card.style.display = 'none';
        }
      });
    });
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
      const res = await fetch('https://api.github.com/repos/VaibhavJalota06/Expense-OS-Mobile/releases/latest');
      if (!res.ok) return;
      const data = await res.json();
      if (!data || !data.tag_name) return;

      const tagName = data.tag_name;
      // Update all release version tags on page
      document.querySelectorAll('.release-version-tag').forEach(el => {
        el.textContent = tagName;
      });

      // Update download assets if specific asset URLs exist in release
      if (Array.isArray(data.assets) && data.assets.length > 0) {
        data.assets.forEach(asset => {
          const name = asset.name.toLowerCase();
          const downloadUrl = asset.browser_download_url;

          if (name.endsWith('.apk')) {
            const apkBtn = document.querySelector('a[data-platform="android"]');
            if (apkBtn) apkBtn.href = downloadUrl;
          } else if (name.endsWith('.exe') || name.endsWith('.msi')) {
            const exeBtn = document.querySelector('a[data-platform="windows"]');
            if (exeBtn) exeBtn.href = downloadUrl;
          } else if (name.endsWith('.ipa')) {
            const ipaBtn = document.querySelector('a[data-platform="ios"]');
            if (ipaBtn) ipaBtn.href = downloadUrl;
          }
        });
      }
    } catch (e) {
      console.log('Using default universal release endpoints:', e);
    }
  }

  fetchLatestRelease();

});



