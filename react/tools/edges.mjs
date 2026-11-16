// node tools/edges.mjs a.png b.png x y0 y1 — rows where column x changes sharply, in both images
import { PNG } from 'pngjs';
import fs from 'fs';
const [a,b,x,y0,y1]=process.argv.slice(2);
const load=p=>PNG.sync.read(fs.readFileSync(p));
const A=load(a),B=load(b);
const edges=(I)=>{const out=[];let prev=null;for(let y=+y0;y<+y1;y++){const i=(y*I.width+ +x)*4;const v=I.data[i]+I.data[i+1]+I.data[i+2];if(prev!=null&&Math.abs(v-prev)>60)out.push(y);prev=v;}return out;};
console.log('F',edges(A).join(' '));console.log('R',edges(B).join(' '));
