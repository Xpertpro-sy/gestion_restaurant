/// Contenu statique de la PWA client servie par [LocalServer].
/// Les clients scannent un QR code → ouverture navigateur → menu direct.
class ClientWebContent {
  static String tableMenuUrl(String ip, int port, int tableId) =>
      'http://$ip:$port/t/$tableId';

  static const String manifestJson = '''
{
  "name": "Resto - Commander",
  "short_name": "Resto",
  "start_url": "/menu",
  "display": "standalone",
  "background_color": "#0F0E17",
  "theme_color": "#FF8906",
  "description": "Commande à table via Wi-Fi local",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 192 192'%3E%3Crect fill='%23FF8906' width='192' height='192' rx='32'/%3E%3Ctext x='96' y='120' font-size='80' text-anchor='middle' fill='white'%3E🍽%3C/text%3E%3C/svg%3E",
      "sizes": "192x192",
      "type": "image/svg+xml"
    }
  ]
}
''';

  static const String serviceWorkerJs = '''
self.addEventListener('install', (e) => {
  self.skipWaiting();
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) =>
    Promise.all(keys.map((k) => caches.delete(k)))
  ));
  self.clients.claim();
});
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.pathname.startsWith('/api/')) return;
  if (e.request.mode === 'navigate' || (e.request.headers.get('accept') || '').includes('text/html')) {
    e.respondWith(fetch(e.request));
    return;
  }
  e.respondWith(
    caches.open('resto-v1').then((cache) =>
      cache.match(e.request).then((cached) => cached || fetch(e.request))
    )
  );
});
''';

