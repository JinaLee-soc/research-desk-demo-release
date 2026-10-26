'use strict';
(() => {
 const root=document.getElementById('conversation');
 let payload=null,expanded=false,lastStamp='',sending=false,draftLoaded=false;
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function post(action,extra={}){
  const bridge=window.webkit?.messageHandlers?.deskAction;
  if(!bridge){root.querySelector('.chat-status').textContent='Chat is available in the native app.';return false;}
  bridge.postMessage({action,requestID:crypto.randomUUID(),...extra});return true;
 }
 function toggle(value){expanded=value;root.querySelector('.chat-history').hidden=!value;const b=root.querySelector('[data-chat="toggle"]');b.textContent=value?'Collapse chat':'Open chat';b.setAttribute('aria-expanded',String(value));}
 function paint(){window.Momo.paint(root.querySelector('canvas'));}
 function mount(){
  root.innerHTML=`<div class="chat-console"><div class="chat-history" hidden><div class="chat-history-heading"><span>MOMO · Chat</span><button type="button" data-chat="clear">Clear chat</button></div><div class="chat-log" role="log" aria-live="polite" aria-relevant="additions text" tabindex="0"></div></div><form class="chat-composer"><canvas class="chat-pet" width="192" height="208" role="img" aria-label="Momo"></canvas><div class="chat-input-wrap"><label for="chat-input">Let’s choose your next step.</label><textarea id="chat-input" rows="1" maxlength="2000" placeholder="I only have 30 minutes today. Where should I start?" aria-label="Message the assistant"></textarea></div><button type="submit" class="chat-send" aria-label="Send message">↑</button><button type="button" data-chat="toggle" aria-expanded="false" class="chat-toggle">Open chat</button></form><div class="chat-bottom"><div class="chat-shortcuts"><button type="button" data-chat="time">Just 30 minutes</button><button type="button" data-chat="why">Why this task?</button><button type="button" data-chat="progress">Record progress</button><button type="button" data-chat="nag">Set reminder</button></div><span class="chat-privacy">Toy data · Simulated replies · No AI calls</span></div><p class="chat-status" role="status"></p></div>`;
  paint();
  const input=root.querySelector('#chat-input');
  input.addEventListener('input',()=>{input.style.height='auto';input.style.height=Math.min(input.scrollHeight,88)+'px';post('chatDraft',{text:input.value});});
  input.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey&&!e.isComposing&&e.keyCode!==229){e.preventDefault();root.querySelector('form').requestSubmit();}});
  root.querySelector('form').addEventListener('submit',e=>{e.preventDefault();const text=input.value.trim();if(!text||sending||payload?.chat?.busy)return;if(post('chatSend',{text,projectID:window.Desk?.selectedProjectID?.()||''})){sending=true;input.value='';input.style.height='auto';toggle(true);root.querySelector('.chat-send').disabled=true;}});
  root.addEventListener('click',e=>{
   const b=e.target.closest('button[data-chat]');if(!b||b.disabled)return;
   switch(b.dataset.chat){
    case 'toggle':toggle(!expanded);break;
    case 'clear':if(post('chatClear')){sending=false;input.value='';input.style.height='auto';toggle(false);}break;
    case 'cancel':post('chatCancel');break;
    case 'time':case 'why':{
     if(sending||payload?.chat?.busy||payload?.error)return;
     if(input.value.trim()){input.focus();root.querySelector('.chat-status').textContent='Send or clear your current draft first. Your text is preserved.';return;}
     input.value=b.dataset.chat==='time'?'I only have 30 minutes today. Where should I start?':'Why did you suggest this task first?';
     post('chatDraft',{text:input.value});root.querySelector('form').requestSubmit();break;
    }
    case 'nag':case 'progress':{
     if(input.value.trim()){input.focus();return;}
     const p=payload?.data?.projects.find(p=>p.id===window.Desk?.selectedProjectID?.());
     input.value=(p?.title?p.title+' — ':'')+(b.dataset.chat==='nag'?'Remind me daily: ':'Work record: ');post('chatDraft',{text:input.value});input.focus();toggle(true);break;
    }
    case 'confirm':case 'dismiss':
     if(post(b.dataset.chat==='confirm'?'chatConfirm':'chatDismiss',{proposalID:b.dataset.id})){b.disabled=true;}
     break;
   }
  });
 }
 function renderMessages(chat){
  const log=root.querySelector('.chat-log'),atBottom=log.scrollHeight-log.scrollTop-log.clientHeight<35;
  const oldTop=log.scrollTop;
  log.innerHTML=(chat.messages||[]).map(m=>{
   const p=m.proposal;
   return `<article class="chat-message ${m.role==='user'?'chat-user':'chat-assistant'}"><span class="chat-speaker">${m.role==='user'?'You':'Momo'}</span><p>${esc(m.text)}</p>${m.sources?.length?`<div class="chat-sources">${m.sources.map(s=>`<span>${esc(s)}</span>`).join('')}</div>`:''}${p?`<section class="chat-proposal"><div class="chat-proposal-title">${p.nag?'Confirm reminder':'Confirm record'} · ${esc(p.projectTitle)}</div>${p.nag?`<p><span>Daily reminder</span>${esc(p.nag)}</p><small>Saved locally · Intensity rises every 3 days (maximum 3) · Pause or end in Assistant. Not a system notification.</small>`:''}${p.activity?`<p><span>Work record</span>${esc(p.activity)}</p>`:''}${p.nextAction!==undefined&&p.nextAction!==null?`<p><span>Next action</span>${esc(p.nextAction||'Not set')}</p>`:''}${p.state?`<p><span>Progress status</span>${esc({active:'Active',waiting:'Waiting for reply',hold:'On hold'}[p.state]||p.state)}</p>`:''}<small>Paper stages, scores and official deadlines stay unchanged.</small><div class="chat-proposal-actions">${m.outcome==='pending'?`<button type="button" class="primary" data-chat="confirm" data-id="${esc(p.id)}" ${payload?.error?'disabled':''}>${p.nag?'Confirm & start reminder':'Confirm & save to wiki'}</button><button type="button" data-chat="dismiss" data-id="${esc(p.id)}">Do not save yet</button>`:`<span class="${m.outcome==='failed'?'red':'blue'}">${esc(m.outcomeText||'Not recorded.')}</span>`}</div></section>`:''}</article>`;
  }).join('')||'<p class="chat-empty">Tell me your next task or progress. Records change only after you confirm.</p>';
  if(chat.busy)log.insertAdjacentHTML('beforeend','<div class="row between chat-empty"><span>Preparing a reply from relevant wiki records…</span><button type="button" data-chat="cancel" class="link">Stop reply</button></div>');
  if(atBottom)log.scrollTop=log.scrollHeight;else log.scrollTop=oldTop;
 }
 window.DeskChatUI={receive(next){
  if((window.__DESK_MODE__||new URLSearchParams(location.search).get('mode'))==='mini')return;
  payload=next;root.hidden=!next.data;document.body.classList.toggle('desk-with-chat',!!next.data);
  if(!root.firstElementChild)mount();
  const chat=next.chat||{messages:[],engine:'Codex Preparing connection',busy:false};
  if(!draftLoaded&&next.chat){root.querySelector('#chat-input').value=chat.draft||'';draftLoaded=true;}
  const stamp=JSON.stringify([chat.messages,chat.engine,chat.busy,chat.error,next.error]);
  if(stamp!==lastStamp){lastStamp=stamp;sending=false;renderMessages(chat);}
  root.querySelector('.chat-send').disabled=!!chat.busy||sending||!!next.error;
  root.querySelector('.chat-status').textContent=next.error?'Reload the wiki before chatting. Your draft is preserved.':chat.error||`${chat.engine||'Codex'} · Chats and drafts saved locally · Confirm changes before saving`;
  root.querySelector('[data-chat="clear"]').textContent='New conversation';
 },open(){toggle(true);root.querySelector('#chat-input').focus();}};
})();
