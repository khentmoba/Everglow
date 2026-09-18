'use strict';
//
// Media proxy composition root. Handlers live in focused media_proxy_*
// modules; this file re-exports the same names so index.js + tests and
// the deployed function names stay unchanged.
//

const { proxyBookText, proxyBookFile } = require('./media_proxy_books.js');
const {
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyMangaDex,
} = require('./media_proxy_manga.js');
const { proxyAnimeImage } = require('./media_proxy_anime.js');
const {
  proxyLastfmImage,
  isAllowedLastfmImageUrl,
} = require('./media_proxy_music.js');
const {
  proxyGalleryImage,
  cleanupGallery,
  deleteGalleryPhoto,
} = require('./media_proxy_gallery.js');
const {
  proxyScanlation,
  proxyFetchHtml,
  proxyEmbed,
} = require('./media_proxy_html.js');
const {
  proxyVideoStream,
  proxyWatchStream,
  initWasm,
} = require('./media_proxy_video.js');
const {
  proxyCatalog,
  resolveCatalogUpstream,
} = require('./media_proxy_catalog.js');

module.exports = {
  proxyBookText,
  proxyBookFile,
  proxyCatalog,
  resolveCatalogUpstream,
  proxyMangaImage,
  proxyMangaKakalotImage,
  proxyMangaKatana,
  proxyComick,
  proxyAnimeImage,
  proxyLastfmImage,
  isAllowedLastfmImageUrl,
  proxyGalleryImage,
  cleanupGallery,
  deleteGalleryPhoto,
  proxyScanlation,
  proxyFetchHtml,
  proxyEmbed,
  proxyMangaDex,
  proxyVideoStream,
  proxyWatchStream,
  initWasm,
};
