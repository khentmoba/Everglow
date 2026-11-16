// Port of lib/features/daily_bloom/presentation/widgets/garden_plant_view.dart
// and lily_painter.dart / plant painters.
import { useEffect, useRef } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppArt, AppColors, withAlpha } from '../../core/theme/colors';
import { Curves, reduceAmbientMotion } from '../../core/theme/motion';
import type { PlantType } from './gardenService';

const PINK_100 = '#F8BBD0';
const PINK_200 = '#F48FB1';
const PINK_300 = '#F06292';

function drawRoundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

function drawPlant(ctx: CanvasRenderingContext2D, w: number, h: number, plantId: string, stage: number, anim: number) {
  ctx.clearRect(0, 0, w, h);
  const cx = w / 2;
  const cy = h * 0.8;

  // Pot colors per plant
  const potColors =
    plantId === 'tulip'
      ? [AppArt.tulipPotLight, AppArt.tulipPot, AppArt.tulipRim]
      : plantId === 'rose'
        ? [AppArt.rosePotLight, AppArt.rosePot, AppArt.roseRim]
        : plantId === 'sakura'
          ? [AppArt.sakuraPotLight, AppArt.sakuraPot, AppArt.barkDeep]
          : plantId === 'sunflower'
            ? [AppArt.sunflowerPotLight, AppArt.barkDeep, AppArt.bark]
            : [PINK_100, PINK_200, PINK_300];

  const potW = 60 + anim * 2;
  const potH = 40;
  const px = cx - potW / 2;
  const py = cy;

  // Soil
  ctx.fillStyle = withAlpha(AppArt.barkDeep, 0.9);
  ctx.beginPath();
  ctx.ellipse(cx, py + 2, potW * 0.4, 5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = withAlpha(AppArt.bark, 0.9);
  ctx.beginPath();
  ctx.ellipse(cx - 3, py + 1, potW * 0.25, 3, 0, 0, Math.PI * 2);
  ctx.fill();

  // Pot body
  const potGrad = ctx.createLinearGradient(px, py, px + potW, py + potH);
  potGrad.addColorStop(0, potColors[0]);
  potGrad.addColorStop(1, potColors[1]);
  ctx.fillStyle = potGrad;
  drawRoundRect(ctx, px, py, potW, potH, 8);
  ctx.fill();

  ctx.fillStyle = withAlpha(potColors[2], 0.35);
  drawRoundRect(ctx, px + potW * 0.72, py + 4, potW * 0.28, potH - 4, 6);
  ctx.fill();

  // Rim
  ctx.fillStyle = potColors[2];
  drawRoundRect(ctx, px - 4, py - 5, potW + 8, 8, 4);
  ctx.fill();
  ctx.fillStyle = withAlpha(AppColors.petalWhite, 0.45);
  drawRoundRect(ctx, px, py - 3.8, potW, 1.6, 0.8);
  ctx.fill();

  if (stage < 1) return;

  const sway = (anim - 0.5) * 5;
  const stemH = 20 + stage * 11 + anim * 3;
  const tx = cx + sway;
  const ty = cy - stemH;
  const ctrlX = cx + 6 + sway * 0.5;
  const ctrlY = cy - stemH * 0.55;

  // Stem
  ctx.strokeStyle = plantId === 'sakura' ? AppArt.bark : AppColors.cinemaGreen;
  ctx.lineWidth = plantId === 'sakura' ? 5 : 4;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(cx, cy);
  ctx.quadraticCurveTo(ctrlX, ctrlY, tx, ty);
  ctx.stroke();

  if (plantId !== 'sakura') {
    ctx.strokeStyle = withAlpha(AppColors.cinemaMatch, 0.8);
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.moveTo(cx + 1.2, cy - 2);
    ctx.quadraticCurveTo(ctrlX + 1.2, ctrlY, tx + 0.8, ty);
    ctx.stroke();
  }

  // Leaves
  const leafCount = Math.max(1, Math.min(4, stage));
  const fracs = [0.22, 0.42, 0.58, 0.72];
  const drawLeaf = (lx: number, ly: number, right: boolean, len: number) => {
    const dir = right ? 1 : -1;
    const tipX = lx + dir * len;
    const tipY = ly - len * 0.45 + 4;
    const lw = len * 0.28;
    ctx.beginPath();
    ctx.moveTo(lx, ly);
    ctx.quadraticCurveTo(lx + dir * len * 0.5, ly - lw, tipX, tipY);
    ctx.quadraticCurveTo(lx + dir * len * 0.45, ly + lw * 0.5, lx, ly);
    ctx.fillStyle = AppColors.cinemaMatch;
    ctx.fill();
    ctx.strokeStyle = withAlpha(AppColors.cinemaGreen, 0.6);
    ctx.lineWidth = 1;
    ctx.stroke();
  };
  for (let i = 0; i < leafCount; i++) {
    const t = fracs[i];
    const u = 1 - t;
    const lx = u * u * cx + 2 * u * t * ctrlX + t * t * tx;
    const ly = u * u * cy + 2 * u * t * ctrlY + t * t * ty;
    drawLeaf(lx, ly, i % 2 === 0, (26 - i * 3) * (stage >= 4 ? 1 : 0.75));
  }

  // Bloom
  if (stage === 1) {
    drawLeaf(tx, ty + 4, true, 10);
    drawLeaf(tx, ty + 4, false, 10);
    ctx.fillStyle = AppColors.cinemaGreen;
    ctx.beginPath();
    ctx.arc(tx, ty - 2, 3, 0, Math.PI * 2);
    ctx.fill();
    return;
  }

  const petalPalette =
    plantId === 'rose'
      ? [AppArt.rosePetalLight, AppArt.roseBloom, AppArt.roseBud]
      : plantId === 'sunflower'
        ? ['#FFF59D', AppArt.sunflowerPetal, AppColors.warmAmber]
        : plantId === 'tulip'
          ? [AppColors.petalWhite, AppColors.auroraRose, AppColors.deepRose]
          : plantId === 'sakura'
            ? [AppColors.petalWhite, AppArt.sakuraPetal, AppColors.auroraRose]
            : [AppColors.petalWhite, AppColors.roseQuartz, AppColors.auroraRose];

  if (stage <= 3) {
    const bw = 11 + stage * 2;
    const bh = 20 + stage * 3;
    const grad = ctx.createLinearGradient(tx, ty + 2, tx, ty - bh + 4);
    grad.addColorStop(0, petalPalette[1]);
    grad.addColorStop(1, petalPalette[2]);
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.moveTo(tx, ty + 2);
    ctx.bezierCurveTo(tx - bw * 0.7, ty - bh * 0.25, tx - bw * 0.45, ty - bh * 0.75, tx, ty - bh + 4);
    ctx.bezierCurveTo(tx + bw * 0.45, ty - bh * 0.75, tx + bw * 0.7, ty - bh * 0.25, tx, ty + 2);
    ctx.fill();
    return;
  }

  const full = stage >= 5;
  const breathe = 1 + anim * 0.04;
  const length = (full ? 32 : 23) * breathe;
  const width = full ? 14.5 : 12;
  const count = plantId === 'sunflower' ? 12 : 6;

  ctx.save();
  ctx.translate(tx, ty);
  ctx.rotate(sway * 0.012);

  if (full) {
    ctx.fillStyle = withAlpha(petalPalette[2], 0.13);
    ctx.beginPath();
    ctx.arc(0, 0, length * 1.15, 0, Math.PI * 2);
    ctx.fill();
  }

  for (let i = 0; i < count; i++) {
    ctx.save();
    ctx.rotate(((Math.PI * 2) / count) * i);
    const pw = plantId === 'sunflower' ? width * 0.65 : width;
    const grad = ctx.createLinearGradient(0, -2, 0, -length);
    grad.addColorStop(0, petalPalette[0]);
    grad.addColorStop(0.45, petalPalette[1]);
    grad.addColorStop(1, petalPalette[2]);
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.moveTo(0, -2);
    ctx.bezierCurveTo(pw * 0.75, -length * 0.3, pw * 0.62, -length * 0.72, 1.2, -length);
    ctx.bezierCurveTo(-pw * 0.62, -length * 0.72, -pw * 0.75, -length * 0.3, 0, -2);
    ctx.fill();
    ctx.strokeStyle = withAlpha(AppColors.deepRose, 0.25);
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.restore();
  }

  ctx.fillStyle = plantId === 'sunflower' ? AppArt.bark : withAlpha(AppColors.auroraGold, 0.95);
  ctx.beginPath();
  ctx.arc(0, 0, full ? 5.5 : 4.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = plantId === 'sunflower' ? AppArt.sunflowerCenter : AppColors.deepRose;
  ctx.beginPath();
  ctx.arc(0, 0, 2.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

export function GardenPlantView({ plantType, stage }: { plantType: PlantType; stage: number }) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    let raf = 0;
    const start = performance.now();
    const render = (now: number) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const w = canvas.clientWidth || 190;
      const h = canvas.clientHeight || 190;
      const dpr = window.devicePixelRatio || 1;
      if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
        canvas.width = Math.round(w * dpr);
        canvas.height = Math.round(h * dpr);
      }
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        const cycle = ((now - start) % 6000) / 3000;
        const t = reduceAmbient ? 0 : Curves.easeInOut(cycle <= 1 ? cycle : 2 - cycle);
        drawPlant(ctx, w, h, plantType.id, stage, t);
      }
      if (!reduceAmbient) raf = requestAnimationFrame(render);
    };
    raf = requestAnimationFrame(render);
    return () => cancelAnimationFrame(raf);
  }, [plantType.id, stage, reduceAmbient]);

  return <canvas ref={canvasRef} style={{ width: '100%', height: '100%', display: 'block' }} aria-hidden />;
}
