const fs=require('fs'),vm=require('vm');global.window=global;
const R=require('path').join(__dirname,'..','..')+'/';
const html=fs.readFileSync(R+'index.html','utf8');
for(const m of html.matchAll(/<script src="((?:core|plants|architecture|animals|characters|souq|majlis|terrain|vehicles|badia)\/[^"]+)"/g)){ if(m[1].includes('viewer'))continue; vm.runInThisContext(fs.readFileSync(R+m[1],'utf8'),{filename:m[1]}); }
module.exports=global.AA;
// حزمة لو-بولي
for (const f of ['lp-core.js', 'lp-plants.js', 'lp-architecture.js', 'lp-characters.js', 'lp-animals.js']) if (fs.existsSync(R + 'lowpoly/' + f)) vm.runInThisContext(fs.readFileSync(R + 'lowpoly/' + f, 'utf8'), { filename: 'lowpoly/' + f });
