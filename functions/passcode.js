'use strict';

const crypto = require('node:crypto');

const { getAdmin, clientIp, cappedHttps, applyCors } = require('./common.js');
const { isValidPasscodeFormat } = require('./auth_core.js');

const _pcAttempts = new Map();
function _pcHit(ip) {
  const now = Date.now();
  const recent = (_pcAttempts.get(ip) || []).filter((time) => now - time < 60000);
  recent.push(now);
  _pcAttempts.delete(ip);
  _pcAttempts.set(ip, recent);
  if (_pcAttempts.size > 400) {
    for (const [k, times] of _pcAttempts) {
      if (times.length === 0 || now - times[times.length - 1] >= 60000) {
        _pcAttempts.delete(k);
      }
    }
    while (_pcAttempts.size > 400) {
      const oldestKey = _pcAttempts.keys().next().value;
      if (oldestKey === undefined) break;
      _pcAttempts.delete(oldestKey);
    }
  }
  return recent.length > 8;
}
const _PC_WINDOW_MS = 10 * 60 * 1000;
const _PC_MAX_FAILS = 20;
const _PC_LOCK_MS = 15 * 60 * 1000;
const _PC_GLOBAL_WINDOW_MS = 24 * 60 * 60 * 1000;
const _PC_GLOBAL_LOCK_MS = 30 * 60 * 1000;
const _PC_GLOBAL_MAX_FAILS = 100;

function _sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function _passcodeMatches(code, expected) {
  if (!expected) return false;
  const a = crypto.createHash('sha256').update(String(code)).digest();
  const b = crypto.createHash('sha256').update(String(expected)).digest();
  return crypto.timingSafeEqual(a, b);
}

async function _pcLockoutAttempt(db, ipRef, globalRef, accepted) {
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
    const prevGlobalLock = Number(globalData.lockedUntil || 0);
    if (
      now - globalFirstFailAt >= _PC_GLOBAL_WINDOW_MS ||
      (prevGlobalLock > 0 && prevGlobalLock <= now)
    ) {
      globalFails = 0;
      globalFirstFailAt = now;
    }
    globalFails++;
    transaction.set(globalRef, {
      fails: globalFails,
      firstFailAt: globalFirstFailAt,
      lockedUntil: globalFails >= _PC_GLOBAL_MAX_FAILS
        ? now + _PC_GLOBAL_LOCK_MS
        : 0,
    }, { merge: true });
    return { locked: false };
  });
}

function profileForPasscode(code, env = process.env) {
  const profiles = [
    ['clairjassen', env.CLAIR_PASSCODE], ['khentsgdz', env.KHENT_PASSCODE],
    ['breyan', env.BREYAN_PASSCODE], ['octagram', env.OCTAGRAM_PASSCODE],
  ];
  const matches = profiles.filter(([, expected]) => _passcodeMatches(code, (expected || '').trim()));
  return matches.length === 1 ? matches[0][0] : null;
}

const verifyPasscode = cappedHttps(10, async(req,res)=>{
  applyCors(req, res, 'POST, OPTIONS', 'Content-Type');
  if(req.method==='OPTIONS'){res.status(204).send('');return;}
  if(req.method!=='POST'){res.status(405).json({error:'POST only'});return;}
  const ip = clientIp(req);
  if(_pcHit(ip)){res.status(429).json({error:'Too many attempts'});return;}
  const code=String((req.body&&req.body.passcode)||'').trim();
  if(!code||!isValidPasscodeFormat(code)){res.status(400).json({error:'passcode required'});return;}
  const username = profileForPasscode(code);
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
  const emails = {
    clairjassen: process.env.CLAIR_EMAIL, khentsgdz: process.env.KHENT_EMAIL,
    breyan: process.env.BREYAN_EMAIL, octagram: process.env.OCTAGRAM_EMAIL,
  };
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


module.exports = { verifyPasscode, _pcLockoutAttempt, profileForPasscode };
