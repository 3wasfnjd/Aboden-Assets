const SCENES = {
  lp: { title: 'لو-بولي: العينات', pond: false, flat: 30, overview: [11, 9, 21], target: [0, 1.5, -1.5], entries: [
    { id:'lp_house', inst:[{ x:-5, z:-6, over:{ seed:1 } }, { x:5.5, z:-6.5, rot:-0.3, over:{ seed:2, width:6, depth:5.5, floors:1, roofRoom:false } }] },
    { id:'lp_palm',  inst:[{ x:-9.5, z:-1.5, over:{ seed:3 } }, { x:9, z:-0.5, over:{ seed:4, height:9, lean:0.6 } }, { x:1.2, z:-9.8, over:{ seed:5, height:5 } }, { x:-1, z:3.5, over:{ seed:6, height:3, fronds:11, frondLen:1.7, bunches:0 } }] },
    { id:'lp_shaib', inst:[{ x:-0.8, z:0.6, rot:0.3, over:{ seed:7 } }, { x:0.6, z:1.2, rot:-0.5, clip:'wave', over:{ seed:8, bisht:'brown' } }, { x:-6, z:2.2, walk:[-6, 2.2, 6, 2.2], over:{ seed:9, bisht:'black' } }, { x:2.4, z:-0.6, rot:-0.9, clip:'sit_floor', over:{ seed:10, skin:'dark' } }] },
    { id:'lp_camel', inst:[{ x:4.5, z:3.9, rot:-1.75, over:{ seed:11, saddle:true, coat:'wadh' } }, { x:-12, z:5.5, walk:[-12, 5.5, 12, 5.5], over:{ seed:12 } }, { x:-8, z:1.6, rot:2.4, clip:'graze', over:{ seed:13, coat:'humr' } }] }
  ], paint: (x, z) => ({ packed: 0, wet: 0 }) }
};
