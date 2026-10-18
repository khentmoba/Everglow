'use strict';

const crypto = require('node:crypto');

const { getAdmin, clientIp, cappedHttps } = require('./common.js');
const { isValidPasscodeFormat } = require('./auth_core.js');

// ===== verifyPasscode (Khent/Clair server gate; Breyan/Octagram stay client) =====
// Per-IP and shared durable limits survive cold starts; the in-memory limit
// also runs before checking whether a submitted code is correct.
const _pcAttempts = new Map();
function _pcHit(ip) {
  const now = Date.now();
  const recent = (_pcAttempts.get(ip) || []).filter((time) => now - time < 60000);
  recent.push(now);
  _pcAttempts.set(ip, recent);
  if (_pcAttempts.size > 400) _pcAttempts.clear();
  return recent.length > 8;
}
const _PC_WINDOW_MS = 10 * 60 * 1000;
const _PC_MAX_FAILS = 20;
const _PC_LOCK_MS = 15 * 60 * 1000;
const _PC_GLOBAL_WINDOW_MS = 24 * 60 * 60 * 1000;
const _PC_GLOBAL_MAX_FAILS = 100;

function _sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function _passcodeMatches(code, expected) {
  if (!expected) return false;
  // Compare hashes (always equal length) so the check is timing-safe and
  // leaks nothing about the real passcode's length or prefix.
  const a = crypto.createHash('sha256').update(String(code)).digest();
  const b = crypto.createHash('sha256').update(String(expected)).digest();
  return crypto.timingSafeEqual(a, b);
}

async function _pcLockoutAttempt(db, ipRef, globalRef, accepted) {
  // Counter errors propagate: no guess may bypass durable enforcement.
  return await db.runTransaction(async (transaction) => {
    const now = Date.now();
    const [ipSnap, globalSnap] = await Promise.all([
      transaction.get(ipRef),
      transaction.get(globalRef),
    ]);

    const ipData = ipSnap.exists ? (ipSnap.data() || {}) : {};
    const globalData = globalSnap.exists ? (globalSnap.data() || {}) : {};
    if ([ipData, globalData].some((data) => Number(data.lockedUntil || 0) > now)) {
      return { locked: true };
    }

    if (accepted) {
      if (ipSnap.exists) transaction.delete(ipRef);
      return { locked: false };
    }

    let ipFails = Number(ipData.fails || 0);
    let ipFirstFailAt = Number(ipData.firstFailAt || now);
    if (now - ipFirstFailAt > _PC_WINDOW_MS) {
      ipFails = 0;
      ipFirstFailAt = now;
    }
    ipFails++;
    transaction.set(ipRef, {
      fails: ipFails,
      firstFailAt: ipFirstFailAt,
      lockedUntil: ipFails >= _PC_MAX_FAILS ? now + _PC_LOCK_MS : 0,
    }, { merge: true });

    let globalFails = Number(globalData.fails || 0);
    let globalFirstFailAt = Number(globalData.firstFailAt || now);
    if (now - globalFirstFailAt >= _PC_GLOBAL_WINDOW_MS) {
      globalFails = 0;
      globalFirstFailAt = now;
    }
    globalFails++;
    transaction.set(globalRef, {
      fails: globalFails,
      firstFailAt: globalFirstFailAt,
      lockedUntil: globalFails >= _PC_GLOBAL_MAX_FAILS
        ? globalFirstFailAt + _PC_GLOBAL_WINDOW_MS
        : 0,
    }, { merge: true });
    return { locked: false };
  });
}

const verifyPasscode = cappedHttps(10, async(req,res)=>{
  res.set('Access-Control-Allow-Origin','*');res.set('Access-Control-Allow-Methods','POST, OPTIONS');res.set('Access-Control-Allow-Headers','Content-Type');
  if(req.method==='OPTIONS'){res.status(204).send('');return;}
  if(req.method!=='POST'){res.status(405).json({error:'POST only'});return;}
  // Use Google's appended client hop, never the caller-supplied XFF prefix.
  const ip = clientIp(req);
  if(_pcHit(ip)){res.status(429).json({error:'Too many attempts'});return;}
  const code=String((req.body&&req.body.passcode)||'').trim();
  if(!code||!isValidPasscodeFormat(code)){res.status(400).json({error:'passcode required'});return;}
  const clair=(process.env.CLAIR_PASSCODE||'').trim();const khent=(process.env.KHENT_PASSCODE||'').trim();
  let username;
  if(_passcodeMatches(code, clair))username='clairjassen';
  else if(_passcodeMatches(code, khent))username='khentsgdz';
  let lock;
  try {
    const db = getAdmin().firestore();
    const attempts = db.collection('auth_attempts');
    const ipRef = attempts.doc(_sha256Hex(ip));
    const globalRef = attempts.doc('global');
    lock = await _pcLockoutAttempt(db, ipRef, globalRef, Boolean(username));
  } catch (e) {
    console.error('[verifyPasscode] lockout transaction failed:', e.message);
    res.status(503).json({error:'Login temporarily unavailable'});return;
  }
  if(lock.locked){res.status(429).json({error:'Too many attempts — try again later'});return;}
  if(!username){res.status(401).json({error:'Invalid passcode'});return;}
  const emails={clairjassen:process.env.CLAIR_EMAIL||'',khentsgdz:process.env.KHENT_EMAIL||''};
  const email=emails[username];if(!email){res.status(500).json({error:'Server not configured'});return;}
  try{
    let user;
    try{
      user=await getAdmin().auth().getUserByEmail(email);
    }catch(e){
      if(e.code==='auth/user-not-found'){
        console.log('verifyPasscode: user not found for '+email+', creating...');
        user=await getAdmin().auth().createUser({email, emailVerified:true, displayName: username});
        console.log('verifyPasscode: created user '+user.uid+' for '+email);
      } else { throw e; }
    }
    const t=await getAdmin().auth().createCustomToken(user.uid,{username});
    res.json({token:t,username});
  }catch(e){console.error('verifyPasscode',e.code||e.message, e.stack||'');res.status(500).json({error:'Auth failed'});}
});


module.exports = { verifyPasscode, _pcLockoutAttempt };
