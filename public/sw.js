const CACHE='water-with-me-v3';
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const key of await caches.keys())if(key.startsWith('water-with-me-')&&key!==CACHE)await caches.delete(key);await self.clients.claim();})()));
self.addEventListener('fetch',event=>{const url=new URL(event.request.url);if(event.request.method!=='GET'||url.origin!==self.location.origin||!url.pathname.startsWith(new URL(self.registration.scope).pathname))return;
if(event.request.mode==='navigate'){event.respondWith((async()=>{const cache=await caches.open(CACHE);const key=self.registration.scope;try{const response=await fetch(event.request);if(response.ok)await cache.put(key,response.clone());return response;}catch{return await cache.match(key)||new Response('Bitte mit dem Internet verbinden und Water With Me erneut öffnen.',{headers:{'Content-Type':'text/plain;charset=utf-8'}});}})());return;}
if(/\.(js|css|png|svg|webmanifest)$/.test(url.pathname)){event.respondWith((async()=>{const cache=await caches.open(CACHE);const cached=await cache.match(event.request);if(cached)return cached;const response=await fetch(event.request);if(response.ok)await cache.put(event.request,response.clone());return response;})());}});

self.addEventListener('push',event=>{
 let payload={};try{payload=event.data?.json()||{};}catch{}
 const base=self.registration.scope;
 event.waitUntil(self.registration.showNotification(typeof payload.title==='string'?payload.title:'Water With Me 💧',{body:typeof payload.body==='string'?payload.body:'In deiner Runde gibt es etwas Neues.',icon:new URL('icon-192.png',base).href,badge:new URL('icon-192.png',base).href,tag:typeof payload.tag==='string'?payload.tag:'wwm-update',data:{url:new URL('./#friends',base).href}}));
});
self.addEventListener('notificationclick',event=>{event.notification.close();const url=new URL('./#friends',self.registration.scope).href;event.waitUntil((async()=>{const pages=await self.clients.matchAll({type:'window',includeUncontrolled:true});for(const page of pages)if(page.url.startsWith(self.registration.scope)){await page.navigate(url);return page.focus();}return self.clients.openWindow(url);})());});
