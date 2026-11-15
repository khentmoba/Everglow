'use strict';

const appMod = require('firebase-admin/app');
const authMod = require('firebase-admin/auth');
const firestoreMod = require('firebase-admin/firestore');
const messagingMod = require('firebase-admin/messaging');
const storageMod = require('firebase-admin/storage');

let _app;

function ensureApp() {
  if (!_app) {
    _app = appMod.initializeApp();
  }
  return _app;
}

function getAdminCompat() {
  if (!_app) ensureApp();

  if (typeof _app.auth !== 'function') {
    const legacy = {
      auth(appArg) {
        return authMod.getAuth(appArg || _app);
      },
      firestore(appArg) {
        const target = appArg || _app;
        const db = firestoreMod.getFirestore(target);
        if (typeof db.app === 'undefined') {
          Object.defineProperty(db, 'app', {
            value: target,
            enumerable: false,
            writable: true,
            configurable: true,
          });
        }
        return db;
      },
      messaging(appArg) {
        return messagingMod.getMessaging(appArg || _app);
      },
      storage(appArg) {
        return storageMod.getStorage(appArg || _app);
      },
    };

    for (const name of Object.keys(legacy)) {
      Object.defineProperty(_app, name, {
        value: legacy[name],
        enumerable: false,
        writable: true,
        configurable: true,
      });
    }

    const statics = {
      FieldValue: firestoreMod.FieldValue,
      Timestamp: firestoreMod.Timestamp,
      GeoPoint: firestoreMod.GeoPoint,
      FieldPath: firestoreMod.FieldPath,
      Filter: firestoreMod.Filter,
      BulkWriter: firestoreMod.BulkWriter,
    };
    for (const [name, value] of Object.entries(statics)) {
      Object.defineProperty(_app.firestore, name, {
        value,
        enumerable: false,
        writable: true,
        configurable: true,
      });
    }
  }

  return _app;
}

module.exports = { getAdminCompat };
