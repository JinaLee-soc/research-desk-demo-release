'use strict';
window.DeskTime=(()=>{
 const colors={'Research':'#dc2626','Teaching':'#2563eb','Job Market':'#d97706','Mentoring':'#16a34a','Meeting People':'#9333ea','Service':'#0891b2','Administration':'#64748b','Other networking':'#db2777'};
 let chosen='',filter='',mode='daily',year='';
 const modeNames={daily:'Daily',weekly:'Weekly trend'};
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const duration=n=>{const m=Math.round(n);return `${Math.floor(m/60)} hr ${m%60} min`};

 function combine(ms,label){
  const projects=new Map(),ids=new Set();
  for(const m of ms)for(const p of m.projects){let q=projects.get(p.name);if(!q){q={...p,minutes:0,ids:new Set()};projects.set(p.name,q)}q.minutes+=p.minutes;for(const id of p.eventIDs||[]){q.ids.add(id);ids.add(id)}}
  const days=ms.flatMap(m=>m.days).sort((a,b)=>a.date.localeCompare(b.date));
  return {month:label,days,projects:[...projects.values()].map(p=>({...p,entries:p.ids.size})).sort((a,b)=>b.minutes-a.minutes),events:ms.flatMap(m=>m.events).sort((a,b)=>b.start.localeCompare(a.start)),minutes:ms.reduce((n,m)=>n+m.minutes,0),overlapMinutes:ms.reduce((n,m)=>n+m.overlapMinutes,0),uniqueMinutes:ms.reduce((n,m)=>n+m.uniqueMinutes,0),entries:ids.size,daysRecorded:days.length,allDayExcluded:ms.reduce((n,m)=>n+m.allDayExcluded,0),unfinishedExcluded:ms.reduce((n,m)=>n+m.unfinishedExcluded,0),detailsOmitted:ms.some(m=>m.detailsOmitted),eventsTruncated:ms.some(m=>m.eventsTruncated)};
 }
 function buckets(ms,kind,endDate){
  const days=ms.flatMap(m=>m.days),out=new Map();
  const start=ms.map(m=>m.month).sort()[0]+'-01';
  const lastMonth=ms.map(m=>m.month).sort().at(-1);
  const last=new Date(Date.UTC(Number(lastMonth.slice(0,4)),Number(lastMonth.slice(5)),0)).toISOString().slice(0,10);
  const end=last<endDate?last:endDate;
  function key(date){if(kind==='monthly')return date.slice(0,7);if(kind==='yearly')return date.slice(0,4);if(kind==='weekly'){const d=new Date(date+'T00:00:00Z');d.setUTCDate(d.getUTCDate()-(d.getUTCDay()+6)%7);return d.toISOString().slice(0,10)}return date}
  for(let d=new Date(start+'T00:00:00Z');d.toISOString().slice(0,10)<=end;d.setUTCDate(d.getUTCDate()+1)){const date=d.toISOString().slice(0,10),k=key(date);if(!out.has(k))out.set(k,{key:k,minutes:0,categories:{}})}
  for(const d of days){const b=out.get(key(d.date));if(!b)continue;b.minutes+=d.minutes;for(const [c,n] of Object.entries(d.categories))b.categories[c]=(b.categories[c]||0)+n}
  return [...out.values()];
 }
 function axisFor(months,kind,endDate){
  if(kind==='daily')return {ceiling:900,tickHours:5};
  const peak=Math.max(0,...buckets(months,kind,endDate).map(b=>b.minutes))/60;
  const raw=Math.max(1,peak/5),power=10**Math.floor(Math.log10(raw));
  const tick=[1,2,3,5,10].map(n=>n*power).find(n=>n>=raw);
  return {ceiling:tick*5*60,tickHours:tick};
 }
 function chart(bs,categories,kind,label,axis){
  const ceiling=axis.ceiling,left=48,bottom=240,h=210,weekly=kind==='weekly';
  const start=Date.UTC(Number(label.slice(0,4)),0,1),end=Date.UTC(Number(label.slice(0,4))+1,0,1);
  const x=i=>weekly?left+Math.max(0,Date.parse(bs[i].key+'T00:00:00Z')-start)/(end-start)*920:left+920/Math.max(1,bs.length)*(i+.5);
  const y=n=>bottom-n/ceiling*h;
  let svg=`<svg viewBox="0 0 1000 285" role="img" aria-label="${esc(label)} ${weekly?'Weekly total work-time line':'Daily stacked bars'} Chart"><title>${esc(label)} Work time</title>`;
  const ticks=weekly?5:3;
  for(let i=0;i<=ticks;i++){const n=ceiling*i/ticks;svg+=`<line x1="${left}" x2="980" y1="${y(n)}" y2="${y(n)}" stroke="#e9e8e4"/><text x="${left-8}" y="${y(n)+4}" text-anchor="end">${(n/60).toFixed(n%60?1:0)}</text>`}
  svg+=`<text x="4" y="15">${weekly?'hours/week':'hr'}</text>`;
  if(weekly){
   for(const c of ['All',...categories]){const col=c==='All'?'#333330':colors[c];svg+=`<polyline points="${bs.map((b,i)=>x(i)+','+y(c==='All'?b.minutes:b.categories[c]||0)).join(' ')}" fill="none" stroke="${col}" stroke-width="${c==='All'?2.5:2}" ${c==='All'?'stroke-dasharray="6 4"':''}/>`;bs.forEach((b,i)=>{const n=c==='All'?b.minutes:b.categories[c]||0;svg+=`<circle cx="${x(i)}" cy="${y(n)}" r="2.6" fill="${col}"><title>${b.key} week starting · ${esc(c)} ${duration(n)}</title></circle>`})}
   for(let month=0;month<12;month++){const xx=left+(Date.UTC(Number(label),month,1)-start)/(end-start)*920;svg+=`<text x="${xx}" y="264" text-anchor="middle">${month+1} Month</text>`}
  }else{
   const step=920/Math.max(1,bs.length);
   bs.forEach((b,i)=>{let top=bottom;for(const c of categories){const n=b.categories[c]||0,hh=Math.min(n/ceiling*h,Math.max(0,top-(bottom-h)));top-=hh;if(hh)svg+=`<rect x="${x(i)-step*.35}" y="${top}" width="${step*.7}" height="${hh}" fill="${colors[c]}"><title>${b.key} · ${esc(c)} ${duration(n)}</title></rect>`}if(b.minutes)svg+=`<text x="${x(i)}" y="${top-6}" text-anchor="middle" class="time-total">${b.minutes>ceiling?'↑ ':''}${(b.minutes/60).toFixed(1)}</text>`;if(i===0||i===bs.length-1||(i+1)%5===0)svg+=`<text x="${x(i)}" y="264" text-anchor="middle">${Number(b.key.slice(-2))}</text>`});
  }
  return svg+'</svg>';
 }
 function render(payload){
  const tracking=payload.calendar?.timeTracking;
  const toolbar='<button type="button" class="outline" data-action="calendarRefresh">Refresh calendar</button>';
  if(!tracking?.months?.length)return `<div class="toolbar">${toolbar}</div><p class="empty">${payload.calendar?.status==='loading'?'Loading calendar work records.':'Could not load work records. Refresh the calendar to try again.'}</p>`;
  const months=tracking.months,years=[...new Set(months.map(m=>m.month.slice(0,4)))].sort().reverse();
  if(!years.includes(year))year=years[0];
  let ms;
  if(mode==='daily'){const m=months.find(m=>m.month===chosen)||months[0];chosen=m.month;ms=[m]}
  else ms=mode==='yearly'?months:months.filter(m=>m.month.startsWith(year));
  const label=mode==='daily'?chosen:mode==='yearly'?years.at(-1)+'–'+years[0]:year;
  const m=combine(ms,label);
  const elapsedDays=buckets(ms,'daily',tracking.fetchedAt.slice(0,10)).length;
  const elapsedWeeks=elapsedDays/7,weeklyAverage=n=>elapsedWeeks?n/elapsedWeeks:0;

  if(filter&&!m.projects.some(p=>p.name===filter))filter='';
  const categories=Object.keys(colors).filter(c=>m.days.some(d=>d.categories[c]));
  const top=m.projects[0],bs=buckets(ms,mode,tracking.fetchedAt.slice(0,10)),axis=axisFor(months,mode,tracking.fetchedAt.slice(0,10)),svg=chart(bs,categories,mode,label,axis);
  const categoriesTotal=categories.map(c=>({name:c,minutes:m.days.reduce((s,d)=>s+(d.categories[c]||0),0)})).sort((a,b)=>b.minutes-a.minutes);
  const projectRows=m.projects.map(p=>`<button type="button" class="time-project ${filter===p.name?'selected':''}" data-action="timeProject" data-name="${esc(p.name)}" aria-pressed="${filter===p.name}"><span>${esc(p.name)}<small>${esc(p.category)} · ${p.entries} items</small></span><span class="time-track"><span style="width:${p.minutes/(top?.minutes||1)*100}%;background:${colors[p.category]||'#555550'}"></span></span><span class="time-value">Cumulative ${duration(p.minutes)}<small>Weekly average ${duration(weeklyAverage(p.minutes))}</small><small>${m.minutes?(p.minutes/m.minutes*100).toFixed(1):0}%</small></span></button>`).join('');
  const entries=m.events.filter(e=>!filter||e.project===filter);
  return `<section class="time-dashboard"><p class="tiny muted spaced" role="status">${payload.calendar.historyCached?'Saved records · ':''}Last refreshed ${esc(tracking.fetchedAt.replace('T',' ').slice(0,16))}${payload.calendar.historyRefreshing?' · Checking latest records…':''} ${esc(payload.calendar.historyRefreshError||payload.calendar.historyCacheError||'')}</p><div class="toolbar"><div class="segmented" aria-label="Aggregation">${Object.entries(modeNames).map(([v,n])=>`<button type="button" data-action="timeMode" data-mode="${v}" aria-pressed="${mode===v}" class="${mode===v?'active':''}">${n}</button>`).join('')}</div>${mode==='daily'?`<label>Period <select data-control="timeMonth" aria-label="Work-time month">${months.map(x=>`<option value="${x.month}" ${x.month===chosen?'selected':''}>${new Date(x.month+'-02').toLocaleDateString('en-US',{month:'long',year:'numeric'})}</option>`).join('')}</select></label>`:mode!=='yearly'?`<label>Year <select data-control="timeYear" aria-label="Work-time year">${years.map(y=>`<option value="${y}" ${y===year?'selected':''}>${y} Year</option>`).join('')}</select></label>`:`<span class="small">${label} Year</span>`}${toolbar}</div>
  <p class="tiny muted">${mode==='weekly'?'Monday–Sunday totals, not daily averages. Boundary weeks include only dates within the selected year. ':''}${mode==='weekly'?'January–December weekly trend · ':''}${mode!=='daily'&&ms.some(x=>x.month.startsWith(tracking.fetchedAt.slice(0,4)))?'This year through '+tracking.fetchedAt.slice(0,10)+'cumulative; the current week is incomplete.':''} Date range: ${tracking.rangeStart?.slice(0,10)||months.at(-1).month+'-01'}–${tracking.fetchedAt.slice(0,10)}</p>
  <div class="time-summary"><div><span>Total work time</span><strong>${duration(m.minutes)}</strong><small>${m.entries} events</small></div><div><span>Weekly average</span><strong>${duration(weeklyAverage(m.minutes))}</strong><small>${elapsedDays} days ${m.daysRecorded} days recorded</small></div><div><span>Top project</span><strong class="time-top">${esc(top?.name||'No records')}</strong><small>${top?'Cumulative '+duration(top.minutes)+' · Weekly average '+duration(weeklyAverage(top.minutes)):'—'}</small></div></div>
  ${tracking.invalidIntervalsExcluded?`<p class="small spaced">Events with invalid time intervals ${tracking.invalidIntervalsExcluded} items excluded from totals.</p>`:''}
  ${tracking.status!=='complete'?'<p class="alert">Some calendar records are unavailable. Totals include retrieved records only.</p>':''}
  ${m.overlapMinutes>.01?`<p class="small spaced">Overlapping events ${duration(m.overlapMinutes)} included · Deduplicated time ${duration(m.uniqueMinutes)}</p>`:''}
  <section class="time-chart"><h2>${mode==='weekly'?'Weekly total work time':'Daily work time'}</h2>${mode==='daily'&&bs.some(b=>b.minutes>900)?'<p class="tiny muted">↑ marks records over 15 hours. Bars cap at 15; labels show actual totals.</p>':''}<p class="tiny muted spaced">Y-axis 0–${axis.ceiling/60} hours · ${axis.tickHours}hour intervals · Fixed across periods within the same aggregation.</p><div class="time-svg ${mode==='weekly'?'time-line':''}">${svg}</div><div class="time-legend">${(mode==='weekly'?['All',...categories]:categories).map(c=>`<span><i style="background:${colors[c]||'#333330'}"></i>${c}</span>`).join('')}</div>${!m.daysRecorded?'<p class="empty">No work records in this period.</p>':''}</section>
  <div class="time-breakdown"><section><h2>Time by project</h2><p class="tiny muted spaced">Select a project to see its records below.</p>${projectRows||'<p class="empty">No records</p>'}</section><section><h2>Time by activity</h2>${categoriesTotal.map(c=>`<div class="time-category"><span>${esc(c.name)}</span><strong>Cumulative ${duration(c.minutes)}<small class="time-week-average">Weekly average ${duration(weeklyAverage(c.minutes))}</small></strong><small>${m.minutes?(c.minutes/m.minutes*100).toFixed(1):0}%</small></div>`).join('')}</section></div>
  ${m.detailsOmitted?'<p class="tiny muted spaced">Totals include all records. Individual event details cover the last two months.</p>':''}<details class="time-records" ${filter?'open':''}><summary>${filter?esc(filter):'Individual events · Last two months'} · ${entries.length}records${filter?' <button type="button" data-action="timeClear">View all</button>':''}</summary><div class="table-wrap"><table class="table"><thead><tr><th>Date</th><th>Project / record</th><th>hr</th></tr></thead><tbody>${entries.map(e=>`<tr><td>${e.date}</td><td>${esc(e.project)}<small class="muted">${esc(e.title)}</small></td><td>${duration(e.minutes)}</td></tr>`).join('')}</tbody></table></div></details>
  <details class="time-method"><summary>Counting rules</summary><p>Weekly average = Total time in selected period ÷ (${elapsedDays} days ÷ 7). Includes days with no records, counting only elapsed days through today. Partial weeks use elapsed days.</p><p>Totals cover completed calendar work sessions. Projects follow calendar names; activity follows calendar categories, not title inference.</p><p>Overnight records are split by day. Overlaps are summed and reported separately. Personal, uncategorized and proposed calendars are excluded.</p><p>All-day / overnight date blocks ${m.allDayExcluded} items; ongoing events ${m.unfinishedExcluded} items excluded. Work calendars ${tracking.calendarCount} items · Time zone ${esc(tracking.timeZone)}. ${m.eventsTruncated?'Displays up to 1,000 individual events.':''}</p><p>Last checked ${esc(tracking.fetchedAt.replace('T',' ').slice(0,16))} · Source calendars are not changed.</p></details></section>`;
 }
 return {render,combine,buckets,axisFor,setMode(v){if(modeNames[v]){mode=v;filter=''}},setYear(v){year=v;filter=''},setMonth(v){chosen=v;filter=''},setProject(v){filter=filter===v?'':v},clear(){filter=''}};
})();
