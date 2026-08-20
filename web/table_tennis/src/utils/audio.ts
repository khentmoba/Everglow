/** Typed Howler wrapper — mirrors game.js audioType switch (0=none,1=Howler,2=audio tag) */
declare const Howler: { volume(v:number):void; mute(b:boolean):void };
declare const Howl: new (opts: unknown)=> { play(id?:string):void; pause():void; volume(v?:number):number; mute(b:boolean):void; playing():boolean; fade(a:number,b:number,c:number):void };

export class AudioManager {
  audioType: 0|1|2 = 0;
  muted = false;
  sound!: InstanceType<typeof Howl>;
  music!: InstanceType<typeof Howl>;

  init(): void {
    try {
      // Howler present → audioType 1
      if (typeof Howler !== 'undefined' && typeof Howl !== 'undefined') {
        this.audioType=1;
        // sound sprite would be loaded here from audio/sound.ogg
      } else this.audioType=0;
    } catch { this.audioType=0; }
  }
  play(id:string): void { if (this.audioType===1) { try{ this.sound?.play(id); }catch{} } }
  toggleMute(): void {
    this.muted=!this.muted;
    if (this.audioType===1){
      try{ Howler.mute(this.muted); if(this.muted) this.music?.pause(); else this.music?.play(); }catch{}
    }
  }
}
