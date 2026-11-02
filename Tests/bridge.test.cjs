const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function fixture() {
  const events = [], intervals = [];
  const player = { ad: false, classList: { contains: () => player.ad }, querySelector: () => null };
  const video = {currentTime:12,duration:100,paused:false,seeking:false,readyState:4,isConnected:true,currentSrc:'media',getBoundingClientRect:()=>({width:300,height:200,top:0,bottom:200}),closest:()=>player};
  const document = {readyState:'complete',documentElement:{toggleAttribute() {},appendChild(){}},head:{appendChild(){}},createElement:()=>({isConnected:true}),querySelectorAll:()=>[video],querySelector:()=>player,addEventListener(){}};
  const context = vm.createContext({document,URL,innerHeight:800,location:{href:'https://m.youtube.com/watch?v=abcdefghijk'},matchMedia:()=>({matches:true,addEventListener(){}}),setInterval:f=>intervals.push(f),Date,Set,console});
  context.window=context;
  context.addEventListener=()=>{};
  context.webkit={messageHandlers:{betterTube:{postMessage:e=>events.push(e)}}};
  context.BetterTubeConfig={adBlock:true,sponsorBlock:true,categories:['sponsor'],accent:'#FF0000',appearance:'dark'};
  for (const file of ['SegmentEngine.js','PlayerBridge.js']) vm.runInContext(fs.readFileSync(`${__dirname}/../BetterTube/Web/${file}`,'utf8'),context);
  const segment={segment:[10,20],UUID:'one',category:'sponsor',actionType:'skip',videoDuration:100};
  return {context,video,player,events,segment,tick:()=>intervals[0](),api:context.BetterTube};
}
test('bridge applies a skip and undo preserves the segment on subsequent ticks',()=>{
  const f=fixture();f.api.setSegments('abcdefghijk',[f.segment]);
  assert.equal(f.video.currentTime,20);
  const event=f.events.find(e=>e.type==='skipped');assert.ok(event);
  assert.equal(f.api.undo(event.token),true);assert.equal(f.video.currentTime,12);
  f.tick();assert.equal(f.video.currentTime,12);
});
test('SPA navigation rejects stale segment replies and undo tokens',()=>{
  const f=fixture();f.api.setSegments('abcdefghijk',[f.segment]);const event=f.events.find(e=>e.type==='skipped');
  f.context.location.href='https://m.youtube.com/watch?v=lmnopqrstuv';f.video.currentTime=12;f.tick();
  assert.equal(f.api.setSegments('abcdefghijk',[f.segment]),false);
  assert.equal(f.api.undo(event.token),false);assert.equal(f.video.currentTime,12);
});
test('turning SponsorBlock off takes effect immediately',()=>{
  const f=fixture();f.api.configure({...f.context.BetterTubeConfig,sponsorBlock:false});
  f.api.setSegments('abcdefghijk',[f.segment]);assert.equal(f.video.currentTime,12);
});
test('paused and seeking videos do not auto-skip',()=>{
  for(const state of ['paused','seeking']) { const f=fixture();f.video[state]=true;f.api.setSegments('abcdefghijk',[f.segment]);assert.equal(f.video.currentTime,12); }
});
test('ad detection is required for ad seeking',()=>{
  const f=fixture();f.tick();assert.equal(f.video.currentTime,12);
  f.player.ad=true;f.tick();assert.ok(f.video.currentTime>99);assert.equal(f.events.filter(e=>e.type==='adSkipped').length,1);
});
test('SponsorBlock never seeks an ad when ad blocking is disabled',()=>{
  const f=fixture();f.player.ad=true;f.api.configure({...f.context.BetterTubeConfig,adBlock:false});
  f.api.setSegments('abcdefghijk',[f.segment]);assert.equal(f.video.currentTime,12);
});
test('skip notification is not repeated at the end of a segment',()=>{
  const f=fixture();f.api.setSegments('abcdefghijk',[f.segment]);f.tick();f.tick();assert.equal(f.events.filter(e=>e.type==='skipped').length,1);
});
test('foreign or malformed video routes do not accept segments',()=>{
  const f=fixture();f.context.location.href='https://m.youtube.com/results?search_query=test';f.tick();
  assert.equal(f.api.setSegments('abcdefghijk',[f.segment]),false);assert.equal(f.video.currentTime,12);
});
