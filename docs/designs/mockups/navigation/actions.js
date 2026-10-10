'use strict';
function perform(action,b,e){const id=b.dataset.id;
 switch(action){
 case 'menu':openModal('menu');break;
 case 'profiles':openModal(concept==='B'?'menu':'profiles');break;
 case 'sidebar-profile':{
   const oldTool=m.nav.section==='browse'&&m.route.page==='tool'?m.route.tool:null;
   transition(()=>{m.switchProfile(id);if(oldTool&&(m.route.tool!==oldTool||m.route.profile!==id))m.push({page:'tool',tool:oldTool,profile:id});},true);if(ui.modal?.type==='menu')menuPendingNav=m.snapshot();
   requestAnimationFrame(()=>{(modal.open?modal:screen).querySelector(`[data-action="sidebar-profile"][data-id="${CSS.escape(id)}"]`)?.focus({preventScroll:true});});
   break;
 }
 case 'following-home':transition(()=>{m.resetSection('following');ui.filter='';},Boolean(ui.modal));break;
 case 'following-folder-open':navigate('following',{page:'following',folder:id});break;
 case 'following-folder-root':transition(()=>visitFolder('following',id));break;
 case 'following-open':transition(()=>{m.openFollowing(id);ui.filter='';ui.onlyNew=false;},Boolean(ui.modal));break;
 case 'following-add':openModal('following-add',{query:m.route.query||''});break;
 case 'following-edit':openModal('following-edit',{id});break;
 case 'following-folder':openModal('following-folder');break;
 case 'following-item-menu':openModal('following-item-menu',{id});break;
 case 'following-move':{m.selection=[id];openModal('following-move');break;}
 case 'following-move-target':transition(()=>{m.followings.filter(f=>m.selection.includes(f.id)).forEach(f=>f.folder=id||null);m.clearSelection();ui.modal=null;},true);toast('Moved in Following. Source profiles are unchanged.');break;
 case 'following-read':transition(()=>{const f=m.followings.find(f=>f.id===id);if(f)f.isNew=false;ui.modal=null;},true);break;
 case 'following-remove':openModal('confirm',{id,title:'Unfollow this topic?',message:'Removes the followed topic from this local collection. Source posts and bookmarks are unaffected.',label:'Unfollow'});break;
 case 'nav':navigate(b.dataset.section);break;
 case 'back':appBack();break;
 case 'close-modal':closeModal();break;
 case 'clear-selection':transition(()=>m.clearSelection(),true);break;
 case 'search':if(!m.profile())openModal('profiles');else openModal('search');break;
 case 'suggestion':{const input=modal.querySelector('[name=query]');input.value=b.dataset.query;input.focus();ui.modal.dirty=true;ui.modal.fields={...(ui.modal.fields||{}),query:input.value};break;}
 case 'pins-root':followTab('pins');break;
 case 'pins-home':followTab('pins',true);break;
 case 'feeds-home':followTab('feeds',true);break;
 case 'feeds-root':followTab('feeds');break;
 case 'following-tab':followTab(b.dataset.page);break;
 case 'pin-folder':navigate('following',{page:'pins',folder:id});break;
 case 'pin-open':transition(()=>{leaveOverlay();m.openPin(id);ui.filter='';},Boolean(ui.modal));toast('Opened with '+m.profile().site+' · '+m.profile().name+'. The pinned-search location is retained.');break;
 case 'feed-open':transition(()=>{m.feeds.find(f=>f.id===id).isNew=false;m.push({page:'feed',id});});break;
 case 'post':transition(()=>{m.openViewer(id,orderedPosts().map(p=>p.key));ui.zoom=false;});break;
 case 'viewer-close':closeViewer();break;
 case 'viewer-next':case 'viewer-prev':transition(()=>{m.viewer.index=Math.max(0,Math.min(m.viewer.keys.length-1,m.viewer.index+(action==='viewer-next'?1:-1)));ui.zoom=false;},true);break;
 case 'viewer-mark':transition(()=>m.toggleViewedBookmark(),true);break;
 case 'viewer-info':openModal('viewer-info');break;
 case 'viewer-more':openModal('viewer-more');break;
 case 'viewer-target':openModal('target');break;
 case 'viewer-zoom':transition(()=>{ui.zoom=!ui.zoom;ui.modal=null;},true);break;
 case 'viewer-hide':transition(()=>{ui.immersive=!ui.immersive;ui.modal=null;},true);break;
 case 'target-choice':transition(()=>{m.defaultGroup=id;ui.modal=null;},true);toast('Default bookmark target: '+m.groups.find(g=>g.id===id).name);break;
 case 'group-open':navigate('bookmarks',{page:'group',group:id});break;
 case 'folder-open':navigate('bookmarks',{page:'groups',folder:id});break;
 case 'folder-root':transition(()=>visitFolder('bookmarks',id));break;
 case 'pin-folder-root':transition(()=>visitFolder('following',id));break;
 case 'bookmarks-root':transition(()=>{m.resetSection('bookmarks');ui.filter='';});break;
 case 'jump-group':navigate('bookmarks',{page:'group',group:id});break;
 case 'create-menu':openModal('create');break;
 case 'page-menu':openModal('page-menu');break;
 case 'item-menu':openModal('item-menu',{id});break;
 case 'create-group':openModal('name',{kind:'group'});break;
 case 'create-folder':openModal('name',{kind:'folder'});break;
 case 'create-pin-folder':openModal('name',{kind:'pin-folder'});break;
 case 'create-pin':case 'pin-query':openModal(concept==='B'?'following-add':'pin',{query:m.route.query||''});break;
 case 'create-feed':openModal('feed-edit');break;
 case 'edit-feed':openModal('feed-edit',{id});break;
 case 'rename-item':{const pin=m.pins.find(p=>p.id===id),g=m.groups.find(g=>g.id===id);openModal('name',{id,kind:pin?'pin':g.type,name:(pin||g).name,rename:true});break;}
 case 'delete-item':openModal('confirm',{id,title:'Remove this item?',message:m.pins.some(p=>p.id===id)?'Unpins the search from the local collection. It does not remove any posts.':'Deletes the selected organization item. This demo retains the bookmarks themselves.',label:'Remove'});break;
 case 'move-item':m.selection=[id];openModal('move');break;
 case 'select-item':beginSelection(id);break;
 case 'begin-selection':if(visibleOrder().length)beginSelection();else toast('No items in this view can be selected.');break;
 case 'select-all':transition(()=>{m.selection=visibleOrder();},true);break;
 case 'mark-read':transition(()=>{m.pins.find(p=>p.id===id).isNew=false;ui.modal=null;},true);break;
 case 'only-new':transition(()=>{ui.onlyNew=!ui.onlyNew;},true);break;
 case 'owner-filter':openModal('owner-filter');break;
 case 'owner-choice':transition(()=>{ui.owner=id;ui.modal=null;},true);break;
 case 'sort':openModal('sort');break;
 case 'sort-choice':transition(()=>{ui.sort=b.dataset.value;ui.modal=null;},true);break;
 case 'demo-order':transition(()=>{ui.sort=b.dataset.order;},true);break;
 case 'refresh':if(m.offline)toast('Offline: cached content and NEW state are retained. Retry when connected.');else{transition(()=>{ui.modal=null;if(concept==='B'){const f=m.followings.find(f=>f.id===m.route.id)||m.followings[0];if(f)f.isNew=true;}else{const p=m.pins.find(p=>p.profile===m.nav.profile)||m.pins[0];if(p)p.isNew=true;if(m.feeds[0])m.feeds[0].isNew=true;}},Boolean(ui.modal));toast('Simulated refresh completed. NEW is a signal, not an unread post count.');}break;
 case 'retry':transition(()=>{m.offline=false;},true);toast('Simulated connection restored. No live requests were made.');break;
 case 'choose-profile':transition(()=>{m.switchProfile(id);ui.modal=null;if(m.route.page==='unavailable')m.resetSection('browse');},true);toast('Browsing profile changed. Your global collections are unchanged.');break;
 case 'setup-profile':transition(()=>{if(!m.profiles.length)m.profiles=copy(NavigationLab.PROFILES);else if(!m.profiles.some(p=>p.id==='extra'))m.profiles.push({id:'extra',name:'Second account',site:'Danbooru',host:'danbooru.donmai.us',signedIn:false,initials:'D'});ui.modal=null;},Boolean(ui.modal));toast('Added a local demo profile. No credentials or requests.');break;
 case 'tool':navigate('browse',{page:'tool',tool:b.dataset.tool,profile:m.nav.profile});break;
 case 'browse-tools':navigate('more');break;
 case 'downloads':navigate('more',{page:'downloads'});break;
 case 'settings':navigate('more',{page:'settings'});break;
 case 'bulk-download':openModal('bulk');break;
 case 'download-toggle':transition(()=>{const d=m.downloads.find(d=>d.id===id);d.status=d.status==='Paused'?'Downloading':'Paused';},true);break;
 case 'download-post':transition(()=>{const p=m.viewedPost;m.downloads.push({id:'job-'+m.nextId++,name:p.title+'.jpg',status:'Downloading',progress:0});},true);toast('Added a simulated download. Find it under Downloads.');break;
 case 'download-info':openModal('info',{title:'Completed demo download',message:'The queue is navigation-independent. This fixture has no file on disk.'});break;
 case 'move':openModal('move');break;
 case 'move-destination':transition(()=>{const mode=selectionKind();if(mode==='posts')m.moveBookmarks(id);else if(mode==='pins'){m.pins.filter(p=>m.selection.includes(p.id)).forEach(p=>p.folder=id||null);m.clearSelection();}else if(mode==='following'){m.followings.filter(p=>m.selection.includes(p.id)).forEach(p=>p.folder=id||null);m.clearSelection();}else{m.groups.filter(g=>m.selection.includes(g.id)).forEach(g=>g.parent=id||null);m.clearSelection();}ui.modal=null;},true);toast('Moved in the demo. Profile ownership and saved searches are unchanged.');break;
 case 'remove-selection':openModal('confirm',{title:'Remove selected items?',message:'This changes only the synthetic demo. Bookmark removal removes the selected local bookmarks; pin and group removal affect their own collections.'});break;
 case 'confirm-remove':transition(()=>{const ids=ui.modal.data.id?[ui.modal.data.id]:m.selection.slice();m.pins=m.pins.filter(p=>!ids.includes(p.id));m.followings=m.followings.filter(f=>!ids.includes(f.id));const foldersRemoved=m.followingFolders.filter(f=>ids.includes(f.id)).map(f=>f.id);m.followingFolders=m.followingFolders.filter(f=>!ids.includes(f.id));m.followingFolders.forEach(f=>{if(foldersRemoved.includes(f.parent))f.parent=null;});m.followings.forEach(f=>{if(foldersRemoved.includes(f.folder))f.folder=null;});const removedFolders=m.groups.filter(g=>ids.includes(g.id)&&g.type==='folder').map(g=>g.id);m.groups=m.groups.filter(g=>!ids.includes(g.id));m.groups.forEach(g=>{if(removedFolders.includes(g.parent))g.parent=null;});m.posts.forEach(p=>{if(ids.includes(p.key)){p.bookmarked=false;p.groups=[];}else p.groups=p.groups.filter(g=>!ids.includes(g));});m.clearSelection();ui.modal=null;if(m.route.page==='following-stream'&&!m.followings.some(f=>f.id===m.route.id))m.resetSection('following');},true);toast('Removed from the demo.');break;
 case 'download-selection':transition(()=>{m.downloads.push({id:'job-'+m.nextId++,name:m.selection.length+' selected demo items',status:'Downloading',progress:0});m.clearSelection();},true);toast('Added a simulated queue entry. No network or file operation.');break;
 case 'export-selection':openModal('info',{title:'Export selection',message:m.selection.length+' items would enter the existing export flow.',detail:'Real .bsexport serialization, filename entry, platform file pickers and permissions are deliberately not implemented by this HTML lab.'});break;
 case 'spaces':openModal('spaces');break;
 case 'create-space':openModal('space-name');break;
 case 'switch-space':transition(()=>{leaveOverlay();m.switchSpace(id);ui.filter='';},Boolean(ui.modal));break;
 case 'close-space':transition(()=>{m.closeSpace(id);},true);break;
 case 'jump':openModal('jump');break;
 case 'signin':openModal('signin');break;
 case 'demo-signin':transition(()=>{m.profile().signedIn=true;ui.modal=null;},true);toast('Demo account enabled. Nothing was sent to the site.');break;
 case 'artist':navigate('browse',{page:'search',query:'original',name:'Artist: '+b.dataset.name});break;
 case 'server-search':navigate('browse',{page:'search',query:'scenery clouds',name:'Server saved search'});break;
 case 'site-collection':navigate('browse',{page:'search',query:'scenery',name:b.dataset.name});break;
 case 'search-tag':{const p=m.viewedPost,owner=p?.sourceProfile||p?.profile||m.nav.profile;transition(()=>{leaveOverlay();if(m.profile(owner))m.switchProfile(owner);m.switchSection('browse');m.push({page:'search',query:b.dataset.query});},true);break;}
 case 'view-source':{const p=m.viewedPost;transition(()=>{const owner=p.sourceProfile||p.profile;leaveOverlay();m.switchProfile(owner);m.switchSection('browse');m.push({page:'search',query:'scenery',name:'From '+p.site});},true);break;}
 case 'add-tag':openModal('tag',{tool:m.route.tool});break;
 case 'edit-tag':openModal('tag',{name:b.dataset.name,tool:b.dataset.tool});break;
 case 'discard-edit':closeModal(true);break;
 case 'keep-editing':transition(()=>{ui.modal=ui.modal.data.previous;},true);break;
 case 'help':openModal('help');break;
 case 'feed-options':case 'feed-help':openModal('info',{title:'Feeds and pins stay distinct',message:'Pinned searches reopen an exact query on its owner profile. Feeds combine independent search sources into one timeline. Following is only their shared navigation category.',detail:'Unifying feed-source persistence with pinned searches is a separate design decision, not a prerequisite for any concept here.'});break;
 case 'scope-help':openModal('info',{title:'Scope & navigation',message:scopeLabel()+'. Switching a primary destination restores its last nested location. Back first dismisses transient UI, then moves up inside the destination.',detail:'Site posts and account actions use a captured owner context. Global bookmarks are identified by canonical site + post, not whichever profile is currently active.'});break;
 case 'backup':openModal('info',{title:'Backup & restore',message:'This is an app-global, guarded task. The final implementation should keep its wizard outside disposable browse branches.',detail:'Resolve conflicts before writes. Returning to the shell must reload imported providers after the durable transaction. No imports or exports occur in this demo.'});break;
 case 'support':case 'donation':openModal('info',{title:action==='support'?'Support & about':'Support development',message:'An app-global destination. In production, retain the existing support, FOSS donation, and eligible premium flows without putting commerce into primary navigation.'});break;
 case 'share-post':openModal('info',{title:'Share or export this post',message:'The existing share flow opens above the viewer and returns to this same post. Platform share sheets, conversion and filesystem access are outside this prototype.'});break;
 case 'comments':case 'forum-thread':openModal('info',{title:action==='comments'?'Comments & notes':'A place for landscape studies',message:'Example nested content. Close this sheet to return to exactly the same viewer or forum location.',detail:'Synthetic discussion: “The muted palette works well here.” No community content was fetched.'});break;
 default:toast('This action is not part of the prototype.');
 }
}
// Event delegation keeps newly rendered pages and modal sheets consistent.
document.addEventListener('click',e=>{
 const b=e.target.closest('button[data-action]');if(!b)return;
 const selectable=b.closest('[data-selectid]');
 if(selectable&&(m.selection.length||e.shiftKey)&&!['item-menu'].includes(b.dataset.action)&&!modal.contains(b)){
   e.preventDefault();transition(()=>m.select(selectable.dataset.selectid,visibleOrder(),e.shiftKey),true);return;
 }
 try{perform(b.dataset.action,b,e);}catch(error){toast(error.message);}
});
document.addEventListener('submit',e=>{
 const form=e.target.closest('form[data-form]');if(!form)return;e.preventDefault();const data=new FormData(form),get=k=>String(data.get(k)||'').trim();
 try{
  const type=form.dataset.form;
   if(type==='following-add'){
     m.addFollowing(get('name'),get('query'),get('profile'),get('folder')||null);
     transition(()=>{ui.modal=null;},true);toast('Now following that search. The source profile is stored with the topic.');
     return;
   }
   if(type==='following-folder'){
     const name=get('name'),id=form.dataset.id;if(!name)throw new Error('Enter a folder name');
     if(m.followingFolders.some(f=>f.name.toLowerCase()===name.toLowerCase()&&f.id!==id))throw new Error('A Following folder with that name exists');
     if(id)m.followingFolders.find(f=>f.id===id).name=name;
     else m.followingFolders.push({id:'following-folder-'+m.nextId++,name,parent:m.route.page==='following'?m.route.folder||null:null});
     transition(()=>{m.empty=false;ui.modal=null;},true);toast(id?'Following folder renamed.':'Following folder created.');return;
   }
   if(type==='following-edit'){
     const topic=m.followings.find(f=>f.id===form.dataset.id);if(!topic)throw new Error('Topic no longer exists');
     const name=get('name');if(!name)throw new Error('Enter a topic name');
     const checked=data.getAll('source').map(Number);const sources=topic.sources.filter((s,i)=>checked.includes(i));
     if(get('query')){if(!m.profile(get('profile')))throw new Error('Choose a source profile');sources.push({name:get('query'),query:get('query'),profile:get('profile')});}
     if(!sources.length)throw new Error('Keep at least one source');
     topic.name=name;topic.sources=sources;
     transition(()=>{ui.modal=null;},true);toast('Source list updated without changing Browse profile.');return;
   }
  if(type==='search'){
    const query=get('query');if(!query)throw new Error('Enter a search query');
    transition(()=>{leaveOverlay();m.switchSection('browse');m.push({page:'search',query});},true);
  }else if(type==='pin'){
    m.addPin(get('name'),get('query'),get('profile'),get('folder')||null);
    transition(()=>{ui.modal=null;},true);toast('Search pinned locally. No refresh request was made.');
  }else if(type==='name'){
    const name=get('name');if(!name)throw new Error('Enter a name');const id=form.dataset.id;
    if(id){const target=m.pins.find(p=>p.id===id)||m.groups.find(g=>g.id===id);if(!target)throw new Error('Item no longer exists');target.name=name;}
    else if(form.dataset.kind==='pin-folder'){if(m.pinFolders.some(f=>f.name.toLowerCase()===name.toLowerCase()))throw new Error('A search folder with that name already exists');m.pinFolders.push({id:'pin-folder-'+m.nextId++,name,parent:m.route.page==='pins'?m.route.folder||null:null});m.empty=false;}else m.addGroup(name,form.dataset.kind,m.route.folder||null);
    transition(()=>{ui.modal=null;},true);toast(id?'Name updated in the demo.':'Created in the demo.');
  }else if(type==='space'){
    m.openSpace(get('name'));transition(()=>{ui.modal=null;},true);toast('A new workspace is active. The previous context is still open.');
  }else if(type==='feed'){
    const name=get('name');if(!name)throw new Error('Enter a feed name');
    const current=m.feeds.find(f=>f.id===form.dataset.id),original=current?.sources||[{name:'Scenery',query:'scenery',profile:m.nav.profile}];
    const checked=data.getAll('source').map(Number);const sources=original.filter((_,i)=>checked.includes(i));
    if(get('query')){if(!m.profile())throw new Error('Choose a browsing profile first');sources.push({name:get('query'),query:get('query'),profile:m.nav.profile});}
    if(!sources.length)throw new Error('Keep at least one source or add a query');
    if(current){current.name=name;current.sources=sources;}else m.feeds.push({id:'feed-'+m.nextId++,name,sources,isNew:false,art:4});
    transition(()=>{m.empty=false;ui.modal=null;},true);toast('Feed definition saved in the demo; no source requests were made.');
  }else if(type==='tag'){
    const name=get('name');if(!name)throw new Error('Enter a tag');const key=form.dataset.tool,old=form.dataset.old;
    if(!ui[key])ui[key]=[];const index=ui[key].indexOf(old);if(index>=0)ui[key][index]=name;else ui[key].push(name);
    transition(()=>{ui.modal=null;},true);
  }else if(type==='bulk'){
    if(!get('query'))throw new Error('Enter a query');
    transition(()=>{m.downloads.push({id:'job-'+m.nextId++,name:get('query')+' · demo job',status:'Downloading',progress:0});ui.modal=null;},true);toast('Simulated job added to Downloads.');
  }
 }catch(error){const target=form.querySelector('.form-error');if(target){target.hidden=false;target.textContent=error.message;target.focus();}else toast(error.message);}
});
function filterList(input){const root=input.closest('.modal-content,.page-pad')||screen;const q=input.value.toLowerCase().trim();let count=0;root.querySelectorAll('.filter-hit').forEach(el=>{const system=el.querySelector('[data-action=group-open][data-id=all],[data-action=group-open][data-id=none]');if(system){el.hidden=false;return;}el.hidden=!el.dataset.filterText.includes(q);if(!el.hidden)count++;});const empty=root.querySelector('.filter-empty');if(empty)empty.hidden=!q||count>0;}
document.addEventListener('input',e=>{
 if(e.target.matches('[data-local-filter]')){ui.filter=e.target.value;filterList(e.target);}
 if(modal.contains(e.target)&&e.target.closest('form')){ui.modal.dirty=true;const values=new FormData(e.target.closest('form'));ui.modal.fields=Object.fromEntries(values.entries());ui.modal.checkedSources=values.getAll('source').map(String);}
});
document.addEventListener('change',e=>{
 if(modal.contains(e.target)&&e.target.closest('form')){ui.modal.dirty=true;const values=new FormData(e.target.closest('form'));ui.modal.fields=Object.fromEntries(values.entries());ui.modal.checkedSources=values.getAll('source').map(String);}
 const type=e.target.dataset.setting;if(!type)return;
 if(type==='theme'){$('#light-theme').checked=e.target.value==='light';frame.classList.toggle('light',$('#light-theme').checked);}
 if(type==='type'){$('#large-text').checked=e.target.value==='large';frame.classList.toggle('large',$('#large-text').checked);}
 if(type==='start')m.start=e.target.value;
 render();toast('Demo preference updated.');
});
modal.addEventListener('cancel',e=>{e.preventDefault();closeModal();});
modal.addEventListener('click',e=>{if(e.target!==modal)return;const r=modal.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)closeModal();});
window.addEventListener('resize',positionModal);window.addEventListener('scroll',positionModal,{passive:true});
window.addEventListener('popstate',e=>{
 if(!e.state?.lab)return;if(ui.modal?.dirty){const previous=copy(ui.modal);historyDepth=e.state.depth;ui.modal={type:'discard',data:{previous}};render();record();return;}saveScroll();const savedMenuNav=ui.modal?.type==='menu'&&menuPendingNav&&!e.state.modal?copy(menuPendingNav):null;const sameViewer=m.viewer&&e.state.viewer&&e.state.concept===concept&&JSON.stringify(m.viewer.keys)===JSON.stringify(e.state.viewer.keys);if(m.viewer&&!sameViewer)m.closeViewer();
 concept=e.state.concept;m=models[concept];m.restore(savedMenuNav||e.state.nav);m.viewer=copy(e.state.viewer);m.selection=(e.state.selection||[]).slice();
 ui.modal=copy(e.state.modal);ui.immersive=false;ui.zoom=false;ui.filter='';historyDepth=e.state.depth;menuPendingNav=null;render();if(savedMenuNav)record(true);
});
document.addEventListener('keydown',e=>{
 const typing=e.target.matches('input,textarea,select,[contenteditable=true]');
 if(e.key==='Escape'&&!modal.open){if(m.viewer){e.preventDefault();closeViewer();}else if(m.selection.length){e.preventDefault();transition(()=>m.clearSelection(),true);}return;}
 if(typing||modal.open)return;
 if(e.key==='/'){e.preventDefault();openModal('search');}
 if(concept==='C'&&(e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='k'){e.preventDefault();if(!m.selection.length)openModal('jump');}
 if(m.viewer&&(e.key==='ArrowLeft'||e.key==='ArrowRight')){e.preventDefault();perform(e.key==='ArrowLeft'?'viewer-prev':'viewer-next',{dataset:{}},e);return;}
 if(!m.selection.length&&!m.viewer&&!e.ctrlKey&&!e.metaKey&&/^[1-6]$/.test(e.key)){
  if(concept==='C'){const s=m.spaces[Number(e.key)-1];if(s)transition(()=>m.switchSpace(s.id));}
  else{const section=['browse','following','bookmarks','more'][Number(e.key)-1];if(section)navigate(section);}
 }
});
// A modest browser gesture model: long press, additive range drag, and edge swipe.
let gesture=null,pressTimer=null,suppressClickUntil=0;
screen.addEventListener('pointerdown',e=>{
 if(e.button!==0||modal.open)return;const item=e.target.closest('[data-selectid]'),rect=frame.getBoundingClientRect();
 gesture={x:e.clientX,y:e.clientY,id:item?.dataset.selectid,edge:e.clientX-rect.left<20,drag:false,last:null};
 if(item&&!e.target.closest('button[data-action=item-menu]'))pressTimer=setTimeout(()=>{if(!gesture)return;gesture.drag=true;suppressClickUntil=Date.now()+700;const id=gesture.id;transition(()=>{if(!m.selection.includes(id))m.select(id,visibleOrder());});},460);
});
screen.addEventListener('pointermove',e=>{
 if(!gesture)return;const dx=e.clientX-gesture.x,dy=e.clientY-gesture.y;
 if(!gesture.drag&&(Math.abs(dx)>10||Math.abs(dy)>10))clearTimeout(pressTimer);
 if(gesture.drag){
  e.preventDefault();const target=document.elementFromPoint(e.clientX,e.clientY)?.closest('[data-selectid]');
  if(target&&target.dataset.selectid!==gesture.last){gesture.last=target.dataset.selectid;transition(()=>m.select(target.dataset.selectid,visibleOrder(),true),true);}
  const scroll=screen.querySelector('.scroll'),r=scroll?.getBoundingClientRect();if(r){if(e.clientY>r.bottom-45)scroll.scrollTop+=14;else if(e.clientY<r.top+45)scroll.scrollTop-=14;}
 }
});
function endGesture(e){clearTimeout(pressTimer);if(gesture){if(gesture.drag)suppressClickUntil=Date.now()+500;else if(gesture.edge&&!m.selection.length&&!m.viewer&&e.clientX-gesture.x>70&&Math.abs(e.clientY-gesture.y)<40)openModal('menu');}gesture=null;}
screen.addEventListener('pointerup',endGesture);screen.addEventListener('pointercancel',()=>{clearTimeout(pressTimer);gesture=null;});
screen.addEventListener('click',e=>{if(Date.now()<suppressClickUntil){e.preventDefault();e.stopPropagation();}},true);
screen.addEventListener('contextmenu',e=>{if(e.target.closest('[data-selectid]')){e.preventDefault();if(!m.selection.length)beginSelection(e.target.closest('[data-selectid]').dataset.selectid);}});
function renderNotes(){const n=notes[concept];$('#concept-caption').textContent=concept+' / '+(concept==='A'?'FAMILIAR SIDEBAR':concept==='B'?'TASK NAVIGATION':'WORKSPACES');$('#concept-notes').innerHTML=`<span class="concept-no">0${['A','B','C'].indexOf(concept)+1}</span><h2>${n.title}</h2><span class="verdict">${n.tag}</span><p class="tagline">${n.desc}</p><div class="decision"><h3>What improves</h3><p>${n.win}</p></div><div class="decision"><h3>The trade-off</h3><p>${n.cost}</p></div><div class="decision"><h3>Try this journey</h3><p>${n.try}</p></div>`;document.querySelectorAll('[data-concept]').forEach(b=>{if(b.tagName==='BUTTON')b.setAttribute('aria-pressed',String(b.dataset.concept===concept));});}
document.querySelectorAll('button[data-concept]').forEach(b=>b.addEventListener('click',()=>{saveScroll();if(m.viewer)m.closeViewer();concept=b.dataset.concept;m=models[concept];ui.modal=null;ui.filter='';ui.onlyNew=false;ui.owner='all';ui.zoom=false;render();record();$('#scenario').value='browse';}));
document.querySelectorAll('button[data-size]').forEach(b=>b.addEventListener('click',()=>{$('.workbench').dataset.size=b.dataset.size;document.querySelectorAll('button[data-size]').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));setTimeout(updateSize,30);}));
function updateSize(){$('#size-caption').textContent=Math.round(frame.clientWidth)+' × '+Math.round(frame.clientHeight);positionModal();}
new ResizeObserver(updateSize).observe(frame);
$('#large-text').addEventListener('change',e=>{frame.classList.toggle('large',e.target.checked);render();});
$('#light-theme').addEventListener('change',e=>{frame.classList.toggle('light',e.target.checked);render();});
$('#keyboard').addEventListener('change',e=>{ui.keyboard=e.target.checked;frame.classList.toggle('has-keyboard',ui.keyboard);render();});
$('#help-button').addEventListener('click',()=>openModal('help'));
$('#reset').addEventListener('click',()=>{models[concept]=new Model(concept);m=models[concept];ui={modal:null,filter:'',onlyNew:false,owner:'all',sort:'Upload: newest',zoom:false,immersive:false,keyboard:$('#keyboard').checked};scrollPositions.clear();viewPreferences.clear();render();record();$('#scenario').value='browse';toast('This concept’s synthetic data and navigation have been reset.');});
$('#scenario').addEventListener('change',e=>{
 transition(()=>{leaveOverlay();m.clearSelection();m.empty=false;m.offline=false;ui.filter='';ui.onlyNew=false;ui.owner='all';if(!m.profiles.length)m.profiles=copy(NavigationLab.PROFILES);
 switch(e.target.value){
 case 'browse':m.resetSection('browse');break;
 case 'nested':m.resetSection('bookmarks');m.push({page:'groups',folder:'collections'});m.push({page:'group',group:'scenery'});break;
 case 'pins':if(concept==='B')m.resetSection('following');else m.resetSection('following',{page:'pins',folder:null});break;
 case 'selection':m.resetSection('bookmarks');m.push({page:'group',group:'all'});m.selection=m.visiblePosts().slice(0,3).map(p=>p.key);break;
 case 'guest':m.switchProfile('guest');m.resetSection('browse');m.push({page:'tool',tool:'Server favorites',profile:'guest'});break;
 case 'offline':m.offline=true;m.resetSection('browse');break;
 case 'empty':m.empty=true;m.resetSection('bookmarks');break;
 case 'no-profile':m.profiles=[];m.resetSection('browse');break;
 case 'missing':m.resetSection('following');m.push({page:'unavailable'});break;
 }
 });
});
// A small, intentionally explicit set of copyable initial deep links.
(function initialRoute(){try{const parts=location.hash.replace(/^#\//,'').split('/');if(['browse','following','bookmarks','more'].includes(parts[0])){m.switchSection(parts[0]);if(parts[1]==='group'&&parts[2])m.push({page:'group',group:decodeURIComponent(parts[2])});if(parts[1]==='folder'&&parts[2])m.push({page:parts[0]==='following'?(concept==='B'?'following':'pins'):'groups',folder:decodeURIComponent(parts[2])});if(parts[1]==='search'&&parts[2])m.push({page:'search',query:decodeURIComponent(parts[2])});if(parts[1]==='feeds')m.resetSection('following',{page:'feeds'});}}catch(_){m.resetSection('browse');toast('The link could not be read. Opened the start destination instead.');}})();
$('button[data-size=phone]').setAttribute('aria-pressed','true');render();record(true);updateSize();
// Read-only test hooks. No production integration or external API access.
window.__navigationLab={get model(){return m;},get ui(){return ui;},render,art};
