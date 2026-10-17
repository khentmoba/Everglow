'use strict';

const crypto = require('node:crypto');

const { getAdmin, clientIp, cappedHttps } = require('./common.js');
const { isValidPasscodeFormat } = require('./auth_core.js');

// ===== verifyPasscode (Khent/Clair server gate; Breyan/Octagram stay client) =====
// Two layers: a cheap in-memory pre-filter that stops hot loops inside one
// instance, plus a Firestore-backed counter that survives cold starts and
// locks an IP out for 15 minutes after 20 bad guesses in 10 minutes.
// Login attempts are rare, so the 1-2 counter reads/writes per attempt
// cost nothing and close the cold-start reset hole.
const _pcAttempts = new Map();
function _pcHit(ip){const n=Date.now();const a=_pcAttempts.get(ip)||[];const w=a.filter(t=>n-t<60000);w.push(n);_pcAttempts.set(ip,w);if(_pcAttempts.size>400)_pcAttempts.clear();return w.length>8;}
const _PC_WINDOW_MS = 10 * 60 * 1000;
const _PC_MAX_FAILS = 20;
const _PC_LOCK_MS = 15 * 60 * 1000;

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

async function _pcLockoutAttempt(db, ref, accepted) {
  try {
    return await db.runTransaction(async (transaction) => {
      const now = Date.now();
      const snap = await transaction.get(ref);
      const data = snap.exists ? (snap.data() || {}) : {};
      if (Number(data.lockedUntil || 0) > now) return { locked: true };

      let fails = Number(data.fails || 0);
      let firstFailAt = Number(data.firstFailAt || now);
      if (now - firstFailAt > _PC_WINDOW_MS) {
        fails = 0;
        firstFailAt = now;
      }

      if (accepted) {
        if (snap.exists) transaction.delete(ref);
        return { locked: false };
      }

      fails++;
      transaction.set(ref, {
        fails,
        firstFailAt,
        lockedUntil: fails >= _PC_MAX_FAILS ? now + _PC_LOCK_MS : 0,
      }, { merge: true });
      return { locked: false };
    });
  } catch (e) {
    // A correct passcode remains usable during a Firestore outage; failed
    // guesses cannot proceed when the durable lockout counter is unavailable.
    if (accepted) {
      console.warn('[verifyPasscode] lockout transaction failed for valid passcode:', e.message);
      return { locked: false };
    }
    throw e;
  }
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
    const ref = db.collection('auth_attempts').doc(_sha256Hex(ip));
    lock = await _pcLockoutAttempt(db, ref, Boolean(username));
  } catch (e) {
    console.error('[verifyPasscode] lockout transaction failed:', e.message);
    if (!username) {
      res.status(503).json({error:'Login temporarily unavailable'});return;
    }
    lock = { locked: false };
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
