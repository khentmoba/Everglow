import type { AssetData, OImageIds } from '../types/index.js';

/** Typed port of Elements.Background game.js:752 */
export class Background {
  private oImgData: AssetData;
  private oGameElementsImgData: AssetData;
  private wallId: number;
  constructor(private getCupId: ()=>number) {
    const al = (window as unknown as {assetLib:{getData(s:string):AssetData}}).assetLib;
    this.oImgData = al.getData('background');
    this.oGameElementsImgData = al.getData('gameElements');
    this.wallId = getCupId() % 5;
  }
  renderGame(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement, tableTop: { offsetY:number }): void {
    const oids = (window as unknown as {oImageIds:OImageIds}).oImageIds;
    ctx.fillStyle='rgba(0,0,0,1)'; ctx.fillRect(0,0,canvas.width,canvas.height);
    {
      const f = this.oGameElementsImgData.oData.oAtlasData[oids.tableBgBottom]!;
      const tempTop = canvas.height/4 - 220 + 193 + tableTop.offsetY*25;
      ctx.drawImage(this.oGameElementsImgData.img as CanvasImageSource,
        f.x,f.y,f.width,f.height, 0, tempTop, canvas.width, (canvas.height-tempTop)*(1+tableTop.offsetY/3)*1.1);
    }
    {
      const f = this.oGameElementsImgData.oData.oAtlasData[oids['tableBg'+this.wallId]]!;
      ctx.drawImage(this.oGameElementsImgData.img as CanvasImageSource,
        f.x,f.y,f.width,f.height, 0, canvas.height/4 - 220 + tableTop.offsetY*25, canvas.width, f.height);
    }
  }
  renderMenu(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement): void {
    ctx.drawImage(this.oImgData.img as CanvasImageSource,
      0,0,(this.oImgData.img as HTMLImageElement).width ?? canvas.width,(this.oImgData.img as HTMLImageElement).height ?? canvas.height,
      0,0,canvas.width,canvas.height);
  }
}
