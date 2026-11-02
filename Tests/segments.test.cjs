const { test } = require('node:test');
const assert = require('node:assert/strict');
const { videoID, plan } = require('../BetterTube/Web/SegmentEngine.js');
const s = (start = 10, end = 20, extra = {}) => ({segment:[start,end], UUID:`${start}-${end}`, category:'sponsor', actionType:'skip', videoDuration:100, ...extra});
test('watch, shorts, live, embed, short links identify videos', () => {
  for (const url of ['https://m.youtube.com/watch?v=abcdefghijk&t=10', 'https://www.youtube.com/shorts/abcdefghijk','https://youtube.com/live/abcdefghijk','https://www.youtube.com/embed/abcdefghijk','https://youtu.be/abcdefghijk']) assert.equal(videoID(url),'abcdefghijk');
});
test('foreign hosts, HTTP, malformed IDs and nonstandard ports are rejected', () => {
  for (const url of ['https://youtube.com.evil.test/watch?v=abcdefghijk','https://notyoutube.com/watch?v=abcdefghijk','http://youtube.com/watch?v=abcdefghijk','https://youtube.com:444/watch?v=abcdefghijk','https://youtube.com/watch?v=short','https://youtube.com/results?v=abcdefghijk','broken']) assert.equal(videoID(url),null);
});
test('skip begins inside a selected segment and stops at its end', () => {
  assert.equal(plan([s()],9.99,100,['sponsor']),null);
  assert.equal(plan([s()],10,100,['sponsor']).to,20);
  assert.equal(plan([s()],20,100,['sponsor']),null);
});
test('merge overlapping and adjacent segments without skipping gaps', () => {
  const result = plan([s(15,30),s(10,20),s(30,40),s(41,50)],12,100,['sponsor']);
  assert.equal(result.to,40); assert.equal(result.ids.length,3);
});
test('ignore undone segments and disabled categories', () => {
  assert.equal(plan([s()],12,100,['intro']),null);
  assert.equal(plan([s()],12,100,['sponsor'],new Set(['10-20'])),null);
});
test('reject live streams, malformed segments, stale durations, mute actions', () => {
  assert.equal(plan([s()],12,Infinity,['sponsor']),null);
  for (const invalid of [s(-1,20),s(20,10),s(10,Infinity),s(10,20,{actionType:'mute'}),s(10,20,{videoDuration:104}),s(10,20,{segment:[10]}),s(10,20,{UUID:''}),s(10,200),s(10,20,{videoDuration:-1})]) assert.equal(plan([invalid],12,100,['sponsor']),null);
});
test('unknown duration and small duration drift are accepted', () => {
  assert.equal(plan([s(10,20,{videoDuration:0})],12,100,['sponsor']).to,20);
  assert.equal(plan([s(10,20,{videoDuration:102})],12,100,['sponsor']).to,20);
});
test('outro clamps to the media duration', () => assert.equal(plan([s(90,100.5)],92,100,['sponsor']).to,100));
