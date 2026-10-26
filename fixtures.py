"""Generate fictional data only. No private files or external services are read."""
from pathlib import Path
import datetime, json, uuid

def generate(res):
    res=Path(res)
    now=datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0); day=now.date(); iso=now.isoformat()
    titles=['Coffee Breaks and Collaboration','The Library Seat Effect','Plants on the Desk','Rainy Days and Reading','Walking Meetings','The Campus Noticeboard','Shared Kitchens, New Ideas','Weekend Writing Clubs']
    projects=[]
    for i,title in enumerate(titles):
        n=[8,5,3,7,2,10,11,4][i]; pid=f'toy-{i+1:02}'
        projects.append(dict(id=pid,title=title,journal='Journal of Everyday Discovery (fictional)',alternate='Toy Research Review',role='Lead' if i%2==0 else 'Coauthor',originalStatus='Synthetic example',originalDue='',sourceRow=i+1,steps=[j<n for j in range(11)],included=True,priority=i<5,focusStep=n if n<11 else None,nextAction=['Revise the opening paragraph','Check the toy table','Draft a figure caption'][i%3],wiki=f'Projects/{pid}.md',state='waiting' if i==5 else 'active',note='Fictional project created only for this demonstration.'))
    events=[]
    for i in range(80):
        t=now-datetime.timedelta(days=i%20,hours=2)
        events.append(dict(id=str(uuid.uuid4()),at=t.isoformat(),actor='user',kind='activity',target=projects[i%8]['id'],summary=['Reviewed a toy table','Drafted a fictional paragraph','Outlined a demo figure'][i%3],undone=False))
    plans=[dict(id=f'plan-{i}',lane='research',kind='research',period=str(day.replace(day=1)+datetime.timedelta(days=i*31))[:7],text=x,original='Synthetic demonstration plan',source='Toy generator',state='active' if i<2 else 'todo') for i,x in enumerate(['Finish the coffee-break paper','Present the library-seat project','Start a campus reading circle','Prepare a fictional grant application'])]
    state=dict(schema=1,revision=str(uuid.uuid4()),updatedAt=iso,sourceSHA256='synthetic',importedAt=iso,projects=projects,plans=plans,history=[dict(id=f'h-{i}',date=str(day-datetime.timedelta(days=30*i)),priorityTotal=25+5*i,priorityMean=5+i,total=36+8*i,mean=4.5+i,source='Toy data') for i in range(6)],deadlineSettings={},events=events,pinnedProjectID='toy-01',settings=dict(reminders=False,urgentDays=7,quietStart=21,quietEnd=9,alwaysOnTop=True,sort='priority',lastMorning='',lastNotificationKey=''),migrationNotes=['Every record in this demonstration is synthetic.'],researchNotes=[dict(id=str(uuid.uuid4()),projectID='toy-01',kind='thought',text='Could informal coffee breaks create new collaboration opportunities? This is a fictional demonstration note.',source='',locator='',createdAt=iso,shared=False)])
    wiki=res/'Toy Wiki'; (wiki/'Root').mkdir(parents=True,exist_ok=True); (wiki/'Projects').mkdir(exist_ok=True)
    rows=['# Fictional deadlines','','| Due date | hr | Item | Deliverables |','| --- | --- | --- | --- |']
    for i,(offset,title) in enumerate([(3,'Coffee Breaks · R&R'),(9,'Toy Discovery Fellowship'),(15,'Everyday Research Conference'),(24,'Library Seat · Special Issue'),(40,'Fictional Peer Review')]):
        did=f'demo-deadline-{i}'; rows.append(f'| {day+datetime.timedelta(days=offset)} | 17:00 | {title} <!-- desk-id: {did} --> | Fictional submission for demonstration |')
        state['deadlineSettings'][did]=dict(category=i+1,participation='considering' if i==1 else 'committed',completed=False,projectID=projects[i]['id'],nextAction='Prepare the toy submission',critical=i==0,criticalReason='Fictional priority example' if i==0 else '',timeZone='America/Chicago')
    (wiki/'Root/Deadlines.md').write_text('\n'.join(rows)+'\n')
    for p in projects:(wiki/p['wiki']).write_text('# '+p['title']+'\n\nFictional project. No real research records are included.\n\n'+p['nextAction'])
    state['rewards']=dict(shownDecorations=['plant','flowers','poster','coffee','sofa'],baselineStages=[],entries=[dict(id='activity:'+e['id'],projectID=e['target'],eventID=e['id'],points=10) for e in events],bonusBaselineActivities=[],rewardStartDay='2026-10-01')
    (res/'seed.json').write_text(json.dumps(state,ensure_ascii=False))
    (res/'portfolio-source.json').write_text(json.dumps(dict(observed_at=iso,sha256='synthetic',sheets={'pipeline':{f'A{i+1}':{'value':t} for i,t in enumerate(titles)},'plans':{'A1':{'value':'Fictional career plan'}}})))
    # Synthetic time history using the same UI schema as the original application.
    months=[]
    for ago in range(3):
        month_number=day.year*12+day.month-1-ago; first=datetime.date(month_number//12,month_number%12+1,1)
        days=[]; entries=[]
        for j in range(1,29):
            d=first.replace(day=j) if j<=28 else first
            if d>=day or d.weekday()>=5: continue
            minutes=180+(j%4)*30
            days.append(dict(date=str(d),minutes=minutes,categories={'Research':minutes-60,'Teaching':60},researchUniqueMinutes=minutes-60))
            entries.append(dict(id=f'{d}-toy',date=str(d),start=f'{d}T09:00:00-05:00',end=f'{d}T13:00:00-05:00',project=titles[0],title='Fictional reading and writing session',category='Research',minutes=minutes))
        total=sum(d['minutes'] for d in days)
        months.append(dict(month=str(first)[:7],days=days,events=entries,projects=[dict(name=titles[0],category='Research',minutes=total,eventIDs=[e['id'] for e in entries],entries=len(entries))],minutes=total,uniqueMinutes=total,overlapMinutes=0,entries=len(entries),daysRecorded=len(days),allDayExcluded=0,unfinishedExcluded=0,detailsOmitted=False,eventsTruncated=False))
    calendar=dict(status='connected',personalExcluded=True,timeZone='America/Chicago',calendarCount=2,fetchedAt=iso,windows=[dict(start=(now+datetime.timedelta(days=i,hours=1)).isoformat(),end=(now+datetime.timedelta(days=i,hours=3)).isoformat(),minutes=120) for i in range(4)],timeTracking=dict(months=months,calendarCount=2,timeZone='America/Chicago',fetchedAt=iso,rangeStart=months[-1]['month']+'-01T00:00:00-05:00',rangeEnd=iso,status='complete',calculationVersion=3,basis='calendar_work_log',truncated=False,failedCalendars=0,invalidIntervalsExcluded=0))
    (res/'demo-calendar.json').write_text(json.dumps(calendar))
