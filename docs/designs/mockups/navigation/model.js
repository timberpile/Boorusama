/* Navigation-only reference model. Synthetic data; no network or production storage. */
(function (root) {
  'use strict';
  const copy = x => JSON.parse(JSON.stringify(x));
  const PROFILES = [
    {id:'personal', name:'Personal', site:'Danbooru', host:'danbooru.donmai.us', signedIn:true, initials:'D'},
    {id:'guest', name:'Guest', site:'Danbooru', host:'danbooru.donmai.us', signedIn:false, initials:'D'},
    {id:'gel', name:'Sketchbook', site:'Gelbooru', host:'gelbooru.com', signedIn:true, initials:'G'}
  ];
  const TITLES = ['Blue hour','A place to return to','After the rain','Quiet orbit','The long way home','Among the clouds','Night garden','Last light','Paper mountains','Morning tide','Soft landing','Far from here'];
  function fixtures() {
    const posts = Array.from({length:36}, (_,i) => ({
      key:(i%3===2?'gelbooru.com':'danbooru.donmai.us')+':'+(820140+i), id:820140+i,
      title:TITLES[i%12], site:i%3===2?'Gelbooru':'Danbooru', profile:i%3===2?'gel':'personal',
      art:i%8, tags:['scenery', i%2?'night':'clouds', i%3?'original':'cityscape'],
      media:i%7===0?'WEBM':'JPG', width:1600, height:2000, groups:i<8?['inspiration']:i<13?['scenery']:[],
      bookmarked:i<16
    }));
    return {
      posts,
      groups:[{id:'collections',name:'Collections',type:'folder',parent:null},{id:'inspiration',name:'Inspiration',type:'group',parent:null},{id:'scenery',name:'Scenery & backgrounds',type:'group',parent:'collections'},{id:'characters',name:'Character studies',type:'group',parent:'collections'}],
      pinFolders:[{id:'worlds',name:'World building',parent:null},{id:'artists',name:'Artists',parent:null},{id:'atmospheres',name:'Atmospheres',parent:'worlds'}],
      pins:[
        {id:'p1',name:'Quiet landscapes',query:'scenery clouds',profile:'personal',folder:'atmospheres',isNew:true,art:0},
        {id:'p2',name:'City after dark',query:'cityscape night',profile:'personal',folder:'worlds',isNew:false,art:2},
        {id:'p3',name:'Sketchbook discoveries',query:'original scenery',profile:'gel',folder:null,isNew:true,art:4},
        {id:'p4',name:'Cloud studies',query:'clouds sky',profile:'guest',folder:null,isNew:false,art:5}
      ],
      /* Separate source records on purpose: grouping the UI does NOT merge feed and pin data. */
      feeds:[
        {id:'f1',name:'Quiet worlds',isNew:true,art:0,sources:[{name:'Open skies',query:'clouds scenery',profile:'personal'},{name:'Drawn places',query:'original scenery',profile:'gel'}]},
        {id:'f2',name:'Late-night inspiration',isNew:false,art:3,sources:[{name:'Night scenes',query:'night cityscape',profile:'personal'}]}
      ],
      downloads:[{id:'d1',name:'Quiet worlds · 8 images',status:'Downloading',progress:63},{id:'d2',name:'Blue hour.jpg',status:'Complete',progress:100}]
    };
  }
  class Model {
    constructor(concept='B') {
      this.concept = ['A','B','C'].includes(concept)?concept:'B';
      this.profiles=copy(PROFILES); Object.assign(this,fixtures());
      this.nav={section:'browse',profile:'personal',followingView:'pins',branches:{}};
      this.selection=[]; this.anchor=null; this.offline=false; this.empty=false;
      this.viewer=null; this.pending={}; this.defaultGroup='inspiration'; this.start='browse';
      this.nextId=1; this.spaces=[]; this.activeSpace='s1';
      this.ensure();
      this.spaces=[{id:'s1',name:'Browse · Danbooru',nav:this.snapshot()}];
      if(this.concept==='C') {
        const feed=this.snapshot();feed.section='following';feed.followingView='feeds';feed.branches['following:feeds']=[{page:'feeds'},{page:'feed',id:'f1'}];
        const saved=this.snapshot();saved.section='bookmarks';saved.branches.bookmarks=[{page:'groups',folder:null},{page:'group',group:'inspiration'}];
        this.spaces.push({id:'s2',name:'Quiet worlds',nav:feed},{id:'s3',name:'Inspiration',nav:saved});
      }
    }
    profile(id=this.nav.profile) { return this.profiles.find(p=>p.id===id)||null; }
    key(section=this.nav.section) { return section==='browse'?'browse:'+this.nav.profile:section==='following'?'following:'+(this.nav.followingView||'pins'):section; }
    root(section) {
      return section==='browse'?{page:'browse'}:section==='following'?{page:this.nav.followingView||'pins',folder:null}:section==='bookmarks'?{page:'groups',folder:null}:{page:'more'};
    }
    ensure() { const k=this.key(); if(!this.nav.branches[k]) this.nav.branches[k]=[this.root(this.nav.section)]; return this.nav.branches[k]; }
    get route() { return this.ensure().at(-1); }
    get depth() { return this.ensure().length; }
    snapshot() { return copy(this.nav); }
    restore(nav) { this.nav=copy(nav); this.clearSelection(); this.ensure(); }
    switchSection(section) {
      if(!['browse','following','bookmarks','more'].includes(section)) throw new Error('Unknown destination');
      this.clearSelection(); this.nav.section=section; this.ensure();
    }
    push(route) { this.clearSelection(); this.ensure().push(copy(route)); }
    switchFollowing(page) { if(!['pins','feeds'].includes(page))throw new Error('Unknown Following view');this.nav.followingView=page;this.switchSection('following'); }
    resetSection(section,route) { if(section==='following'&&['pins','feeds'].includes(route?.page))this.nav.followingView=route.page;this.switchSection(section); this.nav.branches[this.key()]=[copy(route||this.root(section))]; }
    switchProfile(id) {
      if(!this.profile(id)) throw new Error('Profile no longer exists');
      this.clearSelection(); this.nav.profile=id; this.ensure();
    }
    back() {
      if(this.selection.length) { this.clearSelection(); return 'selection'; }
      const stack=this.ensure();
      if(stack.length>1) {
        const last=stack.pop();
        if(last.returnTo) this.switchSection(last.returnTo);
        return 'parent';
      }
      if(this.nav.section!==this.start) {this.switchSection(this.start); return 'start';}
      return 'exit';
    }
    openPin(id) {
      const pin=this.pins.find(p=>p.id===id); if(!pin) throw new Error('Pinned search no longer exists');
      if(!this.profile(pin.profile)) throw new Error('Profile no longer exists');
      const origin=this.nav.section; pin.isNew=false;
      this.switchProfile(pin.profile); this.switchSection('browse');
      this.push({page:'search',query:pin.query,name:pin.name,returnTo:origin==='browse'?null:origin});
    }
    visiblePosts() {
      if(this.empty) return [];
      const r=this.route;
      if(this.nav.section==='bookmarks') return this.posts.filter(p=>p.bookmarked && (r.group==='all'||!r.group||r.group==='none'&&!p.groups.length||p.groups.includes(r.group)));
      if(r.page==='feed') {const f=this.feeds.find(f=>f.id===r.id); const sites=new Set((f?.sources||[]).map(s=>this.profile(s.profile)?.site)); return this.posts.filter(p=>sites.has(p.site));}
      const site=this.profile()?.site;
      let result=this.posts.filter(p=>p.site===site);
      if(r.page==='search'&&r.query) {const q=r.query.toLowerCase().split(/\s+/).filter(Boolean); result=result.filter(p=>q.some(t=>p.tags.includes(t)||p.title.toLowerCase().includes(t)));}
      return result;
    }
    select(id,order=[],range=false) {
      if(range&&this.anchor!==null&&order.includes(this.anchor)&&order.includes(id)) {
        const a=order.indexOf(this.anchor), b=order.indexOf(id);
        this.selection=[...new Set([...this.selection,...order.slice(Math.min(a,b),Math.max(a,b)+1)])];
      } else {this.selection=this.selection.includes(id)?this.selection.filter(k=>k!==id):[...this.selection,id]; this.anchor=id;}
    }
    clearSelection() {this.selection=[]; this.anchor=null;}
    openViewer(key,keys) {this.viewer={keys:keys.slice(),index:keys.indexOf(key)};this.pending={};}
    get viewedPost() {return this.viewer?this.posts.find(p=>p.key===this.viewer.keys[this.viewer.index]):null;}
    isMarked(post) {return Object.prototype.hasOwnProperty.call(this.pending,post.key)?this.pending[post.key]:post.bookmarked;}
    toggleViewedBookmark() {const p=this.viewedPost;if(p) this.pending[p.key]=!this.isMarked(p);}
    closeViewer() {
      for(const [key,value] of Object.entries(this.pending)) {const p=this.posts.find(p=>p.key===key);if(p){p.bookmarked=value;if(value&&!p.groups.length&&this.defaultGroup)p.groups=[this.defaultGroup];if(!value)p.groups=[];}}
      this.viewer=null;this.pending={};
    }
    addGroup(name,type='group',parent=null) {
      name=name.trim();if(!name)throw new Error('Enter a name');
      const id='created-'+this.nextId++;this.groups.push({id,name,type,parent});this.empty=false;return id;
    }
    addPin(name,query,profile,folder=null) {
      query=query.trim();if(!query)throw new Error('Enter a search query');if(!this.profile(profile))throw new Error('Choose an existing profile');
      if(this.pins.some(p=>p.profile===profile&&p.query.replace(/\s+/g,' ')===query.replace(/\s+/g,' ')))throw new Error('This search is already pinned for that profile');
      this.pins.push({id:'pin-'+this.nextId++,name:name.trim()||query,query,profile,folder,isNew:false,art:3});this.empty=false;
    }
    moveBookmarks(group) {
      if(!this.groups.some(g=>g.id===group&&g.type==='group'))throw new Error('Choose a group, not a folder');
      this.posts.filter(p=>this.selection.includes(p.key)).forEach(p=>{p.bookmarked=true;p.groups=[group];});this.clearSelection();
    }
    openSpace(name) {
      if(this.spaces.length>=6)throw new Error('Close a space before opening another (demo limit: 6)');
      this.saveSpace();const id='space-'+this.nextId++;this.spaces.push({id,name:name.trim()||'Untitled space',nav:this.snapshot()});this.activeSpace=id;return id;
    }
    saveSpace() {const s=this.spaces.find(s=>s.id===this.activeSpace);if(s)s.nav=this.snapshot();}
    switchSpace(id) {const s=this.spaces.find(s=>s.id===id);if(!s)throw new Error('Space no longer exists');this.saveSpace();this.activeSpace=id;this.restore(s.nav);}
    closeSpace(id) {
      if(this.spaces.length===1)throw new Error('Keep at least one space open');
      const current=id===this.activeSpace;this.spaces=this.spaces.filter(s=>s.id!==id);
      if(current){this.activeSpace=this.spaces.at(-1).id;this.restore(this.spaces.at(-1).nav);}
    }
  }
  const api={Model,PROFILES,fixtures,copy};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.NavigationLab=api;
})(typeof window!=='undefined'?window:globalThis);
