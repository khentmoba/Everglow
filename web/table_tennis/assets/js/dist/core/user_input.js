export class UserInput {
    constructor(canvas, isBugBrowser) {
        this.canvas = canvas;
        this.isBugBrowser = isBugBrowser;
        this.prevHitTime = 0;
        this.pauseIsOn = false;
        this.isDown = false;
        this.aHitAreas = [];
        this.aKeys = [];
        // pointer-lock helpers game.js:484
        this.userExitLock = (_e) => {
            const dc = document;
            if (dc.pointerLockElement !== this.canvas && dc.mozPointerLockElement !== this.canvas) {
                window.butEventHandler?.('pause');
            }
        };
        this.keyDownEvt = (e) => this.keyDown(e);
        this.keyUpEvt = (e) => this.keyUp(e);
        canvas.addEventListener('touchstart', (e) => {
            for (let i = 0; i < e.changedTouches.length; i++)
                this.hitDown(e, e.changedTouches[i].pageX, e.changedTouches[i].pageY, e.changedTouches[i].identifier);
        }, { passive: false });
        canvas.addEventListener('touchend', (e) => {
            for (let i = 0; i < e.changedTouches.length; i++)
                this.hitUp(e, e.changedTouches[i].pageX, e.changedTouches[i].pageY, e.changedTouches[i].identifier);
        }, { passive: false });
        canvas.addEventListener('touchcancel', (e) => {
            for (let i = 0; i < e.changedTouches.length; i++)
                this.hitCancel(e, e.changedTouches[i].pageX, e.changedTouches[i].pageY, e.changedTouches[i].identifier);
        }, { passive: false });
        canvas.addEventListener('touchmove', (e) => {
            for (let i = 0; i < e.changedTouches.length; i++)
                this.move(e, e.changedTouches[i].pageX, e.changedTouches[i].pageY, e.changedTouches[i].identifier, true);
        }, { passive: false });
        canvas.addEventListener('mousedown', (e) => { this.isDown = true; this.hitDown(e, e.pageX, e.pageY, 1); }, false);
        canvas.addEventListener('mouseup', (e) => { this.isDown = false; this.hitUp(e, e.pageX, e.pageY, 1); }, false);
        canvas.addEventListener('mousemove', (e) => { this.move(e, e.pageX, e.pageY, 1, this.isDown); }, false);
        canvas.addEventListener('mouseout', (e) => { this.isDown = false; this.hitUp(e, Math.abs(e.pageX), Math.abs(e.pageY), 1); }, false);
    }
    // global canvasScale is now injected via GameContext; fallback 1
    get canvasScale() {
        return window.canvasScale ?? 1;
    }
    hitDown(e, posX, posY, id) {
        e.preventDefault();
        e.stopPropagation();
        if (!window.hasFocus)
            window.visibleResume?.();
        if (this.pauseIsOn)
            return;
        const cur = Date.now();
        posX *= this.canvasScale;
        posY *= this.canvasScale;
        for (const ha of this.aHitAreas) {
            if (!ha.rect)
                continue;
            const ax = this.canvas.width * ha.align[0], ay = this.canvas.height * ha.align[1];
            if (posX > ax + ha.area[0] && posY > ay + ha.area[1] && posX < ax + ha.area[2] && posY < ay + ha.area[3]) {
                ha.aTouchIdentifiers.push(id);
                ha.oData['hasLeft'] = false;
                if (!ha.oData.isDown) {
                    ha.oData.isDown = true;
                    ha.oData.x = posX;
                    ha.oData.y = posY;
                    const gs = window.gameState;
                    if ((cur - this.prevHitTime < 500 && (gs !== 'game' || ha.id === 'pause')) && this.isBugBrowser)
                        return;
                    ha.callback(ha.id, ha.oData);
                }
                break;
            }
        }
        this.prevHitTime = cur;
    }
    hitUp(e, posX, posY, id) {
        if (!window.ios9FirstTouch) {
            try {
                window.playSound?.('silence');
            }
            catch { }
            window.ios9FirstTouch = true;
        }
        if (this.pauseIsOn)
            return;
        e.preventDefault();
        e.stopPropagation();
        posX *= this.canvasScale;
        posY *= this.canvasScale;
        for (const ha of this.aHitAreas) {
            if (!ha.rect)
                continue;
            const ax = this.canvas.width * ha.align[0], ay = this.canvas.height * ha.align[1];
            if (posX > ax + ha.area[0] && posY > ay + ha.area[1] && posX < ax + ha.area[2] && posY < ay + ha.area[3]) {
                for (let j = 0; j < ha.aTouchIdentifiers.length; j++)
                    if (ha.aTouchIdentifiers[j] === id) {
                        ha.aTouchIdentifiers.splice(j, 1);
                        j--;
                    }
                if (ha.aTouchIdentifiers.length === 0) {
                    ha.oData.isDown = false;
                    if (ha.oData.multiTouch) {
                        ha.oData.x = posX;
                        ha.oData.y = posY;
                        ha.callback(ha.id, ha.oData);
                    }
                }
                break;
            }
        }
    }
    hitCancel(e, posX, posY, _id) {
        e.preventDefault();
        e.stopPropagation();
        posX *= this.canvasScale;
        posY *= this.canvasScale;
        for (const ha of this.aHitAreas)
            if (ha.oData.isDown) {
                ha.oData.isDown = false;
                ha.aTouchIdentifiers = [];
                if (ha.oData.multiTouch) {
                    ha.oData.x = posX;
                    ha.oData.y = posY;
                    ha.callback(ha.id, ha.oData);
                }
            }
    }
    lockPointer(elem) {
        const el = (elem ?? this.canvas);
        if (el.requestPointerLock)
            el.requestPointerLock();
        else if (el.webkitRequestPointerLock)
            el.webkitRequestPointerLock();
        else if (el.mozRequestPointerLock)
            el.mozRequestPointerLock();
        if ('onpointerlockchange' in document)
            document.addEventListener('pointerlockchange', this.userExitLock);
        else if ('onmozpointerlockchange' in document)
            document.addEventListener('mozpointerlockchange', this.userExitLock);
    }
    unlockPointer() {
        const dc = document;
        if (dc.exitPointerLock)
            dc.exitPointerLock();
        else if (dc.webkitExitPointerLock)
            dc.webkitExitPointerLock();
        else if (dc.mozExitPointerLock)
            dc.mozExitPointerLock();
        if ('onpointerlockchange' in document)
            document.removeEventListener('pointerlockchange', this.userExitLock);
        else if ('onmozpointerlockchange' in document)
            document.removeEventListener('mozpointerlockchange', this.userExitLock);
    }
    move(e, posX, posY, ident, isDown) {
        if (this.pauseIsOn)
            return;
        // desktop: drive userBat directly (mirrors game.js:526)
        const ub = window.userBat;
        const firstRun = window.firstRun;
        const isMobile = window.isMobile;
        if (!isMobile && ub && !firstRun) {
            const dc = document;
            if (dc.pointerLockElement === this.canvas || dc.mozPointerLockElement === this.canvas) {
                const { movementX, movementY } = e;
                const helper = window.famobi?.pointerLockHelper;
                if (helper) {
                    if (helper.mousePos.x + movementX < window.innerWidth && helper.mousePos.x + movementX > 0)
                        helper.mousePos.x += movementX;
                    if (helper.mousePos.y + movementY < window.innerHeight && helper.mousePos.y + movementY > 0)
                        helper.mousePos.y += movementY;
                    ub.targX = helper.mousePos.x * this.canvasScale;
                    ub.targY = helper.mousePos.y * this.canvasScale;
                }
            }
            else {
                ub.targX = posX * this.canvasScale;
                ub.targY = posY * this.canvasScale;
                const helper = window.famobi?.pointerLockHelper;
                if (helper)
                    helper.mousePos = { x: posX, y: posY };
            }
        }
        if (!isDown)
            return;
        posX *= this.canvasScale;
        posY *= this.canvasScale;
        for (const ha of this.aHitAreas) {
            if (!ha.rect)
                continue;
            const ax = this.canvas.width * ha.align[0], ay = this.canvas.height * ha.align[1];
            if (posX > ax + ha.area[0] && posY > ay + ha.area[1] && posX < ax + ha.area[2] && posY < ay + ha.area[3]) {
                ha.oData['hasLeft'] = false;
                if (ha.oData.isDraggable && !ha.oData.isDown) {
                    ha.oData.isDown = true;
                    ha.oData.x = posX;
                    ha.oData.y = posY;
                    ha.aTouchIdentifiers.push(ident);
                    if (ha.oData.multiTouch)
                        ha.callback(ha.id, ha.oData);
                }
                if (ha.oData.isDraggable) {
                    ha.oData.isBeingDragged = true;
                    ha.oData.x = posX;
                    ha.oData.y = posY;
                    ha.callback(ha.id, ha.oData);
                    ha.oData.isBeingDragged = false;
                }
            }
            else if (ha.oData.isDown && !ha.oData['hasLeft']) {
                for (let j = 0; j < ha.aTouchIdentifiers.length; j++)
                    if (ha.aTouchIdentifiers[j] === ident) {
                        ha.aTouchIdentifiers.splice(j, 1);
                        j--;
                    }
                if (ha.aTouchIdentifiers.length === 0) {
                    ha.oData['hasLeft'] = true;
                    if (!ha.oData.isBeingDragged)
                        ha.oData.isDown = false;
                    if (ha.oData.multiTouch)
                        ha.callback(ha.id, ha.oData);
                }
            }
        }
    }
    keyDown(e) { for (const k of this.aKeys)
        if (e.keyCode === k.keyCode) {
            e.preventDefault();
            k.oData.isDown = true;
            k.callback(k.id, k.oData);
        } }
    keyUp(e) { for (const k of this.aKeys)
        if (e.keyCode === k.keyCode) {
            e.preventDefault();
            k.oData.isDown = false;
            k.callback(k.id, k.oData);
        } }
    checkKeyFocus() {
        window.focus();
        if (this.aKeys.length > 0) {
            window.removeEventListener('keydown', this.keyDownEvt);
            window.removeEventListener('keyup', this.keyUpEvt);
            window.addEventListener('keydown', this.keyDownEvt);
            window.addEventListener('keyup', this.keyUpEvt);
        }
    }
    addKey(id, cb, data, keyCode) {
        const oData = data ?? { isDown: false };
        this.aKeys.push({ id, callback: cb, oData, keyCode });
        this.checkKeyFocus();
    }
    removeKey(id) { for (let i = 0; i < this.aKeys.length; i++)
        if (this.aKeys[i].id === id) {
            this.aKeys.splice(i, 1);
            i--;
        } }
    addHitArea(id, cb, oData, type, oAreaData, isUnique = false) {
        if (!oData)
            oData = {};
        if (isUnique)
            this.removeHitArea(id);
        if (!oAreaData.scale)
            oAreaData.scale = 1;
        if (!oAreaData.align)
            oAreaData.align = [0, 0];
        const aTouchIdentifiers = [];
        switch (type) {
            case 'image': {
                const ad = oAreaData;
                const f = ad.oImgData.oData.oAtlasData[ad.id];
                const aRect = [
                    ad.aPos[0] - (f.width / 2) * ad.scale, ad.aPos[1] - (f.height / 2) * ad.scale,
                    ad.aPos[0] + (f.width / 2) * ad.scale, ad.aPos[1] + (f.height / 2) * ad.scale,
                ];
                this.aHitAreas.push({ id, aTouchIdentifiers, callback: cb, oData: oData, rect: true, area: aRect, align: ad.align });
                break;
            }
            case 'rect': {
                const ad = oAreaData;
                this.aHitAreas.push({ id, aTouchIdentifiers, callback: cb, oData: oData, rect: true, area: ad.aRect, align: ad.align ?? [0, 0] });
                break;
            }
        }
    }
    removeHitArea(id) { for (let i = 0; i < this.aHitAreas.length; i++)
        if (this.aHitAreas[i].id === id) {
            this.aHitAreas.splice(i, 1);
            i--;
        } }
    resetAll() { for (const ha of this.aHitAreas) {
        ha.oData.isDown = false;
        ha.oData.isBeingDragged = false;
        ha.aTouchIdentifiers = [];
    } this.isDown = false; }
}
//# sourceMappingURL=user_input.js.map