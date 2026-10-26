'use strict';
(()=>{
 const drafts=new Map();let pending=null;
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const day=at=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Chicago',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(at));
 const draft=id=>{if(!drafts.has(id))drafts.set(id,{text:'',requestID:'',error:''});return drafts.get(id);};
 function view(p,id){
  const d=draft(id),ready=p.rewards?.activityDailyLimit===3;
  const events=(p.data.events||[]).filter(e=>e.target===id&&e.kind==='activity'&&e.actor==='user'&&!e.undone).slice().reverse();
  const rewards=new Map((p.data.rewards?.entries||[]).filter(r=>r.step==null).map(r=>[r.eventID,r.points]));
  const today=events.filter(e=>day(e.at)===day(p.now));const earned=today.reduce((n,e)=>n+(rewards.get(e.id)||0),0);
  return `<section class="office-daily"><div class="row between"><h3>Today’s work</h3><span class="tiny">Today’s XP ${Math.min(3,earned/10)} / 3 times</span></div><form data-office-log="${esc(id)}"><label class="office-log-label" for="office-log-text">Research record</label><div class="office-log-input"><input id="office-log-text" name="text" maxlength="1000" autocomplete="off" placeholder="Record today’s work in one line" value="${esc(d.text)}" ${pending?'disabled':''}><button class="primary" type="submit" ${pending||!ready||p.error?'disabled':''}>${pending?'Saving…':earned>=30?'Record':'Record +10 XP'}</button></div><p class="office-log-status" role="status">${esc(d.error||(!ready?'Restart the app to apply the update.':earned>=30?'Daily recording XP for this project is complete. You can still record more work.':''))}</p></form><h3>Recent records</h3>${events.slice(0,5).map(e=>`<div class="office-log-entry"><time>${esc(new Intl.DateTimeFormat('en-US',{timeZone:'America/Chicago',month:'numeric',day:'numeric',hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date(e.at)))}</time><p>${esc(e.summary)}</p><span>${rewards.has(e.id)?'+'+rewards.get(e.id)+' XP':'Record'}</span></div>`).join('')||'<p class="office-caption">No records yet.</p>'}</section>`;
 }
 document.addEventListener('input',e=>{const f=e.target.closest('[data-office-log]');if(!f)return;const d=draft(f.dataset.officeLog);d.text=e.target.value;d.requestID='';d.error='';});
 document.addEventListener('submit',e=>{const f=e.target.closest('[data-office-log]');if(!f)return;e.preventDefault();if(pending)return;const id=f.dataset.officeLog,d=draft(id);if(!d.text.trim()){d.error='Enter today’s work.';f.querySelector('[role=status]').textContent=d.error;return;}d.requestID ||= crypto.randomUUID();pending={id,requestID:d.requestID};f.querySelector('button').disabled=true;f.querySelector('input').disabled=true;f.querySelector('button').textContent='Saving…';window.Desk.send('activity',{id,text:d.text,requestID:d.requestID});});
 function receive(p){if(!pending||p.replyID!==pending.requestID)return false;const d=draft(pending.id);if(p.replyOK&&!p.error){d.text='';d.requestID='';d.error='';}else d.error=p.notice||p.error||'Could not save. Please try again.';pending=null;return true;}
 window.DeskOfficeLog={view,receive};
})();
