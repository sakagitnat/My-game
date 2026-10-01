const assert=require('node:assert/strict');
const {Tavern}=require('../web/game.js');
let saved=null;const store={getItem:()=>saved,setItem:(k,v)=>{saved=v;}};
const g=new Tavern(store,()=>0);
assert.equal(g.serve(0),false);assert.equal(g.coins,0);
assert.equal(g.cook(0),true);assert.equal(g.cook(1),false);g.tick(4);assert.equal(g.stock[0],1);assert.equal(g.serve(0),true);assert.equal(g.coins,18);assert.equal(g.served,1);
g.coins=60;assert.equal(g.upgrade(),true);assert.equal(g.coins,0);assert.equal(g.level,2);assert.equal(new Tavern(store,()=>0).level,2);
g.arrival=100;g.tick(61);assert.equal(g.customers.length,0);for(let i=0;i<10;i++)g.spawn();assert.equal(g.customers.length,4);
assert.equal(g.cook(-1),false);assert.equal(g.cook(3),false);
const broken=new Tavern({getItem:()=>'{bad',setItem:()=>{throw Error('blocked');}},()=>0);broken.save();assert.match(broken.message,/บันทึกเซฟไม่ได้/);
console.log('PASS web gameplay: cooking, serving, reward, upgrade, save, capacity, patience, unavailable storage');

// Exercise the browser entry point, drawing, menu and accessible serve controls.
const vm=require('node:vm'),fs=require('node:fs');
const ctx=new Proxy({}, {get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
const elements=new Map();function element(){return {textContent:'',disabled:false,value:0,children:[],dataset:{},replaceChildren(){this.children=[];},appendChild(e){this.children.push(e);}};}
const dishButtons=[0,1,2].map(i=>Object.assign(element(),{dataset:{dish:String(i)}}));
const canvas=Object.assign(element(),{getContext:()=>ctx,getBoundingClientRect:()=>({left:0,top:0,width:1100,height:560}),addEventListener:(type,fn)=>{canvas[type]=fn;}});elements.set('scene',canvas);
const doc={hidden:false,getElementById:id=>{if(!elements.has(id))elements.set(id,element());return elements.get(id);},querySelectorAll:()=>dishButtons,createElement:()=>element(),addEventListener:()=>{}};
let frame;const sandbox={document:doc,performance:{now:()=>0},requestAnimationFrame:fn=>{frame=fn;},console,Math: Object.assign(Object.create(Math),{random:()=>0})};sandbox.window=sandbox;sandbox.localStorage={getItem:()=>null,setItem:()=>{}};
vm.createContext(sandbox);vm.runInContext(fs.readFileSync(require.resolve('../web/game.js'),'utf8'),sandbox);vm.runInContext(fs.readFileSync(require.resolve('../web/app.js'),'utf8'),sandbox);
dishButtons[0].onclick();for(let i=1;i<=16;i++)frame(i*250);assert.equal(elements.get('stock0').textContent,1);elements.get('orders').children[0].onclick();assert.equal(elements.get('coins').textContent,18);assert.equal(elements.get('served').textContent,1);assert.equal(elements.get('stock0').textContent,0);
console.log('PASS browser entry: canvas rendering, cooking button, serve button and HUD updates');
