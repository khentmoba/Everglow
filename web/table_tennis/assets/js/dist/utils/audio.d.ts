declare const Howl: new (opts: unknown) => {
    play(id?: string): void;
    pause(): void;
    volume(v?: number): number;
    mute(b: boolean): void;
    playing(): boolean;
    fade(a: number, b: number, c: number): void;
};
export declare class AudioManager {
    audioType: 0 | 1 | 2;
    muted: boolean;
    sound: InstanceType<typeof Howl>;
    music: InstanceType<typeof Howl>;
    init(): void;
    play(id: string): void;
    toggleMute(): void;
}
export {};
//# sourceMappingURL=audio.d.ts.map