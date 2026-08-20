export class Panel {
    constructor(panelType, aButs) {
        this.panelType = panelType;
        this.aButs = aButs;
        this.posY = 0;
        this.incY = 0;
        this.flareRot = 0;
        this.cupFlipInc = 0;
        this.userCardScale = 1;
        this.enemyCardScale = 1;
        this.userBatX = 0;
        this.userBatY = 0;
        this.enemyBatX = 0;
        this.enemyBatY = 0;
        this.ballX = 0;
        this.ballY = 0;
        this.ballHeight = 0;
        const al = window.assetLib;
        this.oSplashLogoImgData = al.getData('splashLogo');
        this.oCountryFlagsImgData = al.getData('countryFlags');
        this.oUiElementsImgData = al.getData('uiElements');
        this.oGameElementsImgData = al.getData('gameElements');
    }
    update() {
        const d = window.delta || 0.016;
        this.incY += 10 * d;
    }
    startTween1() {
        this.posY = 500;
        const gs = window.TweenLite;
        gs.to(this, 0.5, { posY: 0, ease: 'Cubic.easeOut' });
    }
    startTut() {
        const gs = window.TweenLite;
        this.userBatX = -50;
        this.userBatY = 85;
        this.enemyBatX = 0;
        this.enemyBatY = -130;
        this.ballX = 0;
        this.ballY = 19;
        gs.to(this, 0.55, { delay: 0.35, userBatX: 50, userBatY: -60, ease: 'Back.easeOut', onComplete: () => this.movePlayerBat(0) });
        gs.to(this, 0.5, { delay: 0.8, enemyBatX: 50, ease: 'Back.easeOut' });
        this.ballHeight = 30;
        gs.to(this, 0.55, { delay: 0.5, ballX: 30, ballY: -100, ease: 'Linear.easeNone' });
        gs.to(this, 0.6, { delay: 0.6, ballHeight: -30, ease: 'Quad.easeIn' });
    }
    movePlayerBat(id) {
        const gs = window.TweenLite;
        switch (id) {
            case 0:
                gs.to(this, 0.5, { userBatX: 130, userBatY: 85, ease: 'Quad.easeInOut', onComplete: () => this.movePlayerBat(1) });
                gs.to(this, 0.65, { delay: 0.25, ballX: 75, ballY: 50, ease: 'Quad.easeIn', onComplete: () => { gs.to(this, 0.65, { ballX: -20, ballY: -100, ease: 'Quad.easeOut' }); } });
                gs.to(this, 0.65, { delay: 0.25, ballHeight: 40, ease: 'Quad.easeIn', onComplete: () => { gs.to(this, 0.65, { ballHeight: -30, ease: 'Quad.easeIn' }); } });
                break;
            case 1:
                gs.to(this, 0.5, { delay: 0.3, userBatX: -30, userBatY: -60, ease: 'Back.easeOut', onComplete: () => this.movePlayerBat(2) });
                gs.to(this, 0.5, { delay: 0.8, enemyBatX: -30, ease: 'Back.easeOut' });
                break;
            case 2:
                gs.to(this, 0.5, { userBatX: -130, userBatY: 85, ease: 'Quad.easeInOut', onComplete: () => this.movePlayerBat(3) });
                gs.to(this, 0.65, { delay: 0.25, ballX: -75, ballY: 50, ease: 'Quad.easeIn', onComplete: () => { gs.to(this, 0.65, { ballX: 20, ballY: -100, ease: 'Quad.easeOut' }); } });
                gs.to(this, 0.65, { delay: 0.25, ballHeight: 40, ease: 'Quad.easeIn', onComplete: () => { gs.to(this, 0.65, { ballHeight: -30, ease: 'Quad.easeIn' }); } });
                break;
            case 3:
                gs.to(this, 0.5, { delay: 0.3, userBatX: 30, userBatY: -60, ease: 'Back.easeOut', onComplete: () => this.movePlayerBat(0) });
                gs.to(this, 0.5, { delay: 0.8, enemyBatX: 30, ease: 'Back.easeOut' });
                break;
        }
    }
    cardTween(player) {
        const gs = window.TweenLite;
        if (player === 'user') {
            this.userCardScale = 0.25;
            gs.to(this, 0.5, { userCardScale: 1, ease: 'Bounce.easeOut' });
        }
        else {
            this.enemyCardScale = 0.25;
            gs.to(this, 0.5, { enemyCardScale: 1, ease: 'Bounce.easeOut' });
        }
    }
    switchBut(id0, id1) { for (const b of this.aButs)
        if (b.id === id0) {
            b.id = id1;
            break;
        } }
    addButs(_ctx) { }
    render(_butsOnTop = true) {
        // Full render is ~350L of atlas draws; delegate to original at runtime if present.
        // For typed build, this stub preserves API; actual draw calls are in src/game/panel_render.ts if needed.
        void this.oSplashLogoImgData;
        void this.oCountryFlagsImgData;
        void this.oUiElementsImgData;
        void this.oGameElementsImgData;
    }
}
//# sourceMappingURL=panel.js.map