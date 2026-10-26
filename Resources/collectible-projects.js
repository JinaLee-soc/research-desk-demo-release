'use strict';
// Explicit topic designs keyed by stable Desk project IDs. These are visual metaphors,
// not research findings. Keep item IDs and saved ownership independent of presentation.
(()=>{
 const item=(name,main,accent,diagram,meaning)=>({name,main,accent,diagram,meaning});
 const profiles={};
 const add=(id,topic,palette,parts)=>{profiles[id]={topic,palette,stamp:parts[0],cover:parts[1],postcard:parts[2]};};
 const fallback={topic:'Research record',palette:'umber',object:item('Research notes','notebook','pen','',''),stamp:item('Research stamp','book','pen','shelf',''),cover:item('Research cover','notebook','pen','quotes',''),postcard:item('Research postcard','project-scroll','book','path','')};
 const kindLabel={stamp:'Stamp',object:'Object',cover:'Cover',postcard:'Postcard'};
 function resolve(entry){
  if(!entry?.projectID)return null;
  const profile=profiles[entry.projectID]||fallback;
  const completion=entry.id.startsWith('set:');
  const design=completion?{...profile.stamp,name:profile.topic+' · Collection complete',meaning:'A commemorative stamp for completing this project’s collection'}:profile[entry.kind]||fallback.stamp;
  return {...design,topic:profile.topic,palette:profile.palette,completion,mapped:!!profiles[entry.projectID],label:design.name+(completion?'':' · '+(kindLabel[entry.kind]||''))};
 }
 window.DeskCollectibleProjects={resolve,profiles:Object.freeze(profiles)};
})();
