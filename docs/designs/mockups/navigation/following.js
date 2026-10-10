'use strict';
// Concept B deliberately assumes the separate Following-unification work item has
// landed. These topics are not a Pins/Feeds tab switch or a proxy for Browse.
function followingFolderList(parent=null,choice=false,selected='') {
  return m.followingFolders.filter(f=>f.parent===parent).map(f=>
    `<div class="tree-branch">${choice?
      `<label class="check-row"><input type="radio" name="folder" value="${esc(f.id)}" ${selected===f.id?'checked':''}>${icon('folder')}<span>${esc(f.name)}</span></label>`:
      navRow('folder',f.name,'following-move-target',`data-id="${esc(f.id)}"`)}
      <div class="tree-indent">${followingFolderList(f.id,choice,selected)}</div></div>`).join('');
}
function followingScope(item){
  const owners=[...new Set(item.sources.map(s=>s.profile))];
  return owners.map(id=>{const p=m.profile(id);return p?p.site+' · '+p.name:'Missing source';}).join(' + ');
}
function followingPage(){
  const folder=m.followingFolders.find(f=>f.id===m.route.folder),parent=m.route.folder||null;
  const qualifies=f=>(!ui.onlyNew||f.isNew)&&(ui.owner==='all'||f.sources.some(s=>s.profile===ui.owner));
  const folders=m.empty?[]:m.followingFolders.filter(f=>f.parent===parent&&(!(ui.onlyNew||ui.owner!=='all')||m.followingDescendants(f.id).some(qualifies)));
  const topics=m.empty?[]:m.followings.filter(f=>f.folder===parent&&qualifies);
  const crumbs=[{label:'Following',action:'following-home'},...ancestors(m.followingFolders,folder?.parent).map(f=>({label:f.name,action:'following-folder-root',extra:`data-id="${esc(f.id)}"`}))];
  return `<div class="page-pad following-page">${folder?breadcrumb(crumbs):''}${heading(folder?.name||'Following',folder?'Your followed topics in this folder':'All your followed searches, from every source profile.','create-menu')}
  ${localFilter('Filter following topics')}
  <div class="following-controls"><span class="scope">${icon('globe')}${ui.owner==='all'?'Across all profiles':esc(m.profile(ui.owner)?.site+' · '+m.profile(ui.owner)?.name||'Missing profile')}</span>
  ${textButton('filter',ui.owner==='all'?'Source profiles':'Filtered source','owner-filter')}
  </div><div class="chip-row"><button type="button" class="pill" data-action="only-new" aria-pressed="${ui.onlyNew}">${ui.onlyNew?icon('check'):icon('feed')} New only</button>${textButton('refresh','Refresh following','refresh')}</div>
  <div data-filter-list>${folders.map(f=>row({i:'folder',title:f.name,subtitle:m.followingDescendants(f.id).length+' followed topics',action:'following-folder-open',extra:`data-id="${esc(f.id)}"`,count:m.followingDescendants(f.id).some(x=>x.isNew)?'NEW':null})).join('')}
  ${topics.map(f=>`<div class="list-row following-topic filter-hit" data-filter-text="${esc((f.name+' '+f.sources.map(s=>s.query+' '+followingScope(f)).join(' ')).toLowerCase())}" data-selectid="${esc(f.id)}">
    <button type="button" class="row-main" data-action="following-open" data-id="${esc(f.id)}"><span class="tiny-art">${art(f.art)}</span><span class="row-copy"><strong>${esc(f.name)}${f.isNew?'<span class="new-label">NEW</span>':''}</strong>
    <small>${f.sources.length} ${f.sources.length===1?'source':'sources'} · ${esc(followingScope(f))}</small></span>${m.selection.includes(f.id)?icon('check'):icon('right','chevron')}</button>
    ${!m.selection.length?button('more','Actions for '+f.name,'following-item-menu',`data-id="${esc(f.id)}"`):''}</div>`).join('')}</div>
  ${!folders.length&&!topics.length?empty('feed',m.empty?'Nothing followed yet':'No following items here',m.empty?'Follow a search to see its updates here.':'Try another source filter or add a followed search.','following-add','Follow a search'):''}
  <p class="filter-empty" hidden>No matching topics.</p><p class="fine">Following sources keep their own profile. Switching the sidebar profile only changes Browse and site tools.</p></div>`;
}
function followingTopicPage(){
  const f=m.followings.find(f=>f.id===m.route.id);
  if(!f)return `<div class="page-pad">${empty('info','Topic unavailable','This followed topic no longer exists. Return to Following.','following-home','Open Following')}</div>`;
  return `<div class="page-pad follow-stream">${breadcrumb([{label:'Following',action:'following-home'},...ancestors(m.followingFolders,f.folder).map(g=>({label:g.name,action:'following-folder-root',extra:`data-id="${esc(g.id)}"`}))])}
    ${heading(f.name,f.sources.length+' '+(f.sources.length===1?'source':'sources')+' · content stays attached to each source profile','page-menu')}
    <div class="source-stack">${f.sources.map(s=>`<span class="source-pill">${icon('globe')} ${esc(m.profile(s.profile)?.site||'Unavailable')} · ${esc(m.profile(s.profile)?.name||'Missing profile')} <span>${esc(s.query)}</span></span>`).join('')}</div>
    <div class="chip-row">${textButton('edit','Edit sources','following-edit',`data-id="${esc(f.id)}"`)}${textButton('refresh','Refresh','refresh')}${f.isNew?'<span class="pill">New posts</span>':''}</div>
    <div class="grid-toolbar"><small>${m.visiblePosts().length} cached demo posts · source-owned</small>${textButton('sort',ui.sort,'sort')}</div>${postGrid()}
    <p class="fine">End of synthetic sample · source queries remain independent of the current Browse profile.</p></div>`;
}
function followingModalBody(type,data){
  if(concept!=='B')return null;
  if(type==='following-add'){
    const owner=ui.modal.fields?.profile||m.nav.profile,folder=ui.modal.fields?.folder??(m.route.page==='following'?m.route.folder:null);
    return modalHeading('Follow a search')+`<div class="modal-content"><p>One topic can contain one or more source searches. Start with a query and a source profile; edit its sources later.</p>
      <form data-form="following-add">${field('name','Topic name (optional)',data.name||'')}${field('query','Search query',data.query||m.route.query||'')}
      <label class="form-label" for="field-profile">Source profile</label><select class="field" id="field-profile" name="profile">${m.profiles.map(p=>`<option value="${esc(p.id)}" ${p.id===owner?'selected':''}>${esc(p.site+' · '+p.name)}</option>`).join('')}</select>
      <fieldset class="folder-picker"><legend>Following folder</legend><label class="check-row"><input type="radio" name="folder" value="" ${!folder?'checked':''}>Root</label>${followingFolderList(null,true,folder)}</fieldset>${formEnd('Follow search')}</div>`;
  }
  if(type==='following-edit'){
    const f=m.followings.find(x=>x.id===data.id);if(!f)return modalHeading('Source not found');
    return modalHeading('Edit followed topic')+`<div class="modal-content"><form data-form="following-edit" data-id="${esc(f.id)}">${field('name','Topic name',f.name)}
      <label class="form-label">Included sources</label><p>Uncheck a source to remove it. At least one source must remain.</p>
      ${f.sources.map((s,i)=>`<label class="check-row"><input type="checkbox" name="source" value="${i}" ${!ui.modal.checkedSources||ui.modal.checkedSources.includes(String(i))?'checked':''}><span><strong>${esc(s.name)}</strong><small>${esc(m.profile(s.profile)?.site||'Unavailable')} · ${esc(m.profile(s.profile)?.name||'Missing profile')} — ${esc(s.query)}</small></span></label>`).join('')}
      ${field('query','Add source query (optional)')}
      <label class="form-label" for="field-profile">New source profile</label><select class="field" name="profile" id="field-profile">${m.profiles.map(p=>`<option value="${p.id}" ${p.id===(ui.modal.fields?.profile||m.nav.profile)?'selected':''}>${esc(p.site+' · '+p.name)}</option>`).join('')}</select>${formEnd('Save topic')}</div>`;
  }
  if(type==='following-folder'){
    const f=m.followingFolders.find(x=>x.id===data.id);
    return modalHeading(f?'Rename folder':'Add Following folder')+`<div class="modal-content"><form data-form="following-folder" data-id="${esc(f?.id||'')}">${field('name','Folder name',f?.name||'')}${formEnd(f?'Save':'Add folder')}</div>`;
  }
  if(type==='following-item-menu'){
    const f=m.followings.find(x=>x.id===data.id);
    if(!f)return modalHeading('Topic unavailable');
    return modalHeading(f.name)+`<div class="modal-content">${navRow('edit','Edit name & sources','following-edit',`data-id="${esc(f.id)}"`)}${navRow('move','Move to folder','following-move',`data-id="${esc(f.id)}"`)}${navRow('check','Mark as read','following-read',`data-id="${esc(f.id)}"`)}${navRow('select','Select','select-item',`data-id="${esc(f.id)}"`)}${navRow('trash','Unfollow','following-remove',`data-id="${esc(f.id)}"`)}</div>`;
  }
  if(type==='following-move'){
    return modalHeading('Move Following topics')+`<div class="modal-content"><p>Move topics to another folder. Source profiles and queries stay unchanged.</p>${navRow('folder','Following root','following-move-target','data-id=""')}${followingFolderList()}<div class="modal-actions">${textButton('close','Cancel','close-modal')}</div></div>`;
  }
  return null;
}
