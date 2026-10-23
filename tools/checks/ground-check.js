// لكل شخصية وحركة: أدنى نقطة لكل جزء (لكشف الاختراق) وأدنى نقطة للورك/الفخذ
const AA=require('./load.js');
for(const id of (process.argv[2]||'shaib,woman,child,worker,girl,boy').split(',')){const a=AA.assets[id],o=a.generate(AA.params(a,{}),'low'),sk=o.skeleton;
 for(const [cn,c] of Object.entries(o.clips)){let res={},hip=1e9,feet=1e9;for(let s=0;s<=8;s++){const m=AA.boneMatrices(sk,c,s/8*c.duration);
  for(const [pn,p] of Object.entries(o.parts)){if(!p.skinIndex)continue;const P=AA.posePart(sk,p,m);for(let i=0;i<P.length/3;i++){const y=P[i*3+1];res[pn]=Math.min(res[pn]??1e9,y);let best=-1,bw=0;for(let k=0;k<4;k++)if(p.skinWeight[i*4+k]>bw){bw=p.skinWeight[i*4+k];best=p.skinIndex[i*4+k];}const nm=sk.bones[best].name;if(/foot/.test(nm))feet=Math.min(feet,y);if(/hips|thigh/.test(nm))hip=Math.min(hip,y);}}}
  const bad=Object.entries(res).filter(([k,v])=>v<-0.02).map(([k,v])=>k+':'+v.toFixed(2));
  console.log(id+'.'+cn,'hip',hip.toFixed(3),'feet',feet.toFixed(3),bad.length?'BELOW: '+bad.join(' '):'');}}
