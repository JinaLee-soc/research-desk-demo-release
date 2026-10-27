'use strict';
(() => {
 const reduced=()=>window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 const seal=()=>`<img class="wax-seal" src="completion-laurel-wax.png" alt="" aria-hidden="true" width="27" height="27">`;
 const header=p=>{const r=p.rewards||{level:1,progress:0};return `<div class="xp-meter" aria-label="Level ${r.level}, Until next level ${100-r.progress} XP"><span>Lv. ${r.level}</span><span class="xp-fraction">${r.progress} / 100 XP</span><span class="xp-track" role="progressbar" aria-label="Next level" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${r.progress}"><i style="width:${r.progress}%"></i></span></div>`;};
 let timer;
 function effect(points,level,leveled,detail){
  let el=document.getElementById('reward-feedback');
  if(!el){el=document.createElement('div');el.id='reward-feedback';el.setAttribute('role','status');el.setAttribute('aria-live','polite');document.body.append(el);}
  clearTimeout(timer);el.className='reward-feedback'+(leveled?' level-up':'');el.replaceChildren();
  const amount=document.createElement('strong');amount.textContent=`+${points} XP`;el.append(amount);
  const copy=document.createElement('span');copy.textContent=[leveled?`Lv. ${level} · Level up`:'',detail||(!leveled?'Your work adds up':'')].filter(Boolean).join(' · ');el.append(copy);
  el.hidden=false;
  if(!reduced()){
   el.animate([{opacity:0,transform:'translate(-50%, 9px) scale(.96)'},{opacity:1,transform:'translate(-50%, 0) scale(1)'}],{duration:240,easing:'ease-out'});
   if(leveled){
    const ring=document.createElement('i');ring.className='reward-ring';el.append(ring);
    ring.animate([{opacity:.65,transform:'scale(.8)'},{opacity:0,transform:'scale(1.45)'}],{duration:650,easing:'ease-out'});
    document.querySelectorAll('.xp-meter').forEach(m=>m.animate([{opacity:.45},{opacity:1}],{duration:600}));
   }
  }
  timer=setTimeout(()=>{el.hidden=true;},leveled?2400:1500);
 }
 function received(old,next){
  if(!old?.data||!next.data||next.error||next.replyOK===false||old.data.revision===next.data.revision)return;
  const before=old.rewards?.total||0,after=next.rewards?.total||0;
  const known=new Set((old.rewards?.bonuses||[]).map(b=>b.id));
  const bonus=(next.rewards?.bonuses||[]).filter(b=>!known.has(b.id));
  const detail=bonus.map(b=>b.kind==='time'?`3 research hours achieved +${b.points} XP`:b.kind==='comeback'?`Restart +${b.points} XP`:`${b.streak}day streak +${b.points} XP`).join(' · ');
  const unlocks=(next.rewards?.decorations||[]).filter(d=>d.unlocked&&!(old.rewards?.decorations||[]).find(o=>o.id===d.id)?.unlocked);
  if(after>before)effect(after-before,next.rewards.level,next.rewards.level>(old.rewards?.level||1),[detail,...unlocks.map(d=>d.name+' Unlock')].filter(Boolean).join(' · '));
  if(reduced())return;
  for(const p of next.data.projects){
   const prior=old.data.projects.find(v=>v.id===p.id);if(!prior)continue;
   for(let i=0;i<11;i++)if(p.steps[i]===true&&prior.steps[i]!==true){
    document.querySelectorAll('[data-action="step"]').forEach(el=>{
     if(el.dataset.id!==p.id||Number(el.dataset.step)!==i)return;
     (el.querySelector('.wax-seal')||el).animate([{transform:'scale(1.22)',opacity:.35},{transform:'scale(.94)',opacity:1,offset:.7},{transform:'scale(1)',opacity:1}],{duration:260,easing:'ease-out'});
    });
   }
   if(p.included&&p.steps.every(v=>v===true)&&!prior.steps.every(v=>v===true)){
    const row=[...document.querySelectorAll('[data-row]')].find(el=>el.dataset.row===p.id);
    row?.querySelector('.wax-seal')?.animate([{transform:'scale(1.35) rotate(-12deg)',opacity:.3},{transform:'scale(1) rotate(0)',opacity:1}],{duration:340,easing:'ease-out'});
   }
  }
 }
 const hours=m=>`${Math.floor(m/60)} hr ${Math.floor(m%60)} min`;
 const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 let selectedMonth='',inventoryOpen=false;
 document.addEventListener('toggle',e=>{if(e.target.matches?.('.decoration-drawer'))inventoryOpen=e.target.open;},true);
 const officeArt={plant:'vase_flowers',flowers:'8Books',poster:'board-post-it',coffee:'lamp',sofa:'sofa',window:'green-curtains',desk:'table',computer:'computer',chair:'chair1',books:'shelf-books',wall:'living-wall',floor:'living-floor'};
 const crop=id=>id==='person'?`<span class="pixel-crop owner-crop"><img src="PixelOfficeAssets.png" alt="" style="width:${256/15*100}%;height:${160/24*100}%;left:${-2/15*100}%;top:${-104/24*100}%"></span>`:`<img class="styloo-sprite" src="styloo-${officeArt[id]||officeArt.plant}.png" alt="" aria-hidden="true">`;
 const sprite=id=>`<span class="decoration-sprite decor-${escape(id)}" aria-hidden="true">${crop(id)}</span>`;
 function streak(p,id){const s=p.rewards?.streaks?.[id];return s?`<p class="project-streak">Streak ${s.current} days <span>· Best ${s.best} days</span></p>`:'';}
 function officeObjects(p){return (p.rewards?.decorations||[]).filter(d=>d.shown).map(d=>`<span class="office-unlock placed-${escape(d.id)}" role="img" aria-label="${escape(d.name)}">${sprite(d.id)}</span>`).join('');}
 function inventory(p){return `<details class="decoration-drawer" ${inventoryOpen?'open':''}><summary>Decoration inventory · ${(p.rewards?.decorations||[]).filter(d=>d.unlocked).length} / 5 Unlock</summary><p class="office-caption">Decorate your office with items unlocked by leveling up.</p><div class="decoration-list">${(p.rewards?.decorations||[]).map(d=>`<div class="decoration-item ${d.unlocked?'':'locked'}">${sprite(d.id)}<div><strong>${escape(d.name)}</strong><small>Lv. ${d.level}${d.unlocked?' · Unlocked':''}</small></div><button class="outline" data-action="decoration" data-id="${escape(d.id)}" data-visible="${!d.shown}" aria-pressed="${d.shown}" ${!d.unlocked||p.error?'disabled':''}>${d.unlocked?(d.shown?'Hide':'Display'):'Locked'}</button></div>`).join('')}</div></details>`;}
 function cardData(p){const months=p.rewards?.months||[];return months.find(m=>m.month===selectedMonth)||months[0];}
 const sectionHead=(n,title)=>`<header class="note-section-head"><span>${n}</span><div><h4>${title}</h4></div></header>`;
 const metric=(label,value)=>`<div><span>${label}</span><strong>${value}</strong></div>`;
 let cardRenderSequence=0,visibleCard=null;
 function monthly(p){
  if(p.rewards?.researchDayThresholdMinutes!==180)return '<section class="monthly-achievement"><h2>Monthly achievements</h2><p role="status">Quit from the Research Desk menu and reopen to apply the updated calculation.</p></section>';
  const m=cardData(p);if(!m)return '';
  visibleCard={p,m};document.getElementById('monthly-card-menu')?.remove();
  const date=m.month.replace('-','. ');
  const renderID=++cardRenderSequence;
  requestAnimationFrame(()=>paintCard(p,m,renderID));
  return `<section class="monthly-achievement"><div class="row between"><h2>Monthly achievements</h2><div class="row"><select data-control="rewardMonth" aria-label="Achievement month" ${window.DeskCardStickers?.isSaving()?'disabled':''}>${p.rewards.months.map(v=>`<option value="${v.month}" ${v.month===m.month?'selected':''}>${v.month}</option>`).join('')}</select><button class="outline" data-action="calendarRefresh">Refresh time</button><button class="outline" data-action="exportMonthlyCard" ${window.DeskCardStickers?.isSaving()?'disabled':''}>Save as image</button></div></div>${window.DeskCardStickers?.controls(p,m)||''}<article data-card-render="${renderID}" data-card-month="${m.month}" class="achievement-paper canonical-card ${window.DeskCardStickers?.isEditing()?'sticker-editing':''}"><div class="canonical-card-text"><aside class="note-margin">${date}</aside><div class="note-brand">Research Desk Demo</div><header class="note-title"><h3>Monthly achievements</h3><span>${date}</span></header><section class="note-section research-time-summary">${sectionHead('01','Research hours')}<div class="note-hours">${m.timeVerified?`<b>${Math.floor(m.researchMinutes/60)}</b> hr ${Math.floor(m.researchMinutes%60)} min`:'Awaiting confirmation'}</div></section><section class="note-section">${sectionHead('02','Consistency record')}<div class="note-metrics">${metric('3 hours of research per day',m.timeVerified?m.threeHourDays+' days':'—')}${metric('Research record',m.tasks+' items')}${metric('net stages advanced',(m.netStages>0?'+':'')+m.netStages)}</div></section><section class="note-section">${sectionHead('03','Experience earned')}<div class="note-xp"><b>${m.baseXP+m.bonusXP}</b> XP</div><p class="note-breakdown">Default ${m.baseXP} · Work bonus ${m.bonusXP-(m.timeXP||0)} · hr ${m.timeXP||0} XP</p><div class="note-metrics note-pair">${metric('Longest streak',m.longestStreak+' days')}${metric('Restart',m.comebacks+' times')}</div></section><section class="note-section note-last">${sectionHead('04','This month’s progress')}<div class="note-project"><div><p class="note-leaders">${escape(m.leaders.join(', ')||'None yet')}</p><div class="note-metrics note-pair">${metric('Completion seal',m.seals.length+' items')}${metric('New decoration',escape(m.unlocks.join(', ')||'None yet'))}</div><p class="note-seal-names">${escape(m.seals.join(', '))}</p></div>${m.seals.length?seal():''}</div></section>${window.DeskCollection?.monthlyHTML(p,m)||''}</div><img class="canonical-card-image" alt="" aria-hidden="true"><span class="card-render-status" role="status">Loading card…</span>${window.DeskCardStickers?.layer(p,m)||''}</article><details class="ledger-status"><summary>Research-time status</summary><p>${escape(p.timeRewardStatus||'Waiting for research-time check')}${p.rewards.timeVerifiedAt?' · Last checked '+escape(p.rewards.timeVerifiedAt):''}${p.rewards.timeStartDay?' · Rewards start '+escape(p.rewards.timeStartDay):''}</p></details></section>`;
 }
 async function renderCard(p,m,stickers=true){
  if(p.rewards?.researchDayThresholdMinutes!==180)throw new Error('Restart Research Desk to apply the updated reward calculation.');
  if(!m)return;await document.fonts.ready;
  const canvas=document.createElement('canvas');canvas.width=1200;let ctx=canvas.getContext('2d');
  const face='-apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif';
  const wrap=(value,width)=>{ctx.font=`30px ${face}`;const result=[];let line='';for(const c of value){if(ctx.measureText(line+c).width>width){result.push(line);line='';}line+=c;}result.push(line);return result;};
  const leaders=wrap(m.leaders.join(', ')||'None yet',620),unlocks=wrap(m.unlocks.join(', ')||'None yet',330),seals=wrap(m.seals.join(', '),620);
  canvas.height=(p.collectibles?1790:1670)+leaders.length*42+unlocks.length*40+seals.length*34;ctx=canvas.getContext('2d');ctx.fillStyle='#f8f6f0';ctx.fillRect(0,0,1200,canvas.height);
  const text=(str,x,y,size=28,weight=400,color='#333330',serif=false)=>{ctx.fillStyle=color;ctx.font=`${weight} ${size}px ${serif?'Georgia, serif':face}`;ctx.fillText(str,x,y);};
  const line=(x,y,x2,y2)=>{ctx.strokeStyle='#b7b4ab';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x2,y2);ctx.stroke();};
  const rule=y=>line(185,y,1120,y);
  const heading=(n,title,y)=>{text(n,185,y,23,400,'#333330',true);line(240,y-24,240,y+8);text(title,275,y,31,600);};
  const value=(label,val,x,y)=>{text(label,x,y,24);text(val,x,y+65,45);};
  line(125,0,125,canvas.height-50);ctx.save();ctx.translate(76,270);ctx.rotate(-Math.PI/2);text(m.month.replace('-',' · '),0,0,23,400,'#333330',true);ctx.restore();
  text('Research Desk Demo',185,92,39,400,'#333330',true);rule(125);
  text('Monthly achievements',185,245,64,500);text(m.month.replace('-','. '),960,242,29,400,'#333330',true);
  heading('01','Research hours',390);
  text(m.timeVerified?hours(m.researchMinutes):'Awaiting confirmation',275,545,72,400);rule(610);
  heading('02','Consistency record',670);
  value('3 hours of research per day',m.timeVerified?m.threeHourDays+' days':'—',275,775);value('Research record',m.tasks+' items',640,775);value('net stages advanced',(m.netStages>0?'+':'')+m.netStages,910,775);line(600,750,600,855);line(870,750,870,855);rule(905);
  heading('03','Experience earned',965);text(`${m.baseXP+m.bonusXP} XP`,275,1100,78);text(`Default ${m.baseXP} · Work bonus ${m.bonusXP-(m.timeXP||0)} · hr ${m.timeXP||0} XP`,275,1150,26);line(275,1185,1120,1185);value('Longest streak',m.longestStreak+' days',275,1235);value('Restart',m.comebacks+' times',735,1235);line(665,1210,665,1310);rule(1350);
  heading('04','This month’s progress',1410);
  leaders.forEach((v,i)=>text(v,275,1510+i*42,34));let y=1530+leaders.length*42;
  value('Completion seal',m.seals.length+' items',275,y);text('New decoration',530,y,24);unlocks.forEach((v,i)=>text(v,530,y+58+i*40,30));y+=95+unlocks.length*40;seals.forEach((v,i)=>text(v,275,y+i*34,23,400,'#77746d'));
  if(m.seals.length){const im=new Image();im.src=window.__DESK_EXPORT_SEAL__||'completion-laurel-wax.png';await im.decode();ctx.drawImage(im,895,1450,220,220);}

  if(p.collectibles)await window.DeskCollection.drawMonthly(ctx,p,m,canvas.height-130);
  if(stickers)await window.DeskCardStickers?.draw(ctx,p,m);
  return canvas;
 }

 async function paintCard(p,m,renderID){
  const card=document.querySelector(`.canonical-card[data-card-render="${renderID}"]`);if(!card||card.dataset.renderStarted)return;card.dataset.renderStarted='true';
  try {const canvas=await renderCard(p,m,false);if(!card.isConnected)return;const im=card.querySelector('.canonical-card-image');im.width=canvas.width;im.height=canvas.height;im.src=canvas.toDataURL('image/png');await im.decode();if(!card.isConnected)return;card.querySelector('.card-render-status').remove();card.dataset.ready='true';}
  catch {if(card.isConnected)card.querySelector('.card-render-status').textContent='Could not load the card. Reopen this view.';}
 }
 async function exportCard(p){const m=cardData(p);if(!m)return;const canvas=await renderCard(p,m);window.Desk.send('exportMonthlyCard',{month:m.month,png:canvas.toDataURL('image/png').split(',')[1]});}

 document.addEventListener('contextmenu',e=>{
  const card=e.target.closest('.canonical-card');if(!card||!visibleCard)return;e.preventDefault();document.getElementById('monthly-card-menu')?.remove();
  const menu=document.createElement('div');menu.id='monthly-card-menu';menu.setAttribute('role','menu');
  const button=document.createElement('button');button.type='button';button.setAttribute('role','menuitem');button.textContent=window.DeskCardStickers?.isSaving()?'Saving sticker…':'Copy image';button.disabled=!!window.DeskCardStickers?.isSaving();menu.append(button);document.body.append(menu);
  const rect=card.getBoundingClientRect();menu.style.left=Math.max(8,Math.min(e.clientX||rect.left+20,innerWidth-menu.offsetWidth-8))+'px';menu.style.top=Math.max(8,Math.min(e.clientY||rect.top+20,innerHeight-menu.offsetHeight-8))+'px';button.focus();
  const snapshot=visibleCard;
  button.addEventListener('click',async()=>{button.disabled=true;button.textContent='Preparing image…';try{const canvas=await renderCard(snapshot.p,snapshot.m);window.Desk.send('copyMonthlyCard',{month:snapshot.m.month,png:canvas.toDataURL('image/png').split(',')[1]});menu.remove();}catch{button.textContent='Copy failed · Try again';button.disabled=false;}});
 });
 document.addEventListener('pointerdown',e=>{if(!e.target.closest('#monthly-card-menu'))document.getElementById('monthly-card-menu')?.remove();});
 document.addEventListener('keydown',e=>{if(e.key==='Escape')document.getElementById('monthly-card-menu')?.remove();});
 window.addEventListener('resize',()=>document.getElementById('monthly-card-menu')?.remove());

 window.DeskRewardsUI={crop,seal,header,received,streak,officeObjects,inventory,monthly,exportCard,setMonth:value=>{selectedMonth=value;}};
})();
