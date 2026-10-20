const assert = require('node:assert/strict');
const test = require('node:test');
const A = require('./art.js');
const E = require('./engine.js');

test('ช่วงอายุแบ่งเป็นสี่วัยตามที่กำหนด', () => {
  assert.equal(A.stageOf(5), 'child');
  assert.equal(A.stageOf(13), 'youth');
  assert.equal(A.stageOf(18), 'adult');
  assert.equal(A.stageOf(60), 'elder');
  assert.equal(A.stageOf(100), 'elder');
});

test('ทุกวัยมีฉากและทุกอาชีพมีไอคอน', () => {
  for (const stage of Object.keys(A.STAGE_TITLES)) {
    assert.match(A.sceneSvg(stage), /^<svg viewBox="0 0 400 200"[\s\S]*<\/svg>$/);
  }
  for (const origin of E.ORIGINS) {
    assert.match(A.originIcon(origin.id), /^<svg viewBox="0 0 48 48"/);
  }
});

test('ทุกค่าสถานะที่แสดงมีไอคอน', () => {
  for (const key of Object.keys(E.STAT_LABELS)) {
    assert.match(A.statIcon(key), /^<svg viewBox="0 0 24 24"/, key);
  }
});

test('ไม่ทำให้เกิด error เมื่อขอไอคอนที่ไม่มี', () => {
  assert.equal(A.statIcon('unknown'), '');
  assert.match(A.originIcon('unknown'), /<svg/);
});

console.log('art tests done');
