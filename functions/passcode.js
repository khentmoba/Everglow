'use strict';

const functions = require('firebase-functions/v1');

const { getAdmin } = require('./common.js');
const { isValidPasscodeFormat } = require('./auth_core.js');

// ===== verifyPasscode (Khent/Clair server gate; Breyan/Octagram stay client) =====
const _pcAttempts=new Map();
function _pcHit(ip){const n=Date.now();const a=_pcAttempts.get(ip)||[];const w=a.filter(t=>n-t<60000);w.push(n);_pcAttempts.set(ip,w);if(_pcAttempts.size>400)_pcAttempts.clear();return w.length>8;}
const verifyPasscode = functions.https.onRequest(async(req,res)=>{
  res.set('Access-Control-Allow-Origin','*');res.set('Access-Control-Allow-Methods','POST, OPTIONS');res.set('Access-Control-Allow-Headers','Content-Type');
  if(req.method==='OPTIONS'){res.status(204).send('');return;}
  if(req.method!=='POST'){res.status(405).json({error:'POST only'});return;}
  const ip=((req.headers['x-forwarded-for']||'').split(',')[0]||req.ip||'x').trim();
  if(_pcHit(ip)){res.status(429).json({error:'Too many attempts'});return;}
  const code=String((req.body&&req.body.passcode)||req.query.passcode||'').trim();
  if(!code||!isValidPasscodeFormat(code)){res.status(400).json({error:'passcode required'});return;}
  const clair=(process.env.CLAIR_PASSCODE||'').trim();const khent=(process.env.KHENT_PASSCODE||'').trim();
  let username=null;if(clair&&code===clair)username='clairjassen';else if(khent&&code===khent)username='khentsgdz';else{res.status(401).json({error:'Invalid passcode'});return;}
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


module.exports = { verifyPasscode };
