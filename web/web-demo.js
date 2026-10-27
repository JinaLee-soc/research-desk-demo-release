/* Browser-only adapter. All initial records come from the synthetic fixture export. */
'use strict';
(() => {
 const KEY='research-desk-public-demo-v1', clone=v=>JSON.parse(JSON.stringify(v));
 const uid=()=>crypto.randomUUID(), now=()=>new Date().toISOString(), day=()=>new Date().toLocaleDateString('en-CA',{timeZone:'America/Chicago'});
 const seed=window.RESEARCH_DESK_SEED;
 let state=clone(seed), storageOK=true, restored=false;
 try { const saved=JSON.parse(localStorage.getItem(KEY)||'null');if(saved?.version===1&&saved.payload?.data?.projects){state=saved.payload;restored=true;} } catch { storageOK=false; }
 if(!restored){const shift=Math.round((Date.parse(day()+'T12:00Z')-Date.parse(seed.today+'T12:00Z'))/86400000);for(const d of state.deadlines)d.date=new Date(Date.parse(d.date+'T12:00Z')+shift*86400000).toISOString().slice(0,10);}
 state.web=state.web||{baseXP:seed.rewards.total,stageRewards:{},activityXP:0,requests:[],envelopes:{}};
 const event=(kind,target,summary,extra={})=>state.data.events.push({id:uid(),at:now(),actor:'user',kind,target,summary,undone:false,...extra});
 const project=id=>state.data.projects.find(p=>p.id===id);
 const assert=(condition,message)=>{if(!condition)throw Error(message);};
 function persist(){try{localStorage.setItem(KEY,JSON.stringify({version:1,payload:state}));}catch{storageOK=false;}const e=document.getElementById('web-storage');if(e)e.textContent=storageOK?'':'Session only: browser storage is unavailable.';}
 function recalculate(){
  state.now=now();state.today=day();state.readAt=state.now;state.timeZone='America/Chicago';
  const monthEnd=new Date(state.today+'T12:00:00Z');monthEnd.setUTCMonth(monthEnd.getUTCMonth()+1);state.monthEnd=monthEnd.toISOString().slice(0,10);
  const valid=state.data.projects.filter(p=>p.included&&p.steps.every(v=>v!==null)),priority=valid.filter(p=>p.priority);
  const total=ps=>ps.reduce((n,p)=>n+p.steps.filter(v=>!v).length,0);
  state.totals={count:valid.length,total:total(valid),mean:valid.length?total(valid)/valid.length:0,priorityCount:priority.length,priorityTotal:total(priority),priorityMean:priority.length?total(priority)/priority.length:0};
  for(const d of state.deadlines){d.days=Math.round((Date.parse(d.date+'T12:00Z')-Date.parse(state.today+'T12:00Z'))/86400000);d.withinMonth=d.date>=state.today&&d.date<=state.monthEnd;state.data.deadlineSettings[d.id]=d.meta;}
  state.activity=state.data.events.filter(e=>e.kind==='activity'&&!e.undone).slice().reverse().map(e=>({id:e.id,projectID:e.target,action:e.summary,source:'Browser demo',at:e.at,actor:e.actor}));
  const earnedStage=Object.entries(state.web.stageRewards).filter(([key])=>{const [id,step]=key.split('|');return project(id)?.steps[Number(step)];}).reduce((n,[,points])=>n+points,0);
  state.rewards.total=state.web.baseXP+state.web.activityXP+earnedStage;
  state.rewards.level=Math.floor(state.rewards.total/100)+1;state.rewards.progress=state.rewards.total%100;
  const currentMonth=state.today.slice(0,7);let monthly=state.rewards.months.find(m=>m.month===currentMonth);if(monthly){const base=seed.rewards.months.find(m=>m.month===currentMonth);monthly.baseXP=(base?.baseXP||0)+state.web.activityXP+earnedStage;monthly.tasks=state.data.events.filter(e=>e.kind==='activity'&&!e.undone&&e.at.startsWith(currentMonth)).length;monthly.netStages=Object.keys(state.web.stageRewards).filter(key=>{const [id,step]=key.split('|');return project(id)?.steps[Number(step)];}).length;}
  state.rewards.decorations.forEach(d=>{d.unlocked=state.rewards.level>=d.level;d.shown=d.unlocked&&state.data.rewards.shownDecorations.includes(d.id);});
  const w=state.collectibles;
  for(const item of w.catalog){const completed=project(item.projectID)?.steps.filter(Boolean).length||0;const old=w.eligibility[item.id]||{required:0};w.eligibility[item.id]={...old,completed,unlocked:old.unlocked||completed>=old.required};}
  const available=i=>!w.owned[i.id]&&!Object.values(state.web.envelopes).some(e=>e.id===i.id)&&w.eligibility[i.id]?.unlocked&&!i.theme.startsWith('season:');
  for(const theme of new Set(w.catalog.map(i=>i.theme))){const pool=w.catalog.filter(i=>i.theme===theme&&available(i));w.offers[theme]={count:pool.length,singleID:pool.length===1?pool[0].id:'',locked:w.catalog.filter(i=>i.theme===theme&&!w.eligibility[i.id]?.unlocked).length};}
  const next=state.deadlines.filter(d=>!d.meta.completed&&d.meta.participation!=='declined').sort((a,b)=>a.date.localeCompare(b.date))[0];
  const p=project(next?.meta.projectID)||state.data.projects[0];
  state.advice={...state.advice,title:next?next.shortTitle:'Choose a next action',evidence:[next?'Fictional deadline: '+next.date:'No open fictional deadlines'],urgent:!!next&&next.days<=7,projectID:p?.id,deadlineID:next?.id||'',nextAction:p?.nextAction||'Choose a project.',mood:next&&next.days<=7?'critical':'idle',message:next?`${next.shortTitle} · ${next.days<0?'Overdue':next.days+' days away'}. ${p?.nextAction||'Check the next action.'}`:'No open deadlines. Choose a project to continue.'};
 }
 function publish(m={},notice='') {recalculate();state.replyID=m.requestID||uid();state.replyOK=true;state.error=null;state.notice=notice;persist();window.Desk?.receive(clone(state));}
 function work(id,text){assert(project(id),'Choose a project.');assert(text?.trim(),'Enter a work record.');const count=state.data.events.filter(e=>e.kind==='activity'&&e.target===id&&new Date(e.at).toLocaleDateString('en-CA',{timeZone:'America/Chicago'})===day()).length;const eid=uid();event('activity',id,text,{id:eid});if(count<3){state.web.activityXP+=10;state.data.rewards.entries.push({id:'activity:'+eid,eventID:eid,projectID:id,points:10});state.rewards.byProject[id]=(state.rewards.byProject[id]||0)+10;state.collectibles.balance+=2;state.collectibles.earned+=2;state.collectibles.ledger.unshift({id:uid(),source:'activity:'+eid,reason:'Work record',at:now(),amount:2});} }
 function collection(m){
  const w=state.collectibles,{action:a,id='',slot=''}=m,item=w.catalog.find(i=>i.id===id);
  if(a==='collectionBuy'||a==='collectionEnvelope'){
   let chosen=item;
   if(a==='collectionEnvelope'){const pool=w.catalog.filter(i=>i.theme===id&&!w.owned[i.id]&&!Object.values(state.web.envelopes).some(e=>e.id===i.id)&&w.eligibility[i.id]?.unlocked&&!i.theme.startsWith('season:'));chosen=pool[Math.floor(Math.random()*pool.length)];}
   assert(chosen&&!w.owned[chosen.id]&&!Object.values(state.web.envelopes).some(e=>e.id===chosen.id),'No new collectible available.');
   assert(!chosen.theme.startsWith('season:')&&w.eligibility[chosen.id]?.unlocked,'Complete more stages to unlock this item.');
   const price=a==='collectionEnvelope'?30:chosen.price;assert(w.balance>=price,'Not enough coins.');w.balance-=price;w.spent+=price;
   w.ledger.unshift({id:uid(),source:'purchase:'+m.requestID,reason:chosen.title,at:now(),amount:-price});
   if(a==='collectionBuy')w.owned[chosen.id]={item:clone(chosen),acquiredAt:now(),via:'purchase'};
   else{state.web.envelopes[m.requestID]=clone(chosen);w.envelopes.push({id:m.requestID,theme:chosen.theme,themeTitle:chosen.themeTitle,purchasedAt:now()});}
  }else if(a==='collectionOpen'){const i=state.web.envelopes[id];assert(i,'Envelope already opened.');w.owned[i.id]={item:i,acquiredAt:now(),via:'envelope'};delete state.web.envelopes[id];w.envelopes=w.envelopes.filter(e=>e.id!==id);
  }else if(a==='collectionDisplay'){
   assert(['wall','desk','shelf','pinboard'].includes(slot),'Choose a display position.');if(!id){delete w.display[slot];return;}
   const i=w.owned[id]?.item;assert(i,'Choose an owned item.');assert((i.kind==='object'?['desk','shelf']:['wall','pinboard']).includes(slot),'Choose a compatible position.');
   for(const key of Object.keys(w.display))if(w.display[key]===id)delete w.display[key];w.display[slot]=id;delete w.positions[id];
  }else if(a==='collectionMove'||a==='collectionResetPosition'){assert(w.display[slot]===id,'Choose a displayed item.');if(a==='collectionResetPosition')delete w.positions[id];else{assert([m.x,m.y].every(n=>Number.isFinite(n)&&n>=0&&n<=1),'Invalid position.');w.positions[id]={x:m.x,y:m.y};}
  }else if(a==='collectionFavorite'){assert(!id||w.owned[id],'Choose an owned item.');if(id)w.favorites[day().slice(0,7)]=id;else delete w.favorites[day().slice(0,7)];
  }else if(a==='collectionStickerSet'||a==='collectionStickerRemove'){
   assert(w.owned[id]&&/^\d{4}-\d{2}$/.test(slot),'Choose an owned item and month.');w.cardStickers[slot]||={};
   if(a==='collectionStickerRemove')delete w.cardStickers[slot][id];else{assert([m.x,m.y].every(n=>Number.isFinite(n)&&n>=0&&n<=1)&&m.size>=.06&&m.size<=.3,'Invalid sticker position.');w.cardStickers[slot][id]={x:m.x,y:m.y,size:m.size};}
  }else throw Error('This collection action is unavailable.');
 }
 function chat(m){
  const c=state.chat;
  if(m.action==='chatDraft'){c.draft=m.text||'';return;}
  if(m.action==='chatClear'){c.messages=[];c.draft='';return;}
  if(m.action==='chatSend'){
   const text=String(m.text||'').trim().slice(0,2000);assert(text,'Enter a message.');c.messages.push({role:'user',text});c.draft='';const p=project(m.projectID)||state.data.projects[0];
   const reply={role:'assistant',text:`[Prepared demo reply] Check the next action for ${p.title}: ${p.nextAction}. This demo does not call an AI model.`,sources:['Toy projects','Fictional deadlines']};
   if(/work record|remind/i.test(text)){reply.proposal={id:uid(),projectID:p.id,projectTitle:p.title,[/remind/i.test(text)?'nag':'activity']:text};reply.outcome='pending';reply.text='[Prepared demo reply] Confirm to save this example in your browser. Reminders appear inside this demo; no notifications are scheduled.';}
   c.messages.push(reply);
  }else if(['chatConfirm','chatDismiss'].includes(m.action)){
   const reply=c.messages.find(r=>r.proposal?.id===m.proposalID&&r.outcome==='pending');assert(reply,'This request was already handled.');const p=reply.proposal;
   if(m.action==='chatConfirm'){if(p.nag)state.nags.push({id:uid(),projectID:p.projectID,text:p.nag,message:p.nag,status:'active',hidden:false,level:1});else work(p.projectID,p.activity);}
   reply.outcome='done';reply.outcomeText=m.action==='chatConfirm'?'Saved in this browser.':'Not recorded.';
  }
 }
 function download(png,month){assert(typeof png==='string'&&/^[A-Za-z0-9+/=]+$/.test(png),'Invalid image.');const a=document.createElement('a');a.href='data:image/png;base64,'+png;a.download=`research-desk-${/^\d{4}-\d{2}$/.test(month)?month:'card'}.png`;a.click();}
 async function handle(m){
  if(!m||typeof m.action!=='string')return;
  if(state.web.requests.includes(m.requestID)){publish(m,'Request already applied.');return;}
  const before=clone(state);let notice='Saved in this browser.';
  try{
   const a=m.action,id=m.id||'',p=project(id);
   if(m.revision&&m.revision!==state.data.revision&&!['ready','reload'].includes(a))throw Error('The record changed. Close this editor and try again.');
   if(a.startsWith('collection'))collection(m);
   else if(a.startsWith('chat')){chat(m);notice='';}
   else if(a==='step'){assert(p&&Number.isInteger(m.step)&&m.step>=0&&m.step<11,'Invalid stage.');const before=p.steps[m.step];p.steps[m.step]=before!==true;event('step-value',id,'Stage changed',{step:m.step,before,after:p.steps[m.step]});if(p.steps[m.step]){const key=id+'|'+m.step;if(!state.web.stageRewards[key]&&!seed.data.projects.find(v=>v.id===id)?.steps[m.step]){state.web.stageRewards[key]=30;state.collectibles.balance+=10;state.collectibles.earned+=10;state.collectibles.ledger.unshift({id:uid(),source:'stage:'+key,reason:p.title+' · Stage complete',at:now(),amount:10});}if(p.focusStep===m.step)p.focusStep=null;}}
   else if(a==='undoStep'){const e=state.data.events.findLast(e=>e.kind==='step-value'&&!e.undone);assert(e&&project(e.target)?.steps[e.step]===e.after,'No stage change to undo.');project(e.target).steps[e.step]=e.before;e.undone=true;}
   else if(a==='activity')work(id,m.text);
   else if(a==='saveProject'){
    assert(m.title?.trim(),'Enter a title.');const row=p||{id:uid(),steps:Array(11).fill(false),wiki:'',sourceRow:0,originalStatus:'Browser demo',originalDue:'',focusStep:0};
    for(const k of ['title','journal','alternate','role','state','nextAction','note','included','priority'])if(k in m)row[k]=m[k];if(!p)state.data.projects.push(row);
   }else if(a==='saveDeadline'){
    assert(m.title?.trim()&&/^\d{4}-\d{2}-\d{2}$/.test(m.date)&&Number.isFinite(Date.parse(m.date)),'Enter a title and valid date.');let d=state.deadlines.find(d=>d.id===id);
    if(!d){d={id:uid(),meta:{category:6,participation:'considering',completed:false,critical:false,criticalReason:'',projectID:'',nextAction:'',timeZone:''}};state.deadlines.push(d);}
    Object.assign(d,{title:m.title,shortTitle:m.title,date:m.date,time:m.time||'Not provided',detail:m.detail||''});state.deadlineHash=uid();
   }else if(a==='deadlineMeta'){const d=state.deadlines.find(d=>d.id===id);assert(d,'Deadline not found.');for(const k of ['category','priority','participation','completed','critical','criticalReason','projectID','nextAction','timeZone'])if(k in m)d.meta[k]=m[k];if(d.meta.priority===0)delete d.meta.priority;
   }else if(a==='deleteDeadline'){state.deadlines=state.deadlines.filter(d=>d.id!==id);delete state.data.deadlineSettings[id];state.deadlineHash=uid();
   }else if(a==='savePlan'){assert(m.text?.trim(),'Enter a plan.');let row=state.data.plans.find(p=>p.id===id);if(!row){row={id:uid(),original:'',source:'Browser demo'};state.data.plans.push(row);}for(const k of ['text','period','kind','lane','state'])row[k]=m[k]||'';
   }else if(a==='decoration'){const d=state.rewards.decorations.find(d=>d.id===id);assert(d?.unlocked,'Decoration is locked.');state.data.rewards.shownDecorations=state.data.rewards.shownDecorations.filter(x=>x!==id);if(m.visible)state.data.rewards.shownDecorations.push(id);
   }else if(a==='focusStep'){assert(p,'Project not found.');p.focusStep=p.focusStep===m.step?null:m.step;
   }else if(a==='pin')state.data.pinnedProjectID=id;
   else if(a==='focus')state.data.focus={projectID:id,declaredAt:now(),until:new Date(Date.now()+7200000).toISOString()};
   else if(a==='stopFocus')delete state.data.focus;
   else if(a==='recordScore')state.data.history.push({id:uid(),date:day(),...state.totals,source:'Browser demo'});
   else if(a==='deadlineListSort')state.deadlineListSort=m.mode;
   else if(a==='captureNote'){assert(m.note?.text?.trim(),'Enter a note.');state.data.researchNotes.push({id:uid(),projectID:id,...m.note,createdAt:now(),shared:false});}
   else if(a.startsWith('planner')){if(a==='plannerToggle')state.planner.enabled=!state.planner.enabled;if(a==='plannerRefresh'||a==='plannerToggle')state.planner.recommendations=state.planner.enabled?state.data.projects.slice(0,3).map(p=>({id:p.id,projectID:p.id,task:p.nextAction,kind:'work',minutes:30,reason:'Prepared demo suggestion from the project next action.',sourceLabels:['Toy project']})):[];else state.planner.recommendations=state.planner.recommendations.filter(r=>r.id!==id);
   }else if(a.startsWith('nag')){const n=state.nags.find(n=>n.id===id);assert(n,'Reminder not found.');if(a==='nagDone')state.nags=state.nags.filter(n=>n.id!==id);if(a==='nagPause')n.status='paused';if(a==='nagResume')n.status='active';if(a==='nagToday')n.hidden=true;if(a==='nagProgress')n.level=1;
   }else if(['exportMonthlyCard','copyMonthlyCard'].includes(a)){download(m.png,m.month);notice='Image downloaded.';}
   else if(a==='settings'){for(const k of ['urgentDays','quietStart','quietEnd'])state.data.settings[k]=Number(m[k]);notice='Display preferences saved. System notifications are not available in this web demo.';}
   else if(['ready','reload','calendarRefresh'].includes(a)){notice=a==='ready'?'':'Demo refreshed.';}
   else if(['mini','full','hideMini','collapse'].includes(a)){document.body.classList.toggle('web-compact',a==='mini');notice='The web demo stays in this tab. The floating mini window is available in the Mac app.';}
   else if(['snooze','hideAdvice','restoreAdvice'].includes(a)){notice='Demo preference recorded. No system notification is scheduled.';}
   else if(['openWiki','openProjectLiterature','sendToLiquidText','importFromLiquidText','openProjectReferences','refreshLiteratureReferences','openLiteratureWiki','openURL','login','quit'].includes(a)){notice='Demo only: external libraries, calendars and system settings are not connected. See the README to build your own integrations.';}
   else throw Error('This action is not available in the browser demo.');
   if(!['ready','reload','chatDraft','calendarRefresh'].includes(a)){state.data.revision=uid();state.data.updatedAt=now();if(m.requestID)state.web.requests=[...state.web.requests,m.requestID].slice(-500);}
   publish(m,notice);
  }catch(error){state=before;state.replyID=m.requestID;state.replyOK=false;state.notice=error.message;state.error=null;window.Desk?.receive(clone(state));}
 }
 window.webkit={messageHandlers:{deskAction:{postMessage:m=>queueMicrotask(()=>handle(m))}}};
 document.addEventListener('DOMContentLoaded',()=>{
  document.getElementById('web-reset')?.addEventListener('click',()=>{if(confirm('Reset this browser’s demo records, chat and collection to the original toy data?')){try{localStorage.removeItem(KEY);}catch{}location.reload();}});
  persist();
 });
})();
