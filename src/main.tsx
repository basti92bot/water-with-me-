import React,{useEffect,useState} from 'react';
import { createRoot } from 'react-dom/client';
import type {Session} from '@supabase/supabase-js';
import {Droplet} from 'lucide-react';
import {supabase} from './supabase';
import WaterApp from './water-app';
import './globals.css';
function App(){
 const [session,setSession]=useState<Session|null>(null),[ready,setReady]=useState(false),[signup,setSignup]=useState(false),[email,setEmail]=useState(''),[password,setPassword]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 useEffect(()=>{void supabase.auth.getSession().then(({data})=>{setSession(data.session);setReady(true);});const{data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{setSession(next);setReady(true);});return()=>subscription.unsubscribe();},[]);
 if(!ready)return <main className="auth-wrap"><p>Water With Me lädt…</p></main>;
 if(session)return <WaterApp initialInvite={new URL(window.location.href).searchParams.get('invite')||''}/>;
 return <main className="auth-wrap"><div className="auth-card"><div className="auth-brand"><span className="brand-symbol"><Droplet size={25} fill="currentColor"/></span><h1>Water With Me</h1></div><p className="subtext">{signup?'Erstelle dein Konto und verbinde dich mit deinen Freunden.':'Melde dich an und trinke mit deiner Runde.'}</p><form onSubmit={async e=>{e.preventDefault();setBusy(true);setMessage('');try{const result=signup?await supabase.auth.signUp({email,password}):await supabase.auth.signInWithPassword({email,password});if(result.error){setMessage(signup?'Konto konnte nicht erstellt werden. Prüfe deine Angaben oder versuche es später erneut.':'Anmeldung fehlgeschlagen. Prüfe E-Mail und Passwort.');return;}if(signup&&!result.data.session)setMessage('Bestätige deine E-Mail. Öffne danach diese App erneut und melde dich an.');}catch{setMessage('Verbindung fehlgeschlagen. Bitte erneut versuchen.');}finally{setBusy(false);}}}><label className="form-label">E-Mail<input type="email" value={email} onChange={e=>setEmail(e.target.value)} autoComplete="email" required/></label><label className="form-label">Passwort<input type="password" value={password} onChange={e=>setPassword(e.target.value)} autoComplete={signup?'new-password':'current-password'} minLength={signup?8:undefined} required/></label><button className="button primary full" disabled={busy}>{busy?'Einen Moment…':signup?'Konto erstellen':'Anmelden'}</button><p className="auth-message" role="status">{message}</p></form><button className="button secondary full" onClick={()=>{setSignup(!signup);setMessage('');}}>{signup?'Ich habe bereits ein Konto':'Neues Konto erstellen'}</button><p className="form-help auth-note">Du kannst dein bestehendes RepPilot-Konto verwenden. Deine E-Mail sehen deine Freunde nicht.</p></div></main>;
}
createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>);
if('serviceWorker' in navigator)window.addEventListener('load',()=>{void navigator.serviceWorker.register('./sw.js',{updateViaCache:'none'}).catch(()=>{});});
