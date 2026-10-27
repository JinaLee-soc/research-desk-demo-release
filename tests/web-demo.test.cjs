const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const {webcrypto}=require('node:crypto');
const {resolve}=require('node:path');
const root=resolve(__dirname,'..');
const seedSource=readFileSync(resolve(root,'web-dist/web-seed.js'),'utf8');
const adapter=readFileSync(resolve(root,'web/web-demo.js'),'utf8');
function boot(storage=new Map(),blocked=false){
 let payload;
 const ctx={console,crypto:webcrypto,queueMicrotask,URL,Date,confirm:()=>true,location:{reload(){}},document:{getElementById:()=>null,addEventListener(){},body:{classList:{toggle(){}}}},localStorage:{getItem:k=>{if(blocked)throw Error('blocked');return storage.get(k)},setItem:(k,v)=>{if(blocked)throw Error('blocked');storage.set(k,v)},removeItem:k=>storage.delete(k)}};
 ctx.window=ctx;ctx.Desk={receive:p=>payload=p};vm.createContext(ctx);vm.runInContext(seedSource,ctx);vm.runInContext(adapter,ctx);
 return {storage,get state(){return payload},async send(action,extra={}){ctx.webkit.messageHandlers.deskAction.postMessage({action,requestID:webcrypto.randomUUID(),...extra});await new Promise(r=>setImmediate(r));return payload;}};
}
(async()=>{
 const app=boot();await app.send('ready');const initial=app.state;assert.equal(initial.data.projects.length,8);assert.equal(initial.deadlines.length,5);
 const points=initial.rewards.total,coins=initial.collectibles.balance,total=initial.totals.total;
 await app.send('step',{id:'toy-01',step:8});assert.equal(app.state.totals.total,total-1);assert.equal(app.state.rewards.total,points+30);assert.equal(app.state.collectibles.balance,coins+10);
 await app.send('undoStep');assert.equal(app.state.totals.total,total);assert.equal(app.state.rewards.total,points);
 await app.send('step',{id:'toy-01',step:8});assert.equal(app.state.collectibles.balance,coins+10);
 await app.send('step',{id:'toy-01',step:99});assert.equal(app.state.replyOK,false);assert.equal(app.state.totals.total,total-1);
 await app.send('saveProject',{id:'toy-01',title:'Outdated',revision:'old'});assert.equal(app.state.replyOK,false);assert.notEqual(app.state.data.projects[0].title,'Outdated');
 await app.send('saveDeadline',{title:'Toy web deadline',date:'2030-01-15',time:'12:00',detail:'Synthetic example'});const deadline=app.state.deadlines.at(-1);assert.equal(deadline.title,'Toy web deadline');
 await app.send('deadlineMeta',{id:deadline.id,completed:true});assert.equal(app.state.deadlines.at(-1).meta.completed,true);
 await app.send('deleteDeadline',{id:deadline.id});assert.equal(app.state.deadlines.length,5);
 for(const id of ['plant','flowers','poster','coffee','sofa']){await app.send('decoration',{id,visible:false});assert.equal(app.state.rewards.decorations.find(d=>d.id===id).shown,false);await app.send('decoration',{id,visible:true});}
 const item=app.state.collectibles.catalog.find(i=>i.id.startsWith('life:')&&i.kind==='object');const balance=app.state.collectibles.balance;
 await app.send('collectionBuy',{id:item.id});assert.equal(app.state.collectibles.balance,balance-item.price);assert.ok(app.state.collectibles.owned[item.id]);
 await app.send('collectionBuy',{id:item.id});assert.equal(app.state.replyOK,false);assert.equal(app.state.collectibles.balance,balance-item.price);
 await app.send('collectionDisplay',{id:item.id,slot:'desk'});assert.equal(app.state.collectibles.display.desk,item.id);
 await app.send('collectionMove',{id:item.id,slot:'desk',x:.4,y:.6});assert.equal(app.state.collectibles.positions[item.id].x,.4);
 await app.send('collectionStickerSet',{id:item.id,slot:'2030-01',x:.4,y:.2,size:.16});assert.equal(app.state.collectibles.cardStickers['2030-01'][item.id].size,.16);
 const offer=Object.entries(app.state.collectibles.offers).find(([key,o])=>key.startsWith('life:')&&o.count>0);
 await app.send('collectionEnvelope',{id:offer[0]});const env=app.state.collectibles.envelopes.at(-1);assert.ok(env);await app.send('collectionOpen',{id:env.id});assert.equal(app.state.collectibles.envelopes.length,0);
 const count=app.state.data.events.length;await app.send('chatSend',{text:'Work record: checked a toy figure'});assert.equal(app.state.data.events.length,count);
 const proposal=app.state.chat.messages.at(-1).proposal.id;await app.send('chatConfirm',{proposalID:proposal});assert.equal(app.state.data.events.length,count+1);
 await app.send('chatConfirm',{proposalID:proposal});assert.equal(app.state.data.events.length,count+1);
 await app.send('activity',{id:'toy-01',text:'Another toy task'});await app.send('activity',{id:'toy-01',text:'Third toy task'});const xp=app.state.rewards.total;
 await app.send('activity',{id:'toy-01',text:'Fourth toy task'});assert.equal(app.state.rewards.total,xp);
 const reload=boot(app.storage);await reload.send('ready');assert.equal(reload.state.collectibles.display.desk,item.id);assert.equal(reload.state.chat.messages.length,2);
 const other=boot();await other.send('ready');assert.equal(other.state.collectibles.display.desk,initial.collectibles.display.desk);
 const blocked=boot(new Map(),true);await blocked.send('ready');await blocked.send('step',{id:'toy-01',step:8});assert.equal(blocked.state.totals.total,total-1);
 console.log('PASS: browser stages/undo, stale edits, deadlines, decorations, purchases, envelopes, placement, stickers, confirmed chat, XP cap, reload isolation, storage fallback');
})().catch(e=>{console.error(e);process.exitCode=1;});
