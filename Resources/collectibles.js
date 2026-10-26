'use strict';
(()=>{
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const labels={wall:'Wall frame',desk:'Desk',shelf:'Shelf',pinboard:'Pinboard'};
 let drag=null,suppressClickUntil=0;
 let payload,tab='shop',category='all',theme='all',chosen='',previewSlot='',pending=null,reveal='',error='',retry=null;
 const slots=item=>item.kind==='object'?['desk','shelf']:['wall','pinboard'];
 // Original GitHub asset bytes, revision pins, and licenses are bundled locally.
 const spriteLibrary=()=>({...window.DeskCollectibleSprites,...window.DeskSeasonalSprites});
 const seasonal=item=>!!item?.theme?.startsWith('season:');
 const projectDesign=item=>window.DeskCollectibleProjects?.resolve(item);
 const itemName=item=>projectDesign(item)?.label||item?.title||'';
 const projectColors={umber:['#f5eddf','#946a3e','#d3b885'],teal:['#eaf1e8','#47756a','#a9c7b6'],indigo:['#eceef5','#606b8a','#b9c1d4'],rose:['#f3eae5','#956b67','#d3b2a6']};
 function topicDiagram(type,ink){
  const paths={network:'M3 4h10v6h15M3 18h10v-8M13 10v10h15',bridge:'M2 18v-6h7V6h14v6h7v6M2 18h28',split:'M16 1v6H5v13M16 7h11v13',merge:'M5 1v6h11v14M27 1v6H16',three:'M16 1v6H4v13M16 6v14M16 6h12v14',compare:'M3 5h9M20 5h9M3 19h9M20 19h9M16 3v18',steps:'M2 21h7v-6h7V9h7V3h7',path:'M2 21h6v-7h8V8h9V2h6',swap:'M3 5h25v4M28 5l-3-3M29 19H4v-4M4 19l3 3',four:'M2 2h11v8H2zM19 2h11v8H19zM2 15h11v8H2zM19 15h11v8H19z',shelf:'M2 18h28M4 18v4M28 18v4',quotes:'M3 4h5v5H3V4m0 5v3h3M24 12h5v5h-5v-5m0 5v3h3',focus:'M2 8V2h7M23 2h7v6M2 16v6h7M23 22h7v-6',mirror:'M2 2h11v20H2zM19 2h11v20H19zM16 1v22',loop:'M3 6V2h25v5M28 17v5H3v-4',open:'M2 5V1h9v5M2 10h9v12H2zM21 5v17h9V5z',cross:'M3 4l6 6M9 4l-6 6M24 15l6 6M30 15l-6 6',fade:'M3 3h6v6H3zM23 4h4M23 9h4M23 14h4M23 19h4',measure:'M2 2v20h28M2 5h4M2 9h3M2 13h4M2 17h3M9 19v3M17 19v3M25 19v3',dna:'M7 1v3l18 12v5M25 1v3L7 16v5M9 3h14M11 7h10M11 12h10M9 17h14',laurels:'M8 2L3 7v10l5 5M24 2l5 5v10l-5 5'};
  return `<svg x="26" y="24" width="128" height="88" viewBox="0 0 32 24" shape-rendering="crispEdges" aria-hidden="true"><path d="${paths[type]||paths.focus}" fill="none" stroke="${ink}" stroke-width="1" opacity=".65"/></svg>`;
 }
 function topicArtwork(design,kind){
  const [,ink,soft]=projectColors[design.palette]||projectColors.umber;
  if(design.completion)return sprite('laurel',38,15,104)+sprite(design.main,65,42,50);
  const diagram=topicDiagram(design.diagram,soft);
  const positions=kind==='cover'?[43,20,78,110,71,39]:kind==='postcard'?[38,24,78,106,67,42]:[48,20,76,108,72,38];
  return diagram+sprite(design.main,...positions.slice(0,3))+sprite(design.accent,...positions.slice(3));
 }
 const seedFor=text=>[...String(text)].reduce((n,c)=>(Math.imul(n,31)+c.codePointAt(0))>>>0,0);
 function sprite(motif,x=42,y=20,size=96){
  const asset=spriteLibrary()[motif]||spriteLibrary().book;
  if(!asset)return '';
  const drawing=`<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="${asset.viewBox}" shape-rendering="crispEdges">${asset.body}</svg>`;
  return motif==='window'?`<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 32 32" shape-rendering="crispEdges"><rect x="2" y="2" width="28" height="28" fill="#785942"/><svg x="4" y="4" width="24" height="24" viewBox="${asset.viewBox}">${asset.body}</svg><path d="M15 3h2v26h-2zM3 15h26v2H3zM0 29h32v3H0z" fill="#b58b60"/></svg>`:drawing;
 }
 function artwork(item,scene=false){
  if(!item)return '';
  const seed=seedFor(item.projectID||item.id);
  const design=projectDesign(item),motif=item.motif==='project'?'book':item.motif;
  if(scene&&item.kind==='object')return `<svg class="collectible-art collectible-object" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" role="img" aria-label="${esc(itemName(item))}">${sprite(design?design.main:motif,0,0,96)}</svg>`;
  const paper=design?(projectColors[design.palette]||projectColors.umber)[0]:['#f4efe4','#ecf1e8','#f3e9e2','#eaf0f2'][seed%4],ink='#716959';
  const title=(design?(design.completion?'Collection complete':design.name):item.projectID?item.themeTitle:item.title).slice(0,26);
  let frame='';
  if(item.kind!=='object'){
   if(item.kind==='stamp'){
    const holes=[...Array(17)].map((_,i)=>`<rect x="${7+i*10}" y="4" width="4" height="4"/><rect x="${7+i*10}" y="142" width="4" height="4"/>`).join('')+[...Array(13)].map((_,i)=>`<rect x="4" y="${12+i*10}" width="4" height="4"/><rect x="172" y="${12+i*10}" width="4" height="4"/>`).join('');
    frame=`<rect x="6" y="6" width="168" height="138" fill="${paper}" stroke="${ink}"/><g fill="#fff">${holes}</g><rect x="15" y="15" width="150" height="120" fill="none" stroke="#cdc7ba"/>`;
   }else if(item.kind==='cover')frame=`<path d="M14 8h148v134H14z" fill="${paper}" stroke="${ink}"/><path d="M20 8h8v134h-8z" fill="#d1c1a4"/>`;
   else frame=`<rect x="8" y="8" width="164" height="134" fill="${paper}" stroke="#c7bfae"/>`;
   frame+=`<text x="90" y="129" text-anchor="middle" fill="#49463e" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="9">${esc(title)}</text>`;
  }
  return `<svg class="collectible-art" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 150" role="img" aria-label="${esc(itemName(item))}">${frame}${design&&item.kind!=='object'?topicArtwork(design,item.kind):sprite(design?design.main:motif,42,item.kind==='object'?27:18,96)}</svg>`;
 }
 const wallet=()=>payload?.collectibles?.projectSetVersion===2&&payload.collectibles.unlockRules===1?payload.collectibles:null;
 const catalog=()=>wallet()?.catalog||[];
 const itemByID=id=>wallet()?.owned?.[id]?.item||catalog().find(i=>i.id===id);
 const click=(text,action,id='',extra='',disabled=false)=>`<button type="button" data-collect="${action}" data-id="${esc(id)}" ${extra} ${disabled||pending?'disabled':''}>${text}</button>`;
 const clamp=n=>Math.max(0,Math.min(1,n));
 const positionStyle=pos=>pos&&Number.isFinite(pos.x)&&Number.isFinite(pos.y)?`left:${clamp(pos.x)*100}%;top:${clamp(pos.y)*100}%;transform:translate(${-clamp(pos.x)*100}%,${-clamp(pos.y)*100}%);`:'';
 function header(p){const w=p.collectibles;if(!w||w.projectSetVersion!==2||w.unlockRules!==1)return '<p class="office-caption">Restart the app to apply stage unlocks.</p>';
  const move=retry?.action==='collectionMove'||retry?.action==='collectionResetPosition';
  return `<div class="collection-toolbar"><strong>${w.balance.toLocaleString()} coins</strong>${click('Shop','tab','shop')}${click('Collection album · '+Object.keys(w.owned).length,'tab','album')}${click('Coin history','tab','wallet')}</div><p class="collection-placement-help">${w.freePlacement?'Drag to move · Arrow keys to adjust · Home resets':'Restart the app to enable free placement.'}</p>${move?`<div class="collection-move-status" role="status">${pending?'Saving position…':error?esc(error)+' '+click('Retry saving position','retryMove'):''}</div>`:''}`;
 }
 function objects(p){payload=p;const w=p.collectibles;if(!w||w.projectSetVersion!==2)return '';let display={...w.display};if(previewSlot&&chosen)display[previewSlot]=chosen;
  return Object.entries(display).map(([slot,id])=>{const item=itemByID(id),preview=previewSlot===slot;
   const pos=pending?.action==='collectionMove'&&pending.id===id?pending.position:pending?.action==='collectionResetPosition'&&pending.id===id?null:w.positions?.[id];
   const movable=w.freePlacement&&!preview&&!pending;
   return item?`<button type="button" class="collection-placed collect-${slot} ${preview?'collect-preview':''}" data-collect="slot" data-id="${slot}" data-item="${esc(id)}" data-movable="${!!movable}" style="${preview?'':positionStyle(pos)}" title="${movable?'Drag or use arrow keys · Home resets position':esc(itemName(item))}" aria-label="${esc(labels[slot]+': '+itemName(item))}" ${pending?'disabled':''}>${artwork(item,true)}</button>`:'';
  }).join('')+(w.envelopes.length?`<button class="desk-envelope" data-collect="open" data-id="${esc(w.envelopes[0].id)}" aria-label="${esc(w.envelopes[0].themeTitle)} Open envelope" ${pending?'disabled':''}><svg class="envelope-pixel" viewBox="0 0 32 32" aria-hidden="true">${sprite('envelope',0,0,32)}</svg><small>${w.envelopes.length}</small></button>`:'');
 }
 const categoryMatches=i=>category==='all'||(category==='seasonal'?seasonal(i):category==='projects'?!!i.projectID:!i.projectID&&!seasonal(i));
 function filters(){const items=tab==='album'?[...catalog(),...Object.values(wallet().owned).map(o=>o.item)]:catalog();const themes=[...new Map(items.filter(categoryMatches).map(i=>[i.theme,i.themeTitle])).entries()];return `<div class="collection-filters"><label>Category <select data-collection-filter="category">${[['all','All'],['seasonal','Seasonal & holiday'],['projects','Project'],['life','Research life']].map(([v,t])=>`<option value="${v}" ${category===v?'selected':''}>${t}</option>`).join('')}</select></label><label>Theme <select data-collection-filter="theme"><option value="all">All themes</option>${themes.map(([v,t])=>`<option value="${esc(v)}" ${theme===v?'selected':''}>${esc(t)}</option>`).join('')}</select></label></div>`;}
 function matching(i){return categoryMatches(i)&&(theme==='all'||i.theme===theme);}
 const seasonalTarget=item=>Number(item.id.split(':').at(-1));
 function seasonalCopy(item){const s=wallet()?.seasonal;if(wallet()?.owned?.[item.id])return 'Gifts earned through work records';if(s?.theme!==item.theme)return 'Past seasons';return `Days recorded ${Math.min(s.days,seasonalTarget(item))}/${seasonalTarget(item)} days · Free gift`;}
 function seasonView(){const s=wallet()?.seasonal,items=catalog().filter(i=>seasonal(i)&&matching(i));if(!s||!items.length)return '';return `<section class="seasonal-collection" aria-label="Seasonal collectibles"><div class="seasonal-heading"><h3>${esc(s.title)}</h3><span>${esc(s.start)} – ${esc(s.end)}</span></div><p>work records per day across all projects ${s.recordsPerDay}entries count as one day. ${s.milestones.join('·')} days each unlock a gift.</p><p class="seasonal-progress">Today ${Math.min(s.todayRecords,s.recordsPerDay)}/${s.recordsPerDay} times · This season ${s.days} days <span>Breaks do not reset progress · Chicago time</span></p><div class="collectible-grid seasonal-grid">${items.map(i=>itemCard(i,!!wallet().owned[i.id])).join('')}</div><p class="seasonal-note">Keep earned gifts forever. October: Halloween · November: Thanksgiving · December: Christmas · Seasonal items all year.</p></section>`;}
 const access=item=>wallet()?.eligibility?.[item.id]||{unlocked:!item.projectID,required:item.kind==='object'?6:3,completed:0};
 const locked=item=>!seasonal(item)&&!wallet()?.owned?.[item.id]&&!access(item).unlocked;
 const lockCopy=item=>{const a=access(item);return `Complete ${a.completed}/11 · ${Math.max(0,a.required-a.completed)}more stages to unlock`;};
 const maskedArt=item=>`<div class="collectible-silhouette" aria-hidden="true">${artwork(item)}</div>`;
 function itemCard(item,owned=false){const isLocked=locked(item),name=isLocked?(item.kind==='object'?'Object':'Stamp')+' · Locked':itemName(item);return `<button class="collectible-card ${chosen===item.id?'selected':''}" type="button" data-collect="inspect" data-id="${esc(item.id)}" aria-label="${esc(name)}">${isLocked?maskedArt(item):artwork(item)}<strong>${esc(name)}</strong>${item.projectID?`<span class="collectible-project-name">${esc(item.themeTitle)}</span>`:''}<span>${seasonal(item)?(owned?'Owned · Activity gift':seasonalCopy(item)):owned?'Owned':isLocked?lockCopy(item):item.price+' coins · Unlocked'}</span></button>`;}
 function inspect(){const w=wallet(),item=itemByID(chosen);if(!item)return '';const owned=w.owned[item.id],isLocked=locked(item),reserved=w.envelopes.some(e=>e.theme===item.theme)&&!owned;
  if(isLocked)return `<section class="collectible-detail" aria-label="Locked collectible"><div class="collectible-large">${maskedArt(item)}</div><div><h3>${item.kind==='object'?'Object':'Stamp'} · ${access(item).required} stages to unlock</h3><p>${esc(item.themeTitle)}</p><p>${lockCopy(item)}</p><p>${item.price} coins</p>${click('Locked','buy',item.id,'',true)}</div></section>`;
  return `<section class="collectible-detail" aria-label="Collectible preview"><div class="collectible-large">${artwork(item)}</div><div><h3>${esc(itemName(item))}</h3>${seasonal(item)?`<p>${esc(seasonalCopy(item))}</p>${!owned?'<p>Earn gifts by logging at least two activities per day during the season.</p>':''}`:''}${projectDesign(item)?.meaning?`<p class="collectible-topic">${esc(projectDesign(item).meaning)}</p>`:''}<p>${esc(item.themeTitle)}${owned?' · '+new Date(owned.acquiredAt).toLocaleDateString('en-US',{timeZone:'America/Chicago'}):''}</p><div class="collectible-actions">${slots(item).map(slot=>click(labels[slot]+' Preview','preview',item.id,`data-slot="${slot}"`)).join('')}${previewSlot?click('Close preview','stopPreview'):''}</div><div class="collectible-actions">${owned?slots(item).map(slot=>click(labels[slot]+'Display at','display',item.id,`data-slot="${slot}"`)).join('')+click('On this month’s card','favorite',item.id):seasonal(item)?click('Earned automatically through activity','buy',item.id,'',true):click(item.price+' Buy with coins','buy',item.id,'',w.balance<item.price)}</div>${reserved?'<small>Items reserved in unopened envelopes are identified when buying.</small>':''}</div></section>`;
 }
 function view(p){payload=p;const w=wallet();if(!w)return '';const all=catalog(),owned=Object.values(w.owned);let content='';
  const envelopeDesk=w.envelopes.length?`<div class="envelope-desk"><h3>Envelopes on desk</h3>${w.envelopes.map(e=>click(esc(e.themeTitle)+' · Open','open',e.id,'class="envelope-button"')).join('')}</div>`:'';
  const revealView=reveal&&w.owned[reveal]?`<section class="collection-reveal" role="status"><div>${artwork(w.owned[reveal].item)}</div><h3>${esc(itemName(w.owned[reveal].item))}</h3><div>${click('Display','inspect',reveal)}${click('Keep in album','dismiss')}</div></section>`:'';
  if(tab==='wallet')content=`<p>Total earned ${w.earned} · Buy ${w.spent}</p><p class="office-caption">10 coins per stage · 2 per work record (3 per project daily) · 6 for 3 research hours</p>${w.balance<0?'<p role="status">Updated work records applied. Owned items remain; new coins restore the balance.</p>':''}<div class="coin-ledger">${w.ledger.map(e=>`<div><time>${esc(new Date(e.at).toLocaleDateString('en-US',{timeZone:'America/Chicago'}))}</time><span>${esc(e.reason)}</span><strong>${e.amount>0?'+':''}${e.amount}</strong></div>`).join('')}</div>`;
  else if(tab==='album'){
   const themes=[...new Set(all.filter(matching).map(i=>i.theme))];
   content=filters()+`<div class="display-slots">${Object.entries(labels).map(([slot,label])=>`<div><strong>${label}</strong><span>${esc(itemName(w.owned[w.display[slot]]?.item)||'Empty')}</span>${click('Choose','slot',slot)}${w.display[slot]?click('Put away','display','',`data-slot="${slot}"`):''}${w.freePlacement&&w.positions?.[w.display[slot]]?click('Reset position','resetPosition',w.display[slot],`data-slot="${slot}"`):''}</div>`).join('')}</div>`+themes.map(t=>{const entries=all.filter(i=>i.theme===t),have=entries.filter(i=>w.owned[i.id]),bonus=w.owned['set:'+t];return `<section class="album-theme"><h3>${esc(entries[0].themeTitle)} <small>${have.length} / ${entries.length}</small></h3><div class="collectible-grid">${entries.map(i=>w.owned[i.id]?itemCard(w.owned[i.id].item,true):locked(i)||seasonal(i)?itemCard(i):`<div class="collectible-empty"><span>Undiscovered</span><small>${esc(i.kind==='stamp'?'Stamp':i.kind==='cover'?'Cover':i.kind==='object'?'Decorations':'Postcard')}</small></div>`).join('')}${bonus?itemCard(bonus.item,true):''}</div></section>`}).join('');
   const orphan=owned.filter(o=>matching(o.item)&&(!all.some(i=>i.theme===o.item.theme)||(!all.some(i=>i.id===o.item.id)&&!o.item.id.startsWith('set:'))));if(orphan.length)content+=`<h3>Earlier collectibles</h3><div class="collectible-grid">${orphan.map(o=>itemCard(o.item,true)).join('')}</div>`;
  }else{
   const themes=[...new Map(all.filter(i=>matching(i)&&!seasonal(i)).map(i=>[i.theme,i.themeTitle])).entries()];
   const filtered=all.filter(i=>matching(i)&&!seasonal(i)),week=Math.floor(new Date(p.now).getTime()/604800000),featured=filtered.slice().sort((a,b)=>a.id.localeCompare(b.id));const picks=featured.length?[0,1,2].map(n=>featured[(week*3+n)%featured.length]).filter((v,i,a)=>a.findIndex(x=>x.id===v.id)===i):[];
   content=filters()+seasonView()+(filtered.length?`<h3>On the desk this week</h3><div class="collectible-grid featured">${picks.map(i=>itemCard(i,!!w.owned[i.id])).join('')}</div><details class="envelope-shop"><summary>Mystery envelope · 30 coins</summary><div class="envelope-list">${themes.map(([id,title])=>{const offer=w.offers?.[id]||{count:0,locked:0},left=offer.count,single=all.find(i=>i.id===offer.singleID);return `<div><span>${esc(title)} <small>${single?'Envelope contents: '+esc(itemName(single)):left?'Unlocked, not owned '+left+' items':offer.locked?'Waiting for the next stage unlock':'No new collectibles'}</small></span>${click(left?'Buy envelope · 30':offer.locked?'Awaiting unlock':w.envelopes.some(e=>e.theme===id)?'Inside an envelope':'Collection complete','envelope',id,'',left===0||w.balance<30)}</div>`}).join('')}</div></details><h3>Full shop</h3><div class="collectible-grid">${filtered.map(i=>itemCard(i,!!w.owned[i.id])).join('')}</div>`:'');
  }
  return `<section class="collection-panel" aria-label="Research collectible shop"><div class="collection-tabs">${[['shop','Shop'],['album','Collection album'],['wallet','Coin history']].map(([key,label])=>click(label,'tab',key,`aria-pressed="${tab===key}"`)).join('')}</div>${error?`<p role="alert">${esc(error)}</p>`:''}${pending?'<p role="status">Saving…</p>':''}${envelopeDesk}${revealView}${inspect()}${content}</section>`;
 }
 const refresh=()=>window.Desk?.redraw();
 function send(action,id,slot='',position=null){
  if(pending||!wallet())return;if(action==='collectionBuy'&&(locked(itemByID(id))||seasonal(itemByID(id))))return;const sig=JSON.stringify([action,id,slot,position]);const requestID=retry?.sig===sig?retry.requestID:crypto.randomUUID();pending={action,id,slot,position,requestID,before:new Set(Object.keys(wallet().owned))};retry={sig,requestID,action,id,slot,position};error='';window.Desk.send(action,{id,slot,requestID,...(position||{})});refresh();
 }
 function cancelDrag(){if(!drag)return;const d=drag;drag=null;d.el.style.cssText=d.originalStyle;d.el.classList.remove('collect-dragging');if(d.el.hasPointerCapture(d.pointerID))d.el.releasePointerCapture(d.pointerID);}
 function currentPosition(el){const r=el.closest('.office-room').getBoundingClientRect(),b=el.getBoundingClientRect();return {x:clamp((b.left-r.left)/Math.max(1,r.width-b.width)),y:clamp((b.top-r.top)/Math.max(1,r.height-b.height))};}
 document.addEventListener('pointerdown',e=>{
  const el=e.target.closest('.collection-placed[data-movable="true"]');if(!el||e.button!==0||!e.isPrimary||drag||pending)return;
  const b=el.getBoundingClientRect(),r=el.closest('.office-room').getBoundingClientRect();
  drag={el,pointerID:e.pointerId,id:el.dataset.item,slot:el.dataset.id,originalStyle:el.style.cssText,startX:e.clientX,startY:e.clientY,offsetX:e.clientX-b.left,offsetY:e.clientY-b.top,room:r,width:b.width,height:b.height,moved:false,position:currentPosition(el)};
  el.setPointerCapture(e.pointerId);
 });
 document.addEventListener('pointermove',e=>{
  if(!drag||e.pointerId!==drag.pointerID)return;const d=drag;if(!d.el.isConnected){cancelDrag();return;}
  if(!d.moved&&Math.hypot(e.clientX-d.startX,e.clientY-d.startY)<4)return;
  d.moved=true;e.preventDefault();d.el.classList.add('collect-dragging');
  d.position={x:clamp((e.clientX-d.room.left-d.offsetX)/Math.max(1,d.room.width-d.width)),y:clamp((e.clientY-d.room.top-d.offsetY)/Math.max(1,d.room.height-d.height))};d.el.style.cssText=positionStyle(d.position);
 },{passive:false});
 document.addEventListener('pointerup',e=>{
  if(!drag||e.pointerId!==drag.pointerID)return;const d=drag;cancelDrag();if(!d.moved)return;
  e.preventDefault();suppressClickUntil=performance.now()+400;send('collectionMove',d.id,d.slot,d.position);
 });
 document.addEventListener('pointercancel',e=>{if(drag?.pointerID===e.pointerId)cancelDrag();});
 document.addEventListener('lostpointercapture',e=>{if(drag?.pointerID===e.pointerId)cancelDrag();});
 window.addEventListener('blur',cancelDrag);window.addEventListener('resize',cancelDrag);
 document.addEventListener('keydown',e=>{
  if(e.key==='Escape'&&drag){suppressClickUntil=performance.now()+400;cancelDrag();e.preventDefault();return;}
  const el=e.target.closest('.collection-placed[data-movable="true"]');if(!el||pending)return;
  if(e.key==='Home'){e.preventDefault();send('collectionResetPosition',el.dataset.item,el.dataset.id);return;}
  const delta={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]}[e.key];if(!delta)return;
  e.preventDefault();const pos=currentPosition(el),step=e.shiftKey ? 0.05 : 0.01;send('collectionMove',el.dataset.item,el.dataset.id,{x:clamp(pos.x+delta[0]*step),y:clamp(pos.y+delta[1]*step)});
 });
 document.addEventListener('click',e=>{if(e.target.closest('.collection-placed')&&performance.now()<suppressClickUntil){e.preventDefault();return;}const b=e.target.closest('[data-collect]');if(!b||b.disabled)return;const a=b.dataset.collect,id=b.dataset.id||'',slot=b.dataset.slot||'';
  if(a==='seasonalAlbum'){category='seasonal';theme='all';chosen=id;tab='album';document.getElementById('collection-unlock-feedback')?.remove();window.Desk.showPage('office');document.querySelector('.collection-panel')?.scrollIntoView({block:'start'});return;}
  if(a==='unlockShop'){category='projects';theme='project:'+id;chosen='';tab='shop';document.getElementById('collection-unlock-feedback')?.remove();window.Desk.showPage('office');document.querySelector('.collection-panel')?.scrollIntoView({block:'start'});return;}
  if(a==='preview'&&locked(itemByID(id)))return;
  if(a==='retryMove'&&retry){send(retry.action,retry.id,retry.slot,retry.position);return;}
  if(a==='tab'){tab=id;chosen='';previewSlot='';refresh();document.querySelector('.collection-panel')?.scrollIntoView({block:'start',behavior:'smooth'});return;}
  if(a==='inspect'){chosen=id;previewSlot='';reveal='';refresh();document.querySelector('.collectible-detail')?.scrollIntoView({block:'center'});return;}
  if(a==='preview'){previewSlot=slot;chosen=id;refresh();document.querySelector('.office-room')?.scrollIntoView({block:'center'});return;}
  if(a==='stopPreview'){previewSlot='';refresh();return;}
  if(a==='dismiss'){reveal='';refresh();return;}
  if(a==='slot'){tab='album';chosen=wallet()?.display[id]||'';previewSlot='';error=Object.values(wallet()?.owned||{}).some(o=>slots(o.item).includes(id))?labels[id]+'Choose an item to display.':'No owned items available for this position.';refresh();document.querySelector('.collection-panel')?.scrollIntoView({block:'start'});return;}
  const actions={buy:'collectionBuy',envelope:'collectionEnvelope',open:'collectionOpen',display:'collectionDisplay',favorite:'collectionFavorite',resetPosition:'collectionResetPosition'};if(actions[a])send(actions[a],id,slot);
 });
 document.addEventListener('change',e=>{const field=e.target.dataset.collectionFilter;if(!field)return;if(field==='category'){category=e.target.value;theme='all';}else theme=e.target.value;chosen='';previewSlot='';refresh();});
 let unlockTimer;
 function announceUnlocks(before,after){
  if(before?.collectibles?.unlockRules!==1||after.error||after.replyOK===false)return;
  const gifts=before.collectibles?.seasonal?Object.values(after.collectibles?.owned||{}).filter(o=>o.via==='seasonal'&&!before.collectibles.owned?.[o.item.id]).map(o=>o.item):[];
  const fresh=(after.collectibles?.catalog||[]).filter(i=>i.projectID&&after.collectibles.unlocks?.[i.id]&&!before.collectibles.unlocks?.[i.id]);
  if(!fresh.length&&!gifts.length)return;document.getElementById('collection-unlock-feedback')?.remove();clearTimeout(unlockTimer);
  const el=document.createElement('aside');el.id='collection-unlock-feedback';el.className='collection-unlock-feedback';el.setAttribute('role','status');el.innerHTML=`${artwork(gifts[0]||fresh[0])}<div><strong>${[...gifts.map(i=>esc(itemName(i))+' Gift arrived'),...fresh.map(i=>esc(itemName(i))+' Unlock')].join('<br>')}</strong>${gifts.length?click('View in album','seasonalAlbum',gifts[0].id):click('View in shop','unlockShop',fresh[0].projectID)}</div>`;document.body.append(el);
  if(!matchMedia('(prefers-reduced-motion: reduce)').matches)el.animate([{opacity:0,transform:'translateY(8px)'},{opacity:1,transform:'translateY(0)'}],{duration:220});
  unlockTimer=setTimeout(()=>el.remove(),6000);
 }
 function receive(p){cancelDrag();announceUnlocks(payload,p);if(tab==='shop'&&theme.startsWith('season:')&&theme!==p.collectibles?.seasonal?.theme)theme='all';if(chosen&&!p.collectibles?.owned?.[chosen]&&!p.collectibles?.catalog?.some(i=>i.id===chosen)){chosen='';previewSlot='';}payload=p;if(!pending||p.replyID!==pending.requestID)return false;const request=pending;pending=null;if(request.action==='collectionMove'||request.action==='collectionResetPosition')requestAnimationFrame(()=>document.querySelector(`.collection-placed[data-item="${CSS.escape(request.id)}"]`)?.focus({preventScroll:true}));if(p.replyOK&&!p.error){error='';retry=null;previewSlot='';if(request.action==='collectionOpen'){reveal=Object.keys(p.collectibles?.owned||{}).find(id=>!request.before.has(id)&&p.collectibles.owned[id].via==='envelope')||'';requestAnimationFrame(()=>document.querySelector('.collection-reveal')?.scrollIntoView({block:'center',behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'}));}}else error=p.notice||p.error||'Could not save. Please try again.';return true;}
 function monthly(p,m){const w=p.collectibles;if(!w||w.projectSetVersion!==2)return null;const key=at=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Chicago',year:'numeric',month:'2-digit'}).format(new Date(at));const count=Object.values(w.owned).filter(o=>key(o.acquiredAt)===m.month).length;return {count,item:w.owned[w.favorites[m.month]]?.item};}
 function monthlyHTML(p,m){const v=monthly(p,m);if(!v)return '';return `<div class="monthly-collection"><span>New collectible ${v.count} items</span>${v.item?`<div>${artwork(v.item)}<span>${esc(itemName(v.item))}</span></div>`:''}</div>`;}
 async function drawMonthly(ctx,p,m,y){const v=monthly(p,m);if(!v)return;ctx.fillStyle='#333330';ctx.font='24px sans-serif';ctx.fillText('New collectible '+v.count+' items',185,y+35);if(v.item){const im=new Image();im.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(artwork(v.item));await im.decode();ctx.save();ctx.imageSmoothingEnabled=false;ctx.drawImage(im,880,y-10,120,100);ctx.restore();ctx.font='20px sans-serif';ctx.fillText(itemName(v.item).slice(0,45),185,y+72);}}
 window.DeskCollection={header,view,objects,receive,monthlyHTML,drawMonthly,artwork,itemName};
})();