  static const String indexHtml = r'''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="theme-color" content="#FF8906">
  <link rel="manifest" href="/client/manifest.webmanifest">
  <title>Resto — Commander</title>
  <style>
    :root {
      --bg: #0F0E17; --card: #1F1E26; --primary: #FF8906;
      --secondary: #F25F4C; --text: #FFFFFE; --muted: #A7A9BE;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; touch-action: manipulation; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: var(--bg); color: var(--text);
      min-height: 100dvh; display: flex; flex-direction: column;
      touch-action: manipulation;
      -webkit-text-size-adjust: 100%;
    }
    header {
      background: var(--bg); padding: 12px 16px; border-bottom: 1px solid #2a2933;
      display: flex; align-items: center; justify-content: space-between;
      position: sticky; top: 0; z-index: 10;
    }
    header h1 { font-size: 1.1rem; }
    header span { color: var(--primary); }
    .btn-call-waiter {
      display: flex; align-items: center; gap: 8px;
      background: rgba(255,137,6,0.15); border: 1.5px solid var(--primary);
      color: var(--primary); border-radius: 999px; padding: 8px 14px 8px 12px;
      font-size: 0.85rem; font-weight: 700; cursor: pointer;
    }
    .btn-call-waiter svg { width: 18px; height: 18px; flex-shrink: 0; }
    .alert {
      background: var(--primary); color: #fff; padding: 10px 16px;
      display: none; align-items: center; justify-content: space-between;
      font-size: 0.9rem; font-weight: 600;
    }
    .alert.show { display: flex; }
    .alert button { background: none; border: none; color: #fff; font-size: 1.2rem; cursor: pointer; }
    main { flex: 1; overflow: hidden; display: flex; flex-direction: column; }
    .tab-panel { display: none; flex: 1; overflow: hidden; flex-direction: column; }
    .tab-panel.active { display: flex; }
    .search { padding: 12px 16px 8px; }
    .search input {
      width: 100%; padding: 12px 16px 12px 42px; border-radius: 14px; border: 1px solid rgba(255,255,255,0.06);
      background: var(--card); color: var(--text); font-size: 0.95rem;
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='18' height='18' viewBox='0 0 24 24' fill='none' stroke='%23A7A9BE' stroke-width='2'%3E%3Ccircle cx='11' cy='11' r='8'/%3E%3Cpath d='M21 21l-4.35-4.35'/%3E%3C/svg%3E");
      background-repeat: no-repeat; background-position: 14px center;
    }
    .categories {
      display: flex; gap: 8px; padding: 4px 12px 14px; overflow-x: auto;
      scrollbar-width: none;
    }
    .cat-chip {
      padding: 9px 18px; border-radius: 999px; border: 1px solid rgba(255,255,255,0.08);
      cursor: pointer; background: var(--card); color: var(--muted);
      font-weight: 600; white-space: nowrap; font-size: 0.82rem;
      transition: all 0.2s ease;
    }
    .cat-chip.active {
      background: var(--primary); color: #fff; border-color: var(--primary);
      box-shadow: 0 4px 14px rgba(255,137,6,0.35);
    }
    .products { flex: 1; overflow-y: auto; background: var(--bg); }
    .products-grid {
      display: grid; grid-template-columns: 1fr 1fr; gap: 14px;
      padding: 0 16px 16px;
    }
    .product-grid-card {
      position: relative;
      aspect-ratio: 1;
      border-radius: 20px;
      overflow: hidden;
      cursor: pointer;
      border: 1px solid transparent;
      background: #1c1b24;
      transition: transform 0.15s ease, border-color 0.2s ease, box-shadow 0.2s ease;
    }
    .product-grid-card:active { transform: scale(0.98); }
    .product-grid-card.in-cart {
      border-color: rgba(255,137,6,0.45);
      box-shadow: 0 0 0 1px rgba(255,137,6,0.15);
    }
    .product-grid-card.unavailable { opacity: 0.55; }
    .product-grid-card.flash {
      animation: cardPulse 0.35s ease;
    }
    @keyframes cardPulse {
      0% { box-shadow: 0 0 0 0 rgba(255,137,6,0.5); }
      100% { box-shadow: 0 0 0 12px rgba(255,137,6,0); }
    }
    .product-grid-bg {
      position: absolute; inset: 0;
    }
    .product-grid-bg img {
      width: 100%; height: 100%; object-fit: cover; display: block;
    }
    .product-grid-bg .placeholder {
      width: 100%; height: 100%;
      display: flex; align-items: center; justify-content: center;
      background: linear-gradient(135deg, rgba(255,137,6,0.3) 0%, #1F1E26 100%);
      font-size: 2.6rem; color: var(--primary);
    }
    .product-avail-badge {
      position: absolute; top: 10px; right: 10px; z-index: 3;
      width: 32px; height: 32px; border-radius: 50%;
      background: rgba(255,255,255,0.85);
      display: flex; align-items: center; justify-content: center;
    }
    .product-avail-badge svg { width: 18px; height: 18px; display: block; }
    .cart-qty-badge {
      position: absolute; top: 10px; left: 10px; z-index: 3;
      min-width: 22px; height: 22px; padding: 0 6px; border-radius: 11px;
      background: var(--primary); color: #fff; font-size: 0.7rem; font-weight: 800;
      display: flex; align-items: center; justify-content: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
    }
    .product-glass-bar {
      position: absolute; left: 8px; right: 8px; bottom: 8px; z-index: 2;
      display: flex; align-items: center; gap: 8px;
      padding: 8px 10px; border-radius: 14px;
      background: rgba(255,255,255,0.22);
      backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px);
      border: 1px solid rgba(255,255,255,0.25);
    }
    .product-initial {
      width: 28px; height: 28px; border-radius: 50%; flex-shrink: 0;
      background: #2E7D32; color: #fff;
      font-size: 12px; font-weight: 800;
      display: flex; align-items: center; justify-content: center;
    }
    .product-glass-text { flex: 1; min-width: 0; }
    .product-glass-text h3 {
      margin: 0; font-size: 13px; font-weight: 700; line-height: 1.2;
      color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
      text-shadow: 0 1px 4px rgba(0,0,0,0.26);
    }
    .product-glass-text .price {
      display: block; margin-top: 2px;
      font-size: 11px; font-weight: 400; color: rgba(255,255,255,0.9);
      text-shadow: 0 1px 4px rgba(0,0,0,0.26);
    }
    .product-glass-arrow {
      flex-shrink: 0; width: 12px; height: 12px; color: rgba(255,255,255,0.9);
      display: flex; align-items: center; justify-content: center;
    }
    .product-glass-arrow svg { width: 12px; height: 12px; display: block; }
    .product-thumb {
      width: 72px; height: 72px; border-radius: 12px; object-fit: cover;
      background: #2a2933; flex-shrink: 0;
    }
    .product-thumb.placeholder {
      display: flex; align-items: center; justify-content: center;
      font-size: 1.6rem; color: var(--muted);
    }
    .product-body { flex: 1; min-width: 0; }
    .product-info h3 { font-size: 1rem; margin-bottom: 4px; }
    .product-info p { font-size: 0.8rem; color: var(--muted); margin-bottom: 8px; }
    .price { color: var(--primary); font-weight: 700; }
    .qty-stepper { display: flex; align-items: center; gap: 10px; margin-top: 8px; }
    .qty-minus {
      width: 34px; height: 34px; border-radius: 50%; border: 1.5px solid var(--text);
      background: transparent; color: var(--text); font-size: 1.2rem; cursor: pointer;
      display: flex; align-items: center; justify-content: center;
    }
    .qty-plus {
      width: 34px; height: 34px; border-radius: 50%; border: none;
      background: var(--text); color: var(--bg); font-size: 1.2rem; cursor: pointer;
      display: flex; align-items: center; justify-content: center; font-weight: 700;
    }
    .qty-input {
      width: 42px; text-align: center; border: none; background: transparent;
      color: var(--text); font-weight: 700; font-size: 1rem;
      -moz-appearance: textfield;
    }
    .qty-input::-webkit-outer-spin-button, .qty-input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
    .qty-controls { display: flex; align-items: center; gap: 4px; }
    .qty-btn {
      background: none; border: none; color: var(--primary); font-size: 1.5rem; cursor: pointer;
    }
    .btn-add {
      background: var(--primary); color: #fff; border: none; border-radius: 20px;
      padding: 8px 16px; font-weight: 600; cursor: pointer;
    }
    .empty { text-align: center; color: var(--muted); padding: 48px 24px; }
    .cart-swipe-wrap {
      position: relative; margin-bottom: 12px; overflow: hidden; border-radius: 16px;
    }
    .cart-swipe-delete {
      position: absolute; right: 0; top: 0; bottom: 0; width: 88px;
      background: var(--secondary); display: flex; align-items: center;
      justify-content: center; color: #fff;
    }
    .cart-swipe-delete svg { width: 26px; height: 26px; }
    .cart-item {
      position: relative; z-index: 1; background: var(--card); border-radius: 16px;
      padding: 14px; display: flex; gap: 12px; align-items: flex-start;
      transition: transform 0.22s ease; will-change: transform;
    }
    .cart-info { flex: 1; min-width: 0; }
    .cart-info h4 { font-size: 1rem; margin-bottom: 4px; }
    .cart-info .sub { font-size: 0.8rem; color: var(--muted); margin-bottom: 6px; }
    .cart-actions { display: flex; flex-direction: column; align-items: flex-end; gap: 8px; }
    .order-card {
      background: var(--card); border-radius: 16px; padding: 16px; margin-bottom: 16px;
    }
    .order-card h3 { margin-bottom: 6px; }
    .cart-total {
      padding: 16px; border-top: 1px solid #2a2933;
      display: flex; justify-content: space-between; font-size: 1.1rem; font-weight: 700;
    }
    .btn-primary {
      margin: 0 16px 16px; padding: 14px; background: var(--primary); color: #fff;
      border: none; border-radius: 12px; font-size: 1rem; font-weight: 700; cursor: pointer;
    }
    .btn-secondary {
      background: var(--secondary); color: #fff; border: none; border-radius: 12px;
      padding: 12px 20px; font-weight: 600; cursor: pointer; width: 100%;
    }
    nav {
      display: flex; background: var(--card); border-top: 1px solid #2a2933;
      padding-bottom: env(safe-area-inset-bottom);
    }
    nav button {
      flex: 1; padding: 12px 8px; background: none; border: none;
      color: var(--muted); font-size: 0.75rem; cursor: pointer;
      display: flex; flex-direction: column; align-items: center; gap: 4px;
    }
    nav button.active { color: var(--primary); }
    nav button .badge {
      position: absolute; top: 4px; right: calc(50% - 20px);
      background: var(--secondary); color: #fff; border-radius: 50%;
      width: 16px; height: 16px; font-size: 0.6rem; display: flex;
      align-items: center; justify-content: center;
    }
    .nav-item { position: relative; flex: 1; display: flex; }
    .timeline { padding: 16px; }
    .step { display: flex; gap: 12px; margin-bottom: 8px; }
    .dot {
      width: 24px; height: 24px; border-radius: 50%; flex-shrink: 0;
      display: flex; align-items: center; justify-content: center; font-size: 0.7rem;
    }
    .dot.done { background: #2E7D32; color: #fff; }
    .dot.current { border: 3px solid var(--primary); background: transparent; }
    .dot.pending { background: #333; }
    .line { width: 2px; height: 40px; background: #333; margin-left: 11px; }
    .line.done { background: #2E7D32; }
    .step-text h4 { font-size: 0.95rem; }
    .step-text p { font-size: 0.75rem; color: var(--muted); }
    .loading, .error-screen {
      display: flex; flex-direction: column; align-items: center; justify-content: center;
      min-height: 60dvh; padding: 24px; text-align: center; gap: 16px;
    }
    .error-screen h2 { color: var(--secondary); }
    .modal-overlay {
      display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.7);
      z-index: 100; align-items: flex-end; justify-content: center;
    }
    .modal-overlay.show { display: flex; }
    .modal {
      background: var(--card); border-radius: 20px 20px 0 0; padding: 24px;
      width: 100%; max-width: 480px;
    }
    .modal textarea {
      width: 100%; margin-top: 12px; padding: 12px; border-radius: 8px;
      border: 1px solid #333; background: var(--bg); color: var(--text);
    }
    .modal-overlay.center { align-items: center; padding: 24px; }
    .confirm-modal { border-radius: 20px; text-align: center; max-width: 340px; }
    .confirm-icon {
      width: 56px; height: 56px; margin: 0 auto 16px; border-radius: 50%;
      background: rgba(242,95,76,0.15); display: flex; align-items: center; justify-content: center;
    }
    .confirm-icon svg { width: 28px; height: 28px; stroke: var(--secondary); }
    .confirm-modal h3 { margin-bottom: 8px; }
    .confirm-modal p { color: var(--muted); font-size: 0.9rem; margin-bottom: 20px; }
    .btn-danger { background: var(--secondary) !important; color: #fff !important; }
    .modal-actions { display: flex; gap: 12px; margin-top: 16px; }
    .modal-actions button { flex: 1; padding: 12px; border-radius: 8px; border: none; cursor: pointer; font-weight: 600; }
  </style>
</head>
<body>
  <div id="loading" class="loading">
    <p>Connexion au menu…</p>
    <p style="color:var(--muted);font-size:0.85rem">Assurez-vous d'être connecté au Wi-Fi du restaurant.</p>
  </div>
  <div id="error" class="error-screen" style="display:none">
    <h2>Connexion impossible</h2>
    <p id="error-msg">Vérifiez que vous êtes sur le même réseau Wi-Fi que le restaurant.</p>
  </div>
  <div id="app" style="display:none;flex-direction:column;min-height:100dvh">
    <header>
      <h1>Table <span id="table-label">—</span></h1>
      <button class="btn-call-waiter" onclick="callWaiter()" title="Appeler le serveur">
        <span>Appeler serveur</span>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 10-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
      </button>
    </header>
    <div id="alert" class="alert"><span id="alert-text"></span><button onclick="hideAlert()">×</button></div>
    <main>
      <div id="tab-menu" class="tab-panel active">
        <div class="search"><input type="search" placeholder="Rechercher…" oninput="onSearch(this.value)"></div>
        <div id="categories" class="categories"></div>
        <div id="products" class="products"></div>
      </div>
      <div id="tab-cart" class="tab-panel">
        <div id="cart-list" style="flex:1;overflow-y:auto;padding:16px"></div>
        <div class="cart-total"><span>Total</span><span id="cart-total">0 FCFA</span></div>
        <button class="btn-primary" onclick="submitOrder()">Passer la commande</button>
      </div>
      <div id="tab-track" class="tab-panel">
        <div id="track-content" style="flex:1;overflow-y:auto;padding:16px"></div>
        <div style="padding:16px"><button class="btn-secondary" onclick="callWaiter()">Appeler le serveur / Addition</button></div>
      </div>
    </main>
    <nav>
      <div class="nav-item"><button id="nav-menu" class="active" onclick="switchTab(0)">🍽<br>Menu</button></div>
      <div class="nav-item"><button id="nav-cart" onclick="switchTab(1)">🛒<br>Panier<span id="cart-badge" class="badge" style="display:none">0</span></button></div>
      <div class="nav-item"><button id="nav-track" onclick="switchTab(2)">📋<br>Suivi</button></div>
    </nav>
  </div>
  <div id="modal" class="modal-overlay" onclick="if(event.target===this)closeModal()">
    <div class="modal">
      <h3 id="modal-title"></h3>
      <p id="modal-desc" style="color:var(--muted);font-size:0.9rem;margin-top:8px"></p>
      <p id="modal-price" class="price" style="margin-top:8px"></p>
      <textarea id="modal-notes" placeholder="Notes (sans oignons, sauce à part…)"></textarea>
      <div class="modal-actions">
        <button style="background:#333;color:#fff" onclick="closeModal()">Annuler</button>
        <button style="background:var(--primary);color:#fff" onclick="confirmAdd()">Ajouter</button>
      </div>
    </div>
  </div>
  <div id="confirm-modal" class="modal-overlay center" onclick="if(event.target===this)cancelDelete()">
    <div class="modal confirm-modal">
      <div class="confirm-icon" id="confirm-icon"></div>
      <h3>Supprimer cet article ?</h3>
      <p id="confirm-msg">Cet article sera retiré de votre panier.</p>
      <div class="modal-actions">
        <button style="background:#333;color:#fff" onclick="cancelDelete()">Annuler</button>
        <button class="btn-danger" onclick="confirmDelete()">Supprimer</button>
      </div>
    </div>
  </div>
  <script>
    const params = new URLSearchParams(location.search);
    const pathMatch = location.pathname.match(/^\/t\/(\d+)\/?$/);
    const tableId = pathMatch
      ? parseInt(pathMatch[1], 10)
      : parseInt(params.get('t') || params.get('tableId') || '0', 10);
    let menu = [], selectedCat = 0, searchQuery = '', cart = {}, cartNotes = {};
    let activeOrders = [], ws = null, modalProduct = null;
    let pendingDeleteId = null, pendingDeleteReset = null;

    const ICON_TRASH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4a1 1 0 011-1h4a1 1 0 011 1v2"/></svg>';
    const ICON_PLUS = '<svg viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>';
    const ICON_CHECK = '<svg viewBox="0 0 24 24" fill="none" stroke="#2E7D32" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';
    const ICON_UNAVAILABLE = '<svg viewBox="0 0 24 24" fill="none" stroke="#A7A9BE" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><line x1="8" y1="12" x2="16" y2="12"/></svg>';
    const ICON_ARROW = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>';

    function productImageHtml(p, cls) {
      const c = cls || 'product-thumb';
      if (p.image_path) {
        return `<img class="${c}" src="/api/images/${encodeURIComponent(p.image_path)}" alt="">`;
      }
      return `<div class="${c} placeholder">🍽</div>`;
    }

    function productGridBgHtml(p) {
      if (p.image_path) {
        return `<img src="/api/images/${encodeURIComponent(p.image_path)}" alt="">`;
      }
      return `<div class="placeholder">🍽</div>`;
    }

    function productInitial(name) {
      return (name && name.length) ? name.charAt(0).toUpperCase() : '?';
    }

    function isProductAvailable(p) {
      return p.is_available !== 0 && p.is_available !== false;
    }

    function productAvailBadgeHtml(p) {
      return `<div class="product-avail-badge" aria-hidden="true">${isProductAvailable(p) ? ICON_CHECK : ICON_UNAVAILABLE}</div>`;
    }

    function qtyStepperHtml(id, qty) {
      return `<div class="qty-stepper" onclick="event.stopPropagation()">
        <button type="button" class="qty-minus" onclick="event.stopPropagation(); changeQty(${id},-1)">−</button>
        <input class="qty-input" type="number" min="1" max="99" value="${qty}"
          onclick="event.stopPropagation(); this.select()"
          onchange="setQty(${id}, this.value)">
        <button type="button" class="qty-plus" onclick="event.stopPropagation(); changeQty(${id},1)">+</button>
      </div>`;
    }

    function quickAddToCart(id, e) {
      if (e && e.target.closest('.qty-stepper, .qty-minus, .qty-plus, .qty-input')) return;
      const p = findProduct(id);
      if (!p || !isProductAvailable(p)) return;
      cart[id] = (cart[id] || 0) + 1;
      renderProducts();
      renderCart();
      const card = document.querySelector('.product-grid-card[data-id="' + id + '"]');
      if (card) {
        card.classList.add('flash');
        setTimeout(() => card.classList.remove('flash'), 350);
      }
    }

    const STEPS = [
      { key: 'nouvelle', title: 'Commande reçue', sub: 'Nous avons bien reçu votre commande.' },
      { key: 'acceptee', title: 'Acceptée', sub: 'Validée par le personnel.' },
      { key: 'enPreparation', title: 'En préparation', sub: 'Le chef prépare vos plats.' },
      { key: 'prete', title: 'Prête !', sub: 'Vos plats arrivent.' },
      { key: 'servie', title: 'Servie', sub: 'Bon appétit !' },
    ];
    const STATUS_ORDER = ['nouvelle','acceptee','enPreparation','prete','servie','payee'];

    function fmtFcfa(n) { return Math.round(n).toLocaleString('fr-FR') + ' FCFA'; }

    async function init() {
      if (!tableId) { showError('QR Code invalide : numéro de table manquant.'); return; }
      document.getElementById('table-label').textContent = tableId;
      try {
        const res = await fetch('/api/menu');
        if (!res.ok) throw new Error('Menu indisponible');
        menu = await res.json();
        await loadTableOrders();
        connectWs();
        document.getElementById('loading').style.display = 'none';
        document.getElementById('app').style.display = 'flex';
        renderCategories();
        renderProducts();
        if ('serviceWorker' in navigator) navigator.serviceWorker.register('/client/sw.js').catch(() => {});
        document.getElementById('confirm-icon').innerHTML = ICON_TRASH;
      } catch (e) {
        showError('Impossible de joindre le serveur. Connectez-vous au Wi-Fi du restaurant puis réessayez.');
      }
    }

    function showError(msg) {
      document.getElementById('loading').style.display = 'none';
      document.getElementById('error-msg').textContent = msg;
      document.getElementById('error').style.display = 'flex';
    }

    async function loadTableOrders() {
      try {
        const res = await fetch(`/api/orders?table_id=${tableId}`);
        if (!res.ok) return;
        const data = await res.json();
        activeOrders = data.map(o => ({
          id: o.order_id,
          status: o.status,
          total: o.total_amount,
          createdAt: o.created_at,
        }));
      } catch (_) {}
    }

    function connectWs() {
      const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
      ws = new WebSocket(proto + '//' + location.host);
      ws.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          if (data.type === 'pong') return;
          if (data.type === 'order_status_updated') {
            const o = activeOrders.find(x => x.id === data.order_id);
            if (o) {
              o.status = data.status;
              showAlert('Statut commande #' + data.order_id + ' : ' + data.status);
              renderTrack();
            }
          }
          if (data.type === 'order_paid') {
            activeOrders = activeOrders.filter(x => x.id !== data.order_id);
            showAlert('Commande #' + data.order_id + ' réglée. Merci !');
            renderTrack();
          }
        } catch (_) {}
      };
      ws.onopen = () => ws.send(JSON.stringify({ type: 'ping' }));
    }

    function renderCategories() {
      const el = document.getElementById('categories');
      el.innerHTML = menu.map((c, i) =>
        `<button class="cat-chip${i===selectedCat?' active':''}" onclick="selectCat(${i})">${esc(c.name)}</button>`
      ).join('');
    }

    function selectCat(i) { selectedCat = i; renderCategories(); renderProducts(); }

    function onSearch(q) { searchQuery = q.toLowerCase(); renderProducts(); }

    function renderProducts() {
      if (!menu.length) {
        document.getElementById('products').innerHTML = '<div class="empty">Menu vide</div>';
        return;
      }
      const products = (menu[selectedCat].products || []).filter(p =>
        p.name.toLowerCase().includes(searchQuery)
      );
      if (!products.length) {
        document.getElementById('products').innerHTML = '<div class="empty">Aucun résultat</div>';
        return;
      }
      document.getElementById('products').innerHTML = `<div class="products-grid">${products.map(p => {
        const qty = cart[p.id] || 0;
        const badge = qty > 0 ? `<span class="cart-qty-badge">×${qty}</span>` : '';
        const inCart = qty > 0 ? ' in-cart' : '';
        const available = isProductAvailable(p);
        const unavail = available ? '' : ' unavailable';
        const initial = esc(productInitial(p.name));
        const clickAction = available
          ? `quickAddToCart(${p.id}, event)`
          : `openModal(${p.id})`;
        return `<article class="product-grid-card${inCart}${unavail}" data-id="${p.id}" onclick="${clickAction}" role="button" tabindex="0">
          <div class="product-grid-bg">${productGridBgHtml(p)}</div>
          ${productAvailBadgeHtml(p)}
          ${badge}
          <div class="product-glass-bar">
            <div class="product-initial">${initial}</div>
            <div class="product-glass-text">
              <h3>${esc(p.name)}</h3>
              <span class="price">${fmtFcfa(p.price)}</span>
            </div>
            <div class="product-glass-arrow">${ICON_ARROW}</div>
          </div>
        </article>`;
      }).join('')}</div>`;
    }

    function openModal(id) {
      const p = findProduct(id);
      if (!p) return;
      modalProduct = p;
      document.getElementById('modal-title').textContent = p.name;
      document.getElementById('modal-desc').textContent = p.description || '';
      document.getElementById('modal-price').textContent = fmtFcfa(p.price);
      document.getElementById('modal-notes').value = '';
      document.getElementById('modal').classList.add('show');
    }
    function closeModal() { document.getElementById('modal').classList.remove('show'); modalProduct = null; }
    function confirmAdd() {
      if (!modalProduct) return;
      const notes = document.getElementById('modal-notes').value.trim();
      cart[modalProduct.id] = (cart[modalProduct.id] || 0) + 1;
      if (notes) cartNotes[modalProduct.id] = notes;
      closeModal(); renderProducts(); renderCart();
    }

    function setQty(id, value) {
      const q = Math.max(1, Math.min(99, parseInt(value, 10) || 1));
      cart[id] = q;
      renderProducts(); renderCart();
    }

    function changeQty(id, delta) {
      const q = (cart[id] || 0) + delta;
      if (q <= 0) { delete cart[id]; delete cartNotes[id]; }
      else cart[id] = q;
      renderProducts(); renderCart();
    }

    function findProduct(id) {
      for (const c of menu) for (const p of (c.products||[])) if (p.id === id) return p;
      return null;
    }

    function cartTotal() {
      let t = 0;
      for (const [id, qty] of Object.entries(cart)) {
        const p = findProduct(+id);
        if (p) t += p.price * qty;
      }
      return t;
    }

    function renderCart() {
      const ids = Object.keys(cart);
      const badge = document.getElementById('cart-badge');
      const totalQty = ids.reduce((s, id) => s + cart[id], 0);
      badge.style.display = totalQty ? 'flex' : 'none';
      badge.textContent = totalQty;
      document.getElementById('cart-total').textContent = fmtFcfa(cartTotal());
      if (!ids.length) {
        document.getElementById('cart-list').innerHTML = '<div class="empty">Panier vide</div>';
        return;
      }
      document.getElementById('cart-list').innerHTML = ids.map(id => {
        const p = findProduct(+id);
        if (!p) return '';
        const note = cartNotes[id] ? `<div class="sub" style="color:#f59e0b">${esc(cartNotes[id])}</div>` : '';
        return `<div class="cart-swipe-wrap" data-id="${id}">
          <div class="cart-swipe-delete" aria-hidden="true">${ICON_TRASH}</div>
          <div class="cart-item cart-swipe-content">${productImageHtml(p)}<div class="cart-info"><h4>${esc(p.name)}</h4><div class="sub">${esc(p.description||'')}</div><span class="price">${fmtFcfa(p.price)}</span>${note}</div><div class="cart-actions">${qtyStepperHtml(id, cart[id])}</div></div>
        </div>`;
      }).join('');
      initCartSwipe();
    }

    function initCartSwipe() {
      const deleteWidth = 88;
      const threshold = 56;
      document.querySelectorAll('.cart-swipe-wrap').forEach(wrap => {
        const content = wrap.querySelector('.cart-swipe-content');
        const id = +wrap.dataset.id;
        let startX = 0, offsetX = 0, dragging = false;

        const isInteractive = (el) => el && el.closest('input, button, .qty-stepper');

        const onStart = (clientX, target) => {
          if (isInteractive(target)) return false;
          startX = clientX;
          dragging = true;
          content.style.transition = 'none';
          return true;
        };

        const onMove = (clientX) => {
          if (!dragging) return;
          const dx = clientX - startX;
          offsetX = Math.min(0, Math.max(-deleteWidth, dx));
          content.style.transform = `translateX(${offsetX}px)`;
        };

        const onEnd = () => {
          if (!dragging) return;
          dragging = false;
          content.style.transition = 'transform 0.22s ease';
          if (offsetX <= -threshold) {
            content.style.transform = `translateX(-${deleteWidth}px)`;
            showDeleteConfirm(id, () => {
              removeFromCart(id);
            }, () => {
              offsetX = 0;
              content.style.transform = 'translateX(0)';
              content.style.opacity = '1';
            });
          } else {
            offsetX = 0;
            content.style.transform = 'translateX(0)';
          }
        };

        content.addEventListener('touchstart', (e) => {
          if (!onStart(e.touches[0].clientX, e.target)) return;
        }, { passive: true });

        content.addEventListener('touchmove', (e) => {
          if (!dragging) return;
          onMove(e.touches[0].clientX);
        }, { passive: true });

        content.addEventListener('touchend', onEnd);
        content.addEventListener('touchcancel', onEnd);

        content.addEventListener('mousedown', (e) => {
          if (!onStart(e.clientX, e.target)) return;
          e.preventDefault();
          const onMouseMove = (ev) => onMove(ev.clientX);
          const onMouseUp = () => {
            onEnd();
            window.removeEventListener('mousemove', onMouseMove);
            window.removeEventListener('mouseup', onMouseUp);
          };
          window.addEventListener('mousemove', onMouseMove);
          window.addEventListener('mouseup', onMouseUp);
        });
      });
    }

    function showDeleteConfirm(id, onConfirm, onCancel) {
      const p = findProduct(id);
      pendingDeleteId = id;
      pendingDeleteConfirm = onConfirm;
      pendingDeleteReset = onCancel;
      document.getElementById('confirm-icon').innerHTML = ICON_TRASH;
      document.getElementById('confirm-msg').textContent = p
        ? `Voulez-vous retirer « ${p.name} » du panier ?`
        : 'Voulez-vous retirer cet article du panier ?';
      document.getElementById('confirm-modal').classList.add('show');
    }

    let pendingDeleteConfirm = null;

    function confirmDelete() {
      if (pendingDeleteConfirm) pendingDeleteConfirm();
      closeDeleteConfirm();
    }

    function cancelDelete() {
      if (pendingDeleteReset) pendingDeleteReset();
      closeDeleteConfirm();
    }

    function closeDeleteConfirm() {
      document.getElementById('confirm-modal').classList.remove('show');
      pendingDeleteId = null;
      pendingDeleteConfirm = null;
      pendingDeleteReset = null;
    }

    function removeFromCart(id) {
      delete cart[id]; delete cartNotes[id];
      renderProducts(); renderCart();
    }

    async function submitOrder() {
      if (!Object.keys(cart).length) return;
      const items = Object.entries(cart).map(([id, qty]) => {
        const p = findProduct(+id);
        return { product_id: +id, quantity: qty, unit_price: p?.price || 0, notes: cartNotes[id] || '' };
      });
      const total = cartTotal();
      try {
        const res = await fetch('/api/orders', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ table_id: tableId, total_amount: total, items })
        });
        const data = await res.json();
        if (!res.ok) throw new Error();
        activeOrders.unshift({ id: data.order_id, status: 'nouvelle', total, createdAt: new Date().toISOString() });
        cart = {}; cartNotes = {};
        renderCart(); renderProducts(); renderTrack(); switchTab(2);
        showAlert('Commande envoyée !');
      } catch (_) { showAlert('Échec de la commande'); }
    }

    async function callWaiter() {
      try {
        await fetch('/api/waiter_call', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ table_id: tableId })
        });
        showAlert('Serveur appelé !');
      } catch (_) { showAlert('Échec de l\'appel'); }
    }

    function renderOrderTimeline(order) {
      const idx = STATUS_ORDER.indexOf(order.status);
      return STEPS.map((s, i) => {
        const si = STATUS_ORDER.indexOf(s.key);
        const done = idx >= si;
        const current = order.status === s.key;
        const dotClass = current ? 'current' : done ? 'done' : 'pending';
        const lineClass = done && i < STEPS.length - 1 ? 'done' : '';
        return `<div class="step"><div><div class="dot ${dotClass}">${done && !current ? '✓' : ''}</div>${i < STEPS.length-1 ? `<div class="line ${lineClass}"></div>` : ''}</div>
          <div class="step-text"><h4 style="color:${current?'var(--primary)':done?'var(--text)':'var(--muted)'}">${s.title}</h4><p>${s.sub}</p></div></div>`;
      }).join('');
    }

    function renderTrack() {
      const el = document.getElementById('track-content');
      if (!activeOrders.length) {
        el.innerHTML = '<div class="empty">Aucune commande active</div>';
        return;
      }
      el.innerHTML = activeOrders.map(order => `
        <div class="order-card">
          <h3>Commande #${order.id}</h3>
          <p style="color:var(--muted);margin-bottom:16px">Total : ${fmtFcfa(order.total)}</p>
          ${renderOrderTimeline(order)}
        </div>`).join('');
    }

    function switchTab(i) {
      ['menu','cart','track'].forEach((t, j) => {
        document.getElementById('tab-' + t).classList.toggle('active', j === i);
        document.getElementById('nav-' + t).classList.toggle('active', j === i);
      });
      if (i === 2) renderTrack();
    }

    function showAlert(msg) {
      document.getElementById('alert-text').textContent = msg;
      document.getElementById('alert').classList.add('show');
      setTimeout(hideAlert, 5000);
    }
    function hideAlert() { document.getElementById('alert').classList.remove('show'); }
    function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

    init();
  </script>
</body>
</html>''';
}
