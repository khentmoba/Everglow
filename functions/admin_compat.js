'use strict';

/**
 * firebase-admin v13 → v14 compatibility layer.
 *
 * firebase-admin@14 removed the legacy namespace API (`admin.auth()`,
 * `admin.firestore()`, `admin.messaging()`, `admin.storage()` and the
 * `admin.firestore.FieldValue` / `.Timestamp` statics) from the default
 * export; only app-lifecycle functions remain there and every service moved
 * to subpath imports (`firebase-admin/auth`, etc.). This file restores the
 * legacy surface on top of the v14 subpath modules so existing call sites
 * (`getAdmin().auth().createCustomToken(...)`, `getAdmin().firestore()`,
 * ...) keep working unchanged.
 *
 * If/when the codebase migrates to subpath imports, delete this file.
 */

const appMod = require('firebase-admin/app');
const authMod = require('firebase-admin/auth');
const firestoreMod = require('firebase-admin/firestore');
const messagingMod = require('firebase-admin/messaging');
const storageMod = require('firebase-admin/storage');

let _app;

/** Lazily creates (and memoizes) the default Admin app. */
function ensureApp() {
  if (!_app) {
    _app = appMod.initializeApp();
  }
  return _app;
}

/**
 * Returns the default Admin app decorated with the pre-v14 namespace API.
 * Every accessor lazily binds to the default app, mirroring the old
 * behavior where `admin.auth()` used the default app implicitly.
 */
function getAdminCompat() {
  if (!_app) ensureApp();

  if (typeof _app.auth !== 'function') {
    const legacy = {
      /** Legacy `admin.auth(app?)`. */
      auth(appArg) {
        return authMod.getAuth(appArg || _app);
      },
      /** Legacy `admin.firestore(app?)`. */
      firestore(appArg) {
        const target = appArg || _app;
        const db = firestoreMod.getFirestore(target);
        // Legacy Firestore exposed `.app`; v14's instance does not.
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
      /** Legacy `admin.messaging(app?)`. */
      messaging(appArg) {
        return messagingMod.getMessaging(appArg || _app);
      },
      /** Legacy `admin.storage(app?)`. */
      storage(appArg) {
        return storageMod.getStorage(appArg || _app);
      },
    };

    // Attach the service accessors straight onto the app object so
    // `getAdmin().auth()` etc. work exactly like the pre-v14 namespace.
    // Non-enumerable keeps console/JSON views of the app clean.
    for (const name of Object.keys(legacy)) {
      Object.defineProperty(_app, name, {
        value: legacy[name],
        enumerable: false,
        writable: true,
        configurable: true,
      });
    }

    // Legacy statics that lived under `admin.firestore.*`.
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
