(function () {
  'use strict';

  var SITE = 'https://anjanam.store';
  var DEFAULT = {
    title: 'ANJANAM — Shop Online in India',
    description: 'Shop products, digital articles, videos, books, and music on ANJANAM. Secure checkout with Razorpay.',
    image: SITE + '/icons/Icon-512.png',
    type: 'website',
  };

  var lastApplied = '';

  function setMeta(name, content, isProperty) {
    if (!content) return;
    var attr = isProperty ? 'property' : 'name';
    var el = document.querySelector('meta[' + attr + '="' + name + '"]');
    if (!el) {
      el = document.createElement('meta');
      el.setAttribute(attr, name);
      document.head.appendChild(el);
    }
    el.setAttribute('content', content);
  }

  function setCanonical(url) {
    var el = document.querySelector('link[rel="canonical"]');
    if (!el) {
      el = document.createElement('link');
      el.setAttribute('rel', 'canonical');
      document.head.appendChild(el);
    }
    el.setAttribute('href', url);
  }

  function setStructuredData(data) {
    var id = 'anjanam-route-structured-data';
    var existing = document.getElementById(id);
    if (existing && existing.parentNode) existing.parentNode.removeChild(existing);
    if (!data) return;
    var script = document.createElement('script');
    script.id = id;
    script.type = 'application/ld+json';
    script.text = JSON.stringify(data);
    document.head.appendChild(script);
  }

  function truncate(text, max) {
    if (!text) return '';
    var t = String(text).replace(/\s+/g, ' ').trim();
    if (t.length <= max) return t;
    return t.slice(0, max - 1).trim() + '…';
  }

  function firstImage(imageUrls) {
    if (!Array.isArray(imageUrls)) return null;
    for (var i = 0; i < imageUrls.length; i++) {
      var u = String(imageUrls[i] || '').trim();
      if (u) return u;
    }
    return null;
  }

  function applySeo(meta) {
    var fingerprint = [meta.title, meta.description, meta.url, meta.image].join('|');
    if (fingerprint === lastApplied) return;
    lastApplied = fingerprint;

    document.title = meta.title;
    setMeta('description', meta.description);
    setMeta('og:title', meta.title, true);
    setMeta('og:description', meta.description, true);
    setMeta('og:image', meta.image, true);
    setMeta('og:url', meta.url, true);
    setMeta('og:type', meta.type || 'website', true);
    setMeta('og:site_name', 'ANJANAM', true);
    setMeta('twitter:card', 'summary_large_image');
    setMeta('twitter:title', meta.title);
    setMeta('twitter:description', meta.description);
    setMeta('twitter:image', meta.image);
    setMeta('twitter:image:alt', meta.title);
    setMeta('og:image:alt', meta.title, true);
    setCanonical(meta.url);
    setStructuredData(meta.structuredData || null);
  }

  function parseShareRoute() {
    var path = location.pathname.replace(/\/+$/, '');
    var parts = path.split('/').filter(Boolean);
    if (parts.length !== 2) return null;
    var kind = parts[0];
    if (kind !== 'product' && kind !== 'video' && kind !== 'article') return null;
    return { kind: kind, id: decodeURIComponent(parts[1]) };
  }

  function buildRequest(route, config) {
    var base = String(config.supabase_url || '').replace(/\/$/, '');
    var key = config.supabase_anon_key;
    if (!base || !key) return null;

    var headers = {
      apikey: key,
      Authorization: 'Bearer ' + key,
    };

    if (route.kind === 'product') {
      return {
        url: base + '/rest/v1/products?id=eq.' + encodeURIComponent(route.id) +
          '&select=id,title,description,image_urls,price,currency&limit=1',
        headers: headers,
        map: function (rows) {
          var row = rows && rows[0];
          if (!row) return null;
          var price = row.price != null ? row.price + ' ' + (row.currency || 'INR') : '';
          return {
            title: truncate((row.title || 'Product') + ' — ANJANAM', 70),
            description: truncate(row.description || ('Shop ' + (row.title || 'this product') + ' on ANJANAM.' + (price ? ' Price: ' + price + '.' : '')), 160),
            image: firstImage(row.image_urls) || DEFAULT.image,
            url: SITE + '/product/' + encodeURIComponent(row.id),
            type: 'product',
            structuredData: {
              '@context': 'https://schema.org',
              '@type': 'Product',
              name: row.title || 'Product',
              description: row.description || ('Shop ' + (row.title || 'this product') + ' on ANJANAM.'),
              sku: String(row.id),
              image: Array.isArray(row.image_urls) ? row.image_urls : [],
              brand: { '@type': 'Brand', name: 'ANJANAM' },
              offers: {
                '@type': 'Offer',
                url: SITE + '/product/' + encodeURIComponent(row.id),
                priceCurrency: row.currency || 'INR',
                price: row.price,
                availability: 'https://schema.org/InStock',
                itemCondition: 'https://schema.org/NewCondition',
              },
            },
          };
        },
      };
    }

    if (route.kind === 'video') {
      return {
        url: base + '/rest/v1/videos?id=eq.' + encodeURIComponent(route.id) +
          '&select=id,title,description,thumbnail_url&limit=1',
        headers: headers,
        map: function (rows) {
          var row = rows && rows[0];
          if (!row) return null;
          return {
            title: truncate((row.title || 'Video') + ' — ANJANAM', 70),
            description: truncate(row.description || ('Watch ' + (row.title || 'this video') + ' on ANJANAM.'), 160),
            image: (row.thumbnail_url && String(row.thumbnail_url).trim()) || DEFAULT.image,
            url: SITE + '/video/' + encodeURIComponent(row.id),
            type: 'video.other',
          };
        },
      };
    }

    return {
      url: base + '/rest/v1/articles?id=eq.' + encodeURIComponent(route.id) +
        '&select=id,title,description,cover_image_url,is_published&limit=1',
      headers: headers,
      map: function (rows) {
        var row = rows && rows[0];
        if (!row || row.is_published === false) return null;
        return {
          title: truncate((row.title || 'Article') + ' — ANJANAM', 70),
          description: truncate(row.description || ('Read ' + (row.title || 'this article') + ' on ANJANAM.'), 160),
          image: (row.cover_image_url && String(row.cover_image_url).trim()) || DEFAULT.image,
          url: SITE + '/article/' + encodeURIComponent(row.id),
          type: 'article',
        };
      },
    };
  }

  function fetchAndApply() {
    var route = parseShareRoute();
    if (!route) return;

    fetch('/app-config.json', { cache: 'no-store' })
      .then(function (res) {
        if (!res.ok) throw new Error('config');
        return res.json();
      })
      .then(function (config) {
        var req = buildRequest(route, config);
        if (!req) return;
        return fetch(req.url, { headers: req.headers })
          .then(function (res) {
            if (!res.ok) throw new Error('api');
            return res.json();
          })
          .then(function (rows) {
            var meta = req.map(rows);
            if (meta) applySeo(meta);
          });
      })
      .catch(function () {
        applySeo({
          title: DEFAULT.title,
          description: DEFAULT.description,
          image: DEFAULT.image,
          url: SITE + location.pathname,
          type: DEFAULT.type,
        });
      });
  }

  fetchAndApply();
})();
