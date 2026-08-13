/**
 * HLS bridge for the watch-party player.
 *
 * Flutter web creates a real <video> element in a platform view, then
 * this bridge attaches hls.js to it. The bridge keeps the Hls instance
 * in a small registry so Dart can seek/destroy by id instead of holding
 * JS objects across the interop boundary.
 */
(function () {
  'use strict';
  if (window.EverglowHlsBridge) return;

  var players = new Map();
  var nextId = 1;

  function loadHlsScript() {
    return new Promise(function (resolve) {
      if (window.Hls) {
        resolve(true);
        return;
      }
      var existing = document.getElementById('everglow-hlsjs');
      if (existing) {
        existing.addEventListener('load', function () {
          resolve(!!window.Hls);
        });
        existing.addEventListener('error', function () {
          resolve(false);
        });
        return;
      }
      var script = document.createElement('script');
      script.id = 'everglow-hlsjs';
      script.src =
        'https://cdn.jsdelivr.net/npm/hls.js@1.5.17/dist/hls.min.js';
      script.onload = function () {
        resolve(!!window.Hls);
      };
      script.onerror = function () {
        resolve(false);
      };
      document.head.appendChild(script);
    });
  }

  window.EverglowHlsBridge = {
    loadScript: function () {
      return loadHlsScript();
    },
    isSupported: function () {
      return !!(window.Hls && window.Hls.isSupported());
    },
    create: function (video, url, opts) {
      if (!window.Hls || !video || !url) return null;
      var id = nextId++;
      var hls = new window.Hls(
        Object.assign({ enableWorker: true, maxBufferLength: 30 }, opts || {})
      );
      players.set(id, { hls: hls, video: video });
      hls.loadSource(url);
      hls.attachMedia(video);
      return id;
    },
    destroy: function (id) {
      var entry = players.get(id);
      if (!entry) return;
      try {
        entry.hls.destroy();
      } catch (e) {
        // Already destroyed; ignore.
      }
      players.delete(id);
    },
    setCurrentTime: function (id, seconds) {
      var entry = players.get(id);
      if (!entry) return false;
      try {
        entry.video.currentTime = Number(seconds) || 0;
        return true;
      } catch (e) {
        return false;
      }
    },
    instanceCount: function () {
      return players.size;
    }
  };
})();
