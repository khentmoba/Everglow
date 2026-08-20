export class AudioManager {
    constructor() {
        this.audioType = 0;
        this.muted = false;
    }
    init() {
        try {
            // Howler present → audioType 1
            if (typeof Howler !== 'undefined' && typeof Howl !== 'undefined') {
                this.audioType = 1;
                // sound sprite would be loaded here from audio/sound.ogg
            }
            else
                this.audioType = 0;
        }
        catch {
            this.audioType = 0;
        }
    }
    play(id) { if (this.audioType === 1) {
        try {
            this.sound?.play(id);
        }
        catch { }
    } }
    toggleMute() {
        this.muted = !this.muted;
        if (this.audioType === 1) {
            try {
                Howler.mute(this.muted);
                if (this.muted)
                    this.music?.pause();
                else
                    this.music?.play();
            }
            catch { }
        }
    }
}
//# sourceMappingURL=audio.js.map