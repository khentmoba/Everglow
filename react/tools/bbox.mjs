// bbox of pixels close to a colour in region: img x0 y0 x1 y1 hex tol
import { PNG } from 'pngjs'; import fs from 'fs';
const [p,x0,y0,x1,y1,hex,tol='30']=process.argv.slice(2);
const I=PNG.sync.read(fs.readFileSync(p));const c=[0,2,4].map(i=>parseInt(hex.slice(i,i+2),16));
let b=[1e9,1e9,-1,-1];
for(let y=+y0;y<+y1;y++)for(let x=+x0;x<+x1;x++){const i=(y*I.width+x)*4;if(Math.abs(I.data[i]-c[0])+Math.abs(I.data[i+1]-c[1])+Math.abs(I.data[i+2]-c[2])<+tol){b[0]=Math.min(b[0],x);b[1]=Math.min(b[1],y);b[2]=Math.max(b[2],x);b[3]=Math.max(b[3],y);}}
console.log(p.split('/').pop(),b.join(' '));
