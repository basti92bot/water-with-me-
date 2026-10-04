export type DrinkLocation={lat:number;lon:number;label:string};
export function currentDrinkLocation(label:string):Promise<DrinkLocation>{
 return new Promise((resolve,reject)=>{
  if(!navigator.geolocation){reject(new Error('Standort ist hier nicht verfügbar. Deaktiviere „Standort für diesen Eintrag teilen“, um ohne Standort einzutragen.'));return;}
  navigator.geolocation.getCurrentPosition(position=>{
   const {latitude,longitude}=position.coords;
   if(!Number.isFinite(latitude)||!Number.isFinite(longitude)||Math.abs(latitude)>90||Math.abs(longitude)>180){reject(new Error('Der Standort konnte nicht bestimmt werden. Bitte erneut versuchen.'));return;}
   // Share an approximate point, freshly requested for this single drink.
   resolve({lat:Math.round(latitude*1000)/1000,lon:Math.round(longitude*1000)/1000,label:label.trim().slice(0,40)});
  },error=>reject(new Error(error.code===1?'Standort nicht erlaubt. Erlaube ihn in den Geräte-Einstellungen oder deaktiviere „Standort für diesen Eintrag teilen“.':'Standort konnte nicht ermittelt werden. Versuche es erneut oder trage ohne Standort ein.')),{enableHighAccuracy:false,timeout:10000,maximumAge:0});
 });
}
export function coordinates(location:DrinkLocation){return `${location.lat.toFixed(3)}, ${location.lon.toFixed(3)}`;}
export function mapUrl(location:DrinkLocation){return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(coordinates(location))}`;}
