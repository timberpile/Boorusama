const {test}=require('node:test');
const assert=require('node:assert/strict');
const {Model}=require('../model.js');
for(const concept of ['A','B','C']) {
  test(concept+': destinations restore their nested location instead of stacking tabs',()=>{
    const m=new Model(concept);m.switchSection('bookmarks');m.push({page:'groups',folder:'collections'});m.push({page:'group',group:'scenery'});
    m.switchSection('browse');m.switchSection('bookmarks');assert.equal(m.route.group,'scenery');assert.equal(m.depth,3);
    m.back();assert.equal(m.route.folder,'collections');m.back();assert.equal(m.depth,1);m.back();assert.equal(m.nav.section,'browse');assert.equal(m.back(),'exit');
  });
  test(concept+': opening a pin activates its owner but retains the collection return location',()=>{
    const m=new Model(concept);m.switchSection('following');m.push({page:'pins',folder:'worlds'});m.openPin('p3');
    assert.equal(m.nav.profile,'gel');assert.equal(m.route.query,'original scenery');assert.equal(m.pins.find(p=>p.id==='p3').isNew,false);
    m.back();assert.equal(m.nav.section,'following');assert.equal(m.route.folder,'worlds');assert.equal(m.nav.profile,'gel');
  });
}
test('switching profile never filters or resets a global bookmark group',()=>{
  const m=new Model();m.switchSection('bookmarks');m.push({page:'group',group:'inspiration'});const keys=m.visiblePosts().map(p=>p.key);
  m.switchProfile('gel');assert.equal(m.route.group,'inspiration');assert.deepEqual(m.visiblePosts().map(p=>p.key),keys);
});
test('browse histories are independent even for two profiles on the same site',()=>{
  const m=new Model();m.push({page:'search',query:'clouds'});m.switchProfile('guest');assert.equal(m.route.page,'browse');
  m.push({page:'search',query:'night'});m.switchProfile('personal');assert.equal(m.route.query,'clouds');
});
test('selection is cancelled before hierarchy navigation and range selection is additive',()=>{
  const m=new Model();m.push({page:'search',query:'clouds'});m.select('b',['a','b','c','d']);m.select('d',['a','b','c','d'],true);
  assert.deepEqual(m.selection,['b','c','d']);assert.equal(m.back(),'selection');assert.equal(m.route.page,'search');
});
test('viewer bookmark changes are projected, then committed when leaving the viewer',()=>{
  const m=new Model();const p=m.posts[20];m.openViewer(p.key,[p.key]);m.toggleViewedBookmark();
  assert.equal(p.bookmarked,false);assert.equal(m.isMarked(p),true);m.closeViewer();assert.equal(p.bookmarked,true);assert.deepEqual(p.groups,['inspiration']);
});
test('a second viewer toggle cancels pending removal without changing the grid',()=>{
  const m=new Model();const p=m.posts[0];m.openViewer(p.key,[p.key]);m.toggleViewedBookmark();m.toggleViewedBookmark();m.closeViewer();assert.equal(p.bookmarked,true);
});
test('saved searches reject a missing profile and normalized duplicates',()=>{
  const m=new Model();assert.throws(()=>m.addPin('','scenery   clouds','personal'),/already pinned/);
  assert.throws(()=>m.switchProfile('missing'),/no longer exists/);assert.throws(()=>m.addPin('x','sky','missing'),/existing profile/);
});
test('folders and All are not bookmark assignment targets',()=>{
  const m=new Model();m.select(m.posts[0].key);assert.throws(()=>m.moveBookmarks('collections'),/not a folder/);assert.throws(()=>m.moveBookmarks('all'),/not a folder/);
  m.moveBookmarks('scenery');assert.deepEqual(m.posts[0].groups,['scenery']);assert.equal(m.selection.length,0);
});
test('spaces preserve their own profile and branch history and closing the active space is safe',()=>{
  const m=new Model('C');m.push({page:'search',query:'clouds'});m.openSpace('Research');m.switchProfile('gel');m.switchSection('bookmarks');m.push({page:'group',group:'scenery'});
  const second=m.activeSpace;m.switchSpace('s1');assert.equal(m.nav.profile,'personal');assert.equal(m.route.query,'clouds');
  m.switchSpace(second);assert.equal(m.nav.profile,'gel');assert.equal(m.route.group,'scenery');m.closeSpace(second);assert.ok(m.spaces.some(s=>s.id===m.activeSpace));while(m.spaces.length>1)m.closeSpace(m.spaces.at(-1).id);assert.throws(()=>m.closeSpace(m.activeSpace),/at least one/);
});
test('restoring browser navigation does not undo application data mutations',()=>{
  const m=new Model();const nav=m.snapshot();m.addGroup('New group');m.switchSection('bookmarks');m.restore(nav);
  assert.equal(m.nav.section,'browse');assert.ok(m.groups.some(g=>g.name==='New group'));
});

test('Following tabs retain independent nested locations',()=>{const m=new Model();m.switchFollowing('pins');m.push({page:'pins',folder:'worlds'});m.switchFollowing('feeds');m.push({page:'feed',id:'f1'});m.switchFollowing('pins');assert.equal(m.route.folder,'worlds');m.switchFollowing('feeds');assert.equal(m.route.id,'f1');});
