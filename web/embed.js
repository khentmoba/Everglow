(function () {
  'use strict';

  var UPSTREAMS = [
    {
      id: 'videasy',
      label: 'Videasy',
      movie: function (tmdbId) {
        return 'https://player.videasy.net/movie/' + tmdbId + '?autoplay=true';
      },
      tv: function (tmdbId, s, e) {
        return 'https://player.videasy.net/tv/' + tmdbId + '/' + s + '/' + e +
          '?autoplay=true&nextButton=true&episodeSelector=true';
      }
    },
    {
      id: 'cinesrc',
      label: 'CineSrc',
      movie: function (tmdbId) {
        return 'https://cinesrc.st/embed/movie/' + tmdbId;
      },
      tv: function (tmdbId, s, e) {
        return 'https://cinesrc.st/embed/tv/' + tmdbId + '?s=' + s + '&e=' + e;
      }
    },
    {
      id: 'movish',
      label: 'Movish',
      movie: function (tmdbId) {
        return 'https://movish.to/moviebox-embed/move/' + tmdbId;
      },
      tv: function (tmdbId, s, e) {
        return 'https://movish.to/moviebox-embed/tv/' + tmdbId + '/' + s + '/' + e;
      }
    },
    {
      id: 'vidbolt',
      label: 'VidBolt',
      movie: function (tmdbId) {
        return 'https://vidbolt.xyz/movie/' + tmdbId;
      },
      tv: function (tmdbId, s, e) {
        return 'https://vidbolt.xyz/tv/' + tmdbId + '/' + s + '/' + e;
      }
    }
  ];

  var LOAD_TIMEOUT_MS = 12000;

  try { window.open = function () { return null; }; } catch (e) {}
  window.addEventListener('beforeunload', function (e) {
    e.preventDefault();
    e.returnValue = '';
  });

  var observer = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var added = mutations[i].addedNodes;
      for (var j = 0; j < added.length; j++) {
        var node = added[j];
        if (node && node.tagName === 'IFRAME' && node.id !== 'upstream') {
          node.remove();
        }
      }
    }
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });

  document.addEventListener('wheel', function (e) {
    try {
      window.parent.postMessage({ type: 'everglow-embed-scroll', deltaY: e.deltaY }, '*');
    } catch (err) {}
  }, { passive: true });

  function readParams() {
    var q = new URLSearchParams(window.location.search);
    return {
      tmdbId: (q.get('tmdbId') || '').trim(),
      type: q.get('type') === 'tv' ? 'tv' : 'movie',
      s: parseInt(q.get('s') || '1', 10) || 1,
      e: parseInt(q.get('e') || '1', 10) || 1,
      start: parseInt(q.get('start') || '0', 10) || 0
    };
  }

  var p = readParams();
  var frame = document.getElementById('upstream');
  var loader = document.getElementById('loader');
  var serverName = document.getElementById('serverName');
  var bar = document.getElementById('bar');
  var errorBox = document.getElementById('error');
  var retryBtn = document.getElementById('retry');

  var queue = [0, 1, 2, 3];
  var queuePos = 0;
  var current = -1;
  var timer = null;
  var exhausted = false;

  function upstreamUrl(u) {
    var url = p.type === 'tv' ? u.tv(p.tmdbId, p.s, p.e) : u.movie(p.tmdbId);
    if (p.start > 0) {
      url += (url.indexOf('?') === -1 ? '?' : '&') + 'start=' + p.start;
    }
    return url;
  }

  function markBar(activeId) {
    var buttons = bar.querySelectorAll('button');
    for (var i = 0; i < buttons.length; i++) {
      var on = buttons[i].getAttribute('data-id') === activeId;
      if (on) {
        buttons[i].classList.add('active');
      } else {
        buttons[i].classList.remove('active');
      }
    }
  }

  function failAll() {
    exhausted = true;
    clearTimeout(timer);
    loader.classList.add('hidden');
    errorBox.classList.add('visible');
    try {
      window.parent.postMessage({ type: 'everglow-embed-failed' }, '*');
    } catch (e) {}
  }

  function loadPos(pos) {
    queuePos = pos;
    if (pos >= queue.length) {
      failAll();
      return;
    }
    current = queue[pos];
    var u = UPSTREAMS[current];
    loader.classList.remove('hidden');
    frame.classList.add('hidden');
    serverName.textContent = u.label;
    markBar(u.id);
    clearTimeout(timer);
    frame.src = upstreamUrl(u);
    timer = setTimeout(function () {
      if (current === queue[queuePos]) {
        loadPos(queuePos + 1);
      }
    }, LOAD_TIMEOUT_MS);
  }

  function defaultQueue() {
    return [0, 1, 2, 3];
  }

  frame.addEventListener('load', function () {
    clearTimeout(timer);
    loader.classList.add('hidden');
    frame.classList.remove('hidden');
  });
  frame.addEventListener('error', function () {
    clearTimeout(timer);
    loadPos(queuePos + 1);
  });

  UPSTREAMS.forEach(function (u, i) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = u.label;
    btn.setAttribute('data-id', u.id);
    btn.addEventListener('click', function () {
      exhausted = false;
      errorBox.classList.remove('visible');
      var rest = [];
      for (var k = 0; k < UPSTREAMS.length; k++) {
        if (k !== i) rest.push(k);
      }
      queue = [i].concat(rest);
      loadPos(0);
    });
    bar.appendChild(btn);
  });

  retryBtn.addEventListener('click', function () {
    exhausted = false;
    errorBox.classList.remove('visible');
    queue = defaultQueue();
    loadPos(0);
  });

  if (!p.tmdbId) {
    loader.classList.add('hidden');
    errorBox.classList.add('visible');
    errorBox.querySelector('p').textContent = 'Missing tmdbId parameter.';
    return;
  }

  loadPos(0);
})();
