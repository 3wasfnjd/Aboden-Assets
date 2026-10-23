// يفحص واقعية الحركة: انزلاق القدم وقت الملامسة، اختراق الأرض، الطفو، ونسبة الخطوة لسرعة المشي
const AA=require('./load.js');
const only=process.argv[2]?process.argv[2].split(','):null;
for(const id of Object.keys(AA.assets)){
  if(only&&!only.includes(id))continue;
  const a=AA.assets[id]; const o=a.generate(AA.params(a,{}),'low'); if(!o.skeleton)continue;
  const bones=o.skeleton.bones, hasChild=new Set(bones.map(b=>b.parent));
  const feet=bones.map((b,i)=>i).filter(i=>!hasChild.has(i)&&/foot|hoof|cannon|can[FB]|low[FB]|shank|shin/i.test(bones[i].name));
  // رؤوس كل قدم
  const groups={}; for(const f of feet)groups[f]=[];
  for(const [pn,p] of Object.entries(o.parts)){ if(!p.skinIndex)continue; const n=p.positions.length/3;
    for(let i=0;i<n;i++){ let best=-1,bw=0; for(let k=0;k<4;k++){ if(p.skinWeight[i*4+k]>bw){bw=p.skinWeight[i*4+k];best=p.skinIndex[i*4+k];} } if(groups[best]&&bw>0.5)groups[best].push([pn,i]); } }
  for(const [cn,clip] of Object.entries(o.clips)){
    const N=60, res={}, ws=o.meta.walkSpeed||0, walking=/walk/.test(cn);
    const track={}; for(const f of feet)track[f]=[];
    for(let s=0;s<=N;s++){ const t=s/N*clip.duration, mats=AA.boneMatrices(o.skeleton,clip,t);
      const posed={}; for(const [pn,p] of Object.entries(o.parts)) if(p.skinIndex) posed[pn]=AA.posePart(o.skeleton,p,mats);
      for(const f of feet){ let mn=[0,1e9,0]; for(const [pn,i] of groups[f]){ const P=posed[pn]; if(P[i*3+1]<mn[1])mn=[P[i*3],P[i*3+1],P[i*3+2]]; } track[f].push([t,...mn]); } }
    // تحليل
    let minY=1e9, line=[];
    for(const f of feet){ const tr=track[f]; if(!tr.length||tr[0][2]>1e8)continue; const ys=tr.map(r=>r[2]); const m=Math.min(...ys); minY=Math.min(minY,m);
      const contact=tr.map(r=>r[2]<m+0.025); const frac=contact.filter(Boolean).length/tr.length;
      let vs=[]; for(let k=1;k<tr.length;k++) if(contact[k]&&contact[k-1]) vs.push((tr[k][3]-tr[k-1][3])/(tr[k][0]-tr[k-1][0]));
      const v=vs.length?vs.reduce((a,b)=>a+b,0)/vs.length:0, slide=vs.length?Math.max(...vs.map(x=>Math.abs(x-(walking?-ws:0)))):0;
      const lift=Math.max(...ys)-m;
      line.push(`${bones[f].name}: low=${m.toFixed(3)} contact=${(frac*100|0)}% v=${v.toFixed(2)} lift=${lift.toFixed(2)}`); }
    console.log(`${id}.${cn} (speed ${ws.toFixed(2)}): minSole=${minY.toFixed(3)}\n   `+line.join('\n   '));
  }
}
