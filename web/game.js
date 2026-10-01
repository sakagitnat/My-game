(function(root){
'use strict';
const names=['ซุป','ขนมปัง','น้ำผลไม้'],prices=[18,14,12],key='tiny-tavern-web-v1';
class Tavern {
 constructor(storage,random){this.storage=storage;this.random=random||Math.random;this.coins=0;this.served=0;this.level=1;this.stock=[0,0,0];this.customers=[];this.cooking=null;this.arrival=6;this.message='แตะเมนูเพื่อทำอาหาร แล้วแตะลูกค้าเพื่อเสิร์ฟ';this.load();this.spawn();this.spawn();}
 load(){try{const d=JSON.parse(this.storage.getItem(key));if(d){for(const k of ['coins','served','level'])if(Number.isSafeInteger(d[k])&&d[k]>=0)this[k]=d[k];this.level=Math.max(1,this.level);}}catch(e){}}
 save(){try{this.storage.setItem(key,JSON.stringify({coins:this.coins,served:this.served,level:this.level}));}catch(e){this.message+=' (เบราว์เซอร์นี้บันทึกเซฟไม่ได้)';}}
 spawn(){for(let seat=0;seat<4;seat++){if(!this.customers.some(c=>c.seat===seat)){this.customers.push({seat,dish:Math.floor(this.random()*3),patience:60,color:['#aa7cc8','#d69a7b','#8eb6a0','#88a4d3'][seat]});return;}}}
 cook(dish){if(this.cooking||!Number.isInteger(dish)||dish<0||dish>2)return false;const duration=Math.max(.8,3.5-(this.level-1)*.4);this.cooking={dish,left:duration,duration};this.message='กำลังทำ'+names[dish]+'…';return true;}
 serve(seat){const i=this.customers.findIndex(c=>c.seat===seat);if(i<0)return false;const c=this.customers[i];if(!this.stock[c.dish]){this.message='ลูกค้าต้องการ'+names[c.dish]+' ทำอาหารก่อนนะ';return false;}this.stock[c.dish]--;this.coins+=prices[c.dish];this.served++;this.customers.splice(i,1);this.message='ขอบคุณ! ได้รับ '+prices[c.dish]+' เหรียญ';this.save();return true;}
 upgrade(){const cost=this.level*60;if(this.coins<cost)return false;this.coins-=cost;this.level++;this.message='อัปเกรดครัวแล้ว! ทำอาหารได้เร็วขึ้น';this.save();return true;}
 tick(dt){if(!Number.isFinite(dt)||dt<=0)return;if(this.cooking){this.cooking.left-=dt;if(this.cooking.left<=0){this.stock[this.cooking.dish]++;this.message=names[this.cooking.dish]+'พร้อมแล้ว แตะลูกค้าที่สั่งเมนูนี้';this.cooking=null;}}for(let i=this.customers.length-1;i>=0;i--){this.customers[i].patience-=dt;if(this.customers[i].patience<=0){this.customers.splice(i,1);this.message='ลูกค้ารอนานและออกจากร้านแล้ว';}}this.arrival-=dt;if(this.arrival<=0){this.arrival=7;this.spawn();}}
}
root.Tavern=Tavern;root.TavernNames=names;if(typeof module!=='undefined')module.exports={Tavern,names,prices};
})(typeof window!=='undefined'?window:globalThis);
