// Firebase Cloud Messaging service worker.
// Required for receiving background push notifications on web.
// firebase_messaging Flutter package discovers this file automatically.

importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBMk0z4e-k_SAYzaLypYKJn3euwfx0fW5c",
  authDomain: "everglow-1c6db.firebaseapp.com",
  projectId: "everglow-1c6db",
  storageBucket: "everglow-1c6db.firebasestorage.app",
  messagingSenderId: "220334592353",
  appId: "1:220334592353:web:6b31555509529613647520",
});

const messaging = firebase.messaging();

// Show a native notification when a push arrives while the
// browser tab is closed or in the background.
messaging.onBackgroundMessage(function(payload) {
  const title = payload.notification?.title || "Everglow";
  const body = payload.notification?.body || "";
  const data = payload.data || {};

  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data,
    tag: data.type || "everglow",
  });
});

// When the user taps the notification, focus or open the app.
self.addEventListener("notificationclick", function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then(function(clientList) {
      // If the app is already open, focus it.
      for (const client of clientList) {
        if ("focus" in client) return client.focus();
      }
      // Otherwise open a new window.
      return clients.openWindow("/");
    })
  );
});
